//
//  ComparisonCard.swift
//  heatlab
//
//  Displays period-over-period comparison stats with deltas
//

import SwiftUI

struct ComparisonCard: View {
    @Environment(UserSettings.self) var settings
    let comparison: PeriodComparison
    let period: AnalysisPeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text(period.currentLabel)
                    .font(.headline)
                Spacer()
                if comparison.previous != nil {
                    Text(period.comparisonLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ComparisonStatItem(
                    title: "Sessions",
                    currentValue: "\(comparison.current.sessionCount)",
                    delta: comparison.sessionCountDelta.map { Double($0) },
                    isPercentage: false,
                    systemIcon: SFSymbol.yoga,
                    iconColor: Color.HeatLab.sessions
                )

                ComparisonStatItem(
                    title: "Avg HR",
                    currentValue: comparison.current.avgHeartRate > 0 ? "\(Int(comparison.current.avgHeartRate)) bpm" : "--",
                    delta: comparison.avgHRDelta,
                    isPercentage: true,
                    invertDelta: true,
                    systemIcon: SFSymbol.heartFill,
                    iconColor: Color.HeatLab.heartRate
                )

                ComparisonStatItem(
                    title: "Duration",
                    currentValue: comparison.current.formattedDuration,
                    delta: comparison.durationDelta,
                    isPercentage: true,
                    systemIcon: SFSymbol.clock,
                    iconColor: Color.HeatLab.duration
                )

                if settings.showCaloriesInApp {
                    ComparisonStatItem(
                        title: "Calories",
                        currentValue: comparison.current.totalCalories > 0 ? "\(Int(comparison.current.totalCalories))" : "--",
                        delta: comparison.caloriesDelta,
                        isPercentage: true,
                        systemIcon: SFSymbol.fireFill,
                        iconColor: Color.HeatLab.calories
                    )
                } else {
                    ComparisonStatItem(
                        title: "Avg Temp",
                        currentValue: comparison.current.avgTemperature > 0 ? formattedTemperature(comparison.current.avgTemperature) : "--",
                        delta: comparison.avgTemperatureDelta,
                        isPercentage: false,
                        systemIcon: SFSymbol.thermometer,
                        iconColor: Color.HeatLab.calories
                    )
                }
            }
        }
        .heatLabCard()
    }
    
    private func formattedTemperature(_ fahrenheit: Double) -> String {
        let temp = Temperature(fahrenheit: Int(fahrenheit))
        let value = temp.value(for: settings.temperatureUnit)
        return "\(value)°"
    }
}

struct ComparisonStatItem: View {
    let title: String
    let currentValue: String
    var delta: Double?
    var isPercentage: Bool = true
    var invertDelta: Bool = false  // When true, negative delta is shown as positive (improvement)
    var systemIcon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: systemIcon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(currentValue)
                .font(.title3.bold())

            // Delta indicator
            if let delta = delta {
                DeltaIndicator(
                    delta: delta,
                    isPercentage: isPercentage,
                    invertDelta: invertDelta
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DeltaIndicator: View {
    let delta: Double
    var isPercentage: Bool = true
    var invertDelta: Bool = false
    
    private var isPositive: Bool {
        invertDelta ? delta < 0 : delta > 0
    }
    
    private var displayDelta: Double {
        abs(delta)
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
                Text("\(Int(displayDelta))%")
                    .font(.caption.bold())
            } else {
                Text(delta > 0 ? "+\(Int(delta))" : "\(Int(delta))")
                    .font(.caption.bold())
            }
        }
        .foregroundStyle(color)
    }
}

#Preview {
    VStack(spacing: 20) {
        ComparisonCard(
            comparison: PeriodComparison(
                current: PeriodStats(
                    periodStart: Date(),
                    periodEnd: Date(),
                    sessionCount: 4,
                    totalDuration: 3600 * 3,
                    totalCalories: 1200,
                    avgHeartRate: 142,
                    maxHeartRate: 168,
                    avgTemperature: 102
                ),
                previous: PeriodStats(
                    periodStart: Date(),
                    periodEnd: Date(),
                    sessionCount: 3,
                    totalDuration: 3600 * 2.5,
                    totalCalories: 950,
                    avgHeartRate: 148,
                    maxHeartRate: 172,
                    avgTemperature: 100
                )
            ),
            period: .week
        )
        
        ComparisonCard(
            comparison: PeriodComparison(
                current: PeriodStats(
                    periodStart: Date(),
                    periodEnd: Date(),
                    sessionCount: 2,
                    totalDuration: 3600 * 1.5,
                    totalCalories: 600,
                    avgHeartRate: 138,
                    maxHeartRate: 160,
                    avgTemperature: 105
                ),
                previous: nil
            ),
            period: .week
        )
    }
    .padding()
    .environment(UserSettings())
}
