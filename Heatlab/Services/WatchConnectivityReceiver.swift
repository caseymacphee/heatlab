//
//  WatchConnectivityReceiver.swift
//  heatlab
//
//  Receives relayed session data from Watch via WatchConnectivity
//  This is an optional fast-lane - CloudKit sync is the primary mechanism
//

import WatchConnectivity
import SwiftData
import Foundation
import Combine

/// Receives session data relayed from Watch for faster sync
/// This is a "fast lane" optimization - CloudKit handles the authoritative sync
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
    
    private func handleReceivedSession(_ data: [String: Any]) {
        guard let modelContext = modelContext else {
            print("ModelContext not configured for WatchConnectivityReceiver")
            return
        }
        
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let startDateTimestamp = data["startDate"] as? TimeInterval,
              let roomTemperature = data["roomTemperature"] as? Int else {
            print("Invalid session data received")
            return
        }
        
        // Check if session already exists
        let predicate = #Predicate<HeatSession> { $0.id == id }
        let descriptor = FetchDescriptor<HeatSession>(predicate: predicate)
        
        do {
            let existing = try modelContext.fetch(descriptor)
            
            if let existingSession = existing.first {
                // Update existing session
                updateSession(existingSession, from: data)
            } else {
                // Create new session
                let session = createSession(from: data, id: id, startDate: Date(timeIntervalSince1970: startDateTimestamp), roomTemperature: roomTemperature)
                modelContext.insert(session)
            }
            
            try modelContext.save()
            
            DispatchQueue.main.async {
                self.lastReceivedDate = Date()
            }
        } catch {
            print("Failed to save received session: \(error.localizedDescription)")
        }
    }
    
    private func createSession(from data: [String: Any], id: UUID, startDate: Date, roomTemperature: Int) -> HeatSession {
        let session = HeatSession(startDate: startDate, roomTemperature: roomTemperature)
        session.id = id
        
        updateSession(session, from: data)
        
        // Mark as synced since it came from Watch via relay
        session.syncState = .synced
        
        return session
    }
    
    private func updateSession(_ session: HeatSession, from data: [String: Any]) {
        if let endDateTimestamp = data["endDate"] as? TimeInterval {
            session.endDate = Date(timeIntervalSince1970: endDateTimestamp)
        }
        if let workoutUUIDString = data["workoutUUID"] as? String,
           let workoutUUID = UUID(uuidString: workoutUUIDString) {
            session.workoutUUID = workoutUUID
        }
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
    
    // Handle messages from Watch
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message from Watch: \(message)")
        
        if let type = message["type"] as? String, type == "session" {
            handleReceivedSession(message)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Received message from Watch (with reply): \(message)")
        
        if let type = message["type"] as? String, type == "session" {
            handleReceivedSession(message)
            replyHandler(["status": "saved"])
        } else {
            replyHandler(["status": "unknown_type"])
        }
    }
}

