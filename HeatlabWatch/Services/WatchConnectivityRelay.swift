//
//  WatchConnectivityRelay.swift
//  HeatlabWatch
//
//  Optional sync accelerator using WatchConnectivity
//  When iPhone is reachable, relays session data for faster sync
//  NOT a dependency - Watch app works 100% without this
//

import WatchConnectivity
import SwiftData
import Combine
import Foundation

/// Relays session data to iPhone when reachable for faster sync
/// Also receives settings from iPhone via application context
/// This is a "fast lane" optimization, not a requirement
final class WatchConnectivityRelay: NSObject, ObservableObject {
    static let shared = WatchConnectivityRelay()
    
    @Published var isReachable = false
    
    private var session: WCSession?
    private weak var userSettings: UserSettings?
    
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
    
    /// Configure with UserSettings to receive settings updates from iPhone
    func configure(settings: UserSettings) {
        self.userSettings = settings
        
        // Apply any pending application context immediately
        if let context = session?.receivedApplicationContext, !context.isEmpty {
            applySettings(from: context)
        }
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
    
    // MARK: - Public API
    
    /// Attempt to relay a session to iPhone for faster sync
    /// Calls completion with true if iPhone acknowledged receipt
    func relaySession(_ session: HeatSession, completion: @escaping (Bool) -> Void) {
        guard let wcSession = self.session,
              wcSession.isReachable else {
            completion(false)
            return
        }
        
        // Convert session to dictionary for transfer
        let data = sessionToDict(session)
        
        wcSession.sendMessage(data, replyHandler: { response in
            let status = response["status"] as? String
            let success = status == "saved"
            print("Session relay response: \(response), success: \(success)")
            completion(success)
        }, errorHandler: { error in
            print("Failed to relay session: \(error.localizedDescription)")
            completion(false)
        })
    }
    
    /// Relay multiple sessions (e.g., on sync trigger)
    /// Calls completion with the IDs of sessions that were successfully acknowledged
    func relaySessions(_ sessions: [HeatSession], completion: @escaping (Set<UUID>) -> Void) {
        guard !sessions.isEmpty else {
            completion([])
            return
        }
        
        var successfulIDs = Set<UUID>()
        let group = DispatchGroup()
        let lock = NSLock()
        
        for session in sessions {
            group.enter()
            relaySession(session) { success in
                if success {
                    lock.lock()
                    successfulIDs.insert(session.id)
                    lock.unlock()
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(successfulIDs)
        }
    }
    
    // MARK: - Private Helpers
    
    private func sessionToDict(_ session: HeatSession) -> [String: Any] {
        var dict: [String: Any] = [
            "type": "session",
            "id": session.id.uuidString,
            "startDate": session.startDate.timeIntervalSince1970,
            "roomTemperature": session.roomTemperature,
            "createdAt": session.createdAt.timeIntervalSince1970,
            "updatedAt": session.updatedAt.timeIntervalSince1970,
            "syncStateRaw": session.syncStateRaw
        ]
        
        if let endDate = session.endDate {
            dict["endDate"] = endDate.timeIntervalSince1970
        }
        if let workoutUUID = session.workoutUUID {
            dict["workoutUUID"] = workoutUUID.uuidString
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
        dict["perceivedEffortRaw"] = session.perceivedEffortRaw
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
    }
    
    // Handle messages from iPhone (if needed in future)
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message from iPhone: \(message)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Received message from iPhone (with reply): \(message)")
        replyHandler(["status": "received"])
    }
    
    // Handle application context updates from iPhone (settings sync)
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("Received application context from iPhone: \(applicationContext.keys)")
        applySettings(from: applicationContext)
    }
}

