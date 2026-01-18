//
//  SyncEngine.swift
//  Heatlab Watch Watch App
//
//  Handles opportunistic CloudKit sync for local-first data model
//  Sessions save locally first, then sync when network/iCloud available
//  Optionally uses WatchConnectivity as a fast lane when iPhone is reachable
//

import CloudKit
import SwiftData
import Observation
import Foundation

@Observable
final class SyncEngine {
    // CloudKit container and database
    private let container = CKContainer(identifier: CloudKitConfig.containerID)
    private var database: CKDatabase { container.privateCloudDatabase }
    
    // WatchConnectivity relay (optional fast lane)
    private let wcRelay = WatchConnectivityRelay.shared
    
    // Observable state
    var isSyncing = false
    var lastSyncDate: Date?
    var pendingSessionCount: Int = 0
    var pendingBaselineCount: Int = 0
    var lastError: String?
    
    // MARK: - Public API
    
    /// Total pending items to sync
    var totalPendingCount: Int {
        pendingSessionCount + pendingBaselineCount
    }
    
    /// Whether WatchConnectivity is available as a fast lane
    var isWatchConnectivityAvailable: Bool {
        wcRelay.isReachable
    }
    
    /// Check if CloudKit is available
    func isCloudKitAvailable() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }
    
    /// Sync all pending sessions and baselines
    /// Call this on: session save, app foreground, background refresh
    func syncPending(from context: ModelContext) async {
        guard !isSyncing else { return }
        
        isSyncing = true
        lastError = nil
        
        let pending = fetchPendingSessions(from: context)
        
        // Try WatchConnectivity first (fast lane)
        // When iPhone acknowledges receipt, mark sessions as synced
        if wcRelay.isReachable && !pending.isEmpty {
            let successfulIDs = await withCheckedContinuation { continuation in
                wcRelay.relaySessions(pending) { ids in
                    continuation.resume(returning: ids)
                }
            }
            
            // Mark successfully relayed sessions as synced
            for session in pending where successfulIDs.contains(session.id) {
                session.syncState = .synced
                session.lastSyncError = nil
            }
            
            if !successfulIDs.isEmpty {
                try? context.save()
                print("Marked \(successfulIDs.count) sessions as synced via WatchConnectivity")
            }
        }
        
        // Then try CloudKit for any remaining pending sessions
        let cloudKitAvailable = await isCloudKitAvailable()
        if cloudKitAvailable {
            do {
                // Sync sessions (will only sync those still pending)
                try await syncPendingSessions(from: context)
                
                // Sync baselines
                try await syncPendingBaselines(from: context)
                
                lastSyncDate = Date()
            } catch {
                lastError = error.localizedDescription
            }
        } else if !wcRelay.isReachable {
            // Neither CloudKit nor WatchConnectivity available
            // That's fine - sessions are saved locally, we'll try again later
        }
        
        // Update pending counts
        await updatePendingCounts(from: context)
        
        isSyncing = false
    }
    
    /// Update the pending counts without syncing
    @MainActor
    func updatePendingCounts(from context: ModelContext) async {
        pendingSessionCount = fetchPendingSessions(from: context).count
        pendingBaselineCount = fetchPendingBaselines(from: context).count
    }
    
    // MARK: - Session Sync
    
    private func syncPendingSessions(from context: ModelContext) async throws {
        let pending = fetchPendingSessions(from: context)
        
        for session in pending {
            try await syncSession(session, context: context)
        }
    }
    
    private func fetchPendingSessions(from context: ModelContext) -> [HeatSession] {
        let descriptor = FetchDescriptor<HeatSession>(
            predicate: #Predicate<HeatSession> { session in
                session.syncStateRaw == "pending" || session.syncStateRaw == "failed"
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    private func syncSession(_ session: HeatSession, context: ModelContext) async throws {
        // Mark as uploading
        session.syncState = .uploading
        try? context.save()
        
        do {
            // Convert to CloudKit record
            let record = createSessionRecord(from: session)
            
            // Save to CloudKit
            _ = try await database.save(record)
            
            // Mark as synced
            session.syncState = .synced
            session.lastSyncError = nil
            try? context.save()
        } catch {
            // Mark as failed
            session.syncState = .failed
            session.lastSyncError = error.localizedDescription
            try? context.save()
            
            // Don't throw - continue with other sessions
            print("Failed to sync session \(session.id): \(error.localizedDescription)")
        }
    }
    
    private func createSessionRecord(from session: HeatSession) -> CKRecord {
        let recordID = CKRecord.ID(recordName: session.id.uuidString)
        let record = CKRecord(recordType: CloudKitConfig.RecordType.session, recordID: recordID)
        
        // Map session fields to CloudKit record
        record["id"] = session.id.uuidString
        record["startDate"] = session.startDate
        record["endDate"] = session.endDate
        record["roomTemperature"] = session.roomTemperature
        record["sessionTypeId"] = session.sessionTypeId?.uuidString
        record["userNotes"] = session.userNotes
        record["aiSummary"] = session.aiSummary
        record["createdAt"] = session.createdAt
        record["updatedAt"] = session.updatedAt
        record["perceivedEffortRaw"] = session.perceivedEffortRaw
        
        if let workoutUUID = session.workoutUUID {
            record["workoutUUID"] = workoutUUID.uuidString
        }
        
        if let manualDuration = session.manualDurationOverride {
            record["manualDurationOverride"] = manualDuration
        }
        
        if let deletedAt = session.deletedAt {
            record["deletedAt"] = deletedAt
        }
        
        return record
    }
    
    // MARK: - Baseline Sync
    
    private func syncPendingBaselines(from context: ModelContext) async throws {
        let pending = fetchPendingBaselines(from: context)
        
        for baseline in pending {
            try await syncBaseline(baseline, context: context)
        }
    }
    
    private func fetchPendingBaselines(from context: ModelContext) -> [UserBaseline] {
        let descriptor = FetchDescriptor<UserBaseline>(
            predicate: #Predicate<UserBaseline> { baseline in
                baseline.syncStateRaw == "pending" || baseline.syncStateRaw == "failed"
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    private func syncBaseline(_ baseline: UserBaseline, context: ModelContext) async throws {
        // Mark as uploading
        baseline.syncState = .uploading
        try? context.save()
        
        do {
            // Convert to CloudKit record
            let record = createBaselineRecord(from: baseline)
            
            // Save to CloudKit
            _ = try await database.save(record)
            
            // Mark as synced
            baseline.syncState = .synced
            baseline.lastSyncError = nil
            try? context.save()
        } catch {
            // Mark as failed
            baseline.syncState = .failed
            baseline.lastSyncError = error.localizedDescription
            try? context.save()
            
            print("Failed to sync baseline \(baseline.id): \(error.localizedDescription)")
        }
    }
    
    private func createBaselineRecord(from baseline: UserBaseline) -> CKRecord {
        let recordID = CKRecord.ID(recordName: baseline.id.uuidString)
        let record = CKRecord(recordType: CloudKitConfig.RecordType.baseline, recordID: recordID)
        
        // Map baseline fields to CloudKit record
        record["id"] = baseline.id.uuidString
        record["temperatureBucketRaw"] = baseline.temperatureBucketRaw
        record["averageHR"] = baseline.averageHR
        record["sessionCount"] = baseline.sessionCount
        record["createdAt"] = baseline.createdAt
        record["updatedAt"] = baseline.updatedAt
        
        if let deletedAt = baseline.deletedAt {
            record["deletedAt"] = deletedAt
        }
        
        return record
    }
}

