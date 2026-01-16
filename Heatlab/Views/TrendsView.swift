//
//  TrendsView.swift
//  heatlab
//
//  Displays trends over time with charts
//

import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(UserSettings.self) var settings
    @EnvironmentObject var wcReceiver: WatchConnectivityReceiver
    @State private var selectedBucket: TemperatureBucket = .veryHot
    @State private var trendData: [TrendPoint] = []
    @State private var acclimation: AcclimationSignal?
    @State private var sessions: [SessionWithStats] = []
    @State private var isLoading = true
    
    private let calculator = TrendCalculator()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Temperature Bucket Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Temperature Range")
                        .font(.headline)
                    
                    Picker("Temperature Range", selection: $selectedBucket) {
                        ForEach(TemperatureBucket.allCases, id: \.self) {
                            Text($0.displayName)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Intensity Over Time Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Average HR Over Time")
                        .font(.headline)
                    
                    if isLoading {
                        ProgressView()
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                    } else if trendData.isEmpty {
                        ContentUnavailableView(
                            "No Sessions Yet",
                            systemImage: "flame",
                            description: Text("Complete sessions at \(selectedBucket.displayName) to see trends")
                        )
                        .frame(height: 200)
                    } else {
                        Chart(trendData) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("HR", point.value)
                            )
                            .foregroundStyle(chartGradient)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("HR", point.value)
                            )
                            .foregroundStyle(pointColor(for: point.temperature))
                            .annotation(position: .top, spacing: 4) {
                                Text(formattedTemp(point.temperature))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .chartYAxisLabel("Avg Heart Rate (bpm)")
                        .chartYScale(domain: yAxisDomain)
                        .frame(height: 220)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Acclimation Signal
                if let acclimation = acclimation {
                    AcclimationCardView(signal: acclimation)
                }
                
                // Session count by bucket
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sessions by Temperature")
                        .font(.headline)
                    
                    ForEach(TemperatureBucket.allCases, id: \.self) { bucket in
                        let count = sessions.filter { $0.session.temperatureBucket == bucket }.count
                        HStack {
                            Text(bucket.displayName)
                            Spacer()
                            Text("\(count) sessions")
                                .foregroundStyle(.secondary)
                            
                            // Progress bar
                            let maxCount = max(1, sessions.count)
                            GeometryReader { geo in
                                Capsule()
                                    .fill(bucketColor(bucket).opacity(0.3))
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(bucketColor(bucket))
                                            .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxCount))
                                    }
                            }
                            .frame(width: 60, height: 8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle("Trends")
        .task {
            await loadData()
        }
        .onChange(of: selectedBucket) { _, _ in
            updateTrends()
        }
        .refreshable {
            await loadData()
        }
        .onChange(of: wcReceiver.lastReceivedDate) {
            Task {
                await loadData()
            }
        }
    }
    
    /// Format temperature for chart annotation (compact)
    private func formattedTemp(_ fahrenheit: Int) -> String {
        let temp = Temperature(fahrenheit: fahrenheit)
        let value = temp.value(for: settings.temperatureUnit)
        return "\(value)°"
    }
    
    private var chartGradient: LinearGradient {
        LinearGradient(
            colors: [.orange, .red],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var yAxisDomain: ClosedRange<Double> {
        guard !trendData.isEmpty else { return 100...180 }
        let values = trendData.map { $0.value }
        let minVal = max(60, (values.min() ?? 100) - 10)
        let maxVal = (values.max() ?? 180) + 10
        return minVal...maxVal
    }
    
    private func pointColor(for temperature: Int) -> Color {
        switch temperature {
        case ..<90: return .yellow
        case 90..<100: return .orange
        case 100..<105: return .red
        default: return .pink
        }
    }
    
    private func bucketColor(_ bucket: TemperatureBucket) -> Color {
        switch bucket {
        case .warm: return .yellow
        case .hot: return .orange
        case .veryHot: return .red
        case .extreme: return .pink
        }
    }
    
    private func loadData() async {
        isLoading = true
        let repo = SessionRepository(modelContext: modelContext)
        sessions = (try? await repo.fetchSessionsWithStats()) ?? []
        updateTrends()
        isLoading = false
    }
    
    private func updateTrends() {
        trendData = calculator.calculateIntensityTrend(sessions: sessions, bucket: selectedBucket)
        acclimation = calculator.calculateAcclimation(sessions: sessions, bucket: selectedBucket)
    }
}

#Preview {
    NavigationStack {
        TrendsView()
    }
    .modelContainer(for: HeatSession.self, inMemory: true)
    .environment(UserSettings())
    .environmentObject(WatchConnectivityReceiver.shared)
}
