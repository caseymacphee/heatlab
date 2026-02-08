//
//  HeatLabStyles.swift
//  heatlab
//
//  Reusable view modifiers for consistent card and component styling
//

import SwiftUI

// MARK: - Platform Colors

/// Card background color that adapts to platform (uses design system)
private var cardBackgroundColor: Color {
    Color.hlSurface
}

/// System background color that adapts to platform (uses design system)
private var systemBackgroundColor: Color {
    Color.hlBackground
}

// MARK: - Card Styles

/// Primary card style for main content cards
struct HeatLabCardStyle: ViewModifier {
    var radius: CGFloat = HLRadius.card

    func body(content: Content) -> some View {
        content
            .padding(HeatLabSpacing.md)
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

/// Secondary card style for stat cards and smaller elements
struct HeatLabSecondaryCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(HeatLabSpacing.md)
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
    }
}

/// Hint card style for info/warning messages
struct HeatLabHintCardStyle: ViewModifier {
    var color: Color

    func body(content: Content) -> some View {
        content
            .padding(HeatLabSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
    }
}

/// Input field style for edit mode (elevated, no shadow per design system)
struct HeatLabInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(HeatLabSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: HLRadius.input)
                    .fill(Color.hlSurface)
            )
    }
}

/// Tooltip overlay style for chart callouts and inspection popups
struct HeatLabTooltipStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, watchOS 26, *) {
            content
                .padding(10)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: HeatLabRadius.sm))
        } else {
            content
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: HeatLabRadius.sm)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply primary card styling (padding, surface background, 14pt corners)
    func heatLabCard(radius: CGFloat = HLRadius.card) -> some View {
        modifier(HeatLabCardStyle(radius: radius))
    }

    /// Apply secondary card styling for stat cards (smaller radius)
    func heatLabSecondaryCard() -> some View {
        modifier(HeatLabSecondaryCardStyle())
    }

    /// Apply hint card styling with tinted background
    func heatLabHintCard(color: Color) -> some View {
        modifier(HeatLabHintCardStyle(color: color))
    }

    /// Apply input field styling for edit mode (elevated with shadow)
    func heatLabInput() -> some View {
        modifier(HeatLabInputStyle())
    }

    /// Apply tooltip styling for chart callouts (liquid glass on iOS 26+, material fallback)
    func heatLabTooltip() -> some View {
        modifier(HeatLabTooltipStyle())
    }
}
