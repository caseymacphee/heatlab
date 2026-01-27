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
    @Environment(SubscriptionManager.self) var subscriptionManager
    @EnvironmentObject var wcReceiver: WatchConnectivityReceiver
    @Binding var selectedTab: Int
    @Binding var navigationPath: NavigationPath

    @State private var sessions: [SessionWithStats] = []
    @State private var isLoading = true
    @State private var weekComparison: PeriodComparison?
    @State private var analysisResult: AnalysisResult?
    @State private var claimableWorkoutCount: Int = 0
    @State private var showingClaimList = false

    private let analysisCalculator = AnalysisCalculator()

    /// Sessions from the Past 7 Days (inclusive of full 7th day)
    private var recentSessions: [SessionWithStats] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
        return sessions.filter { $0.session.startDate >= sevenDaysAgo }
    }

    @ViewBuilder
    private func StatsGrid(comparison: PeriodComparison, trendPoints: [TrendPoint]) -> some View {
        let hrRange = computeHRRange(from: trendPoints)
        
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            // 1. Sessions
            StatItem(
                title: "Sessions",
                value: "\(comparison.current.sessionCount)",
                systemIcon: SFSymbol.yoga
            )

            // 2. Avg Temp
            StatItem(
                title: "Avg Temp",
                value: comparison.current.avgTemperature > 0 ? formattedTemperature(comparison.current.avgTemperature) : "--",
                systemIcon: SFSymbol.thermometer
            )

            // 3. Avg HR
            StatItem(
                title: "Avg HR",
                value: comparison.current.avgHeartRate > 0 ? "\(Int(comparison.current.avgHeartRate)) bpm" : "--",
                systemIcon: SFSymbol.heartFill
            )

            // 4. Calories OR HR Range (conditional)
            if settings.showCaloriesInApp {
                StatItem(
                    title: "Calories",
                    value: comparison.current.totalCalories > 0 ? "\(Int(comparison.current.totalCalories))" : "--",
                    systemIcon: SFSymbol.fireFill
                )
            } else {
                StatItem(
                    title: "HR Range",
                    value: hrRange != nil ? "\(hrRange!.min)–\(hrRange!.max)" : "--",
                    systemIcon: SFSymbol.waveform
                )
            }
        }
    }
    
    private func computeHRRange(from trendPoints: [TrendPoint]) -> (min: Int, max: Int)? {
        let values = trendPoints.map { $0.value }.filter { $0 > 0 }
        guard values.count > 1 else { return nil }
        
        let minValue = Int(values.min() ?? 0)
        let maxValue = Int(values.max() ?? 0)
        
        guard minValue != maxValue else { return nil }
        return (min: minValue, max: maxValue)
    }

    private func formattedTemperature(_ fahrenheit: Double) -> String {
        let temp = Temperature(fahrenheit: Int(fahrenheit))
        let value = temp.value(for: settings.temperatureUnit)
        return "\(value)\(settings.temperatureUnit.rawValue)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                } else if let comparison = weekComparison, comparison.current.sessionCount > 0 {
                    // MARK: - Claim Workouts CTA (when claimable workouts exist)
                    if claimableWorkoutCount > 0 {
                        ClaimWorkoutsCTA(count: claimableWorkoutCount) {
                            showingClaimList = true
                        }
                    }
                    
                    // MARK: - Insight Preview (taps to Analysis tab)
                    InsightPreviewCard(
                        result: analysisResult,
                        isPro: subscriptionManager.isPro,
                        aiInsight: nil,  // AI insights generated on Analysis view
                        onTap: { selectedTab = 2 }
                    )

                    // MARK: - Past 7 Days Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Past 7 Days")
                            .font(.headline)

                        StatsGrid(comparison: comparison, trendPoints: analysisResult?.trendPoints ?? [])
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
                                    .foregroundStyle(Color.hlAccent)
                                }
                            }

                            VStack(spacing: 8) {
                                ForEach(recentSessions.prefix(3)) { session in
                                    NavigationLink(value: session) {
                                        SessionRowView(session: session)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .heatLabCard()
                    }
                } else {
                    // MARK: - Claim Workouts CTA (also shown in empty state)
                    if claimableWorkoutCount > 0 {
                        ClaimWorkoutsCTA(count: claimableWorkoutCount) {
                            showingClaimList = true
                        }
                    }
                    
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: SFSymbol.mindAndBody)
                            .font(.system(size: 48))
                            .foregroundStyle(Color.hlMuted)

                        Text("No sessions yet")
                            .font(.title3.bold())

                        Text("Start tracking your practice to see insights here.")
                            .font(.subheadline)
                            .foregroundStyle(Color.hlMuted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity)
                    .background(Color.hlSurface)
                    .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
                }
            }
            .padding()
        }
        .background(Color.hlBackground)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .onChange(of: wcReceiver.lastReceivedDate) {
            Task {
                await loadData()
            }
        }
        .navigationDestination(for: SessionWithStats.self) { session in
            SessionDetailView(
                session: session,
                baselineEngine: BaselineEngine(modelContext: modelContext)
            )
        }
        .navigationDestination(isPresented: $showingClaimList) {
            ClaimListView()
        }
        .onChange(of: navigationPath.count) { oldCount, newCount in
            // Reset showingClaimList when navigation path is cleared (e.g., when switching tabs)
            if newCount == 0 && oldCount > 0 {
                showingClaimList = false
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        let repo = SessionRepository(modelContext: modelContext)
        
        // Request HealthKit read authorization (no-op if already granted)
        try? await repo.requestHealthKitAuthorization()
        
        // Dashboard shows "Past 7 Days" which is the free tier, so we fetch all sessions
        // and filter locally (needed for previous period comparison)
        sessions = (try? await repo.fetchAllSessionsWithStats()) ?? []

        // DEBUG: Check session data
        print("📊 DashboardView - Total sessions: \(sessions.count)")
        print("📊 DashboardView - Sessions with HR: \(sessions.filter { $0.stats.averageHR > 0 }.count)")
        print("📊 DashboardView - Recent sessions (Past 7 Days): \(recentSessions.count)")

        // Calculate "Past 7 Days" comparison (not calendar week)
        weekComparison = calculateLast7DaysComparison()
        print("📊 DashboardView - Past 7 Days sessions: \(weekComparison?.current.sessionCount ?? 0)")

        // Generate analysis result for insight card
        if let comparison = weekComparison, comparison.current.sessionCount > 0 {
            analysisResult = analysisCalculator.analyze(
                sessions: sessions,
                filters: AnalysisFilters(temperatureBucket: nil, sessionTypeId: nil, period: .week),
                isPro: subscriptionManager.isPro
            )
        } else {
            analysisResult = nil
        }
        
        // Check for claimable workouts from Apple Health
        let importer = HealthKitImporter(modelContext: modelContext)
        do {
            claimableWorkoutCount = try await importer.claimableWorkoutCount(
                isPro: subscriptionManager.isPro,
                enabledTypes: settings.enabledWorkoutTypes
            )
            print("📊 DashboardView - Claimable workouts: \(claimableWorkoutCount)")
        } catch {
            print("📊 DashboardView - Failed to fetch claimable workouts: \(error)")
            claimableWorkoutCount = 0
        }

        isLoading = false
    }

    /// Calculate comparison for Past 7 Days vs previous 7 days (not calendar week)
    /// Uses start of day to ensure full days are included
    private func calculateLast7DaysComparison() -> PeriodComparison {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: startOfToday) ?? startOfToday

        // Current period: Past 7 Days (inclusive of full 7th day)
        let currentSessions = sessions.filter { $0.session.startDate >= sevenDaysAgo }
        let currentStats = computePeriodStats(sessions: currentSessions, start: sevenDaysAgo, end: now)

        // Previous period: 14-7 days ago (inclusive of full 14th day)
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

        // Only include sessions with temperature data in temperature average
        let sessionsWithTemp = sessions.filter { $0.session.roomTemperature != nil }
        let avgTemperature = sessionsWithTemp.isEmpty ? 0 : sessionsWithTemp.reduce(0.0) { $0 + Double($1.session.roomTemperature!) } / Double(sessionsWithTemp.count)

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

}

// MARK: - Claim Workouts CTA

struct ClaimWorkoutsCTA: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: SFSymbol.claimFill)
                    .font(.title2)
                    .foregroundStyle(Color.hlAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(count == 1 ? "1 Workout to Claim" : "\(count) Workouts to Claim")
                        .font(.headline)
                        .foregroundStyle(Color.hlText)

                    Text("From Apple Health")
                        .font(.caption)
                        .foregroundStyle(Color.hlMuted)
                }

                Spacer()

                Image(systemName: SFSymbol.chevronRight)
                    .font(.caption)
                    .foregroundStyle(Color.hlMuted)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: HLRadius.card)
                    .fill(Color.hlAccent.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Item

private struct StatItem: View {
    let title: String
    let value: String
    let systemIcon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: systemIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        DashboardView(selectedTab: .constant(0), navigationPath: .constant(NavigationPath()))
    }
    .modelContainer(for: WorkoutSession.self, inMemory: true)
    .environment(UserSettings())
    .environment(SubscriptionManager())
    .environmentObject(WatchConnectivityReceiver.shared)
}

#Preview("Claim CTA") {
    VStack {
        ClaimWorkoutsCTA(count: 3) { }
        ClaimWorkoutsCTA(count: 1) { }
    }
    .padding()
}

