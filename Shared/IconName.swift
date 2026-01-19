//
//  IconName.swift
//  heatlab
//
//  Type-safe icon names for Heroicons integration
//
//  DEPRECATED: Use SFSymbol constants from HeatLabTheme.swift instead.
//  This file is kept for backward compatibility during the migration.
//  All new code should use SF Symbols via the SFSymbol enum.
//

import SwiftUI

/// Icon names for Heroicons assets
/// @available(*, deprecated, message: "Use SFSymbol constants from HeatLabTheme.swift instead")
enum IconName: String {
    // Navigation - Outline
    case home = "icon-home"
    case bars3 = "icon-bars-3"
    case chartBar = "icon-chart-bar"
    case cog6Tooth = "icon-cog-6-tooth"

    // Navigation - Solid (for selected tab state)
    case homeSolid = "icon-home-solid"
    case bars3Solid = "icon-bars-3-solid"
    case chartBarSolid = "icon-chart-bar-solid"
    case cog6ToothSolid = "icon-cog-6-tooth-solid"

    // Fire icons (for calories/heat)
    case fire = "icon-fire"
    case fireSolid = "icon-fire-solid"

    // Health/Stats
    case heart = "icon-heart"
    case clock = "icon-clock"

    // Actions
    case playCircle = "icon-play-circle"
    case pauseCircle = "icon-pause-circle"
    case stopCircle = "icon-stop-circle"
    case trash = "icon-trash"
    case plusCircle = "icon-plus-circle"
    case sparkles = "icon-sparkles"
    case arrowPath = "icon-arrow-path"

    // Status/Comparison
    case arrowUpCircle = "icon-arrow-up-circle"
    case arrowDownCircle = "icon-arrow-down-circle"
    case minusCircle = "icon-minus-circle"
    case chevronDown = "icon-chevron-down"
    case informationCircle = "icon-information-circle"
}

extension Image {
    /// Create an image from an IconName asset
    init(icon: IconName) {
        self.init(icon.rawValue)
    }
}

extension Label where Title == Text, Icon == Image {
    /// Create a label with an IconName asset
    init(_ title: String, icon: IconName) {
        self.init {
            Text(title)
        } icon: {
            Image(icon: icon)
        }
    }
}
