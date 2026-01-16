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
    var icon: String? = nil
    var iconColor: Color = .primary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack {
        HStack {
            StatCard(title: "Duration", value: "45:32", icon: "clock", iconColor: .blue)
            StatCard(title: "Avg HR", value: "142 bpm", icon: "heart.fill", iconColor: .red)
        }
        HStack {
            StatCard(title: "Max HR", value: "168 bpm", icon: "heart.fill", iconColor: .pink)
            StatCard(title: "Calories", value: "387 kcal", icon: "flame.fill", iconColor: .orange)
        }
    }
    .padding()
}

