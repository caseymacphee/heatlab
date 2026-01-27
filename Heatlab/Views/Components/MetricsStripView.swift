//
//  MetricsStripView.swift
//  heatlab
//
//  Compact horizontal metrics strip for period summary
//  Shows: Sessions, Temp, Avg HR, HR Range, + Calories (if enabled)
//

import SwiftUI

struct MetricsStripView: View {
    @Environment(UserSettings.self) var settings
    
    let comparison: PeriodComparison
    let trendPoints: [TrendPoint]
    let period: AnalysisPeriod?  // nil for Dashboard (always "Past 7 Days")
    
    private var hrRange: (min: Int, max: Int)? {
        let values = trendPoints.map { $0.value }.filter { $0 > 0 }
        guard values.count > 1 else { return nil }
        
        let minValue = Int(values.min() ?? 0)
        let maxValue = Int(values.max() ?? 0)
        
        // Only show range if there's meaningful variance
        guard minValue != maxValue else { return nil }
        
        return (min: minValue, max: maxValue)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 1. Sessions
            metricItem(label: "Sessions", value: "\(comparison.current.sessionCount)")
            
            Spacer(minLength: 0)
            
            // 2. Avg Temp
            metricItem(
                label: "Avg Temp",
                value: comparison.current.avgTemperature > 0 
                    ? formattedTemperature(comparison.current.avgTemperature) 
                    : "--"
            )
            
            Spacer(minLength: 0)
            
            // 3. Avg HR
            metricItem(
                label: "Avg HR",
                value: comparison.current.avgHeartRate > 0 
                    ? "\(Int(comparison.current.avgHeartRate)) bpm" 
                    : "--"
            )
            
            Spacer(minLength: 0)
            
            // 4. HR Range (always shown)
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
                    value: comparison.current.totalCalories > 0 
                        ? "\(Int(comparison.current.totalCalories))" 
                        : "--"
                )
            }
        }
        .padding(.horizontal, HeatLabSpacing.sm)
        .padding(.vertical, HeatLabSpacing.xs)
        .background(Color.hlSurface)
        .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
    }
    
    private func metricItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
    }
    
    private func formattedTemperature(_ fahrenheit: Double) -> String {
        let temp = Temperature(fahrenheit: Int(fahrenheit))
        let value = temp.value(for: settings.temperatureUnit)
        return "\(value)\(settings.temperatureUnit.rawValue)"
    }
}

#Preview {
    VStack(spacing: 20) {
        // With all data
        MetricsStripView(
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
            period: .week
        )
        
        // No HR data
        MetricsStripView(
            comparison: PeriodComparison(
                current: PeriodStats(
                    periodStart: Date(),
                    periodEnd: Date(),
                    sessionCount: 3,
                    totalDuration: 3600,
                    totalCalories: 400,
                    avgHeartRate: 0,
                    maxHeartRate: 0,
                    avgTemperature: 102
                ),
                previous: nil
            ),
            trendPoints: [],
            period: .week
        )
        
        // Single session (no range)
        MetricsStripView(
            comparison: PeriodComparison(
                current: PeriodStats(
                    periodStart: Date(),
                    periodEnd: Date(),
                    sessionCount: 1,
                    totalDuration: 1800,
                    totalCalories: 200,
                    avgHeartRate: 145,
                    maxHeartRate: 160,
                    avgTemperature: 105
                ),
                previous: nil
            ),
            trendPoints: [
                TrendPoint(date: Date(), value: 145, temperature: 105)
            ],
            period: nil
        )
    }
    .padding()
    .environment(UserSettings())
}
