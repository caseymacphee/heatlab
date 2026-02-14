//
//  PersonalRecord.swift
//  heatlab
//
//  Tracks personal records across sessions (highest max HR, most calories, etc.)
//  iOS schema only — records are computed on iPhone
//

import SwiftData
import Foundation

@Model
final class PersonalRecord {
    var id: UUID = UUID()
    /// Record type: "highest_max_hr", "most_calories", "longest_zone4plus"
    var recordType: String = ""
    /// Scope: "overall" or session type name (e.g., "Vinyasa", "Bikram")
    var scope: String = "overall"
    /// The record value
    var value: Double = 0
    /// Links to the session that set this record (nil for count records)
    var sessionUUID: UUID?
    /// When this record was achieved
    var achievedAt: Date = Date()

    init(recordType: String, scope: String, value: Double, sessionUUID: UUID?, achievedAt: Date = Date()) {
        self.id = UUID()
        self.recordType = recordType
        self.scope = scope
        self.value = value
        self.sessionUUID = sessionUUID
        self.achievedAt = achievedAt
    }
}
