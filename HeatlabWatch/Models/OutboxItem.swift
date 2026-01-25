//
//  OutboxItem.swift
//  HeatlabWatch
//
//  SwiftData model for queued session data awaiting delivery to iPhone
//  Part of the "slow lane" reliability mechanism using transferUserInfo
//

import SwiftData
import Foundation

/// Outbox status for session delivery
enum OutboxStatus: Int, Codable {
    case pending = 0   // Awaiting delivery
    case acked = 1     // Phone confirmed receipt
}

/// Queued session data for reliable delivery to iPhone
/// Uses transferUserInfo as a "slow lane" that survives app termination
@Model
final class OutboxItem {
    /// Unique key for deduplication (workoutUUID string)
    @Attribute(.unique) var dedupeKey: String
    
    /// Session ID for debugging/logging
    var sessionID: String
    
    /// JSON-encoded session dictionary
    var payload: Data
    
    /// When the item was first enqueued
    var createdAt: Date
    
    /// When the item was last updated
    var updatedAt: Date
    
    /// Number of delivery attempts
    var attemptCount: Int
    
    /// When delivery was last attempted
    var lastAttemptAt: Date?
    
    /// Current delivery status
    var statusRaw: Int
    
    var status: OutboxStatus {
        get { OutboxStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
    
    init(dedupeKey: String, sessionID: String, payload: Data) {
        self.dedupeKey = dedupeKey
        self.sessionID = sessionID
        self.payload = payload
        self.createdAt = Date()
        self.updatedAt = Date()
        self.attemptCount = 0
        self.statusRaw = OutboxStatus.pending.rawValue
    }
}
