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

/// Source of a workout for deduplication priority
/// Lower rawValue = higher priority (HeatLab Watch is most trusted)
enum WorkoutSource: Int, Codable, CaseIterable {
    case heatlabWatch = 0   // Highest priority - native app
    case appleWatch = 1     // Apple's native workout app
    case garmin = 2         // Good HR data
    case whoop = 3          // Continuous HR monitoring
    case oura = 4           // Sleep/recovery focused
    case strava = 5         // Often aggregates from other sources, no HR sampler
    case unknown = 99       // Unknown/unidentified source

    /// Detect source from HKWorkout bundle identifier
    static func from(bundleIdentifier: String?) -> WorkoutSource {
        guard let bundle = bundleIdentifier?.lowercased() else { return .unknown }

        if bundle.contains("com.macpheelabs.heatlab") { return .heatlabWatch }
        if bundle.contains("com.apple.health") || bundle.contains("com.apple.workout") { return .appleWatch }
        if bundle.contains("garmin") { return .garmin }
        if bundle.contains("whoop") { return .whoop }
        if bundle.contains("oura") { return .oura }
        if bundle.contains("strava") { return .strava }

        return .unknown
    }

    /// Human-readable name for display
    var displayName: String {
        switch self {
        case .heatlabWatch: return "HeatLab Watch"
        case .appleWatch: return "Apple Watch"
        case .garmin: return "Garmin"
        case .whoop: return "Whoop"
        case .oura: return "Oura"
        case .strava: return "Strava"
        case .unknown: return "Unknown"
        }
    }
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
    var workoutTypeRaw: String = "yoga"  // HealthKit workout type: "yoga", "pilates", "barre"
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

    // Source tracking for deduplication
    var sourceRaw: Int = WorkoutSource.unknown.rawValue
    var relatedWorkoutUUIDsJSON: String?  // JSON array of UUID strings for duplicate workouts
    
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pending }
        set { syncStateRaw = newValue.rawValue }
    }

    var perceivedEffort: PerceivedEffort {
        get { PerceivedEffort(rawValue: perceivedEffortRaw) ?? .none }
        set { perceivedEffortRaw = newValue.rawValue }
    }

    var source: WorkoutSource {
        get { WorkoutSource(rawValue: sourceRaw) ?? .unknown }
        set { sourceRaw = newValue.rawValue }
    }

    /// UUIDs of duplicate workouts that were dismissed when this one was claimed
    var relatedWorkoutUUIDs: [UUID]? {
        get {
            guard let json = relatedWorkoutUUIDsJSON,
                  let data = json.data(using: .utf8),
                  let strings = try? JSONDecoder().decode([String].self, from: data) else {
                return nil
            }
            return strings.compactMap { UUID(uuidString: $0) }
        }
        set {
            guard let uuids = newValue, !uuids.isEmpty else {
                relatedWorkoutUUIDsJSON = nil
                return
            }
            let strings = uuids.map { $0.uuidString }
            if let data = try? JSONEncoder().encode(strings),
               let json = String(data: data, encoding: .utf8) {
                relatedWorkoutUUIDsJSON = json
            }
        }
    }
    
    /// Display name for the workout type (Yoga, Pilates, Barre)
    var workoutTypeDisplayName: String {
        switch workoutTypeRaw {
        case "yoga": return "Yoga"
        case "pilates": return "Pilates"
        case "barre": return "Barre"
        default: return "Yoga"  // Fallback
        }
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
    case unheated
    case warm      // 80-89°F / 27-31°C
    case hot       // 90-99°F / 32-37°C
    case veryHot   // 100-104°F / 38-40°C
    case hottest   // 105°F+ / 41°C+

    static func from(temperature: Int) -> TemperatureBucket {
        switch temperature {
        case ..<90: return .warm
        case 90..<100: return .hot
        case 100..<105: return .veryHot
        default: return .hottest
        }
    }

    /// Display name showing the temperature range in the user's preferred unit
    func displayName(for unit: TemperatureUnit) -> String {
        switch self {
        case .unheated:
            return "Unheated"
        case .warm:
            return unit == .fahrenheit ? "80-89°F" : "27-31°C"
        case .hot:
            return unit == .fahrenheit ? "90-99°F" : "32-37°C"
        case .veryHot:
            return unit == .fahrenheit ? "100-104°F" : "38-40°C"
        case .hottest:
            return unit == .fahrenheit ? "105°F+" : "41°C+"
        }
    }

    /// Whether this is a heated temperature bucket
    var isHeated: Bool {
        self != .unheated
    }

    /// Returns only the heated buckets (for UI filtering when you only want temperature options)
    static var heatedCases: [TemperatureBucket] {
        allCases.filter { $0.isHeated }
    }
}


