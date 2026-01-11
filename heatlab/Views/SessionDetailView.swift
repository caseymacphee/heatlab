//
//  SessionDetailView.swift
//  heatlab
//
//  Detailed view for a single session
//

import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) var modelContext
    let session: SessionWithStats
    let baselineEngine: BaselineEngine
    
    @State private var isGeneratingSummary = false
    @State private var localAiSummary: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with temperature badge
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.session.classType?.rawValue ?? "Heated Class")
                            .font(.title2.bold())
                        Text(session.session.startDate.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TemperatureBadge(temperature: session.session.roomTemperature, size: .large)
                }
                
                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(
                        title: "Duration",
                        value: formatDuration(session.stats.duration),
                        icon: "clock",
                        iconColor: .blue
                    )
                    StatCard(
                        title: "Avg HR",
                        value: "\(Int(session.stats.averageHR)) bpm",
                        icon: "heart.fill",
                        iconColor: .red
                    )
                    StatCard(
                        title: "Max HR",
                        value: "\(Int(session.stats.maxHR)) bpm",
                        icon: "heart.fill",
                        iconColor: .pink
                    )
                    StatCard(
                        title: "Calories",
                        value: "\(Int(session.stats.calories)) kcal",
                        icon: "flame.fill",
                        iconColor: .orange
                    )
                }
                
                // Min HR and range
                if session.stats.minHR > 0 {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Heart Rate Range")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(session.stats.minHR)) - \(Int(session.stats.maxHR)) bpm")
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Baseline Comparison
                BaselineComparisonView(comparison: baselineEngine.compareToBaseline(session: session))
                
                // AI Summary Section
                aiSummarySection
                
                // Notes (if available)
                if let notes = session.session.userNotes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Update baseline when viewing session
            baselineEngine.updateBaseline(for: session.session, averageHR: session.stats.averageHR)
        }
    }
    
    @ViewBuilder
    private var aiSummarySection: some View {
        let displaySummary = localAiSummary ?? session.session.aiSummary
        
        if let summary = displaySummary {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("AI Summary")
                        .font(.headline)
                    Spacer()
                    Button {
                        generateSummary()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .disabled(isGeneratingSummary)
                }
                
                Text(summary)
                    .font(.body)
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            // Generate summary button
            Button {
                generateSummary()
            } label: {
                HStack {
                    if isGeneratingSummary {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGeneratingSummary ? "Generating..." : "Generate AI Summary")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.opacity(0.1))
                .foregroundStyle(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isGeneratingSummary)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func generateSummary() {
        guard !isGeneratingSummary else { return }
        
        isGeneratingSummary = true
        let comparison = baselineEngine.compareToBaseline(session: session)
        
        Task {
            do {
                let summary: String
                if #available(iOS 26.0, *), SummaryGenerator.isAvailable {
                    let generator = SummaryGenerator()
                    summary = try await generator.generateSummary(for: session, comparison: comparison)
                } else {
                    // Fallback for devices without Foundation Models
                    summary = SummaryGeneratorFallback.generateBasicSummary(for: session, comparison: comparison)
                }
                
                // Update the session with the summary
                await MainActor.run {
                    session.session.aiSummary = summary
                    localAiSummary = summary
                    try? modelContext.save()
                    isGeneratingSummary = false
                }
            } catch {
                print("Failed to generate summary: \(error)")
                await MainActor.run {
                    // Use fallback on error
                    let summary = SummaryGeneratorFallback.generateBasicSummary(for: session, comparison: comparison)
                    session.session.aiSummary = summary
                    localAiSummary = summary
                    try? modelContext.save()
                    isGeneratingSummary = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(
            session: SessionWithStats(
                session: {
                    let s = HeatSession(startDate: Date(), roomTemperature: 102)
                    s.classType = .heatedVinyasa
                    s.aiSummary = "Great session! You maintained a strong, consistent effort throughout this heated vinyasa class. Your heart rate stayed in your typical range for 102°F sessions."
                    return s
                }(),
                workout: nil,
                stats: SessionStats(averageHR: 145, maxHR: 168, minHR: 95, calories: 387, duration: 2732)
            ),
            baselineEngine: BaselineEngine(modelContext: try! ModelContainer(for: HeatSession.self).mainContext)
        )
    }
}
