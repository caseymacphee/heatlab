//
//  HeatLabStyles.swift
//  heatlab
//
//  Reusable view modifiers for consistent card and component styling
//

import SwiftUI

// MARK: - Platform Colors

/// Card background color that adapts to platform
private var cardBackgroundColor: Color {
    #if os(watchOS)
    Color.gray.opacity(0.2)
    #else
    Color(.systemGray6)
    #endif
}

/// System background color that adapts to platform
private var systemBackgroundColor: Color {
    #if os(watchOS)
    Color.black
    #else
    Color(.systemBackground)
    #endif
}

// MARK: - Card Styles

/// Primary card style for main content cards
struct HeatLabCardStyle: ViewModifier {
    var radius: CGFloat = HeatLabRadius.lg

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
            .clipShape(RoundedRectangle(cornerRadius: HeatLabRadius.md))
    }
}

/// Hint card style for info/warning messages
struct HeatLabHintCardStyle: ViewModifier {
    var color: Color

    func body(content: Content) -> some View {
        content
            .padding(HeatLabSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: HeatLabRadius.md))
    }
}

/// Input field style for edit mode (elevated with subtle shadow)
struct HeatLabInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(HeatLabSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: HeatLabRadius.lg)
                    .fill(systemBackgroundColor)
                    .shadow(
                        color: HeatLabShadow.subtle.color,
                        radius: HeatLabShadow.subtle.radius,
                        x: HeatLabShadow.subtle.x,
                        y: HeatLabShadow.subtle.y
                    )
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply primary card styling (padding, gray background, rounded corners)
    func heatLabCard(radius: CGFloat = HeatLabRadius.lg) -> some View {
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
}
