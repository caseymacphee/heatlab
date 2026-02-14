//
//  ZoneTrendChartView.swift
//  heatlab
//
//  Stacked bar chart showing zone distribution per session over time
//

import SwiftUI
import Charts

struct ZoneTrendChartView: View {
    let sessions: [SessionWithStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if chartData.isEmpty {
                ContentUnavailableView(
                    "No Zone Data",
                    systemImage: "chart.bar",
                    description: Text("Set your age in Settings to see zone trends")
                )
                .frame(height: 200)
            } else {
                Chart(chartData, id: \.id) { entry in
                    BarMark(
                        x: .value("Date", entry.date),
                        y: .value("Percentage", entry.percentage * 100)
                    )
                    .foregroundStyle(entry.zone.color)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.twoDigits).day())
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxisLabel(" ")
                .chartLegend(.hidden)
                .frame(height: 220)

                // Compact zone legend
                HStack(spacing: 12) {
                    ForEach(HeartRateZone.allCases, id: \.rawValue) { zone in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(zone.color)
                                .frame(width: 6, height: 6)
                            Text("Z\(zone.rawValue)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        // Note: parent (AnalysisView trendChartSection) provides the card wrapper
    }

    // MARK: - Chart Data

    private struct ChartEntry: Identifiable {
        let id = UUID()
        let date: Date
        let zone: HeartRateZone
        let percentage: Double
    }

    private var chartData: [ChartEntry] {
        sessions.compactMap { session -> [ChartEntry]? in
            guard let distribution = session.zoneDistribution, !distribution.entries.isEmpty else {
                return nil
            }
            // Build entries for all 5 zones (0% for zones not present) sorted zone1→zone5
            return HeartRateZone.allCases.map { zone in
                let entry = distribution.entries.first { $0.zone == zone }
                return ChartEntry(
                    date: session.session.startDate,
                    zone: zone,
                    percentage: entry?.percentage ?? 0
                )
            }
        }
        .flatMap { $0 }
    }
}

#Preview {
    ZoneTrendChartView(sessions: [])
        .padding()
}
