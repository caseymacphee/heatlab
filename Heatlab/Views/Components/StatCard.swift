//
//  StatCard.swift
//  heatlab
//
//  Reusable stat display card
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var systemIcon: String
    var iconColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemIcon)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .heatLabSecondaryCard()
    }
}

#Preview {
    VStack {
        HStack {
            StatCard(title: "Duration", value: "45:32", systemIcon: SFSymbol.clock, iconColor: Color.HeatLab.duration)
            StatCard(title: "Avg HR", value: "142 bpm", systemIcon: SFSymbol.heartFill, iconColor: Color.HeatLab.heartRate)
        }
        HStack {
            StatCard(title: "Max HR", value: "168 bpm", systemIcon: SFSymbol.heartFill, iconColor: .pink)
            StatCard(title: "Calories", value: "387 kcal", systemIcon: SFSymbol.fireFill, iconColor: Color.HeatLab.calories)
        }
    }
    .padding()
}

