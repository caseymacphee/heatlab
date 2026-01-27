//
//  WorkoutSession.swift
//  heatlab
//
//  Shared SwiftData model for workout sessions
//

import SwiftData
import Foundation

/// Sync state for local-first data model
enum SyncState: String, Codable {
    case pending    // Not yet synced to CloudKit
    case uploading  // Currently syncing
    case synced     // Successfully synced
    case failed     // Sync failed, will retry
}

/// Perceived effort level for a session
enum PerceivedEffort: String, Codable, CaseIterable {
    case none = "none"
    case veryEasy = "very_easy"
    case easy = "easy"
    case moderate = "moderate"
    case hard = "hard"
    case veryHard = "very_hard"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .veryEasy: return "Very Easy"
        case .easy: return "Easy"
        case .moderate: return "Moderate"
        case .hard: return "Hard"
        case .veryHard: return "Very Hard"
        }
    }

    /// Short name for compact displays (watchOS)
    var shortName: String {
        switch self {
        case .none: return "None"
        case .veryEasy: return "V.Easy"
        case .easy: return "Easy"
        case .moderate: return "Mod"
        case .hard: return "Hard"
        case .veryHard: return "V.Hard"
        }
    }
}

@Model
final class WorkoutSession {
    // Identity
    var id: UUID = UUID()
    
    /// Links to HKWorkout - used for upserts (uniqueness enforced in code, not DB - CloudKit doesn't support unique constraints)
    /// nil for sessions created without a HealthKit workout
    var workoutUUID: UUID?
    
    // Session data
    var startDate: Date = Date()
    var endDate: Date?
    var roomTemperature: Int?  // Degrees Fahrenheit (e.g., 95, 105) - nil means unheated
    var sessionTypeId: UUID?  // References SessionTypeConfig.id
    var userNotes: String?
    var aiSummary: String?
    var manualDurationOverride: TimeInterval?  // Manual duration override (overrides HealthKit workout duration)
    var perceivedEffortRaw: String = PerceivedEffort.none.rawValue  // Store raw value for SwiftData compatibility
    
    // Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Sync metadata (local-first architecture)
    var syncStateRaw: String = SyncState.pending.rawValue
    var lastSyncError: String?
    var deletedAt: Date?  // Tombstone for soft deletes
    
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pending }
        set { syncStateRaw = newValue.rawValue }
    }
    
    var perceivedEffort: PerceivedEffort {
        get { PerceivedEffort(rawValue: perceivedEffortRaw) ?? .none }
        set { perceivedEffortRaw = newValue.rawValue }
    }
    
    /// Whether this session needs to be synced to CloudKit
    var needsSync: Bool {
        syncState == .pending || syncState == .failed
    }
    
    /// Whether this session has been soft-deleted
    var isDeleted: Bool {
        deletedAt != nil
    }
    
    init(workoutUUID: UUID, startDate: Date, roomTemperature: Int? = nil) {
        self.id = UUID()
        self.workoutUUID = workoutUUID
        self.startDate = startDate
        self.roomTemperature = roomTemperature
        self.createdAt = Date()
        self.updatedAt = Date()
        self.syncStateRaw = SyncState.pending.rawValue
        self.perceivedEffortRaw = PerceivedEffort.none.rawValue
    }
    
    /// Mark session as updated (call before any modification)
    func markUpdated() {
        updatedAt = Date()
        if syncState == .synced {
            syncState = .pending
        }
    }
    
    /// Soft delete this session
    func softDelete() {
        deletedAt = Date()
        markUpdated()
    }
    
    /// Returns a temperature bucket for baseline comparisons
    /// Returns .unheated when roomTemperature is nil
    var temperatureBucket: TemperatureBucket {
        guard let temp = roomTemperature else { return .unheated }
        return TemperatureBucket.from(temperature: temp)
    }
}

/// Temperature buckets for baseline grouping
/// Includes temperature ranges for heated sessions and a separate bucket for unheated
enum TemperatureBucket: String, Codable, CaseIterable {
    case unheated = "Unheated"    // roomTemperature == nil
    case warm = "80-89°F"         // < 90
    case hot = "90-99°F"          // 90-99
    case veryHot = "100-104°F"    // 100-104
    case extreme = "105°F+"       // 105+
    
    static func from(temperature: Int) -> TemperatureBucket {
        switch temperature {
        case ..<90: return .warm
        case 90..<100: return .hot
        case 100..<105: return .veryHot
        default: return .extreme
        }
    }
    
    var displayName: String { rawValue }
    
    /// Whether this is a heated temperature bucket
    var isHeated: Bool {
        self != .unheated
    }
    
    /// Returns only the heated buckets (for UI filtering when you only want temperature options)
    static var heatedCases: [TemperatureBucket] {
        allCases.filter { $0.isHeated }
    }
}


