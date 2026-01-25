//
//  TemperatureBadge.swift
//  heatlab
//
//  Reusable temperature badge component
//

import SwiftUI

struct TemperatureBadge: View {
    /// Temperature in Fahrenheit (storage format) - nil for non-heated sessions
    let temperature: Int?
    /// Display unit preference
    let unit: TemperatureUnit
    var size: BadgeSize = .regular
    
    enum BadgeSize {
        case small, regular, large
        
        var font: Font {
            switch self {
            case .small: return .caption2.bold()
            case .regular: return .subheadline.bold()
            case .large: return .title3.bold()
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .regular: return 12
            case .large: return 16
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .small: return 4
            case .regular: return 6
            case .large: return 8
            }
        }
    }
    
    var body: some View {
        if let temp = temperature {
            let tempValue = Temperature(fahrenheit: temp)
            Text(tempValue.formatted(unit: unit))
                .font(size.font)
                .padding(.horizontal, size.horizontalPadding)
                .padding(.vertical, size.verticalPadding)
                .background(Color.HeatLab.temperature(fahrenheit: temp).opacity(0.2))
                .foregroundStyle(Color.HeatLab.temperature(fahrenheit: temp))
                .clipShape(Capsule())
        }
        // No badge shown for non-heated sessions
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Fahrenheit")
        TemperatureBadge(temperature: 85, unit: .fahrenheit, size: .small)
        TemperatureBadge(temperature: 95, unit: .fahrenheit)
        TemperatureBadge(temperature: 102, unit: .fahrenheit, size: .large)
        
        Divider()
        
        Text("Celsius")
        TemperatureBadge(temperature: 85, unit: .celsius, size: .small)
        TemperatureBadge(temperature: 95, unit: .celsius)
        TemperatureBadge(temperature: 102, unit: .celsius, size: .large)
        
        Divider()
        
        Text("Non-heated (no badge)")
        HStack {
            Text("Before:")
            TemperatureBadge(temperature: nil, unit: .fahrenheit)
            Text("After")
        }
    }
}
