//
//  UserBaseline.swift
//  heatlab
//
//  Tracks user's baseline heart rate per temperature bucket (temperature ranges + unheated)
//

import SwiftData
import Foundation

@Model
final class UserBaseline {
    // Identity
    var id: UUID = UUID()
    
    // Baseline data
    var temperatureBucketRaw: String = TemperatureBucket.hot.rawValue  // Store raw value for SwiftData compatibility
    var averageHR: Double = 0
    var sessionCount: Int = 0
    
    // Timestamps
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Sync metadata (local-first architecture)
    var syncStateRaw: String = SyncState.pending.rawValue
    var lastSyncError: String?
    var deletedAt: Date?  // Tombstone for soft deletes
    
    var temperatureBucket: TemperatureBucket {
        get { TemperatureBucket(rawValue: temperatureBucketRaw) ?? .hot }
        set { temperatureBucketRaw = newValue.rawValue }
    }
    
    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pending }
        set { syncStateRaw = newValue.rawValue }
    }
    
    /// Whether this baseline needs to be synced to CloudKit
    var needsSync: Bool {
        syncState == .pending || syncState == .failed
    }
    
    init(temperatureBucket: TemperatureBucket, averageHR: Double, sessionCount: Int, lastUpdated: Date) {
        self.id = UUID()
        self.temperatureBucketRaw = temperatureBucket.rawValue
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

