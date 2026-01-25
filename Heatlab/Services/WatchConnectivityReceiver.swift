//
//  WatchConnectivityReceiver.swift
//  heatlab
//
//  Receives session data from Watch via WatchConnectivity dual-path:
//  - Fast lane: sendMessage (when both apps active)
//  - Slow lane: transferUserInfo (queued, survives app termination)
//
//  Sends ACKs back to Watch so it can clean up its outbox.
//

import WatchConnectivity
import SwiftData
import Foundation
import Combine

/// Receives session data from Watch and sends ACKs for reliable delivery
final class WatchConnectivityReceiver: NSObject, ObservableObject {
    static let shared = WatchConnectivityReceiver()
    
    @Published var isReachable = false
    @Published var isPaired = false
    @Published var lastReceivedDate: Date?
    
    private var session: WCSession?
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
    
    /// Set the model context for saving received sessions
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Settings Sync (iOS -> Watch)
    
    /// Send current settings to Watch via application context
    /// Application context persists and delivers even if Watch app isn't running
    func sendSettingsToWatch(_ settings: UserSettings) {
        guard let session = session,
              session.activationState == .activated,
              session.isPaired else {
            print("WCSession not ready for settings transfer")
            return
        }
        
        let settingsDict = settings.toDictionary()
        
        do {
            try session.updateApplicationContext(settingsDict)
            print("Settings sent to Watch via application context")
        } catch {
            print("Failed to send settings to Watch: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helpers
    
    /// Handle received session data and send ACK on success
    /// - Parameter data: Session dictionary from Watch
    /// - Parameter sendAck: Whether to send ACK back to Watch (default true)
    private func handleReceivedSession(_ data: [String: Any], sendAck: Bool = true) {
        guard let modelContext = modelContext else {
            print("ModelContext not configured for WatchConnectivityReceiver")
            return
        }
        
        // Required fields - workoutUUID is now the primary key for upserts
        guard let workoutUUIDString = data["workoutUUID"] as? String,
              let workoutUUID = UUID(uuidString: workoutUUIDString),
              let startDateTimestamp = data["startDate"] as? TimeInterval,
              let incomingUpdatedAtTimestamp = data["updatedAt"] as? TimeInterval else {
            print("Invalid session data received - missing required fields (workoutUUID, startDate, updatedAt)")
            return
        }
        
        let incomingUpdatedAt = Date(timeIntervalSince1970: incomingUpdatedAtTimestamp)
        
        // Optional fields - roomTemperature nil means unheated
        let roomTemperature = data["roomTemperature"] as? Int
        
        // Upsert by workoutUUID (the unique constraint)
        let predicate = #Predicate<WorkoutSession> { $0.workoutUUID == workoutUUID }
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: predicate)
        
        do {
            let existing = try modelContext.fetch(descriptor)
            
            if let existingSession = existing.first {
                // Only update if incoming data is newer
                if incomingUpdatedAt > existingSession.updatedAt {
                    updateSession(existingSession, from: data, roomTemperature: roomTemperature)
                    print("Updated session \(workoutUUID) - incoming updatedAt \(incomingUpdatedAt) > existing \(existingSession.updatedAt)")
                } else {
                    print("Skipped update for session \(workoutUUID) - incoming updatedAt \(incomingUpdatedAt) <= existing \(existingSession.updatedAt)")
                }
            } else {
                // Create new session
                let session = createSession(from: data, workoutUUID: workoutUUID, startDate: Date(timeIntervalSince1970: startDateTimestamp), roomTemperature: roomTemperature)
                modelContext.insert(session)
                print("Created new session for workoutUUID \(workoutUUID)")
            }
            
            try modelContext.save()
            
            DispatchQueue.main.async {
                self.lastReceivedDate = Date()
            }
            
            // Send ACK to Watch so it can clean up its outbox
            if sendAck {
                sendAckToWatch(workoutUUID: workoutUUIDString)
            }
        } catch {
            print("Failed to save received session: \(error.localizedDescription)")
        }
    }
    
    /// Send ACK message to Watch for outbox cleanup
    private func sendAckToWatch(workoutUUID: String) {
        guard let session = session, session.isReachable else {
            print("Watch not reachable for ACK - outbox will retry")
            return
        }
        
        let ackMessage: [String: Any] = [
            "type": "ack",
            "workoutUUID": workoutUUID
        ]
        
        session.sendMessage(ackMessage, replyHandler: nil) { error in
            print("Failed to send ACK to Watch: \(error.localizedDescription)")
            // Watch outbox will retry via transferUserInfo, eventually connectivity will align
        }
        
        print("Sent ACK to Watch for workoutUUID \(workoutUUID)")
    }
    
    private func createSession(from data: [String: Any], workoutUUID: UUID, startDate: Date, roomTemperature: Int?) -> WorkoutSession {
        let session = WorkoutSession(workoutUUID: workoutUUID, startDate: startDate, roomTemperature: roomTemperature)
        
        // Override id if provided (for cross-device consistency)
        if let idString = data["id"] as? String, let id = UUID(uuidString: idString) {
            session.id = id
        }
        
        updateSession(session, from: data, roomTemperature: roomTemperature)
        
        // Mark as synced since it came from Watch via relay
        session.syncState = .synced
        
        return session
    }
    
    private func updateSession(_ session: WorkoutSession, from data: [String: Any], roomTemperature: Int?) {
        // Update roomTemperature (nil means unheated)
        session.roomTemperature = roomTemperature
        
        if let endDateTimestamp = data["endDate"] as? TimeInterval {
            session.endDate = Date(timeIntervalSince1970: endDateTimestamp)
        }
        // workoutUUID is immutable after creation - it's the unique key
        if let sessionTypeIdString = data["sessionTypeId"] as? String,
           let sessionTypeId = UUID(uuidString: sessionTypeIdString) {
            session.sessionTypeId = sessionTypeId
        }
        if let userNotes = data["userNotes"] as? String {
            session.userNotes = userNotes
        }
        if let aiSummary = data["aiSummary"] as? String {
            session.aiSummary = aiSummary
        }
        if let updatedAtTimestamp = data["updatedAt"] as? TimeInterval {
            session.updatedAt = Date(timeIntervalSince1970: updatedAtTimestamp)
        }
        if let deletedAtTimestamp = data["deletedAt"] as? TimeInterval {
            session.deletedAt = Date(timeIntervalSince1970: deletedAtTimestamp)
        }
        if let perceivedEffortRaw = data["perceivedEffortRaw"] as? String {
            session.perceivedEffortRaw = perceivedEffortRaw
        }
        if let manualDuration = data["manualDurationOverride"] as? TimeInterval {
            session.manualDurationOverride = manualDuration
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityReceiver: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            self.isPaired = session.isPaired
        }
        
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated: state=\(activationState.rawValue), reachable=\(session.isReachable)")
            // Send settings to Watch when session activates
            if activationState == .activated && session.isPaired {
                // Settings will be sent when explicitly called with UserSettings instance
                print("WCSession ready - call sendSettingsToWatch() to sync settings")
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        // Reactivate for switching between watches
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        print("WCSession reachability changed: \(session.isReachable)")
    }
    
    // Handle messages from Watch (fast lane)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message from Watch: \(message)")
        
        if let type = message["type"] as? String, type == "session" {
            handleReceivedSession(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Received message from Watch (with reply): \(message)")
        
        if let type = message["type"] as? String, type == "session" {
            // Fast lane with reply - ACK is implicit in the reply, but we still send explicit ACK
            // for consistency (in case watch processes reply handler failure)
            handleReceivedSession(message, sendAck: true)
            replyHandler(["status": "saved"])
        } else {
            replyHandler(["status": "unknown_type"])
        }
    }
    
    // Handle transferUserInfo from Watch (slow lane - reliable delivery)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        print("Received userInfo from Watch (slow lane): \(userInfo.keys)")
        
        if let type = userInfo["type"] as? String, type == "session" {
            handleReceivedSession(userInfo, sendAck: true)
        }
    }
}

