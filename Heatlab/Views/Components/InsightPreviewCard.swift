//
//  InsightPreviewCard.swift
//  heatlab
//
//  Compact insight preview card for Dashboard - tappable to navigate to Analysis
//

import SwiftUI

struct InsightPreviewCard: View {
    let insight: String?
    let isGenerating: Bool
    let sessionCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: SFSymbol.sparkles)
                        .foregroundStyle(Color.HeatLab.coral)
                    Text("Insight")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: SFSymbol.chevronRight)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let insight = insight {
                    Text(insight)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else if isGenerating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Analyzing your practice...")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                } else if sessionCount < 2 {
                    Text("Log \(2 - sessionCount) more session\(sessionCount == 1 ? "" : "s") to unlock insights")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("Tap to view detailed analysis")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(LinearGradient.insight)
            .clipShape(RoundedRectangle(cornerRadius: HeatLabRadius.lg))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        InsightPreviewCard(
            insight: "Great consistency this week! Your avg HR dropped 3% compared to last week at the same temperatures.",
            isGenerating: false,
            sessionCount: 5,
            onTap: {}
        )

        InsightPreviewCard(
            insight: nil,
            isGenerating: true,
            sessionCount: 3,
            onTap: {}
        )

        InsightPreviewCard(
            insight: nil,
            isGenerating: false,
            sessionCount: 1,
            onTap: {}
        )
    }
    .padding()
}
