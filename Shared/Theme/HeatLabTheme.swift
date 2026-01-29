//
//  HeatLabTheme.swift
//  heatlab
//
//  Central theme system for Heat Lab - colors, spacing, typography
//

import SwiftUI

// MARK: - Design System Colors (Asset Catalog)

extension Color {
    /// Warm cream background (#F6F1E8 light, #000000 dark)
    static let hlBackground = Color("Background")
    /// Card/elevated surface (#FFFFFF light, #1C1C1E dark)
    static let hlSurface = Color("Surface")
    /// Secondary surface (#EFE6DA light, #2C2C2E dark)
    static let hlSurface2 = Color("Surface2")
    /// Primary text (#1A1A18 light, #FFFFFF dark)
    static let hlText = Color("TextPrimary")
    /// Muted/secondary text (#6A645B light, #98989D dark)
    static let hlMuted = Color("TextMuted")
    /// Heated clay accent (#C96A4A) - uses system AccentColor
    static let hlAccent = Color.accentColor
    /// Cool/recovery state (#4F8FA3 light, #64D2FF dark)
    static let hlCool = Color("Cool")
    /// Good/positive state (#6E907B light, #30D158 dark)
    static let hlGood = Color("Good")
    /// Grid/divider lines (#E6DED2 light, #38383A dark)
    static let hlGrid = Color("Grid")
    /// Pro highlight - warm honey (#D4A24A light, #B8862F dark)
    static let hlProHighlight = Color("ProHighlight")
}

// MARK: - Watch Display Colors

extension Color {
    /// Warm off-white base color for watch displays
    /// Slightly creamy/warm tone instead of pure blue-white
    private static let watchWarmWhite = Color(red: 1.0, green: 0.98, blue: 0.94)

    /// Primary watch text (timer, main values) - 88% opacity warm white
    /// High contrast but not harsh for hot yoga studio environment
    static let watchTextPrimary = watchWarmWhite.opacity(0.88)

    /// Secondary watch text (labels like BPM, Cal) - 75% opacity warm white
    static let watchTextSecondary = watchWarmWhite.opacity(0.75)

    /// Tertiary watch text (hints, subtle labels) - 55% opacity warm white
    static let watchTextTertiary = watchWarmWhite.opacity(0.55)
}

// MARK: - Legacy Brand Colors (Deprecated - use hl* colors)

extension Color {
    /// Heat Lab brand color palette
    enum HeatLab {
        // Primary Brand Colors - now mapped to design system
        /// Brand accent - heated clay (#C96A4A)
        static let coral = Color.hlAccent
        /// Lighter coral for dark mode accent - use hlAccent instead
        static let coralLight = Color.hlAccent
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
        static let duration = Color.hlAccent
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

/// Design system spacing constants
enum HLSpacing {
    static let micro: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let standard: CGFloat = 16
    static let comfortable: CGFloat = 20
    static let section: CGFloat = 24
    static let major: CGFloat = 32
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

/// Design system corner radius constants
enum HLRadius {
    static let card: CGFloat = 14
    static let button: CGFloat = 12
    static let chip: CGFloat = 8
    static let input: CGFloat = 10
    static let badge: CGFloat = 6
}

// MARK: - Shadow Presets

enum HeatLabShadow {
    /// Subtle shadow for elevated inputs (edit mode)
    static let subtle = (color: Color.black.opacity(0.05), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(2))
}

// MARK: - SF Symbol Names

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
    static let pilates = "figure.pilates"
    static let barre = "figure.barre"
    static let mindAndBody = "figure.mind.and.body"

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
    static let claim = "tag"       // Claim workouts (toolbar, low chrome)
    static let claimFill = "tag.fill"  // Claim workouts (CTA, high intent)

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
