//
//  BaselineComparisonView.swift
//  heatlab
//
//  Displays baseline comparison for a session
//

import SwiftUI

struct BaselineComparisonView: View {
    let comparison: BaselineComparison
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: comparison.icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("vs Your Baseline")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(comparison.displayText)
                    .font(.subheadline)
            }
            
            Spacer()
        }
        .padding()
        .background(iconColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var iconColor: Color {
        switch comparison {
        case .typical: return .blue
        case .higherEffort: return .orange
        case .lowerEffort: return .green
        case .insufficientData: return .gray
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        BaselineComparisonView(comparison: .typical)
        BaselineComparisonView(comparison: .higherEffort(percentAbove: 12))
        BaselineComparisonView(comparison: .lowerEffort(percentBelow: 8))
        BaselineComparisonView(comparison: .insufficientData(sessionsNeeded: 2))
    }
    .padding()
}

