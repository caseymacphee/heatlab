//
//  InsightPreviewCard.swift
//  heatlab
//
//  Compact insight preview card for Dashboard - tappable to navigate to Analysis
//
//  Shows deterministic pattern-based insights with cycling capability
//  Pro users with AI: Shows AI-generated insights with cycling
//

import SwiftUI

struct InsightPreviewCard: View {
    @Environment(UserSettings.self) var settings

    let result: AnalysisResult?
    let allSessions: [SessionWithStats]
    let isPro: Bool
    let lastSessionDate: Date?  // For inactivity insight generation when zero sessions in period
    let onTap: () -> Void

    // MARK: - Deterministic Insight State
    @State private var currentInsightIndex = 0
    @State private var availableInsights: [DeterministicInsight] = []

    // MARK: - AI Insight State
    @State private var aiInsights: [AIInsightCategory: AIInsight] = [:]  // Cache
    @State private var applicableCategories: [AIInsightCategory] = []
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
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Icon: AI sparkles or deterministic icon
                    if useAIInsights, let aiInsight = currentAIInsight {
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
                    Spacer()

                    // Loading indicator for AI
                    if useAIInsights && isLoadingAIInsight && currentAIInsight == nil {
                        ProgressView()
                            .scaleEffect(0.6)
                    }

                    // Cycle button when multiple insights available
                    if insightCount > 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                cycleInsight()
                            }
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

                if let result = result, result.comparison.current.sessionCount > 0 {
                    // Primary insight text
                    Text(displayText(from: result))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .id(currentInsightIndex)  // Force view update on cycle

                    // Secondary text
                    Text(secondaryText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Tap to view detailed analysis")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(LinearGradient.insight)
            .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
        }
        .buttonStyle(.plain)
        .onChange(of: result?.filters) { _, _ in
            regenerateInsights()
            clearAICache()
        }
        .onChange(of: result?.comparison.current.sessionCount) { _, _ in
            regenerateInsights()
            clearAICache()
        }
        .onAppear {
            regenerateInsights()
            updateApplicableCategories()
            // Load first AI insight for Pro users
            if useAIInsights && !applicableCategories.isEmpty {
                loadCurrentAIInsight()
            }
        }
    }

    private var currentInsight: DeterministicInsight? {
        guard !availableInsights.isEmpty else { return nil }
        let safeIndex = currentInsightIndex % availableInsights.count
        return availableInsights[safeIndex]
    }

    private func cycleInsight() {
        if useAIInsights {
            cycleAIInsight()
        } else {
            cycleDeterministicInsight()
        }
    }

    private func cycleDeterministicInsight() {
        guard availableInsights.count > 1 else { return }
        currentInsightIndex = (currentInsightIndex + 1) % availableInsights.count
    }

    private func regenerateInsights() {
        guard let result = result else {
            availableInsights = []
            currentInsightIndex = 0
            return
        }

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

        updateApplicableCategories()
    }

    // MARK: - AI Insight Helpers

    /// Current AI insight for Pro users
    private var currentAIInsight: AIInsight? {
        guard !applicableCategories.isEmpty else { return nil }
        let safeIndex = currentInsightIndex % applicableCategories.count
        let category = applicableCategories[safeIndex]
        return aiInsights[category]
    }

    /// Update the list of applicable AI categories based on available deterministic insights
    private func updateApplicableCategories() {
        applicableCategories = availableInsights.compactMap { insight -> AIInsightCategory? in
            switch insight.category {
            case .recentComparison: return .recentComparison
            case .temperatureAnalysis: return .temperatureAnalysis
            case .sessionTypeComparison: return .sessionTypeComparison
            case .periodOverPeriod: return .periodOverPeriod
            case .progression: return .progression
            case .acclimation: return .acclimation
            case .peakSession, .hrConsistency, .inactivity, .volume: return nil
            }
        }
    }

    /// Clear cached AI insights
    private func clearAICache() {
        aiInsights.removeAll()
        if currentInsightIndex >= max(applicableCategories.count, 1) {
            currentInsightIndex = 0
        }
        if useAIInsights && !applicableCategories.isEmpty {
            loadCurrentAIInsight()
        }
    }

    /// Cycle to next AI insight category
    private func cycleAIInsight() {
        guard applicableCategories.count > 1 else { return }
        currentInsightIndex = (currentInsightIndex + 1) % applicableCategories.count
        loadCurrentAIInsight()
    }

    /// Load AI insight for current category if not cached
    private func loadCurrentAIInsight() {
        guard let result = result, !applicableCategories.isEmpty else { return }
        let safeIndex = currentInsightIndex % applicableCategories.count
        let category = applicableCategories[safeIndex]

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
                if let deterministicInsight = availableInsights.first(where: { $0.category == category.deterministicCategory }) {
                    aiInsights[category] = AIInsight(
                        category: category,
                        text: deterministicInsight.text,
                        isAIGenerated: false
                    )
                }
            }
            isLoadingAIInsight = false
        }
    }

    /// Number of insights available for cycling
    private var insightCount: Int {
        useAIInsights ? applicableCategories.count : availableInsights.count
    }

    private func displayText(from result: AnalysisResult) -> String {
        // Pro users with AI: show AI insight text (truncated for preview)
        if useAIInsights, let aiInsight = currentAIInsight {
            return truncateForPreview(aiInsight.text)
        }

        // Use deterministic insight
        if let insight = currentInsight {
            return insight.text
        }

        // Ultimate fallback
        return factualInsight(from: result)
    }

    private var secondaryText: String {
        if useAIInsights && currentAIInsight != nil {
            return "Tap for full insight"
        }
        return "Tap for details"
    }

    /// Truncate text for preview display
    private func truncateForPreview(_ text: String) -> String {
        // Find first sentence ending
        if let range = text.range(of: ".", options: .literal) {
            let sentence = String(text[..<range.lowerBound])
            // If sentence is reasonable length, use it
            if sentence.count > 20 && sentence.count <= 120 {
                return sentence + "..."
            }
            // If too short, try to include second sentence
            if sentence.count <= 20 {
                let afterFirst = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if let secondRange = afterFirst.range(of: ".", options: .literal) {
                    return sentence + ". " + String(afterFirst[..<secondRange.lowerBound]) + "..."
                }
            }
        }
        // No period or sentence too long, truncate
        if text.count > 100 {
            let index = text.index(text.startIndex, offsetBy: 100)
            return String(text[..<index]) + "..."
        }
        return text
    }

    private func factualInsight(from result: AnalysisResult) -> String {
        let comparison = result.comparison

        // HR-based insight
        if comparison.current.avgHeartRate > 0 {
            let avgHR = Int(comparison.current.avgHeartRate)
            let sessionCount = comparison.current.sessionCount

            if let range = hrRange(from: result) {
                return "Avg HR \(avgHR) bpm (range \(range.min)–\(range.max)) across \(sessionCount) session\(sessionCount == 1 ? "" : "s")"
            } else {
                return "Avg HR \(avgHR) bpm across \(sessionCount) session\(sessionCount == 1 ? "" : "s")"
            }
        }

        // Temperature-based insight (if no HR data)
        if comparison.current.avgTemperature > 0 {
            let formattedTemp = Temperature(fahrenheit: Int(comparison.current.avgTemperature)).formatted(unit: settings.temperatureUnit)
            return "Most sessions were \(formattedTemp) this week"
        }

        // Session count only fallback
        let sessionCount = comparison.current.sessionCount
        return "\(sessionCount) session\(sessionCount == 1 ? "" : "s") this week"
    }

    private func hrRange(from result: AnalysisResult) -> (min: Int, max: Int)? {
        let values = result.trendPoints.map { $0.value }.filter { $0 > 0 }
        guard !values.isEmpty else { return nil }

        let minValue = Int(values.min() ?? 0)
        let maxValue = Int(values.max() ?? 0)

        // Only show range if there's meaningful variance
        guard minValue != maxValue else { return nil }

        return (min: minValue, max: maxValue)
    }
}

#Preview("Free - Deterministic Insights") {
    VStack(spacing: 16) {
        InsightPreviewCard(
            result: AnalysisResult(
                filters: .default,
                comparison: PeriodComparison(
                    current: PeriodStats(
                        periodStart: Date(),
                        periodEnd: Date(),
                        sessionCount: 6,
                        totalDuration: 0,
                        totalCalories: 0,
                        avgHeartRate: 60,
                        maxHeartRate: 0,
                        avgTemperature: 95
                    ),
                    previous: PeriodStats(
                        periodStart: Date(),
                        periodEnd: Date(),
                        sessionCount: 4,
                        totalDuration: 0,
                        totalCalories: 0,
                        avgHeartRate: 65,
                        maxHeartRate: 0,
                        avgTemperature: 94
                    )
                ),
                trendPoints: [
                    TrendPoint(date: Date().addingTimeInterval(-86400 * 6), value: 65, temperature: 95),
                    TrendPoint(date: Date().addingTimeInterval(-86400 * 4), value: 62, temperature: 95),
                    TrendPoint(date: Date().addingTimeInterval(-86400 * 2), value: 58, temperature: 95),
                    TrendPoint(date: Date(), value: 57, temperature: 95)
                ],
                acclimation: nil,
                sessionMap: [:]
            ),
            allSessions: [],
            isPro: false,
            lastSessionDate: nil,
            onTap: {}
        )
    }
    .padding()
    .environment(UserSettings())
}

#Preview("Pro - With AI Insights") {
    VStack(spacing: 16) {
        InsightPreviewCard(
            result: AnalysisResult(
                filters: .default,
                comparison: PeriodComparison(
                    current: PeriodStats(
                        periodStart: Date(),
                        periodEnd: Date(),
                        sessionCount: 6,
                        totalDuration: 0,
                        totalCalories: 0,
                        avgHeartRate: 61,
                        maxHeartRate: 0,
                        avgTemperature: 96
                    ),
                    previous: nil
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
            onTap: {}
        )
    }
    .padding()
    .environment(UserSettings())
}

#Preview("No Data") {
    VStack(spacing: 16) {
        InsightPreviewCard(
            result: nil,
            allSessions: [],
            isPro: false,
            lastSessionDate: nil,
            onTap: {}
        )
    }
    .padding()
    .environment(UserSettings())
}
