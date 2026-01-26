//
//  SummaryCard.swift
//  heatlab
//
//  Unified summary card following Weather app pattern:
//  - Pro: AI interpretation with sparkle icon (or factual while loading)
//  - Free: Factual summary + upsell teaser
//  - Both: Metrics row below divider
//

import SwiftUI

struct SummaryCard: View {
    @Environment(UserSettings.self) var settings
    
    let result: AnalysisResult
    let isPro: Bool
    let aiInsight: String?
    let isGeneratingInsight: Bool
    let onUpgradeTap: () -> Void
    
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
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: HeatLabRadius.lg))
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
        if let insight = aiInsight {
            // AI insight available
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: SFSymbol.sparkles)
                        .foregroundStyle(Color.HeatLab.coral)
                    Text("Insight")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
                
                Text(insight)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        } else if isGeneratingInsight {
            // Generating insight - show factual + spinner
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: SFSymbol.sparkles)
                        .foregroundStyle(Color.HeatLab.coral)
                    Text("Insight")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Text(factualSummary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        } else {
            // AI unavailable or insufficient data - show factual only
            Text(factualSummary)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Free Text Section
    
    private var freeTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Factual summary
            Text(factualSummary)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            // Upsell teaser
            Button(action: onUpgradeTap) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unlock AI insights")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.HeatLab.coral)
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

#Preview("Pro - AI Ready with Comparison") {
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
                TrendPoint(date: Date(), value: 60, temperature: 96),
                TrendPoint(date: Date(), value: 63, temperature: 96)
            ],
            acclimation: nil,
            sessionMap: [:]
        ),
        isPro: true,
        aiInsight: "Your HR was very stable this week (60–63 bpm range), even on hotter classes (90–99°F). Consider staying hydrated on 100°F+ days.",
        isGeneratingInsight: false,
        onUpgradeTap: {}
    )
    .padding()
    .environment(UserSettings())
}

#Preview("Pro - Generating") {
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
                previous: nil
            ),
            trendPoints: [
                TrendPoint(date: Date(), value: 60, temperature: 96),
                TrendPoint(date: Date(), value: 63, temperature: 96)
            ],
            acclimation: nil,
            sessionMap: [:]
        ),
        isPro: true,
        aiInsight: nil,
        isGeneratingInsight: true,
        onUpgradeTap: {}
    )
    .padding()
    .environment(UserSettings())
}

#Preview("Free - With Upsell & Comparison") {
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
                TrendPoint(date: Date(), value: 60, temperature: 96),
                TrendPoint(date: Date(), value: 63, temperature: 96)
            ],
            acclimation: nil,
            sessionMap: [:]
        ),
        isPro: false,
        aiInsight: nil,
        isGeneratingInsight: false,
        onUpgradeTap: {}
    )
    .padding()
    .environment(UserSettings())
}
