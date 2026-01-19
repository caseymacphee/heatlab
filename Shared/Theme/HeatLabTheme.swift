//
//  HeatLabTheme.swift
//  heatlab
//
//  Central theme system for Heat Lab - colors, spacing, typography
//

import SwiftUI

// MARK: - Brand Colors

extension Color {
    /// Heat Lab brand color palette
    enum HeatLab {
        // Primary Brand Colors
        /// Brand coral - primary accent color (#FF4D2D)
        static let coral = Color(red: 1.0, green: 0.302, blue: 0.176)
        /// Lighter coral for dark mode accent (#FF6A55)
        static let coralLight = Color(red: 1.0, green: 0.416, blue: 0.333)
        /// Deep heat - use sparingly for extreme temps (#E23B33)
        static let deepHeat = Color(red: 0.886, green: 0.231, blue: 0.200)

        // Temperature Gradient Colors
        /// Warm amber for <90F temps
        static let tempWarm = Color(red: 1.0, green: 0.75, blue: 0.4)
        /// Orange for 90-99F temps
        static let tempHot = Color(red: 1.0, green: 0.5, blue: 0.2)
        /// Coral for 100-104F temps (matches brand)
        static let tempVeryHot = coral
        /// Deep heat for 105F+ temps
        static let tempExtreme = deepHeat

        // Semantic Stat Colors (use for icons/accents)
        static let heartRate = Color.red
        static let duration = Color.blue
        static let calories = Color.orange
        static let sessions = Color.purple

        /// Unified temperature color mapping
        /// Use this everywhere to ensure consistency
        static func temperature(fahrenheit: Int) -> Color {
            switch fahrenheit {
            case ..<90: return tempWarm
            case 90..<100: return tempHot
            case 100..<105: return tempVeryHot
            default: return tempExtreme
            }
        }
    }
}

// MARK: - Gradients

extension LinearGradient {
    /// Brand gradient for primary elements (coral tones)
    static let heatLabPrimary = LinearGradient(
        colors: [Color.HeatLab.coral, Color.HeatLab.coralLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Chart gradient for HR and trend charts (warm to hot)
    static let heatLabChart = LinearGradient(
        colors: [Color.HeatLab.tempHot, Color.HeatLab.tempVeryHot],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Temperature gauge gradient (full range)
    static let temperatureGauge = LinearGradient(
        colors: [
            Color.HeatLab.tempWarm,
            Color.HeatLab.tempHot,
            Color.HeatLab.tempVeryHot,
            Color.HeatLab.tempExtreme
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Insight card subtle gradient (brand-aligned)
    static let insight = LinearGradient(
        colors: [Color.HeatLab.coral.opacity(0.12), Color.HeatLab.coralLight.opacity(0.06)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Spacing Constants

enum HeatLabSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Corner Radius Constants

enum HeatLabRadius {
    /// Small elements: filter dropdowns, small badges
    static let sm: CGFloat = 8
    /// Secondary cards: stat cards, badges, buttons
    static let md: CGFloat = 12
    /// Primary cards: main content cards, charts
    static let lg: CGFloat = 16
    /// Large modal sheets
    static let xl: CGFloat = 20
}

// MARK: - Shadow Presets

enum HeatLabShadow {
    /// Subtle shadow for elevated inputs (edit mode)
    static let subtle = (color: Color.black.opacity(0.05), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(2))
}

// MARK: - SF Symbol Names

/// SF Symbol names for consistent iconography
enum SFSymbol {
    // Navigation
    static let home = "house"
    static let homeFill = "house.fill"
    static let sessions = "list.bullet"
    static let sessionsFill = "list.bullet"
    static let analysis = "chart.bar"
    static let analysisFill = "chart.bar.fill"
    static let settings = "gearshape"
    static let settingsFill = "gearshape.fill"

    // Health/Stats
    static let heart = "heart"
    static let heartFill = "heart.fill"
    static let clock = "clock"
    static let fire = "flame"
    static let fireFill = "flame.fill"
    static let waveform = "waveform.path.ecg"
    static let thermometer = "thermometer.medium"
    static let yoga = "figure.yoga"

    // Actions
    static let play = "play.circle"
    static let playFill = "play.circle.fill"
    static let pause = "pause.circle"
    static let pauseFill = "pause.circle.fill"
    static let stop = "stop.circle"
    static let stopFill = "stop.circle.fill"
    static let trash = "trash"
    static let add = "plus.circle"
    static let addFill = "plus.circle.fill"
    static let sparkles = "sparkles"
    static let refresh = "arrow.clockwise"
    static let edit = "pencil"
    static let checkmark = "checkmark"
    static let xmark = "xmark"

    // Status/Comparison
    static let arrowUp = "arrow.up.circle"
    static let arrowUpFill = "arrow.up.circle.fill"
    static let arrowDown = "arrow.down.circle"
    static let arrowDownFill = "arrow.down.circle.fill"
    static let minus = "minus.circle"
    static let minusFill = "minus.circle.fill"
    static let chevronDown = "chevron.down"
    static let chevronRight = "chevron.right"
    static let info = "info.circle"
    static let infoFill = "info.circle.fill"
    static let externalLink = "arrow.up.right.square"
}
