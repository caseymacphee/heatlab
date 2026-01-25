//
//  AIInsightSection.swift
//  heatlab
//
//  AI insight display with three states: ready, generating, insufficient data, unavailable
//

import SwiftUI

enum AIInsightState {
    case ready(String)
    case generating
    case insufficientData(sessionsNeeded: Int)
    case unavailable
}

struct AIInsightSection: View {
    let state: AIInsightState
    var onRetry: (() -> Void)? = nil

    var body: some View {
        switch state {
        case .ready(let insight):
            readyView(insight: insight)
        case .generating:
            generatingView
        case .insufficientData(let needed):
            insufficientDataView(sessionsNeeded: needed)
        case .unavailable:
            // Hidden entirely - not useful even in debug builds
            EmptyView()
        }
    }

    private func readyView(insight: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: SFSymbol.sparkles)
                    .foregroundStyle(Color.HeatLab.coral)
                Text("Insight")
                    .font(.headline)
                Spacer()
                if let onRetry = onRetry {
                    Button(action: onRetry) {
                        Image(systemName: SFSymbol.refresh)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text(insight)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient.insight)
        .clipShape(RoundedRectangle(cornerRadius: HeatLabRadius.lg))
    }

    private var generatingView: some View {
        HStack(spacing: 8) {
            Image(systemName: SFSymbol.sparkles)
                .foregroundStyle(Color.HeatLab.coral)
            Text("Insight")
                .font(.headline)
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient.insight)
        .clipShape(RoundedRectangle(cornerRadius: HeatLabRadius.lg))
    }

    private func insufficientDataView(sessionsNeeded: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: SFSymbol.sparkles)
                .foregroundStyle(Color.HeatLab.coral.opacity(0.5))
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Insights")
                    .font(.subheadline.bold())
                Text("Log \(sessionsNeeded)+ session\(sessionsNeeded == 1 ? "" : "s") to unlock personalized analysis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: HeatLabRadius.lg))
    }

    private var unavailableView: some View {
        Text("AI insights require a physical device")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }
}

#Preview {
    VStack(spacing: 16) {
        AIInsightSection(
            state: .ready("Great week! Your average heart rate dropped 5% compared to last week at similar temperatures, indicating improved heat tolerance."),
            onRetry: {}
        )

        AIInsightSection(state: .generating)

        AIInsightSection(state: .insufficientData(sessionsNeeded: 2))

        AIInsightSection(state: .unavailable)
    }
    .padding()
}
