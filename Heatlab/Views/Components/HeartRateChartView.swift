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
    let minHR: Double
    let maxHR: Double
    let averageHR: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Over Time")
                .font(.headline)
            
            if dataPoints.isEmpty {
                ContentUnavailableView(
                    "No Heart Rate Data",
                    systemImage: "heart.slash",
                    description: Text("Heart rate data is not available for this session")
                )
                .frame(height: 200)
            } else {
                Chart(dataPoints) { point in
                    LineMark(
                        x: .value("Time", point.timeInMinutes),
                        y: .value("Heart Rate", point.heartRate)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .red],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    
                    // Add average HR reference line
                    RuleMark(y: .value("Average", averageHR))
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
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
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let bpm = value.as(Double.self) {
                                Text("\(Int(bpm))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYScale(domain: yAxisDomain)
                .chartYAxisLabel("Heart Rate (bpm)", position: .leading)
                .chartXAxisLabel("Time (minutes)", position: .bottom)
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
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var yAxisDomain: ClosedRange<Double> {
        guard !dataPoints.isEmpty else {
            return 60...180
        }
        
        // Calculate actual min/max from the data points themselves
        // This ensures we capture all data points, even if they're below typical thresholds
        let actualMinHR = dataPoints.map { $0.heartRate }.min() ?? minHR
        let actualMaxHR = dataPoints.map { $0.heartRate }.max() ?? maxHR
        
        let padding = 10.0
        // Don't hardcode a minimum - use the actual minimum from data with padding
        let minValue = max(0, (actualMinHR - padding).rounded(.down))
        let maxValue = (actualMaxHR + padding).rounded(.up)
        
        return minValue...maxValue
    }
    
    private func formatTimeLabel(_ minutes: Double) -> String {
        let totalMinutes = Int(minutes)
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", mins))"
        } else {
            return "\(mins)m"
        }
    }
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
        minHR: 100,
        maxHR: 160,
        averageHR: 140
    )
    .padding()
}
