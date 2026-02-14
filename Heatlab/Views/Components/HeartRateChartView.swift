//
//  HeartRateChartView.swift
//  heatlab
//
//  Chart view for displaying heart rate over time during a session
//

import SwiftUI
import Charts

struct HeartRateChartView: View {
    let dataPoints: [HeartRateDataPoint]
    let duration: TimeInterval
    let minHR: Double
    let maxHR: Double
    let averageHR: Double
    var zonedDataPoints: [ZonedHeartRateDataPoint]? = nil
    var zoneMaxHR: Double? = nil

    @State private var selectedTimeInMinutes: Double?

    private var selectedDataPoint: HeartRateDataPoint? {
        guard let selectedTime = selectedTimeInMinutes else { return nil }
        return dataPoints.min(by: {
            abs($0.timeInMinutes - selectedTime) < abs($1.timeInMinutes - selectedTime)
        })
    }

    /// Whether to render zone-colored lines instead of gradient
    private var useZoneColoring: Bool {
        zonedDataPoints != nil && zoneMaxHR != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate")
                .font(.headline)

            if dataPoints.isEmpty {
                ContentUnavailableView(
                    "No Heart Rate Data",
                    systemImage: "heart.slash",
                    description: Text("Heart rate data is not available for this session")
                )
                .frame(height: 200)
            } else {
                chartContent
                    .chartXSelection(value: $selectedTimeInMinutes)
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            if let selected = selectedDataPoint,
                               let xPos = proxy.position(forX: selected.timeInMinutes),
                               let yPos = proxy.position(forY: selected.heartRate) {
                                let plotArea = geo[proxy.plotFrame!]
                                let pointX = plotArea.origin.x + xPos
                                let pointY = plotArea.origin.y + yPos

                                VStack(spacing: 2) {
                                    Text("\(Int(selected.heartRate)) bpm")
                                        .font(.caption.bold())
                                    Text(formatTimeLabel(selected.timeInMinutes))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .heatLabTooltip()
                                .position(tooltipPosition(
                                    pointX: pointX,
                                    pointY: pointY,
                                    in: geo.size
                                ))
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .chartXAxis {
                        AxisMarks(values: xAxisTicks(durationMinutes: duration / 60.0)) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let minutes = value.as(Double.self) {
                                    Text(formatTimeLabel(minutes))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let bpm = value.as(Double.self) {
                                    Text("\(Int(bpm))")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXScale(domain: 0...(duration / 60.0))
                    .chartYScale(domain: yAxisDomain)
                    .chartPlotStyle { $0.clipped() }
                    .frame(height: 220)

                // Legend for average line
                HStack(spacing: 6) {
                    // Orange dashed line indicator
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 24, y: 0))
                    }
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .frame(height: 1.5)

                    Text("Avg: \(Int(averageHR)) bpm")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .heatLabCard()
    }

    // MARK: - Chart Content

    @ViewBuilder
    private var chartContent: some View {
        if useZoneColoring, let zoned = zonedDataPoints {
            zoneColoredChart(zoned: zoned)
        } else {
            gradientChart
        }
    }

    private func zoneColoredChart(zoned: [ZonedHeartRateDataPoint]) -> some View {
        let flatPoints = zoneRunFlatPoints(from: zoned)
        return Chart(flatPoints, id: \.id) { point in
            LineMark(
                x: .value("Time", point.timeInMinutes),
                y: .value("Heart Rate", point.heartRate),
                series: .value("Run", point.runIDString)
            )
            .foregroundStyle(point.color)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        .chartBackground { _ in EmptyView() }
        .chartOverlay { _ in EmptyView() }
        .chartLegend(.hidden)
        .overlay(zoneOverlayChart)
    }

    /// Overlay chart with just the average line and crosshair (avoids complex type-checking in one Chart)
    private var zoneOverlayChart: some View {
        Chart {
            averageAndCrosshairMarks
        }
        .chartXScale(domain: 0...(duration / 60.0))
        .chartYScale(domain: yAxisDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .allowsHitTesting(false)
    }

    private var gradientChart: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("Time", point.timeInMinutes),
                y: .value("Heart Rate", point.heartRate)
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
        .overlay(zoneOverlayChart)
    }

    @ChartContentBuilder
    private var averageAndCrosshairMarks: some ChartContent {
        RuleMark(y: .value("Average", averageHR))
            .foregroundStyle(.orange)
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

        if let selected = selectedDataPoint {
            RuleMark(x: .value("Selected", selected.timeInMinutes))
                .foregroundStyle(.white.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            RuleMark(y: .value("Selected HR", selected.heartRate))
                .foregroundStyle(.white.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

            PointMark(
                x: .value("Selected Time", selected.timeInMinutes),
                y: .value("Selected HR", selected.heartRate)
            )
            .symbolSize(40)
            .foregroundStyle(.white)
        }
    }

    // MARK: - Zone Runs

    /// Flattens zone runs into a flat array of chart-ready points.
    /// Each point carries its run ID and zone color for direct use in Chart.
    private func zoneRunFlatPoints(from points: [ZonedHeartRateDataPoint]) -> [ZoneRunPoint] {
        guard !points.isEmpty else { return [] }

        let sorted = points.sorted { $0.timeOffset < $1.timeOffset }
        var result: [ZoneRunPoint] = []
        var currentZone = sorted[0].zone
        var runID = UUID()

        result.append(ZoneRunPoint(
            heartRate: sorted[0].heartRate,
            timeInMinutes: sorted[0].timeInMinutes,
            runID: runID,
            color: currentZone.color
        ))

        for i in 1..<sorted.count {
            let pt = sorted[i]
            if pt.zone != currentZone {
                // Add boundary point to current run for line continuity
                result.append(ZoneRunPoint(
                    heartRate: pt.heartRate,
                    timeInMinutes: pt.timeInMinutes,
                    runID: runID,
                    color: currentZone.color
                ))
                // Start new run
                currentZone = pt.zone
                runID = UUID()
            }
            result.append(ZoneRunPoint(
                heartRate: pt.heartRate,
                timeInMinutes: pt.timeInMinutes,
                runID: runID,
                color: currentZone.color
            ))
        }

        return result
    }

    // MARK: - Helpers

    private var yAxisDomain: ClosedRange<Double> {
        guard !dataPoints.isEmpty else {
            return 60...180
        }

        let actualMinHR = dataPoints.map { $0.heartRate }.min() ?? minHR
        let actualMaxHR = dataPoints.map { $0.heartRate }.max() ?? maxHR

        let padding = 10.0
        let minValue = max(0, (actualMinHR - padding).rounded(.down))
        let maxValue = (actualMaxHR + padding).rounded(.up)

        return minValue...maxValue
    }

    private func tooltipPosition(pointX: CGFloat, pointY: CGFloat, in size: CGSize) -> CGPoint {
        let tooltipWidth: CGFloat = 100
        let tooltipHeight: CGFloat = 50
        let offset: CGFloat = 12

        var x = pointX
        var y = pointY - tooltipHeight / 2 - offset

        if y - tooltipHeight / 2 < 0 {
            y = pointY + tooltipHeight / 2 + offset
        }

        x = max(tooltipWidth / 2, min(x, size.width - tooltipWidth / 2))

        return CGPoint(x: x, y: y)
    }

    private func xAxisTicks(durationMinutes: Double) -> [Double] {
        let interval: Double
        if durationMinutes <= 5 { interval = 1 }
        else if durationMinutes <= 15 { interval = 5 }
        else if durationMinutes <= 60 { interval = 10 }
        else { interval = 30 }

        var values: [Double] = []
        var t = 0.0
        while t < durationMinutes {
            values.append(t)
            t += interval
        }
        values.append(durationMinutes)
        return values
    }

    private func formatTimeLabel(_ minutes: Double) -> String {
        let totalSeconds = Int((minutes * 60).rounded())
        let hours = totalSeconds / 3600
        let mins = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return "\(hours):\(String(format: "%02d", mins))"
        } else if secs > 0 {
            return "\(mins):\(String(format: "%02d", secs))"
        } else {
            return "\(mins)m"
        }
    }
}

// MARK: - Zone Run Point

private struct ZoneRunPoint: Identifiable {
    let id = UUID()
    let heartRate: Double
    let timeInMinutes: Double
    let runID: UUID
    let color: Color
    var runIDString: String { runID.uuidString }
}

#Preview {
    let sampleData = (0..<30).map { index in
        HeartRateDataPoint(
            heartRate: Double(120 + Int.random(in: -20...40)),
            timeOffset: TimeInterval(index * 60)
        )
    }

    return HeartRateChartView(
        dataPoints: sampleData,
        duration: 1800,
        minHR: 100,
        maxHR: 160,
        averageHR: 140
    )
    .padding()
}
