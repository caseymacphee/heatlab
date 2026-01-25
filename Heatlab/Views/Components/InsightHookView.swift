//
//  InsightHookView.swift
//  heatlab
//
//  Quick "so what" summary of analysis period
//

import SwiftUI

struct InsightHookView: View {
    let result: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Primary insight: Avg HR + range + session count
            if result.comparison.current.avgHeartRate > 0 {
                Text(primaryInsight)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            } else {
                Text(noHRInsight)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            
            // Secondary insight: Comparison delta (if available)
            if let comparisonInsight = comparisonInsight {
                Text(comparisonInsight)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: HeatLabRadius.lg))
    }
    
    // MARK: - Computed Properties
    
    private var primaryInsight: String {
        let avgHR = Int(result.comparison.current.avgHeartRate)
        let sessionCount = result.comparison.current.sessionCount
        let range = hrRange
        
        if let range = range {
            return "Avg HR \(avgHR) bpm (range \(range.min)–\(range.max)) across \(sessionCount) session\(sessionCount == 1 ? "" : "s")."
        } else {
            return "Avg HR \(avgHR) bpm across \(sessionCount) session\(sessionCount == 1 ? "" : "s")."
        }
    }
    
    private var noHRInsight: String {
        let sessionCount = result.comparison.current.sessionCount
        return "\(sessionCount) session\(sessionCount == 1 ? "" : "s") logged (no heart rate data)."
    }
    
    private var comparisonInsight: String? {
        guard let previous = result.comparison.previous,
              previous.avgHeartRate > 0,
              result.comparison.current.avgHeartRate > 0 else {
            return nil
        }
        
        let currentAvg = result.comparison.current.avgHeartRate
        let previousAvg = previous.avgHeartRate
        let delta = currentAvg - previousAvg
        let absDelta = abs(Int(delta))
        
        if delta > 0 {
            return "Avg HR +\(absDelta) bpm vs \(result.filters.period.previousLabel.lowercased())."
        } else if delta < 0 {
            return "Avg HR -\(absDelta) bpm vs \(result.filters.period.previousLabel.lowercased())."
        } else {
            return nil  // No change
        }
    }
    
    private var hrRange: (min: Int, max: Int)? {
        // Calculate range from trend points
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
        // With comparison
        InsightHookView(
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
                        avgTemperature: 0
                    ),
                    previous: PeriodStats(
                        periodStart: Date(),
                        periodEnd: Date(),
                        sessionCount: 10,
                        totalDuration: 0,
                        totalCalories: 0,
                        avgHeartRate: 57,
                        maxHeartRate: 0,
                        avgTemperature: 0
                    )
                ),
                trendPoints: [
                    TrendPoint(date: Date(), value: 57, temperature: 100),
                    TrendPoint(date: Date(), value: 62, temperature: 100)
                ],
                acclimation: nil,
                sessionMap: [:]
            )
        )
        
        // Without comparison
        InsightHookView(
            result: AnalysisResult(
                filters: .default,
                comparison: PeriodComparison(
                    current: PeriodStats(
                        periodStart: Date(),
                        periodEnd: Date(),
                        sessionCount: 3,
                        totalDuration: 0,
                        totalCalories: 0,
                        avgHeartRate: 145,
                        maxHeartRate: 0,
                        avgTemperature: 0
                    ),
                    previous: nil
                ),
                trendPoints: [
                    TrendPoint(date: Date(), value: 142, temperature: 100),
                    TrendPoint(date: Date(), value: 148, temperature: 100)
                ],
                acclimation: nil,
                sessionMap: [:]
            )
        )
    }
    .padding()
}
