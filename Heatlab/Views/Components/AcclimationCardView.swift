//
//  AcclimationCardView.swift
//  heatlab
//
//  Displays acclimation signal for heat adaptation
//

import SwiftUI

struct AcclimationCardView: View {
    let signal: AcclimationSignal
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: signal.icon)
                .font(.title)
                .foregroundStyle(iconColor)
                .frame(width: 44)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Heat Acclimation")
                    .font(.headline)
                Text(signal.displayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(iconColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var iconColor: Color {
        switch signal.direction {
        case .improving: return .green
        case .stable: return .blue
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        AcclimationCardView(signal: AcclimationSignal(
            percentChange: -8.5,
            direction: .improving,
            sessionCount: 12
        ))
        AcclimationCardView(signal: AcclimationSignal(
            percentChange: 2.1,
            direction: .stable,
            sessionCount: 8
        ))
    }
    .padding()
}

