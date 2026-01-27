//
//  InsightPreviewCard.swift
//  heatlab
//
//  Compact insight preview card for Dashboard - tappable to navigate to Analysis
//
//  Pro users: Shows first sentence of AI insight + "..." + sparkle icon
//  Free users: Shows factual summary
//

import SwiftUI

struct InsightPreviewCard: View {
    let result: AnalysisResult?
    let isPro: Bool
    let aiInsight: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: SFSymbol.sparkles)
                        .foregroundStyle(Color.hlAccent)
                    Text("Insight")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: SFSymbol.chevronRight)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let result = result, result.comparison.current.sessionCount > 0 {
                    // Primary insight text
                    Text(displayText(from: result))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
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
    }
    
    private func displayText(from result: AnalysisResult) -> String {
        // Pro users with AI insight: show first sentence + "..."
        if isPro, let insight = aiInsight {
            return firstSentence(of: insight) + "..."
        }
        
        // Fallback to factual summary
        return factualInsight(from: result)
    }
    
    private var secondaryText: String {
        if isPro && aiInsight != nil {
            return "Tap for full insight"
        }
        return "Tap for details"
    }
    
    /// Extract first sentence from AI insight
    private func firstSentence(of text: String) -> String {
        // Find first sentence ending
        if let range = text.range(of: ".", options: .literal) {
            let sentence = String(text[..<range.lowerBound])
            // Avoid too-short sentences
            if sentence.count > 20 {
                return sentence
            }
            // Try to get second sentence if first is too short
            let afterFirst = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let secondRange = afterFirst.range(of: ".", options: .literal) {
                return sentence + ". " + String(afterFirst[..<secondRange.lowerBound])
            }
        }
        // No period found, truncate if too long
        if text.count > 100 {
            let index = text.index(text.startIndex, offsetBy: 100)
            return String(text[..<index])
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

#Preview("Free - Factual") {
    VStack(spacing: 16) {
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
            isPro: false,
            aiInsight: nil,
            onTap: {}
        )
    }
    .padding()
}

#Preview("Pro - With AI Insight") {
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
                    TrendPoint(date: Date(), value: 60, temperature: 96),
                    TrendPoint(date: Date(), value: 63, temperature: 96)
                ],
                acclimation: nil,
                sessionMap: [:]
            ),
            isPro: true,
            aiInsight: "Your HR was very stable this week (60–63 bpm range), even on hotter classes. Consider staying hydrated on 100°F+ days.",
            onTap: {}
        )
    }
    .padding()
}

#Preview("No Data") {
    VStack(spacing: 16) {
        InsightPreviewCard(
            result: nil,
            isPro: false,
            aiInsight: nil,
            onTap: {}
        )
    }
    .padding()
}
