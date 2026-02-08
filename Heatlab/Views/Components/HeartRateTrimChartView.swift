//
//  HeartRateTrimChartView.swift
//  heatlab
//
//  Heart rate chart with draggable trim handle for adjusting session duration
//

import SwiftUI
import Charts

struct HeartRateTrimChartView: View {
    let dataPoints: [HeartRateDataPoint]  // ALL points (unfiltered)
    let maxDuration: TimeInterval
    @Binding var trimDuration: TimeInterval

    @State private var selectedTimeInMinutes: Double?
    @State private var isDraggingHandle: Bool = false

    private let chartHeight: CGFloat = 180

    // Points in the kept (active) region
    private var activeDataPoints: [HeartRateDataPoint] {
        dataPoints.filter { $0.timeOffset <= trimDuration }
    }

    private var activeAverageHR: Double {
        let active = activeDataPoints
        guard !active.isEmpty else { return 0 }
        return active.map(\.heartRate).reduce(0, +) / Double(active.count)
    }

    private var selectedDataPoint: HeartRateDataPoint? {
        guard let selectedTime = selectedTimeInMinutes else { return nil }
        // Only show tooltip in the active region
        let trimMinutes = trimDuration / 60.0
        guard selectedTime <= trimMinutes else { return nil }
        return dataPoints.min(by: {
            abs($0.timeInMinutes - selectedTime) < abs($1.timeInMinutes - selectedTime)
        })
    }

    private var yAxisDomain: ClosedRange<Double> {
        guard !dataPoints.isEmpty else { return 60...180 }
        let minHR = dataPoints.map(\.heartRate).min() ?? 60
        let maxHR = dataPoints.map(\.heartRate).max() ?? 180
        let padding = 10.0
        let minValue = max(0, (minHR - padding).rounded(.down))
        let maxValue = (maxHR + padding).rounded(.up)
        return minValue...maxValue
    }

    private var maxTimeInMinutes: Double {
        maxDuration / 60.0
    }

    private var trimTimeInMinutes: Double {
        trimDuration / 60.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Duration header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duration")
                        .font(.headline)
                    Text("Drag handle to trim session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(formatDuration(trimDuration))
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.hlAccent)
            }

            // Chart with trim overlay
            Chart(dataPoints) { point in
                // Area fill
                AreaMark(
                    x: .value("Time", point.timeInMinutes),
                    yStart: .value("Min", yAxisDomain.lowerBound),
                    yEnd: .value("Heart Rate", point.heartRate)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.HeatLab.tempHot.opacity(0.3), Color.HeatLab.tempVeryHot.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line on top
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

                // Average HR rule (recalculates based on trim)
                if activeAverageHR > 0 {
                    RuleMark(y: .value("Average", activeAverageHR))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }

                // Selected point crosshair (only in active region)
                if let selected = selectedDataPoint, !isDraggingHandle {
                    RuleMark(x: .value("Selected", selected.timeInMinutes))
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
            .chartXScale(domain: 0...maxTimeInMinutes)
            .chartYScale(domain: yAxisDomain)
            .chartPlotStyle { $0.clipped() }
            .chartXSelection(value: isDraggingHandle ? .constant(nil) : $selectedTimeInMinutes)
            .chartXAxis {
                AxisMarks(values: xAxisTicks(durationMinutes: maxTimeInMinutes)) { value in
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
            .chartOverlay { proxy in
                GeometryReader { geo in
                    let plotArea = geo[proxy.plotFrame!]

                    // Trim curtain — constrained to plot rect so it doesn't cover y-axis labels
                    if let trimX = proxy.position(forX: trimTimeInMinutes) {
                        let curtainOriginX = plotArea.origin.x + trimX
                        let curtainWidth = max(0, plotArea.maxX - curtainOriginX)

                        if curtainWidth > 0 {
                            Rectangle()
                                .fill(Color(.systemBackground).opacity(0.82))
                                .frame(width: curtainWidth, height: plotArea.height)
                                .position(
                                    x: curtainOriginX + curtainWidth / 2,
                                    y: plotArea.midY
                                )
                                .allowsHitTesting(false)
                        }
                    }

                    // Draggable trim handle — vertical line + open circle at top
                    if let trimX = proxy.position(forX: trimTimeInMinutes) {
                        let handleX = plotArea.origin.x + trimX
                        let circleSize: CGFloat = 14

                        ZStack(alignment: .top) {
                            // Vertical line spanning plot height
                            Rectangle()
                                .fill(Color.hlAccent)
                                .frame(width: 2, height: plotArea.height)

                            // Open circle handle at top
                            Circle()
                                .strokeBorder(Color.hlAccent, lineWidth: 2.5)
                                .background(Circle().fill(Color(.systemBackground)))
                                .frame(width: circleSize, height: circleSize)
                                .offset(y: -circleSize / 2)
                        }
                        .frame(height: plotArea.height)
                        .position(x: handleX, y: plotArea.midY)
                        .allowsHitTesting(false)

                        // Invisible hit target for dragging
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 44, height: plotArea.height + circleSize)
                            .contentShape(Rectangle())
                            .position(x: handleX, y: plotArea.midY)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isDraggingHandle = true
                                        selectedTimeInMinutes = nil

                                        let localX = value.location.x - plotArea.origin.x
                                        let clampedX = max(0, min(plotArea.width, localX))

                                        if let time = proxy.value(atX: clampedX) as Double? {
                                            let newDuration = max(60, min(maxDuration, time * 60))
                                            trimDuration = newDuration
                                        }
                                    }
                                    .onEnded { _ in
                                        isDraggingHandle = false
                                    }
                            )
                    }

                    // Tooltip for selected point
                    if let selected = selectedDataPoint, !isDraggingHandle,
                       let xPos = proxy.position(forX: selected.timeInMinutes),
                       let yPos = proxy.position(forY: selected.heartRate) {
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
                        .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: chartHeight)

            // Legend
            HStack(spacing: 6) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 24, y: 0))
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(height: 1.5)

                Text("Avg: \(Int(activeAverageHR)) bpm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())

                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
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
}

#Preview {
    @Previewable @State var trim: TimeInterval = 1800

    let sampleData = (0..<45).map { index in
        let time = TimeInterval(index * 60)
        let baseHR: Double
        if index < 5 {
            baseHR = 90 + Double(index) * 8
        } else if index < 30 {
            baseHR = 140 + Double.random(in: -15...15)
        } else {
            baseHR = 140 - Double(index - 30) * 4 + Double.random(in: -5...5)
        }
        return HeartRateDataPoint(heartRate: max(70, baseHR), timeOffset: time)
    }

    HeartRateTrimChartView(
        dataPoints: sampleData,
        maxDuration: 2700,
        trimDuration: $trim
    )
    .padding()
}
