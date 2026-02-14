//
//  StreakBadgeView.swift
//  heatlab
//
//  Compact streak badge for the Dashboard — flame icon + week count
//  Hidden when streak is 0 (keep dashboard clean)
//

import SwiftUI

struct StreakBadgeView: View {
    let streak: Int

    var body: some View {
        if streak > 0 {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.hlAccent)
                Text("\(streak)-week streak")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.hlText)
            }
            .heatLabHintCard(color: .hlAccent)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StreakBadgeView(streak: 5)
        StreakBadgeView(streak: 1)
        StreakBadgeView(streak: 0) // Should be empty
    }
    .padding()
}
