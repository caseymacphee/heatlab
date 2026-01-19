//
//  WatchHeartRateChartView.swift
//  HeatlabWatch
//
//  Compact heart rate chart for watchOS real-time display
//  Shows a sliding 5-minute window with T-5 to T (current) on X-axis
//

import SwiftUI
import Charts

struct WatchHeartRateChartView: View {
    let dataPoints: [HeartRateDataPoint]
    let currentElapsedTime: TimeInterval

    private let windowMinutes: Double = 5.0

    /// Data points filtered to last 5 minutes, with X values relative to current time
    private var windowedDataPoints: [(x: Double, y: Double)] {
        let windowSeconds = windowMinutes * 60.0

        return dataPoints.compactMap { point in
            let relativeTime = point.timeOffset - currentElapsedTime
            let relativeMinutes = relativeTime / 60.0

            // Only include points within the 5-minute window
            guard relativeMinutes >= -windowMinutes else { return nil }

            return (x: relativeMinutes, y: point.heartRate)
        }
    }

    var body: some View {
        if windowedDataPoints.count < 2 {
            // Need at least 2 points to draw a line
            VStack(spacing: 8) {
                Image(systemName: SFSymbol.heartFill)
                    .font(.title2)
                    .foregroundStyle(Color.HeatLab.heartRate)
                Text("Collecting data...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                ForEach(Array(windowedDataPoints.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Time", point.x),
                        y: .value("HR", point.y)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.HeatLab.tempHot, Color.HeatLab.tempVeryHot],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
            .chartXScale(domain: -windowMinutes...0)
            .chartXAxis {
                AxisMarks(values: [-5.0, -2.5, 0.0]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let minutes = value.as(Double.self) {
                            if minutes == 0 {
                                Text("T")
                                    .font(.system(size: 9))
                            } else {
                                Text("T\(Int(minutes))")
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let bpm = value.as(Double.self) {
                            Text("\(Int(bpm))")
                                .font(.system(size: 9))
                        }
                    }
                }
            }
            .chartYScale(domain: yAxisDomain)
        }
    }

    private var yAxisDomain: ClosedRange<Double> {
        guard !windowedDataPoints.isEmpty else {
            return 60...180
        }

        let minHR = windowedDataPoints.map { $0.y }.min() ?? 60
        let maxHR = windowedDataPoints.map { $0.y }.max() ?? 180

        let padding = 10.0
        let minValue = max(40, (minHR - padding).rounded(.down))
        let maxValue = (maxHR + padding).rounded(.up)

        return minValue...maxValue
    }
}

#Preview {
    // 5 minutes of data at 30-second intervals (10 points)
    let currentTime: TimeInterval = 5 * 60
    return WatchHeartRateChartView(
        dataPoints: (0..<10).map { index in
            HeartRateDataPoint(
                heartRate: Double(110 + Int.random(in: -10...30)),
                timeOffset: TimeInterval(index * 30)
            )
        },
        currentElapsedTime: currentTime
    )
    .frame(height: 120)
    .padding()
}
