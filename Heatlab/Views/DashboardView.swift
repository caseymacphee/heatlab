//
//  DashboardView.swift
//  heatlab
//
//  Main dashboard with overview stats
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(UserSettings.self) var settings
    @EnvironmentObject var wcReceiver: WatchConnectivityReceiver
    @Binding var selectedTab: Int

    @State private var sessions: [SessionWithStats] = []
    @State private var isLoading = true
    @State private var weekComparison: PeriodComparison?
    @State private var selectedSession: SessionWithStats?

    // Insight state
    @State private var headlineInsight: String?
    @State private var isGeneratingInsight = false

    private let analysisCalculator = AnalysisCalculator()
    private let insightGenerator = AnalysisInsightGenerator()

    /// Sessions from the last 7 days
    private var recentSessions: [SessionWithStats] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.session.startDate >= sevenDaysAgo }
    }

    @ViewBuilder
    private func ComparisonStatsGrid(comparison: PeriodComparison) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ComparisonStatItem(
                title: "Sessions",
                currentValue: "\(comparison.current.sessionCount)",
                delta: comparison.sessionCountDelta.map { Double($0) },
                isPercentage: false,
                systemIcon: SFSymbol.yoga
            )

            ComparisonStatItem(
                title: "Avg HR",
                currentValue: comparison.current.avgHeartRate > 0 ? "\(Int(comparison.current.avgHeartRate)) bpm" : "--",
                delta: comparison.avgHRDelta,
                isPercentage: true,
                invertDelta: true,
                systemIcon: SFSymbol.heartFill
            )

            ComparisonStatItem(
                title: "Duration",
                currentValue: comparison.current.formattedDuration,
                delta: comparison.durationDelta,
                isPercentage: true,
                systemIcon: SFSymbol.clock
            )

            if settings.showCaloriesInApp {
                ComparisonStatItem(
                    title: "Calories",
                    currentValue: comparison.current.totalCalories > 0 ? "\(Int(comparison.current.totalCalories))" : "--",
                    delta: comparison.caloriesDelta,
                    isPercentage: true,
                    systemIcon: SFSymbol.fireFill
                )
            } else {
                ComparisonStatItem(
                    title: "Avg Temp",
                    currentValue: comparison.current.avgTemperature > 0 ? formattedTemperature(comparison.current.avgTemperature) : "--",
                    delta: comparison.avgTemperatureDelta,
                    isPercentage: false,
                    systemIcon: SFSymbol.thermometer
                )
            }
        }
    }

    private func formattedTemperature(_ fahrenheit: Double) -> String {
        let temp = Temperature(fahrenheit: Int(fahrenheit))
        let value = temp.value(for: settings.temperatureUnit)
        return "\(value)°"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                } else if let comparison = weekComparison, comparison.current.sessionCount > 0 {
                    // MARK: - Insight Preview (taps to Analysis tab)
                    InsightPreviewCard(
                        insight: headlineInsight,
                        isGenerating: isGeneratingInsight,
                        sessionCount: comparison.current.sessionCount,
                        onTap: { selectedTab = 2 }
                    )

                    // MARK: - Last 7 Days Stats
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Last 7 Days")
                                .font(.headline)
                            Spacer()
                            if comparison.previous != nil {
                                Text("vs Previous 7 Days")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ComparisonStatsGrid(comparison: comparison)
                    }
                    .heatLabCard()

                    // MARK: - Recent Sessions (limited to 3 + "See All")
                    if !recentSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Sessions")
                                    .font(.headline)
                                Spacer()
                                if recentSessions.count > 3 {
                                    Button("See All") {
                                        selectedTab = 1
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(Color.HeatLab.coral)
                                }
                            }

                            VStack(spacing: 8) {
                                ForEach(recentSessions.prefix(3)) { session in
                                    Button {
                                        selectedSession = session
                                    } label: {
                                        SessionRowView(session: session, useRelativeTime: true)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .heatLabCard()
                    }
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: SFSymbol.yoga)
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)

                        Text("Ready to begin?")
                            .font(.title3.bold())

                        Text("Start a session on your Apple Watch to begin tracking.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: HeatLabRadius.lg))
                }
            }
            .padding()
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
            await generateHeadlineInsight()
        }
        .refreshable {
            await loadData()
            await generateHeadlineInsight()
        }
        .onChange(of: wcReceiver.lastReceivedDate) {
            Task {
                await loadData()
                await generateHeadlineInsight()
            }
        }
        .navigationDestination(item: $selectedSession) { session in
            SessionDetailView(
                session: session,
                baselineEngine: BaselineEngine(modelContext: modelContext)
            )
        }
    }
    
    private func loadData() async {
        isLoading = true
        let repo = SessionRepository(modelContext: modelContext)
        sessions = (try? await repo.fetchSessionsWithStats()) ?? []

        // DEBUG: Check session data
        print("📊 DashboardView - Total sessions: \(sessions.count)")
        print("📊 DashboardView - Sessions with HR: \(sessions.filter { $0.stats.averageHR > 0 }.count)")
        print("📊 DashboardView - Sessions without workoutUUID: \(sessions.filter { $0.session.workoutUUID == nil }.count)")
        print("📊 DashboardView - Recent sessions (last 7 days): \(recentSessions.count)")

        // Calculate "last 7 days" comparison (not calendar week)
        weekComparison = calculateLast7DaysComparison()
        print("📊 DashboardView - Last 7 days sessions: \(weekComparison?.current.sessionCount ?? 0)")

        isLoading = false
    }

    /// Calculate comparison for last 7 days vs previous 7 days (not calendar week)
    private func calculateLast7DaysComparison() -> PeriodComparison {
        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now

        // Current period: last 7 days
        let currentSessions = sessions.filter { $0.session.startDate >= sevenDaysAgo }
        let currentStats = computePeriodStats(sessions: currentSessions, start: sevenDaysAgo, end: now)

        // Previous period: 14-7 days ago
        let previousSessions = sessions.filter { $0.session.startDate >= fourteenDaysAgo && $0.session.startDate < sevenDaysAgo }
        let previousStats = computePeriodStats(sessions: previousSessions, start: fourteenDaysAgo, end: sevenDaysAgo)

        return PeriodComparison(
            current: currentStats,
            previous: previousStats.sessionCount > 0 ? previousStats : nil
        )
    }

    private func computePeriodStats(sessions: [SessionWithStats], start: Date, end: Date) -> PeriodStats {
        guard !sessions.isEmpty else {
            return PeriodStats(
                periodStart: start,
                periodEnd: end,
                sessionCount: 0,
                totalDuration: 0,
                totalCalories: 0,
                avgHeartRate: 0,
                maxHeartRate: 0,
                avgTemperature: 0
            )
        }

        let totalDuration = sessions.reduce(0) { $0 + $1.stats.duration }
        let totalCalories = sessions.reduce(0) { $0 + $1.stats.calories }

        // Only include sessions with valid HR data in heart rate averages
        let sessionsWithHR = sessions.filter { $0.stats.averageHR > 0 }
        let avgHeartRate = sessionsWithHR.isEmpty ? 0 : sessionsWithHR.reduce(0) { $0 + $1.stats.averageHR } / Double(sessionsWithHR.count)
        let maxHeartRate = sessionsWithHR.map { $0.stats.maxHR }.max() ?? 0

        let avgTemperature = sessions.reduce(0.0) { $0 + Double($1.session.roomTemperature) } / Double(sessions.count)

        return PeriodStats(
            periodStart: start,
            periodEnd: end,
            sessionCount: sessions.count,
            totalDuration: totalDuration,
            totalCalories: totalCalories,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            avgTemperature: avgTemperature
        )
    }

    @MainActor
    private func generateHeadlineInsight() async {
        // Only generate if AI is available and we have data
        guard AnalysisInsightGenerator.isAvailable,
              let comparison = weekComparison,
              comparison.current.sessionCount >= 2 else {
            return
        }

        isGeneratingInsight = true

        let result = AnalysisResult(
            filters: .default,
            comparison: comparison,
            trendPoints: [],
            acclimation: nil,
            sessionMap: [:]
        )

        do {
            headlineInsight = try await insightGenerator.generateInsight(
                for: result,
                temperatureName: nil,
                classTypeName: nil
            )
        } catch {
            // Silently fail - insight is optional enhancement
            print("Failed to generate headline insight: \(error)")
        }

        isGeneratingInsight = false
    }
}

#Preview {
    NavigationStack {
        DashboardView(selectedTab: .constant(0))
    }
    .modelContainer(for: HeatSession.self, inMemory: true)
    .environment(UserSettings())
    .environmentObject(WatchConnectivityReceiver.shared)
}

