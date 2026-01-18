//
//  SessionStats.swift
//  heatlab
//
//  Computed statistics for a yoga session
//

import Foundation
import HealthKit

/// Computed stats derived from HealthKit data
struct SessionStats: Hashable {
    let averageHR: Double
    let maxHR: Double
    let minHR: Double
    let calories: Double
    let duration: TimeInterval
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Combined session metadata and stats for display
struct SessionWithStats: Identifiable, Hashable {
    let session: HeatSession
    let workout: HKWorkout?
    let stats: SessionStats
    
    var id: UUID { session.id }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SessionWithStats, rhs: SessionWithStats) -> Bool {
        lhs.id == rhs.id
    }
}

/// Heart rate data point with time offset from session start
struct HeartRateDataPoint: Identifiable {
    let id = UUID()
    let heartRate: Double
    let timeOffset: TimeInterval
    
    var timeInMinutes: Double {
        timeOffset / 60.0
    }
}
