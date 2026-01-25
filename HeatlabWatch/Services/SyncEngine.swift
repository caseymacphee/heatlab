//
//  SyncEngine.swift
//  Heatlab Watch Watch App
//
//  Handles session sync from Watch to iPhone via WatchConnectivity
//  Uses outbox pattern for reliable at-least-once delivery:
//  - Sessions are always enqueued to OutboxItem
//  - Dual-path delivery: sendMessage (fast) + transferUserInfo (reliable)
//  - iPhone ACKs trigger outbox cleanup
//

import SwiftData
import Observation
import Foundation

@Observable
final class SyncEngine {
    // WatchConnectivity relay to iPhone
    private let wcRelay = WatchConnectivityRelay.shared
    
    // Observable state
    var isSyncing = false
    var lastSyncDate: Date?
    var pendingSessionCount: Int = 0
    var pendingOutboxCount: Int = 0
    var lastError: String?
    
    // MARK: - Public API
    
    /// Whether iPhone is reachable for sync
    var isPhoneReachable: Bool {
        wcRelay.isReachable
    }
    
    /// Enqueue a session for reliable delivery to iPhone
    /// This is the primary API - always call this when saving a session
    func enqueueSession(_ session: WorkoutSession, from context: ModelContext) {
        // Mark session as synced locally (outbox handles delivery)
        session.syncState = .synced
        session.lastSyncError = nil
        try? context.save()
        
        // Enqueue to outbox for reliable delivery
        wcRelay.enqueueSession(session)
        
        lastSyncDate = Date()
        print("Session enqueued for delivery: \(session.workoutUUID?.uuidString ?? session.id.uuidString)")
    }
    
    /// Sync all pending sessions to iPhone via WatchConnectivity
    /// Call this on: app foreground, background refresh
    /// Note: For new sessions, prefer enqueueSession() directly
    func syncPending(from context: ModelContext) async {
        guard !isSyncing else { return }
        
        isSyncing = true
        lastError = nil
        
        // Enqueue any sessions that aren't in the outbox yet
        let pending = fetchPendingSessions(from: context)
        for session in pending {
            wcRelay.enqueueSession(session)
            session.syncState = .synced  // Outbox now owns delivery
        }
        
        if !pending.isEmpty {
            try? context.save()
            print("Enqueued \(pending.count) pending session(s) to outbox")
        }
        
        // Drain the outbox (handles both fast and slow lane)
        wcRelay.drainOutbox()
        
        // Update counts
        await updatePendingCounts(from: context)
        
        if pendingOutboxCount > 0 {
            lastSyncDate = Date()
        }
        
        isSyncing = false
    }
    
    /// Update the pending count without syncing
    @MainActor
    func updatePendingCounts(from context: ModelContext) async {
        pendingSessionCount = fetchPendingSessions(from: context).count
        pendingOutboxCount = fetchPendingOutboxItems(from: context)
    }
    
    // MARK: - Private Helpers
    
    private func fetchPendingSessions(from context: ModelContext) -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.syncStateRaw == "pending" || session.syncStateRaw == "failed"
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    private func fetchPendingOutboxItems(from context: ModelContext) -> Int {
        let predicate = #Predicate<OutboxItem> { $0.statusRaw == 0 }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}

