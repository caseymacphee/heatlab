//
//  SummaryCard.swift
//  heatlab
//
//  Unified summary card following Weather app pattern:
//  - Pro + AI: Category-based AI insights, generated on-demand as user cycles
//  - Pro without AI: Deterministic insights with cycling
//  - Free: Deterministic insights with cycling + upsell teaser
//  - Both: Metrics row below divider
//

import SwiftUI

struct SummaryCard: View {
    @Environment(UserSettings.self) var settings

    let result: AnalysisResult
    let allSessions: [SessionWithStats]
    let isPro: Bool
    let lastSessionDate: Date?  // For inactivity insight when zero sessions in period
    let onUpgradeTap: () -> Void

    // MARK: - Deterministic Insight State
    @State private var currentInsightIndex = 0
    @State private var availableInsights: [DeterministicInsight] = []

    // MARK: - AI Insight State
    @State private var aiInsights: [AIInsightCategory: AIInsight] = [:]  // Cache
    @State private var isLoadingAIInsight = false

    private let deterministicGenerator = DeterministicInsightGenerator()
    private let aiGenerator = AnalysisInsightGenerator()

    /// Apple Intelligence availability status
    private var aiStatus: AppleIntelligenceStatus {
        AnalysisInsightGenerator.availabilityStatus
    }

    /// Whether to use AI insights (Pro + AI available)
    private var useAIInsights: Bool {
        isPro && aiStatus.isAvailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Text Section
            textSection
                .padding()

            Divider()
                .padding(.horizontal)

            // Metrics Row (always visible)
            metricsRow
                .padding()

            // Trends upsell hint (free users without comparison data)
            if !isPro && result.comparison.previous == nil {
                trendsUpsellHint
                    .padding(.horizontal)
                    .padding(.bottom)
            }
        }
        .background(Color.hlSurface)
        .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
        .onChange(of: result.filters) { _, _ in
            regenerateInsights()
            clearAICache()
        }
        .onChange(of: result.comparison.current.sessionCount) { _, _ in
            regenerateInsights()
            clearAICache()
        }
        .onAppear {
            regenerateInsights()
            if useAIInsights {
                loadCurrentAIInsight()
            }
        }
    }

    // MARK: - Deterministic Insight Helpers

    private var currentInsight: DeterministicInsight? {
        guard !availableInsights.isEmpty else { return nil }
        let safeIndex = currentInsightIndex % availableInsights.count
        return availableInsights[safeIndex]
    }

    private func cycleInsight() {
        guard availableInsights.count > 1 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentInsightIndex = (currentInsightIndex + 1) % availableInsights.count
        }
        if useAIInsights {
            loadCurrentAIInsight()
        }
    }

    private func regenerateInsights() {
        availableInsights = deterministicGenerator.generateInsights(
            from: result,
            allSessions: allSessions,
            sessionTypes: settings.manageableSessionTypes,
            temperatureUnit: settings.temperatureUnit,
            lastSessionDate: lastSessionDate
        )

        // Reset index if out of bounds
        if currentInsightIndex >= availableInsights.count {
            currentInsightIndex = 0
        }
    }

    // MARK: - AI Insight Helpers

    /// Maps a deterministic InsightCategory to its AIInsightCategory equivalent, if one exists
    private func aiCategory(for category: InsightCategory) -> AIInsightCategory? {
        switch category {
        case .recentComparison: return .recentComparison
        case .temperatureAnalysis: return .temperatureAnalysis
        case .sessionTypeComparison: return .sessionTypeComparison
        case .periodOverPeriod: return .periodOverPeriod
        case .progression: return .progression
        case .acclimation: return .acclimation
        case .peakSession, .hrConsistency, .inactivity, .volume, .zoneDominance, .zoneShift: return nil
        }
    }

    /// Current AI insight for Pro users (looked up via current deterministic insight)
    private var currentAIInsight: AIInsight? {
        guard let insight = currentInsight,
              let category = aiCategory(for: insight.category) else { return nil }
        return aiInsights[category]
    }

    /// Clear cached AI insights (called on filter/data changes)
    private func clearAICache() {
        aiInsights.removeAll()
        if currentInsightIndex >= max(availableInsights.count, 1) {
            currentInsightIndex = 0
        }
        if useAIInsights {
            loadCurrentAIInsight()
        }
    }

    /// Load AI insight for current category if not cached
    private func loadCurrentAIInsight() {
        guard let insight = currentInsight,
              let category = aiCategory(for: insight.category) else { return }

        // Already cached
        if aiInsights[category] != nil { return }

        isLoadingAIInsight = true

        Task { @MainActor in
            do {
                let text = try await aiGenerator.generateCategoryInsight(
                    category: category,
                    result: result,
                    allSessions: allSessions,
                    sessionTypes: settings.manageableSessionTypes,
                    temperatureUnit: settings.temperatureUnit
                )
                aiInsights[category] = AIInsight(
                    category: category,
                    text: text,
                    isAIGenerated: true
                )
            } catch {
                // Fall back to deterministic insight
                aiInsights[category] = AIInsight(
                    category: category,
                    text: insight.text,
                    isAIGenerated: false
                )
            }
            isLoadingAIInsight = false
        }
    }

    /// Number of insights available for cycling (always based on all available insights)
    private var insightCount: Int {
        availableInsights.count
    }
    
    // MARK: - Text Section
    
    @ViewBuilder
    private var textSection: some View {
        if isPro {
            proTextSection
        } else {
            freeTextSection
        }
    }
    
    // MARK: - Pro Text Section

    @ViewBuilder
    private var proTextSection: some View {
        if useAIInsights {
            // Pro + AI available: Show category-based AI insights with cycling
            aiInsightSection
        } else {
            // Pro but AI unavailable: Show deterministic insights with cycling
            deterministicInsightSection
        }
    }

    // MARK: - AI Insight Section

    @ViewBuilder
    private var aiInsightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                // Icon: sparkles for AI, category icon for deterministic fallback
                if let aiInsight = currentAIInsight {
                    Image(systemName: aiInsight.icon)
                        .foregroundStyle(Color.hlAccent)
                } else if let insight = currentInsight {
                    Image(systemName: insight.icon)
                        .foregroundStyle(Color.hlAccent)
                } else {
                    Image(systemName: SFSymbol.sparkles)
                        .foregroundStyle(Color.hlAccent)
                }

                Text("Insight")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                // Loading indicator
                if isLoadingAIInsight && currentAIInsight == nil {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                // Cycle controls when multiple categories available
                if insightCount > 1 {
                    Button {
                        cycleInsight()
                    } label: {
                        HStack(spacing: 4) {
                            // Page dots
                            ForEach(0..<insightCount, id: \.self) { index in
                                Circle()
                                    .fill(index == currentInsightIndex % insightCount ? Color.hlAccent : Color.hlMuted.opacity(0.5))
                                    .frame(width: 5, height: 5)
                            }
                            Image(systemName: SFSymbol.refresh)
                                .font(.caption)
                        }
                        .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Insight text
            if let aiInsight = currentAIInsight {
                Text(aiInsight.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .id("ai-\(currentInsightIndex)")  // Force view update on cycle
            } else {
                // Show deterministic while loading
                Text(currentInsight?.text ?? factualSummary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }
    
    // MARK: - Free Text Section

    private var freeTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Deterministic insights with cycling
            deterministicInsightSection

            // Upsell teaser (only when AI is available on platform)
            if aiStatus.isAvailable {
                Button(action: onUpgradeTap) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Unlock AI insights")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.hlAccent)
                            Text("Personalized takeaways from your sessions")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Image(systemName: SFSymbol.chevronRight)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Deterministic Insight Section

    @ViewBuilder
    private var deterministicInsightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let insight = currentInsight {
                    Image(systemName: insight.icon)
                        .foregroundStyle(Color.hlAccent)
                } else {
                    Image(systemName: SFSymbol.sparkles)
                        .foregroundStyle(Color.hlAccent)
                }
                Text("Insight")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                // Cycle controls when multiple insights available
                if availableInsights.count > 1 {
                    Button {
                        cycleInsight()
                    } label: {
                        HStack(spacing: 4) {
                            // Page dots
                            ForEach(0..<availableInsights.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentInsightIndex ? Color.hlAccent : Color.hlMuted.opacity(0.5))
                                    .frame(width: 5, height: 5)
                            }
                            Image(systemName: SFSymbol.refresh)
                                .font(.caption)
                        }
                        .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(currentInsight?.text ?? factualSummary)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .id(currentInsightIndex)  // Force view update on cycle
        }
    }
    
    // MARK: - Trends Upsell Hint
    
    private var trendsUpsellHint: some View {
        Button(action: onUpgradeTap) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("See week-over-week trends with Pro")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Metrics Row
    
    private var metricsRow: some View {
        HStack(spacing: 0) {
            // 1. Sessions
            metricItem(
                label: "Sessions",
                value: "\(result.comparison.current.sessionCount)",
                delta: result.comparison.sessionCountDelta.map { Double($0) },
                isPercentage: false
            )
            
            Spacer(minLength: 0)
            
            // 2. Avg Temp
            metricItem(
                label: "Avg Temp",
                value: result.comparison.current.avgTemperature > 0
                    ? formattedTemperature(result.comparison.current.avgTemperature)
                    : "--",
                delta: result.comparison.avgTemperatureDelta,
                isPercentage: false
            )
            
            Spacer(minLength: 0)
            
            // 3. Avg HR (lower is better, so invert delta color)
            metricItem(
                label: "Avg HR",
                value: result.comparison.current.avgHeartRate > 0
                    ? "\(Int(result.comparison.current.avgHeartRate)) bpm"
                    : "--",
                delta: result.comparison.avgHRDelta,
                isPercentage: true,
                invertDelta: true
            )
            
            Spacer(minLength: 0)
            
            // 4. HR Range (no delta for range)
            if let range = hrRange {
                metricItem(label: "HR Range", value: "\(range.min)–\(range.max)")
            } else {
                metricItem(label: "HR Range", value: "--")
            }
            
            // 5. Avg Calories (if enabled)
            if settings.showCaloriesInApp {
                Spacer(minLength: 0)
                
                metricItem(
                    label: "Avg Cal",
                    value: result.comparison.current.totalCalories > 0
                        ? "\(Int(result.comparison.current.totalCalories))"
                        : "--",
                    delta: result.comparison.caloriesDelta,
                    isPercentage: true
                )
            }
        }
    }
    
    private func metricItem(
        label: String,
        value: String,
        delta: Double? = nil,
        isPercentage: Bool = true,
        invertDelta: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            
            // Delta indicator (only shown when comparison data exists)
            if let delta = delta {
                MetricDeltaIndicator(
                    delta: delta,
                    isPercentage: isPercentage,
                    invertDelta: invertDelta
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var factualSummary: String {
        let comparison = result.comparison
        let sessionCount = comparison.current.sessionCount
        let periodLabel = result.filters.period.rawValue
        
        // HR-based summary
        if comparison.current.avgHeartRate > 0 {
            let avgHR = Int(comparison.current.avgHeartRate)
            
            if let range = hrRange {
                return "Past \(periodLabel): \(sessionCount) session\(sessionCount == 1 ? "" : "s"). Avg HR \(avgHR) bpm (\(range.min)–\(range.max))."
            } else {
                return "Past \(periodLabel): \(sessionCount) session\(sessionCount == 1 ? "" : "s"). Avg HR \(avgHR) bpm."
            }
        }
        
        // Temperature-based fallback
        if comparison.current.avgTemperature > 0 {
            let avgTemp = formattedTemperature(comparison.current.avgTemperature)
            return "Past \(periodLabel): \(sessionCount) session\(sessionCount == 1 ? "" : "s"). Avg temp \(avgTemp)."
        }
        
        // Session count only
        return "Past \(periodLabel): \(sessionCount) session\(sessionCount == 1 ? "" : "s") logged."
    }
    
    private var hrRange: (min: Int, max: Int)? {
        let values = result.trendPoints.map { $0.value }.filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        
        let minValue = Int(values.min() ?? 0)
        let maxValue = Int(values.max() ?? 0)
        
        // Only show range if there's meaningful variance
        guard minValue != maxValue else { return nil }
        
        return (min: minValue, max: maxValue)
    }
    
    private func formattedTemperature(_ fahrenheit: Double) -> String {
        let temp = Temperature(fahrenheit: Int(fahrenheit))
        let value = temp.value(for: settings.temperatureUnit)
        return "\(value)\(settings.temperatureUnit.rawValue)"
    }
}

// MARK: - Metric Delta Indicator

private struct MetricDeltaIndicator: View {
    let delta: Double
    var isPercentage: Bool = true
    var invertDelta: Bool = false
    
    private var isPositive: Bool {
        invertDelta ? delta < 0 : delta > 0
    }
    
    private var arrow: String {
        if delta > 0 {
            return "arrow.up"
        } else if delta < 0 {
            return "arrow.down"
        } else {
            return "minus"
        }
    }
    
    private var color: Color {
        if delta == 0 { return .secondary }
        return isPositive ? .green : .red
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: arrow)
                .font(.caption2.bold())
            
            if isPercentage {
                Text("\(Int(abs(delta)))%")
                    .font(.caption.bold())
            } else {
                Text(delta > 0 ? "+\(Int(delta))" : "\(Int(delta))")
                    .font(.caption.bold())
            }
        }
        .foregroundStyle(color)
    }
}

#Preview("Pro - With AI Insights") {
    SummaryCard(
        result: AnalysisResult(
            filters: .default,
            comparison: PeriodComparison(
                current: PeriodStats(
                    periodStart: Date(),
                    periodEnd: Date(),
                    sessionCount: 6,
                    totalDuration: 3600 * 2,
                    totalCalories: 800,
                    avgHeartRate: 61,
                    maxHeartRate: 65,
                    avgTemperature: 96
                ),
                previous: PeriodStats(
                    periodStart: Date(),
                    periodEnd: Date(),
                    sessionCount: 4,
                    totalDuration: 3600 * 1.5,
                    totalCalories: 600,
                    avgHeartRate: 65,
                    maxHeartRate: 70,
                    avgTemperature: 94
                )
            ),
            trendPoints: [
                TrendPoint(date: Date().addingTimeInterval(-86400), value: 60, temperature: 96),
                TrendPoint(date: Date(), value: 63, temperature: 96)
            ],
            acclimation: nil,
            sessionMap: [:]
        ),
        allSessions: [],
        isPro: true,
        lastSessionDate: nil,
        onUpgradeTap: {}
    )
    .padding()
    .environment(UserSettings())
}

#Preview("Pro - Multiple Categories") {
    SummaryCard(
        result: AnalysisResult(
            filters: .default,
            comparison: PeriodComparison(
                current: PeriodStats(
                    periodStart: Date(),
                    periodEnd: Date(),
                    sessionCount: 6,
                    totalDuration: 3600 * 2,
                    totalCalories: 800,
                    avgHeartRate: 61,
                    maxHeartRate: 65,
                    avgTemperature: 96
                ),
                previous: PeriodStats(
                    periodStart: Date(),
                    periodEnd: Date(),
                    sessionCount: 4,
                    totalDuration: 3600 * 1.5,
                    totalCalories: 600,
                    avgHeartRate: 65,
                    maxHeartRate: 70,
                    avgTemperature: 94
                )
            ),
            trendPoints: [
                TrendPoint(date: Date().addingTimeInterval(-86400 * 5), value: 65, temperature: 96),
                TrendPoint(date: Date().addingTimeInterval(-86400 * 3), value: 62, temperature: 96),
                TrendPoint(date: Date(), value: 58, temperature: 96)
            ],
            acclimation: nil,
            sessionMap: [:]
        ),
        allSessions: [],
        isPro: true,
        lastSessionDate: nil,
        onUpgradeTap: {}
    )
    .padding()
    .environment(UserSettings())
}

#Preview("Free - Deterministic with Cycling") {
    SummaryCard(
        result: AnalysisResult(
            filters: .default,
            comparison: PeriodComparison(
                current: PeriodStats(
                    periodStart: Date(),
                    periodEnd: Date(),
                    sessionCount: 6,
                    totalDuration: 3600 * 2,
                    totalCalories: 800,
                    avgHeartRate: 61,
                    maxHeartRate: 65,
                    avgTemperature: 96
                ),
                previous: PeriodStats(
                    periodStart: Date(),
                    periodEnd: Date(),
                    sessionCount: 4,
                    totalDuration: 3600 * 1.5,
                    totalCalories: 600,
                    avgHeartRate: 65,
                    maxHeartRate: 70,
                    avgTemperature: 94
                )
            ),
            trendPoints: [
                TrendPoint(date: Date().addingTimeInterval(-86400 * 6), value: 68, temperature: 96),
                TrendPoint(date: Date().addingTimeInterval(-86400 * 4), value: 65, temperature: 96),
                TrendPoint(date: Date().addingTimeInterval(-86400 * 2), value: 62, temperature: 96),
                TrendPoint(date: Date(), value: 58, temperature: 96)
            ],
            acclimation: nil,
            sessionMap: [:]
        ),
        allSessions: [],
        isPro: false,
        lastSessionDate: nil,
        onUpgradeTap: {}
    )
    .padding()
    .environment(UserSettings())
}
