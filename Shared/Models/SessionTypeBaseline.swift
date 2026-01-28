//
//  SessionTypeBaseline.swift
//  heatlab
//
//  Tracks user's baseline heart rate per class/session type (e.g., Vinyasa, Pilates, Bikram)
//  This complements UserBaseline which tracks by temperature bucket.
//

import SwiftData
import Foundation

@Model
final class SessionTypeBaseline {
    // Identity
    var id: UUID = UUID()

    // Baseline data
    var sessionTypeId: UUID?  // References SessionTypeConfig.id
    var averageHR: Double = 0
    var sessionCount: Int = 0

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

    /// Whether this baseline needs to be synced to CloudKit
    var needsSync: Bool {
        syncState == .pending || syncState == .failed
    }

    init(sessionTypeId: UUID?, averageHR: Double, sessionCount: Int, lastUpdated: Date) {
        self.id = UUID()
        self.sessionTypeId = sessionTypeId
        self.averageHR = averageHR
        self.sessionCount = sessionCount
        self.createdAt = Date()
        self.updatedAt = lastUpdated
        self.syncStateRaw = SyncState.pending.rawValue
    }

    /// Mark baseline as updated (call before any modification)
    func markUpdated() {
        updatedAt = Date()
        if syncState == .synced {
            syncState = .pending
        }
    }
}
