//
//  DeterministicInsightGenerator.swift
//  heatlab
//
//  Generates deterministic pattern-based insights from AnalysisResult
//  without relying on AI. Cycles through 3-5 relevant insights based on data patterns.
//

import Foundation

// MARK: - Insight Types

enum InsightCategory: String, CaseIterable {
    case recentComparison
    case temperatureAnalysis
    case sessionTypeComparison
    case periodOverPeriod
    case peakSession
    case hrConsistency
    case acclimation
    case progression
    case volume  // Fallback
}

struct DeterministicInsight: Identifiable, Equatable {
    let id = UUID()
    let category: InsightCategory
    let text: String
    let icon: String  // SF Symbol

    static func == (lhs: DeterministicInsight, rhs: DeterministicInsight) -> Bool {
        lhs.category == rhs.category && lhs.text == rhs.text
    }
}

// MARK: - Generator

struct DeterministicInsightGenerator {

    // MARK: - Thresholds

    private enum Threshold {
        static let recentComparisonBpm = 3.0      // 3+ bpm difference between last two sessions
        static let temperatureAnalysisBpm = 5.0   // 5+ bpm difference between buckets
        static let minSessionsPerBucket = 2       // Need 2+ sessions per bucket for temp analysis
        static let sessionTypeComparisonBpm = 5.0 // 5+ bpm difference between types
        static let minSessionsPerType = 2         // Need 2+ sessions per type for comparison
        static let periodSessionDelta = 2         // 2+ session difference for period-over-period
        static let periodHrDeltaPercent = 3.0     // 3%+ HR delta for period-over-period
        static let hrConsistencyTight = 10.0      // Range <= 10 is tight
        static let hrConsistencyWide = 25.0       // Range >= 25 is wide
        static let minSessionsForProgression = 2  // Need at least 2 sessions for progression
        static let progressionBpm = 3.0           // 3+ bpm difference for progression
    }

    // MARK: - Main Generation

    /// Generate all applicable insights for the given analysis result
    func generateInsights(
        from result: AnalysisResult,
        allSessions: [SessionWithStats],
        sessionTypes: [SessionTypeConfig],
        temperatureUnit: TemperatureUnit = .fahrenheit
    ) -> [DeterministicInsight] {
        var insights: [DeterministicInsight] = []

        let filterContext = FilterContext(
            filters: result.filters,
            sessionTypes: sessionTypes,
            temperatureUnit: temperatureUnit
        )

        // Try each insight category in priority order
        if let insight = recentComparisonInsight(from: result, context: filterContext) {
            insights.append(insight)
        }

        if let insight = temperatureAnalysisInsight(from: result, allSessions: allSessions, context: filterContext) {
            insights.append(insight)
        }

        if let insight = sessionTypeComparisonInsight(from: result, allSessions: allSessions, sessionTypes: sessionTypes, context: filterContext) {
            insights.append(insight)
        }

        if let insight = periodOverPeriodInsight(from: result, context: filterContext) {
            insights.append(insight)
        }

        if let insight = peakSessionInsight(from: result, context: filterContext) {
            insights.append(insight)
        }

        if let insight = hrConsistencyInsight(from: result, context: filterContext) {
            insights.append(insight)
        }

        if let insight = acclimationInsight(from: result, context: filterContext) {
            insights.append(insight)
        }

        if let insight = progressionInsight(from: result, context: filterContext) {
            insights.append(insight)
        }

        // Fallback: always have at least one insight
        if insights.isEmpty {
            insights.append(volumeInsight(from: result, context: filterContext))
        }

        return insights
    }

    // MARK: - Filter Context Helper

    private struct FilterContext {
        let filters: AnalysisFilters
        let sessionTypes: [SessionTypeConfig]
        let temperatureUnit: TemperatureUnit

        var hasTemperatureFilter: Bool {
            filters.temperatureBucket != nil
        }

        var hasSessionTypeFilter: Bool {
            filters.sessionTypeId != nil
        }

        var sessionTypePrefix: String {
            if let typeId = filters.sessionTypeId,
               let config = sessionTypes.first(where: { $0.id == typeId }) {
                return "\(config.name) "
            }
            return ""
        }

        var temperaturePrefix: String {
            if let bucket = filters.temperatureBucket {
                return "\(bucket.displayName(for: temperatureUnit)) "
            }
            return ""
        }

        var contextPrefix: String {
            // Combine filters for context
            let type = sessionTypePrefix.isEmpty ? "" : sessionTypePrefix.trimmingCharacters(in: .whitespaces)
            let temp = temperaturePrefix.isEmpty ? "" : temperaturePrefix.trimmingCharacters(in: .whitespaces)

            if !type.isEmpty && !temp.isEmpty {
                return "\(type) at \(temp)"
            } else if !type.isEmpty {
                return type
            } else if !temp.isEmpty {
                return temp
            }
            return ""
        }
    }

    // MARK: - Individual Insight Generators

    /// "Your last session was 8 bpm lower than the one before"
    private func recentComparisonInsight(from result: AnalysisResult, context: FilterContext) -> DeterministicInsight? {
        let points = result.trendPoints.sorted { $0.date > $1.date }
        guard points.count >= 2 else { return nil }

        let latest = points[0]
        let previous = points[1]

        let diff = latest.value - previous.value
        guard abs(diff) >= Threshold.recentComparisonBpm else { return nil }

        let direction = diff > 0 ? "higher" : "lower"
        let absVal = Int(abs(diff))

        let sessionWord = context.contextPrefix.isEmpty ? "session" : "\(context.contextPrefix) session"
        let text = "Your last \(sessionWord) was \(absVal) bpm \(direction) than the one before"

        return DeterministicInsight(
            category: .recentComparison,
            text: text,
            icon: "heart"
        )
    }

    /// "Sessions in Hot (90-99F) averaged 12 bpm higher than Warm"
    private func temperatureAnalysisInsight(from result: AnalysisResult, allSessions: [SessionWithStats], context: FilterContext) -> DeterministicInsight? {
        // Skip if filtering by a specific temperature bucket
        guard !context.hasTemperatureFilter else { return nil }

        // Get sessions from current period only
        let periodSessions = allSessions.filter { session in
            result.trendPoints.contains { $0.date == session.session.startDate }
        }.filter { $0.stats.averageHR > 0 }

        // Group by temperature bucket
        var bucketStats: [TemperatureBucket: (count: Int, totalHR: Double)] = [:]
        for session in periodSessions {
            let bucket = session.session.temperatureBucket
            let current = bucketStats[bucket] ?? (0, 0)
            bucketStats[bucket] = (current.count + 1, current.totalHR + session.stats.averageHR)
        }

        // Need at least 2 buckets with enough sessions each
        let qualifiedBuckets = bucketStats.filter { $0.value.count >= Threshold.minSessionsPerBucket }
        guard qualifiedBuckets.count >= 2 else { return nil }

        // Find buckets with largest difference
        var maxDiff: Double = 0
        var highBucket: TemperatureBucket?
        var lowBucket: TemperatureBucket?

        let bucketArray = Array(qualifiedBuckets)
        for i in 0..<bucketArray.count {
            for j in (i+1)..<bucketArray.count {
                let avg1 = bucketArray[i].value.totalHR / Double(bucketArray[i].value.count)
                let avg2 = bucketArray[j].value.totalHR / Double(bucketArray[j].value.count)
                let diff = abs(avg1 - avg2)

                if diff > maxDiff {
                    maxDiff = diff
                    if avg1 > avg2 {
                        highBucket = bucketArray[i].key
                        lowBucket = bucketArray[j].key
                    } else {
                        highBucket = bucketArray[j].key
                        lowBucket = bucketArray[i].key
                    }
                }
            }
        }

        guard maxDiff >= Threshold.temperatureAnalysisBpm,
              let high = highBucket,
              let low = lowBucket else { return nil }

        let typePrefix = context.sessionTypePrefix
        let text = "\(typePrefix)Sessions in \(high.displayName(for: context.temperatureUnit)) averaged \(Int(maxDiff)) bpm higher than \(low.displayName(for: context.temperatureUnit))"

        return DeterministicInsight(
            category: .temperatureAnalysis,
            text: text.trimmingCharacters(in: .whitespaces),
            icon: "thermometer.variable"
        )
    }

    /// "Bikram pushes your HR 15 bpm higher than Vinyasa"
    private func sessionTypeComparisonInsight(from result: AnalysisResult, allSessions: [SessionWithStats], sessionTypes: [SessionTypeConfig], context: FilterContext) -> DeterministicInsight? {
        // Skip if filtering by a specific session type
        guard !context.hasSessionTypeFilter else { return nil }

        // Get sessions from current period only
        let periodSessions = allSessions.filter { session in
            result.trendPoints.contains { $0.date == session.session.startDate }
        }.filter { $0.stats.averageHR > 0 && $0.session.sessionTypeId != nil }

        // Group by session type
        var typeStats: [UUID: (count: Int, totalHR: Double)] = [:]
        for session in periodSessions {
            guard let typeId = session.session.sessionTypeId else { continue }
            let current = typeStats[typeId] ?? (0, 0)
            typeStats[typeId] = (current.count + 1, current.totalHR + session.stats.averageHR)
        }

        // Need at least 2 types with enough sessions each
        let qualifiedTypes = typeStats.filter { $0.value.count >= Threshold.minSessionsPerType }
        guard qualifiedTypes.count >= 2 else { return nil }

        // Find types with largest difference
        var maxDiff: Double = 0
        var highType: UUID?
        var lowType: UUID?

        let typeArray = Array(qualifiedTypes)
        for i in 0..<typeArray.count {
            for j in (i+1)..<typeArray.count {
                let avg1 = typeArray[i].value.totalHR / Double(typeArray[i].value.count)
                let avg2 = typeArray[j].value.totalHR / Double(typeArray[j].value.count)
                let diff = abs(avg1 - avg2)

                if diff > maxDiff {
                    maxDiff = diff
                    if avg1 > avg2 {
                        highType = typeArray[i].key
                        lowType = typeArray[j].key
                    } else {
                        highType = typeArray[j].key
                        lowType = typeArray[i].key
                    }
                }
            }
        }

        guard maxDiff >= Threshold.sessionTypeComparisonBpm,
              let highId = highType,
              let lowId = lowType,
              let highName = sessionTypes.first(where: { $0.id == highId })?.name,
              let lowName = sessionTypes.first(where: { $0.id == lowId })?.name else { return nil }

        let tempPrefix = context.temperaturePrefix
        let text = "\(highName) pushes your HR \(Int(maxDiff)) bpm higher than \(lowName)\(tempPrefix.isEmpty ? "" : " in \(tempPrefix.trimmingCharacters(in: .whitespaces))")"

        return DeterministicInsight(
            category: .sessionTypeComparison,
            text: text,
            icon: "arrow.left.arrow.right"
        )
    }

    /// "You trained 3 more times than last week"
    private func periodOverPeriodInsight(from result: AnalysisResult, context: FilterContext) -> DeterministicInsight? {
        guard let sessionDelta = result.comparison.sessionCountDelta else { return nil }

        let sessionThresholdMet = abs(sessionDelta) >= Threshold.periodSessionDelta
        let hrDelta = result.comparison.avgHRDelta
        let hrThresholdMet = hrDelta.map { abs($0) >= Threshold.periodHrDeltaPercent } ?? false

        // Prefer session count delta, but use HR delta if session count isn't significant
        if sessionThresholdMet {
            let periodLabel = result.filters.period.previousLabel.lowercased()
            let prefix = context.contextPrefix

            if sessionDelta > 0 {
                let text = prefix.isEmpty
                    ? "You trained \(sessionDelta) more time\(sessionDelta == 1 ? "" : "s") than \(periodLabel)"
                    : "You logged \(sessionDelta) more \(prefix) session\(sessionDelta == 1 ? "" : "s") than \(periodLabel)"
                return DeterministicInsight(
                    category: .periodOverPeriod,
                    text: text,
                    icon: "arrow.up.forward"
                )
            } else {
                let absVal = abs(sessionDelta)
                let text = prefix.isEmpty
                    ? "You trained \(absVal) fewer time\(absVal == 1 ? "" : "s") than \(periodLabel)"
                    : "You logged \(absVal) fewer \(prefix) session\(absVal == 1 ? "" : "s") than \(periodLabel)"
                return DeterministicInsight(
                    category: .periodOverPeriod,
                    text: text,
                    icon: "arrow.down.forward"
                )
            }
        } else if hrThresholdMet, let delta = hrDelta {
            let periodLabel = result.filters.period.previousLabel.lowercased()
            let prefix = context.contextPrefix
            let direction = delta < 0 ? "dropped" : "increased"
            let absVal = Int(abs(delta))

            let text = prefix.isEmpty
                ? "Your avg HR \(direction) \(absVal)% vs \(periodLabel)"
                : "Your avg HR in \(prefix) sessions \(direction) \(absVal)% vs \(periodLabel)"

            return DeterministicInsight(
                category: .periodOverPeriod,
                text: text,
                icon: "heart"
            )
        }

        return nil
    }

    /// "Your most intense session was Tuesday at 102F (avg 158 bpm)"
    private func peakSessionInsight(from result: AnalysisResult, context: FilterContext) -> DeterministicInsight? {
        guard result.trendPoints.count >= 2 else { return nil }

        // Find the session with highest HR
        guard let peak = result.trendPoints.max(by: { $0.value < $1.value }) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"  // Day name
        let dayName = formatter.string(from: peak.date)

        let tempStr = peak.temperature > 0
            ? " at \(Temperature(fahrenheit: peak.temperature).formatted(unit: context.temperatureUnit))"
            : ""

        let prefix = context.contextPrefix.isEmpty ? "" : "\(context.contextPrefix) "
        let text = "Your most intense \(prefix)session was \(dayName)\(tempStr) (avg \(Int(peak.value)) bpm)"

        return DeterministicInsight(
            category: .peakSession,
            text: text,
            icon: "flame"
        )
    }

    /// "Tight HR range (145-152) shows great consistency"
    private func hrConsistencyInsight(from result: AnalysisResult, context: FilterContext) -> DeterministicInsight? {
        let values = result.trendPoints.map { $0.value }.filter { $0 > 0 }
        guard values.count >= 3 else { return nil }

        guard let minVal = values.min(), let maxVal = values.max() else { return nil }
        let range = maxVal - minVal

        let prefix = context.contextPrefix.isEmpty ? "Your" : "Your \(context.contextPrefix)"

        if range <= Threshold.hrConsistencyTight {
            let text = "\(prefix) HR range (\(Int(minVal))–\(Int(maxVal))) shows great consistency"
            return DeterministicInsight(
                category: .hrConsistency,
                text: text,
                icon: "equal.circle"
            )
        } else if range >= Threshold.hrConsistencyWide {
            let text = "\(prefix) HR varied widely (\(Int(minVal))–\(Int(maxVal)) bpm) this period"
            return DeterministicInsight(
                category: .hrConsistency,
                text: text,
                icon: "arrow.up.arrow.down"
            )
        }

        return nil
    }

    /// Uses existing AcclimationSignal
    private func acclimationInsight(from result: AnalysisResult, context: FilterContext) -> DeterministicInsight? {
        guard let acclimation = result.acclimation else { return nil }

        return DeterministicInsight(
            category: .acclimation,
            text: acclimation.displayText,
            icon: acclimation.icon
        )
    }

    /// "Your last Hot session ran 6 bpm lower than your first this week"
    private func progressionInsight(from result: AnalysisResult, context: FilterContext) -> DeterministicInsight? {
        let points = result.trendPoints.sorted { $0.date < $1.date }
        guard points.count >= Threshold.minSessionsForProgression else { return nil }

        let first = points.first!
        let last = points.last!

        let diff = last.value - first.value
        guard abs(diff) >= Threshold.progressionBpm else { return nil }

        let direction = diff > 0 ? "higher" : "lower"
        let absVal = Int(abs(diff))

        let periodLabel = result.filters.period.currentLabel.lowercased()
        let prefix = context.contextPrefix

        let text = prefix.isEmpty
            ? "Your last session ran \(absVal) bpm \(direction) than your first this \(periodLabel)"
            : "Your last \(prefix) session ran \(absVal) bpm \(direction) than your first this \(periodLabel)"

        return DeterministicInsight(
            category: .progression,
            text: text,
            icon: diff < 0 ? "chart.line.downtrend.xyaxis" : "chart.line.uptrend.xyaxis"
        )
    }

    /// Fallback: "N sessions logged this week"
    private func volumeInsight(from result: AnalysisResult, context: FilterContext) -> DeterministicInsight {
        let count = result.comparison.current.sessionCount
        let periodLabel = result.filters.period.currentLabel.lowercased()
        let prefix = context.contextPrefix

        let text = prefix.isEmpty
            ? "\(count) session\(count == 1 ? "" : "s") logged this \(periodLabel)"
            : "\(count) \(prefix) session\(count == 1 ? "" : "s") this \(periodLabel)"

        return DeterministicInsight(
            category: .volume,
            text: text,
            icon: "number"
        )
    }
}
