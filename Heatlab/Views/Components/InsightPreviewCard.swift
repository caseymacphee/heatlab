//
//  InsightPreviewCard.swift
//  heatlab
//
//  Compact insight preview card for Dashboard - tappable to navigate to Analysis
//

import SwiftUI

struct InsightPreviewCard: View {
    let result: AnalysisResult?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: SFSymbol.sparkles)
                        .foregroundStyle(Color.HeatLab.coral)
                    Text("Insight")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: SFSymbol.chevronRight)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let result = result, result.comparison.current.sessionCount > 0 {
                    // Primary insight: 1-line data summary
                    Text(primaryInsight(from: result))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    // Secondary: tap for details
                    Text("Tap for details")
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
            .clipShape(RoundedRectangle(cornerRadius: HeatLabRadius.lg))
        }
        .buttonStyle(.plain)
    }
    
    private func primaryInsight(from result: AnalysisResult) -> String {
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
            let avgTemp = Int(comparison.current.avgTemperature)
            return "Most sessions were \(avgTemp)°F this week"
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

#Preview {
    VStack(spacing: 16) {
        // With HR range
        InsightPreviewCard(
            result: AnalysisResult(
                filters: .default,
                comparison: PeriodComparison(
                    current: PeriodStats(
                        periodStart: Date(),
                        periodEnd: Date(),
                        sessionCount: 11,
                        totalDuration: 0,
                        totalCalories: 0,
                        avgHeartRate: 60,
                        maxHeartRate: 0,
                        avgTemperature: 95
                    ),
                    previous: nil
                ),
                trendPoints: [
                    TrendPoint(date: Date(), value: 57, temperature: 95),
                    TrendPoint(date: Date(), value: 62, temperature: 95)
                ],
                acclimation: nil,
                sessionMap: [:]
            ),
            onTap: {}
        )
        
        // Temperature-based (no HR)
        InsightPreviewCard(
            result: AnalysisResult(
                filters: .default,
                comparison: PeriodComparison(
                    current: PeriodStats(
                        periodStart: Date(),
                        periodEnd: Date(),
                        sessionCount: 7,
                        totalDuration: 0,
                        totalCalories: 0,
                        avgHeartRate: 0,
                        maxHeartRate: 0,
                        avgTemperature: 95
                    ),
                    previous: nil
                ),
                trendPoints: [],
                acclimation: nil,
                sessionMap: [:]
            ),
            onTap: {}
        )

        // No data
        InsightPreviewCard(
            result: nil,
            onTap: {}
        )
    }
    .padding()
}
