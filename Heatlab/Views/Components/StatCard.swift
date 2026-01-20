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
    var iconColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemIcon)
                    .foregroundStyle(.secondary)
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
            StatCard(title: "Duration", value: "45:32", systemIcon: SFSymbol.clock)
            StatCard(title: "Avg HR", value: "142 bpm", systemIcon: SFSymbol.heartFill)
        }
        HStack {
            StatCard(title: "Max HR", value: "168 bpm", systemIcon: SFSymbol.heartFill)
            StatCard(title: "Calories", value: "387 kcal", systemIcon: SFSymbol.fireFill)
        }
    }
    .padding()
}

