//
//  TemperatureDialView.swift
//  Heatlab Watch Watch App
//
//  Digital Crown-controlled temperature selector
//

import SwiftUI

struct TemperatureDialView: View {
    @Binding var temperature: Int
    
    // Temperature range for hot yoga: 80°F - 115°F
    private let minTemp = 80
    private let maxTemp = 115
    
    var body: some View {
        VStack(spacing: 8) {
            // Temperature display with color gradient based on heat
            Text("\(temperature)°F")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(temperatureColor)
            
            // Visual arc/gauge indicator
            TemperatureGaugeView(
                temperature: temperature,
                range: minTemp...maxTemp
            )
            .frame(height: 40)
            
            Text("Turn crown to adjust")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .focusable()
        .digitalCrownRotation(
            $temperature,
            from: minTemp,
            through: maxTemp,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
    }
    
    private var temperatureColor: Color {
        switch temperature {
        case ..<90: return .yellow
        case 90..<100: return .orange
        case 100..<105: return .red
        default: return .pink
        }
    }
}

// Visual gauge showing temperature on a curved arc
struct TemperatureGaugeView: View {
    let temperature: Int
    let range: ClosedRange<Int>
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background arc
                Arc(startAngle: .degrees(135), endAngle: .degrees(405))
                    .stroke(.gray.opacity(0.3), lineWidth: 6)
                
                // Filled arc based on temperature
                Arc(startAngle: .degrees(135), endAngle: .degrees(135 + progress * 270))
                    .stroke(
                        LinearGradient(
                            colors: [.yellow, .orange, .red, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
            }
        }
    }
    
    private var progress: Double {
        Double(temperature - range.lowerBound) / Double(range.upperBound - range.lowerBound)
    }
}

// Custom arc shape
struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY - 10)
        let radius = min(rect.width, rect.height) * 0.8
        
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        
        return path
    }
}

#Preview {
    TemperatureDialView(temperature: .constant(100))
}

