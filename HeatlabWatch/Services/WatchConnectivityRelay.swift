//
//  WatchConnectivityRelay.swift
//  HeatlabWatch
//
//  Reliable session sync to iPhone using dual-path delivery:
//  - Fast lane: sendMessage when reachable (immediate ACK)
//  - Slow lane: transferUserInfo (queued, survives app termination)
//
//  Sessions are always enqueued to an OutboxItem, ensuring at-least-once delivery.
//  The iPhone's upsert-by-workoutUUID makes duplicate delivery safe.
//

import WatchConnectivity
import SwiftData
import Combine
import Foundation

/// Relays session data to iPhone using reliable outbox pattern
/// Also receives settings from iPhone via application context
final class WatchConnectivityRelay: NSObject, ObservableObject {
    static let shared = WatchConnectivityRelay()
    
    @Published var isReachable = false
    
    private var session: WCSession?
    private weak var userSettings: UserSettings?
    private var modelContext: ModelContext?
    
    override init() {
        super.init()
        
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported on this device")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    /// Configure with UserSettings and ModelContext
    func configure(settings: UserSettings, modelContext: ModelContext) {
        self.userSettings = settings
        self.modelContext = modelContext
        
        // Apply any pending application context immediately
        if let context = session?.receivedApplicationContext, !context.isEmpty {
            applySettings(from: context)
        }
        
        // Drain any pending outbox items
        drainOutbox()
    }
    
    // MARK: - Settings Sync (iPhone -> Watch)
    
    private func applySettings(from context: [String: Any]) {
        guard let settings = userSettings else {
            print("UserSettings not configured for WatchConnectivityRelay")
            return
        }
        
        DispatchQueue.main.async {
            settings.apply(from: context)
            print("Settings applied from iPhone application context")
        }
    }
    
    // MARK: - Outbox API (Reliable Delivery)
    
    /// Enqueue a session for reliable delivery to iPhone
    /// Always enqueues regardless of reachability, then attempts immediate drain
    func enqueueSession(_ session: WorkoutSession) {
        guard let modelContext = modelContext else {
            print("ModelContext not configured - cannot enqueue session")
            return
        }
        
        guard let workoutUUID = session.workoutUUID else {
            print("Cannot enqueue session without workoutUUID")
            return
        }
        
        let dict = sessionToDict(session)
        guard let data = encodePayload(dict) else {
            print("Failed to encode session payload for outbox")
            return
        }
        
        let key = workoutUUID.uuidString
        
        // Upsert OutboxItem by dedupeKey
        let predicate = #Predicate<OutboxItem> { $0.dedupeKey == key }
        let fetch = FetchDescriptor(predicate: predicate)
        let existing = try? modelContext.fetch(fetch).first
        
        if let item = existing {
            // Update existing item with fresh payload
            item.payload = data
            item.updatedAt = Date()
            item.status = .pending
            print("Updated outbox item for workoutUUID \(key)")
        } else {
            // Create new outbox item
            let item = OutboxItem(dedupeKey: key, sessionID: session.id.uuidString, payload: data)
            modelContext.insert(item)
            print("Enqueued new outbox item for workoutUUID \(key)")
        }
        
        try? modelContext.save()
        
        // Attempt immediate delivery
        drainOutbox()
    }
    
    /// Drain pending outbox items using dual-path delivery
    /// - Fast lane: sendMessage if reachable (immediate ACK potential)
    /// - Slow lane: transferUserInfo (queued, survives app termination)
    func drainOutbox() {
        guard let modelContext = modelContext,
              let wcSession = self.session else { return }
        
        // Fetch pending items
        let predicate = #Predicate<OutboxItem> { $0.statusRaw == 0 }
        let fetch = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        guard let pending = try? modelContext.fetch(fetch), !pending.isEmpty else { return }
        
        print("Draining outbox: \(pending.count) pending item(s), reachable=\(wcSession.isReachable)")
        
        for item in pending.prefix(20) {
            item.attemptCount += 1
            item.lastAttemptAt = Date()
            
            // Decode payload back to dictionary
            guard let dict = decodePayload(item.payload) else {
                print("Failed to decode outbox payload for \(item.dedupeKey) - skipping")
                continue
            }
            
            // Slow lane: Always queue via transferUserInfo (survives app termination)
            wcSession.transferUserInfo(dict)
            print("Queued transferUserInfo for \(item.dedupeKey) (attempt \(item.attemptCount))")
            
            // Fast lane: Also try sendMessage if reachable (for immediate ACK)
            if wcSession.isReachable {
                let dedupeKey = item.dedupeKey
                wcSession.sendMessage(dict, replyHandler: { [weak self] response in
                    if (response["status"] as? String) == "saved" {
                        print("Fast lane ACK received for \(dedupeKey)")
                        self?.markAcked(workoutUUID: dedupeKey)
                    }
                }, errorHandler: { error in
                    print("Fast lane failed for \(dedupeKey): \(error.localizedDescription)")
                    // Slow lane will deliver eventually
                })
            }
        }
        
        try? modelContext.save()
    }
    
    /// Mark an outbox item as acknowledged and delete it
    func markAcked(workoutUUID: String) {
        guard let modelContext = modelContext else { return }
        
        let predicate = #Predicate<OutboxItem> { $0.dedupeKey == workoutUUID }
        let fetch = FetchDescriptor(predicate: predicate)
        
        if let item = try? modelContext.fetch(fetch).first {
            modelContext.delete(item)
            try? modelContext.save()
            print("Deleted acked outbox item for \(workoutUUID)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func encodePayload(_ dict: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: dict, options: [])
    }
    
    private func decodePayload(_ data: Data) -> [String: Any]? {
        guard let obj = try? JSONSerialization.jsonObject(with: data),
              let dict = obj as? [String: Any] else { return nil }
        return dict
    }
    
    private func sessionToDict(_ session: WorkoutSession) -> [String: Any] {
        var dict: [String: Any] = [
            "type": "session",
            "id": session.id.uuidString,
            "startDate": session.startDate.timeIntervalSince1970,
            "createdAt": session.createdAt.timeIntervalSince1970,
            "updatedAt": session.updatedAt.timeIntervalSince1970,
            "syncStateRaw": session.syncStateRaw,
            "perceivedEffortRaw": session.perceivedEffortRaw
        ]
        
        // workoutUUID is required for upserts - should be validated before calling this
        if let workoutUUID = session.workoutUUID {
            dict["workoutUUID"] = workoutUUID.uuidString
        }
        // roomTemperature nil means unheated (no separate isHeated field)
        if let roomTemperature = session.roomTemperature {
            dict["roomTemperature"] = roomTemperature
        }
        if let endDate = session.endDate {
            dict["endDate"] = endDate.timeIntervalSince1970
        }
        if let sessionTypeId = session.sessionTypeId {
            dict["sessionTypeId"] = sessionTypeId.uuidString
        }
        if let userNotes = session.userNotes {
            dict["userNotes"] = userNotes
        }
        if let aiSummary = session.aiSummary {
            dict["aiSummary"] = aiSummary
        }
        if let deletedAt = session.deletedAt {
            dict["deletedAt"] = deletedAt.timeIntervalSince1970
        }
        if let lastSyncError = session.lastSyncError {
            dict["lastSyncError"] = lastSyncError
        }
        if let manualDuration = session.manualDurationOverride {
            dict["manualDurationOverride"] = manualDuration
        }
        
        return dict
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityRelay: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated: state=\(activationState.rawValue), reachable=\(session.isReachable)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        print("WCSession reachability changed: \(session.isReachable)")
        
        // Drain outbox when phone becomes reachable (fast lane opportunity)
        if session.isReachable {
            drainOutbox()
        }
    }
    
    // Handle ACK messages from iPhone
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message from iPhone: \(message)")
        handleIncomingMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Received message from iPhone (with reply): \(message)")
        handleIncomingMessage(message)
        replyHandler(["status": "received"])
    }
    
    private func handleIncomingMessage(_ message: [String: Any]) {
        // Handle ACK from iPhone
        if let type = message["type"] as? String, type == "ack",
           let workoutUUID = message["workoutUUID"] as? String {
            print("Received ACK for workoutUUID \(workoutUUID)")
            markAcked(workoutUUID: workoutUUID)
        }
    }
    
    // Handle application context updates from iPhone (settings sync)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("Received application context from iPhone: \(applicationContext.keys)")
        applySettings(from: applicationContext)
    }
}

