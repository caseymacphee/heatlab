//
//  PersonalRecordTracker.swift
//  heatlab
//
//  Detects and stores personal records from session data
//  iOS only — records are computed from enriched SessionWithStats
//

import SwiftData
import Foundation

final class PersonalRecordTracker {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Check if a session breaks any personal records and return newly broken records.
    /// Checks per-session record types for both "overall" and session-type-specific scope.
    func checkAndUpdateRecords(
        for session: SessionWithStats,
        allSessions: [SessionWithStats],
        sessionTypeName: String?
    ) -> [PersonalRecord] {
        var newRecords: [PersonalRecord] = []

        let scopes: [String] = {
            var s = ["overall"]
            if let name = sessionTypeName { s.append(name) }
            return s
        }()

        for scope in scopes {
            let scopeSessions = scope == "overall" ? allSessions : allSessions.filter { sws in
                // Match by session type name — need to compare sessionTypeId
                sws.session.sessionTypeId == session.session.sessionTypeId
            }

            // 1. Highest Max HR
            if session.stats.maxHR > 0 {
                if let record = checkRecord(
                    type: "highest_max_hr",
                    scope: scope,
                    newValue: session.stats.maxHR,
                    sessionUUID: session.session.id
                ) {
                    newRecords.append(record)
                }
            }

            // 2. Most Calories
            if session.stats.calories > 0 {
                if let record = checkRecord(
                    type: "most_calories",
                    scope: scope,
                    newValue: session.stats.calories,
                    sessionUUID: session.session.id
                ) {
                    newRecords.append(record)
                }
            }

            // 3. Longest Zone 4+ time
            if let zoneDistribution = session.zoneDistribution {
                let zone4PlusTime = zoneDistribution.entries
                    .filter { $0.zone.rawValue >= 4 }
                    .reduce(0.0) { $0 + $1.duration }

                if zone4PlusTime > 0 {
                    if let record = checkRecord(
                        type: "longest_zone4plus",
                        scope: scope,
                        newValue: zone4PlusTime,
                        sessionUUID: session.session.id
                    ) {
                        newRecords.append(record)
                    }
                }
            }
        }

        if !newRecords.isEmpty {
            try? modelContext.save()
        }

        return newRecords
    }

    /// Fetch all records associated with a specific session.
    func records(for sessionID: UUID) -> [PersonalRecord] {
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate<PersonalRecord> { record in
                record.sessionUUID == sessionID
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetch all personal records.
    func allRecords() -> [PersonalRecord] {
        let descriptor = FetchDescriptor<PersonalRecord>(
            sortBy: [SortDescriptor(\.achievedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Private

    /// Check if newValue beats the existing record for (type, scope). If so, upsert and return the new record.
    private func checkRecord(
        type: String,
        scope: String,
        newValue: Double,
        sessionUUID: UUID
    ) -> PersonalRecord? {
        let descriptor = FetchDescriptor<PersonalRecord>(
            predicate: #Predicate<PersonalRecord> { record in
                record.recordType == type && record.scope == scope
            }
        )
        let existing = try? modelContext.fetch(descriptor)

        if let current = existing?.first {
            guard newValue > current.value else { return nil }
            // Update existing record
            current.value = newValue
            current.sessionUUID = sessionUUID
            current.achievedAt = Date()
            return current
        } else {
            // Create new record
            let record = PersonalRecord(
                recordType: type,
                scope: scope,
                value: newValue,
                sessionUUID: sessionUUID
            )
            modelContext.insert(record)
            return record
        }
    }
}
