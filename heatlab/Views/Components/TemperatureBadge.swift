//
//  TemperatureBadge.swift
//  heatlab
//
//  Reusable temperature badge component
//

import SwiftUI

struct TemperatureBadge: View {
    let temperature: Int
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
        Text("\(temperature)°F")
            .font(size.font)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(backgroundColor.opacity(0.2))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        switch temperature {
        case ..<90: return .yellow
        case 90..<100: return .orange
        case 100..<105: return .red
        default: return .pink
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TemperatureBadge(temperature: 85, size: .small)
        TemperatureBadge(temperature: 95)
        TemperatureBadge(temperature: 102, size: .large)
        TemperatureBadge(temperature: 108)
    }
}

