//
//  HLEmptyStateView.swift
//  heatlab
//
//  Reusable empty state component with consistent centering and styling
//

import SwiftUI

struct HLEmptyStateView: View {
    let systemImage: String
    let title: String
    let description: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil
    
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
        } actions: {
            if let action, let label = actionLabel {
                Button(label, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Basic") {
    HLEmptyStateView(
        systemImage: SFSymbol.mindAndBody,
        title: "No Sessions Yet",
        description: "Complete your first session on Apple Watch to see it here."
    )
}

#Preview("With Action") {
    HLEmptyStateView(
        systemImage: SFSymbol.mindAndBody,
        title: "No Matching Sessions",
        description: "Try adjusting your filters to see more sessions.",
        action: { },
        actionLabel: "Clear Filters"
    )
}
