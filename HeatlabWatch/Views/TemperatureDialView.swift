//
//  TemperatureDialView.swift
//  Heatlab Watch Watch App
//
//  Digital Crown-controlled temperature selector with unit support
//

import SwiftUI

/// Conditionally applies digital crown rotation only when the view is ready
/// This prevents the "Crown Sequencer was set up without a view property" warning
private struct CrownRotationModifier: ViewModifier {
    @Binding var crownValue: Double
    let minTemp: Double
    let maxTemp: Double
    let isReady: Bool
    
    func body(content: Content) -> some View {
        if isReady {
            content
                .digitalCrownRotation(
                    $crownValue,
                    from: minTemp,
                    through: maxTemp,
                    by: 1.0,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
        } else {
            content
        }
    }
}

struct TemperatureDialView: View {
    @Binding var temperature: Int  // Value in user's preferred unit
    let unit: TemperatureUnit
    
    // Internal Double state for Digital Crown (requires BinaryFloatingPoint)
    @State private var crownValue: Double = 0
    @State private var isViewReady = false
    @FocusState private var isFocused: Bool
    
    private var minTemp: Double { Double(unit.inputRange.lowerBound) }
    private var maxTemp: Double { Double(unit.inputRange.upperBound) }
    
    var body: some View {
        VStack(spacing: 8) {
            // Temperature display with color gradient based on heat
            Text("\(temperature)\(unit.rawValue)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(temperatureColor)
            
            // Visual arc/gauge indicator
            TemperatureGaugeView(
                temperature: temperature,
                range: unit.inputRange
            )
            .frame(height: 40)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .focusable(isViewReady)
        .focused($isFocused)
        .modifier(CrownRotationModifier(
            crownValue: $crownValue,
            minTemp: minTemp,
            maxTemp: maxTemp,
            isReady: isViewReady
        ))
        .onAppear {
            crownValue = Double(temperature)
            // Delay enabling focusable and crown until view is fully laid out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isViewReady = true
                // Set focus after crown is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isFocused = true
                }
            }
        }
        .onChange(of: crownValue) { _, newValue in
            temperature = Int(newValue.rounded())
        }
    }
    
    private var temperatureColor: Color {
        // Convert to Fahrenheit for consistent color thresholds
        let fahrenheit = Temperature.fromUserInput(temperature, unit: unit).fahrenheit
        switch fahrenheit {
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
    TemperatureDialView(temperature: .constant(100), unit: .fahrenheit)
}
