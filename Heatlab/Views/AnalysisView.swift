//
//  AnalysisView.swift
//  heatlab
//
//  Multi-dimensional analysis with period comparisons and AI insights
//

import SwiftUI
import SwiftData
import Charts

struct AnalysisView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(UserSettings.self) var settings
    @EnvironmentObject var wcReceiver: WatchConnectivityReceiver
    
    // Filter state
    @State private var selectedPeriod: AnalysisPeriod = .week
    @State private var selectedTemperature: TemperatureBucket? = nil
    @State private var selectedClassType: UUID? = nil
    
    // Data state
    @State private var sessions: [SessionWithStats] = []
    @State private var analysisResult: AnalysisResult?
    @State private var isLoading = true
    
    // AI insight state
    @State private var aiInsight: String?
    @State private var isGeneratingInsight = false
    @State private var insightGenerationTask: Task<Void, Never>?
    
    private let calculator = AnalysisCalculator()
    private let insightGenerator = AnalysisInsightGenerator()
    
    private var filters: AnalysisFilters {
        AnalysisFilters(
            temperatureBucket: selectedTemperature,
            sessionTypeId: selectedClassType,
            period: selectedPeriod
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Filter Bar
                filterSection

                if isLoading {
                    loadingView
                } else if let result = analysisResult {
                    if result.hasData {
                        // MARK: - AI Insight Card (handles all states internally)
                        insightSection

                        // MARK: - Comparison Card
                        ComparisonCard(comparison: result.comparison, period: selectedPeriod)

                        // MARK: - No Prior Period Data Hint
                        if !result.hasComparison {
                            noPriorPeriodHint
                        }

                        // MARK: - Trend Chart
                        trendChartSection(result: result)

                        // MARK: - Acclimation Signal
                        if let acclimation = result.acclimation {
                            AcclimationCardView(signal: acclimation)
                        } else if result.comparison.current.sessionCount < 5 {
                            // Hint about needing more sessions for acclimation
                            acclimationHint(sessionsNeeded: 5 - result.comparison.current.sessionCount)
                        }
                    } else {
                        // MARK: - Empty State
                        emptyStateView
                    }
                }
            }
            .padding()
            .padding(.bottom, 20)  // Extra padding to avoid tab bar clipping
        }
        .navigationTitle("Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            updateAnalysis()
        }
        .onChange(of: selectedTemperature) { _, _ in
            updateAnalysis()
        }
        .onChange(of: selectedClassType) { _, _ in
            updateAnalysis()
        }
        .onChange(of: wcReceiver.lastReceivedDate) {
            Task {
                await loadData()
            }
        }
        .refreshable {
            await loadData()
        }
    }
    
    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Period Picker (keep visible - primary control)
            Picker("Period", selection: $selectedPeriod) {
                ForEach(AnalysisPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            // Compact filter pills for Temperature + Class Type
            FilterPillRow(
                selectedTemperature: $selectedTemperature,
                selectedClassType: $selectedClassType
            )
        }
    }
    
    private var selectedClassTypeName: String? {
        guard let id = selectedClassType else { return nil }
        return settings.sessionTypeName(for: id)
    }
    
    // MARK: - Trend Chart

    private func trendChartSection(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Trend")
                .font(.headline)

            if result.trendPoints.isEmpty {
                ContentUnavailableView(
                    "No Data for Period",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("Complete sessions \(periodDescription) to see trends")
                )
                .frame(height: 200)
            } else {
                // Chart summary row
                chartSummary(for: result.trendPoints)

                Chart(result.trendPoints) { point in
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
                }
                .chartYAxisLabel("Avg Heart Rate (bpm)")
                .chartYScale(domain: yAxisDomain(for: result.trendPoints))
                .chartXScale(domain: xAxisDomain(for: result.filters.period))
                .chartXAxis {
                    AxisMarks(values: xAxisValues(for: result.filters.period)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: xAxisLabelFormat(for: result.filters.period))
                    }
                }
                .frame(height: 220)
                .padding(.bottom, 4)
            }
        }
        .heatLabCard()
    }

    @ViewBuilder
    private func chartSummary(for points: [TrendPoint]) -> some View {
        let values = points.map { $0.value }.filter { $0 > 0 }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let avgValue = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)

        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Range")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(minValue > 0 ? "\(Int(minValue))-\(Int(maxValue)) bpm" : "--")
                    .font(.subheadline.bold())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Average")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(avgValue > 0 ? "\(Int(avgValue)) bpm" : "--")
                    .font(.subheadline.bold())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Sessions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("\(points.count)")
                    .font(.subheadline.bold())
            }

            Spacer()
        }
        .padding(.bottom, 4)
    }
    
    private var periodDescription: String {
        switch selectedPeriod {
        case .week: return "this week"
        case .month: return "this month"
        case .year: return "this year"
        }
    }
    
    // MARK: - AI Insight Section

    @ViewBuilder
    private var insightSection: some View {
        let state: AIInsightState = {
            if !AnalysisInsightGenerator.isAvailable {
                return .unavailable
            }
            if let insight = aiInsight {
                return .ready(insight)
            }
            if isGeneratingInsight {
                return .generating
            }
            if let result = analysisResult, result.comparison.current.sessionCount < 2 {
                return .insufficientData(sessionsNeeded: 2 - result.comparison.current.sessionCount)
            }
            return .generating
        }()

        AIInsightSection(state: state) {
            scheduleInsightGeneration()
        }
        .animation(.easeInOut(duration: 0.3), value: aiInsight)
    }
    
    // MARK: - Loading & Empty States
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading analysis...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Sessions Found",
            systemImage: "flame.fill",
            description: Text(emptyStateDescription)
        )
        .frame(height: 250)
    }
    
    private var emptyStateDescription: String {
        var parts: [String] = []
        
        if let temp = selectedTemperature {
            parts.append("at \(temp.displayName)")
        }
        if let typeName = selectedClassTypeName {
            parts.append("for \(typeName)")
        }
        parts.append(periodDescription)
        
        if parts.isEmpty {
            return "Complete some sessions to see analysis"
        }
        return "No sessions found \(parts.joined(separator: " "))"
    }
    
    // MARK: - Context Hints

    private var noPriorPeriodHint: some View {
        Text("Comparison data will appear next \(selectedPeriod.rawValue.lowercased())")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
    
    private func acclimationHint(sessionsNeeded: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: SFSymbol.fireFill)
                .foregroundStyle(Color.HeatLab.coral)

            VStack(alignment: .leading, spacing: 2) {
                Text("Building Your Heat Baseline")
                    .font(.subheadline.bold())
                Text("\(sessionsNeeded) more session\(sessionsNeeded == 1 ? "" : "s") needed to track heat acclimation progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .heatLabHintCard(color: Color.HeatLab.coral)
    }
    
    // MARK: - Chart Helpers

    private var chartGradient: LinearGradient {
        LinearGradient.heatLabChart
    }

    private func yAxisDomain(for points: [TrendPoint]) -> ClosedRange<Double> {
        guard !points.isEmpty else { return 100...180 }
        let values = points.map { $0.value }
        let minVal = max(60, (values.min() ?? 100) - 10)
        let maxVal = (values.max() ?? 180) + 10
        return minVal...maxVal
    }

    private func pointColor(for temperature: Int) -> Color {
        Color.HeatLab.temperature(fahrenheit: temperature)
    }
    
    private func formattedTemp(_ fahrenheit: Int) -> String {
        let temp = Temperature(fahrenheit: fahrenheit)
        let value = temp.value(for: settings.temperatureUnit)
        return "\(value)°"
    }
    
    // MARK: - X-Axis Helpers
    
    private func xAxisDomain(for period: AnalysisPeriod) -> ClosedRange<Date> {
        let (start, end) = calculator.periodDateRange(for: period, offset: 0)
        return start...end
    }
    
    private func xAxisValues(for period: AnalysisPeriod) -> [Date] {
        let (start, end) = calculator.periodDateRange(for: period, offset: 0)
        let calendar = Calendar.current
        
        switch period {
        case .week:
            // Show each day of the week
            var dates: [Date] = []
            var currentDate = start
            while currentDate <= end {
                dates.append(currentDate)
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDate
            }
            return dates
            
        case .month:
            // Show approximately weekly intervals (every 7 days)
            var dates: [Date] = [start]
            var currentDate = start
            while currentDate < end {
                guard let nextDate = calendar.date(byAdding: .day, value: 7, to: currentDate) else { break }
                if nextDate <= end {
                    dates.append(nextDate)
                }
                currentDate = nextDate
            }
            if dates.last != end {
                dates.append(end)
            }
            return dates
            
        case .year:
            // Show monthly intervals
            var dates: [Date] = [start]
            var currentDate = start
            while currentDate < end {
                guard let nextDate = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
                if nextDate <= end {
                    dates.append(nextDate)
                }
                currentDate = nextDate
            }
            if dates.last != end {
                dates.append(end)
            }
            return dates
        }
    }
    
    private func xAxisLabelFormat(for period: AnalysisPeriod) -> Date.FormatStyle {
        switch period {
        case .week:
            // Format as M/d (e.g., "11/2", "11/3")
            return Date.FormatStyle()
                .month(.twoDigits)
                .day(.twoDigits)
            
        case .month:
            // Format as M/d for month view
            return Date.FormatStyle()
                .month(.twoDigits)
                .day(.twoDigits)
            
        case .year:
            // Format as M/d for year view (compact)
            return Date.FormatStyle()
                .month(.twoDigits)
                .day(.twoDigits)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        let repo = SessionRepository(modelContext: modelContext)
        sessions = (try? await repo.fetchSessionsWithStats()) ?? []

        // DEBUG: Check session data
        print("📊 AnalysisView - Total sessions: \(sessions.count)")
        print("📊 AnalysisView - Sessions with HR: \(sessions.filter { $0.stats.averageHR > 0 }.count)")
        print("📊 AnalysisView - Sessions without workoutUUID: \(sessions.filter { $0.session.workoutUUID == nil }.count)")

        updateAnalysis()
        isLoading = false
    }
    
    private func updateAnalysis() {
        analysisResult = calculator.analyze(sessions: sessions, filters: filters)

        // DEBUG: Check analysis results
        if let result = analysisResult {
            print("📊 AnalysisView - After filtering: \(result.comparison.current.sessionCount) sessions")
            print("📊 AnalysisView - hasData: \(result.hasData)")
            print("📊 AnalysisView - hasComparison: \(result.hasComparison)")
        }

        // Clear existing insight and trigger new generation with debounce
        aiInsight = nil
        scheduleInsightGeneration()
    }
    
    private func scheduleInsightGeneration() {
        // Don't generate if AI not available
        guard AnalysisInsightGenerator.isAvailable else { return }
        
        // Cancel any pending insight generation
        insightGenerationTask?.cancel()
        
        // Debounce: wait a short moment before generating to avoid rapid requests
        insightGenerationTask = Task {
            // Small delay to debounce rapid filter changes
            try? await Task.sleep(for: .milliseconds(300))
            
            guard !Task.isCancelled else { return }
            
            await generateInsight()
        }
    }
    
    @MainActor
    private func generateInsight() async {
        guard let result = analysisResult, result.hasData else {
            aiInsight = nil
            return
        }
        
        isGeneratingInsight = true
        
        do {
            let insight = try await insightGenerator.generateInsight(
                for: result,
                temperatureName: selectedTemperature?.displayName,
                classTypeName: selectedClassTypeName
            )
            
            // Only update if we haven't been cancelled (filters didn't change)
            if !Task.isCancelled {
                withAnimation {
                    aiInsight = insight
                }
            }
        } catch {
            // Silently fail - insight is optional enhancement
            print("Failed to generate insight: \(error)")
        }
        
        isGeneratingInsight = false
    }
}

#Preview {
    NavigationStack {
        AnalysisView()
    }
    .modelContainer(for: HeatSession.self, inMemory: true)
    .environment(UserSettings())
    .environmentObject(WatchConnectivityReceiver.shared)
}
