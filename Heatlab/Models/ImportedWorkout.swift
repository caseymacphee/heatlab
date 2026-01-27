//
//  ImportedWorkout.swift
//  heatlab
//
//  Tracks Apple Health workouts that have been viewed/dismissed by the user
//  Used to avoid re-prompting for already dismissed workouts
//

import SwiftData
import Foundation

@Model
final class ImportedWorkout {
    // Identity
    var id: UUID = UUID()
    
    /// Links to HKWorkout.uuid - the unique identifier from HealthKit
    /// Optional for CloudKit compatibility, but always set via init
    var workoutUUID: UUID?
    
    /// Whether the user has dismissed this workout (doesn't want to claim it)
    var isDismissed: Bool = false
    
    // Timestamps
    var createdAt: Date = Date()
    var lastUpdatedAt: Date = Date()
    
    // Sync metadata (local-first architecture)
    var syncStateRaw: String = SyncState.pending.rawValue
    var lastSyncError: String?
    var deletedAt: Date?  // Tombstone for soft deletes
    
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pending }
        set { syncStateRaw = newValue.rawValue }
    }
    
    /// Whether this record needs to be synced to CloudKit
    var needsSync: Bool {
        syncState == .pending || syncState == .failed
    }
    
    init(workoutUUID: UUID, isDismissed: Bool = false) {
        self.id = UUID()
        self.workoutUUID = workoutUUID
        self.isDismissed = isDismissed
        self.createdAt = Date()
        self.lastUpdatedAt = Date()
        self.syncStateRaw = SyncState.pending.rawValue
    }
    
    /// Mark as updated (call before any modification)
    func markUpdated() {
        lastUpdatedAt = Date()
        if syncState == .synced {
            syncState = .pending
        }
    }
    
    /// Mark this workout as dismissed
    func dismiss() {
        isDismissed = true
        markUpdated()
    }
    
    /// Restore a dismissed workout (make it claimable again)
    func restore() {
        isDismissed = false
        markUpdated()
    }
}
