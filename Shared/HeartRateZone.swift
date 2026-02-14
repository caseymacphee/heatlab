//
//  HeartRateZone.swift
//  heatlab
//
//  Heart rate zone model for contextualizing effort during sessions
//

import SwiftUI

// MARK: - Heart Rate Zone

enum HeartRateZone: Int, CaseIterable, Comparable, Codable {
    case zone1 = 1
    case zone2 = 2
    case zone3 = 3
    case zone4 = 4
    case zone5 = 5

    var label: String {
        "Zone \(rawValue)"
    }

    var intensityLabel: String {
        switch self {
        case .zone1: return "Very Light"
        case .zone2: return "Light"
        case .zone3: return "Moderate"
        case .zone4: return "Hard"
        case .zone5: return "Maximum"
        }
    }

    var color: Color {
        switch self {
        case .zone1: return Color(red: 0x8F/255, green: 0xAF/255, blue: 0x9B/255) // Soft Sage
        case .zone2: return Color(red: 0x7F/255, green: 0x9A/255, blue: 0x4E/255) // Muted Olive
        case .zone3: return Color(red: 0xC6/255, green: 0xA3/255, blue: 0x5A/255) // Warm Sand
        case .zone4: return Color(red: 0xC9/255, green: 0x7A/255, blue: 0x4A/255) // Terracotta
        case .zone5: return Color(red: 0x5B/255, green: 0x2D/255, blue: 0x47/255) // Deep Plum
        }
    }

    /// Percentage of max HR range for this zone (lower bound, upper bound)
    var percentageRange: ClosedRange<Double> {
        switch self {
        case .zone1: return 0.50...0.60
        case .zone2: return 0.60...0.70
        case .zone3: return 0.70...0.80
        case .zone4: return 0.80...0.90
        case .zone5: return 0.90...1.00
        }
    }

    /// BPM range for a given max heart rate
    func bpmRange(maxHR: Double) -> ClosedRange<Double> {
        (percentageRange.lowerBound * maxHR)...(percentageRange.upperBound * maxHR)
    }

    /// Determine which zone a heart rate falls into
    static func zone(for heartRate: Double, maxHR: Double) -> HeartRateZone {
        guard maxHR > 0 else { return .zone1 }
        let pct = heartRate / maxHR
        switch pct {
        case ..<0.60: return .zone1
        case 0.60..<0.70: return .zone2
        case 0.70..<0.80: return .zone3
        case 0.80..<0.90: return .zone4
        default: return .zone5
        }
    }

    static func < (lhs: HeartRateZone, rhs: HeartRateZone) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Zone Distribution

struct ZoneDistribution: Codable, Equatable {
    let maxHR: Double
    let entries: [Entry]

    struct Entry: Codable, Equatable, Identifiable {
        var id: Int { zone.rawValue }
        let zone: HeartRateZone
        let duration: TimeInterval
        let percentage: Double // 0–1
    }

    /// Entries sorted by time spent (descending) for UI display
    var sortedByTimeSpent: [Entry] {
        entries.sorted { $0.duration > $1.duration }
    }

    /// Zone with the most time spent
    var dominantZone: HeartRateZone? {
        entries.max(by: { $0.duration < $1.duration })?.zone
    }

    /// Highest zone reached (any time spent)
    var peakZone: HeartRateZone? {
        entries.filter { $0.duration > 0 }.max(by: { $0.zone < $1.zone })?.zone
    }

    /// Total tracked duration across all zones
    var totalDuration: TimeInterval {
        entries.reduce(0) { $0 + $1.duration }
    }
}

// MARK: - Zoned Heart Rate Data Point

struct ZonedHeartRateDataPoint: Identifiable {
    let id = UUID()
    let heartRate: Double
    let timeOffset: TimeInterval
    let zone: HeartRateZone

    var timeInMinutes: Double {
        timeOffset / 60.0
    }
}
