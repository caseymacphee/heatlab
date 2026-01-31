//
//  HealthKitImporter.swift
//  heatlab
//
//  Service to fetch claimable workouts from Apple Health
//  Filters out already claimed sessions and dismissed workouts
//

import HealthKit
import SwiftData
import Foundation

/// Represents a claimable workout from Apple Health
struct ClaimableWorkout: Identifiable, Hashable {
    let id: UUID  // HKWorkout.uuid
    let workout: HKWorkout
    let isDismissed: Bool
    /// UUIDs of duplicate workouts that will be auto-dismissed when this is claimed
    let duplicateUUIDs: [UUID]

    var startDate: Date { workout.startDate }
    var endDate: Date { workout.endDate }
    var duration: TimeInterval { workout.duration }

    var calories: Double {
        workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie()) ?? 0
    }

    /// SF Symbol icon based on workout activity type
    var icon: String {
        switch workout.workoutActivityType {
        case .yoga: return SFSymbol.yoga
        case .pilates: return SFSymbol.pilates
        case .barre: return SFSymbol.barre
        default: return SFSymbol.yoga  // Fallback
        }
    }

    /// Display name for the workout type
    var workoutTypeName: String {
        switch workout.workoutActivityType {
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .barre: return "Barre"
        default: return "Session"
        }
    }

    /// Raw workout type string for matching with SessionTypeConfig.hkActivityTypeRaw
    var workoutTypeRaw: String {
        switch workout.workoutActivityType {
        case .yoga: return "yoga"
        case .pilates: return "pilates"
        case .barre: return "barre"
        default: return "yoga"  // Fallback
        }
    }

    /// Detected source of this workout
    var source: WorkoutSource {
        WorkoutSource.from(bundleIdentifier: workout.sourceRevision.source.bundleIdentifier)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ClaimableWorkout, rhs: ClaimableWorkout) -> Bool {
        lhs.id == rhs.id
    }
}

final class HealthKitImporter {
    private let healthStore = HKHealthStore()
    private let modelContext: ModelContext
    private let deduplicator: WorkoutDeduplicator

    /// Number of days to look back for importable workouts (free tier)
    static let freeTierLookbackDays: Int = 7

    /// Pro tier has unlimited lookback (nil means no date restriction)
    static let proTierLookbackDays: Int? = nil

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.deduplicator = WorkoutDeduplicator(healthStore: healthStore)
    }
    
    // MARK: - Authorization
    
    /// Request HealthKit authorization for reading workout data
    func requestAuthorization() async throws {
        let typesToRead: Set<HKObjectType> = [
            .workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }
    
    // MARK: - Fetch Claimable Workouts
    
    /// Fetches workouts that haven't been claimed or dismissed, with deduplication
    /// - Parameters:
    ///   - isPro: Whether user has Pro subscription (allows unlimited lookback)
    ///   - enabledTypes: Set of workout type strings (e.g., "yoga", "pilates", "barre") to fetch
    ///   - includeDismissed: If true, includes previously dismissed workouts
    ///   - startDate: Optional explicit start date (overrides tier-based lookback when provided)
    /// - Returns: Array of claimable workouts sorted by date (newest first)
    func fetchClaimableWorkouts(isPro: Bool, enabledTypes: Set<String>, includeDismissed: Bool = false, startDate: Date? = nil) async throws -> [ClaimableWorkout] {
        // Convert string types to HKWorkoutActivityType
        let hkTypes = enabledTypes.compactMap { rawToHKType($0) }
        guard !hkTypes.isEmpty else { return [] }

        // 1. Fetch workouts from HealthKit
        let workouts: [HKWorkout]
        if let explicitStart = startDate {
            // Explicit start date provided (e.g., from Dashboard optimization)
            workouts = try await fetchWorkouts(startDate: explicitStart, types: Set(hkTypes))
        } else {
            // Standard tier-based lookback
            let lookbackDays: Int? = isPro ? Self.proTierLookbackDays : Self.freeTierLookbackDays
            workouts = try await fetchWorkouts(lookbackDays: lookbackDays, types: Set(hkTypes))
        }

        // 2. Get UUIDs of already claimed workouts (existing WorkoutSessions)
        // Also collect related UUIDs that were dismissed as duplicates
        let claimedUUIDs = try fetchClaimedWorkoutUUIDs()
        let relatedUUIDs = try fetchRelatedWorkoutUUIDs()
        let allClaimedUUIDs = claimedUUIDs.union(relatedUUIDs)

        // 3. Get ImportedWorkout records to check dismissed status
        let importedRecords = try fetchImportedWorkoutRecords()
        let dismissedUUIDs = Set(importedRecords.filter { $0.isDismissed }.compactMap { $0.workoutUUID })

        // 4. Filter out already claimed/related workouts before deduplication
        let unclaimedWorkouts = workouts.filter { !allClaimedUUIDs.contains($0.uuid) }

        // 5. Run deduplication to group workouts that represent the same activity
        let groups = await deduplicator.groupDuplicates(unclaimedWorkouts)

        // 6. Build claimable list from deduplicated groups
        var claimable: [ClaimableWorkout] = []

        for group in groups {
            let primary = group.primary

            // Check if any workout in the group is dismissed
            let groupUUIDs = group.allUUIDs
            let groupDismissed = groupUUIDs.contains { dismissedUUIDs.contains($0) }

            // Skip dismissed unless includeDismissed is true
            if groupDismissed && !includeDismissed {
                continue
            }

            claimable.append(ClaimableWorkout(
                id: primary.uuid,
                workout: primary,
                isDismissed: groupDismissed,
                duplicateUUIDs: group.duplicateUUIDs
            ))
        }

        // Sort by date (newest first)
        return claimable.sorted { $0.startDate > $1.startDate }
    }
    
    /// Returns the count of claimable workouts (not dismissed)
    /// - Parameters:
    ///   - isPro: Whether user has Pro subscription (allows unlimited lookback)
    ///   - enabledTypes: Set of workout type strings (e.g., "yoga", "pilates", "barre") to fetch
    func claimableWorkoutCount(isPro: Bool, enabledTypes: Set<String>) async throws -> Int {
        let workouts = try await fetchClaimableWorkouts(isPro: isPro, enabledTypes: enabledTypes, includeDismissed: false)
        return workouts.count
    }

    // MARK: - Dashboard Optimization (Recent Claimable)

    /// Fetches RECENT claimable workouts for Dashboard CTA - optimized to avoid querying entire history
    /// Uses smart cutoff: workouts newer than most recently claimed session
    /// Falls back to full list if no workouts have been claimed yet
    /// - Parameters:
    ///   - isPro: Whether user has Pro subscription (affects fallback lookback)
    ///   - enabledTypes: Set of workout type strings to fetch
    /// - Returns: Tuple of (workouts, isRecent) where isRecent indicates if using smart cutoff
    func fetchRecentClaimableWorkouts(isPro: Bool, enabledTypes: Set<String>) async throws -> (workouts: [ClaimableWorkout], isRecent: Bool) {
        // Check if user has any claimed workouts
        let newestClaimedDate = try fetchNewestClaimedWorkoutDate()

        if let newestClaimed = newestClaimedDate {
            // User has claimed workouts - only fetch workouts AFTER that date
            let workouts = try await fetchClaimableWorkouts(
                isPro: isPro,
                enabledTypes: enabledTypes,
                includeDismissed: false,
                startDate: newestClaimed
            )
            return (workouts, isRecent: true)
        } else {
            // No claimed workouts - fetch all (standard behavior)
            let workouts = try await fetchClaimableWorkouts(
                isPro: isPro,
                enabledTypes: enabledTypes,
                includeDismissed: false
            )
            return (workouts, isRecent: false)
        }
    }

    /// Gets the start date of the most recently claimed workout session
    private func fetchNewestClaimedWorkoutDate() throws -> Date? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.startDate
    }
    
    /// Convert raw string to HKWorkoutActivityType
    private func rawToHKType(_ raw: String) -> HKWorkoutActivityType? {
        switch raw {
        case "yoga": return .yoga
        case "pilates": return .pilates
        case "barre": return .barre
        default: return nil
        }
    }
    
    // MARK: - Dismiss/Restore Workouts
    
    /// Dismisses a workout so it won't appear in the claim list
    func dismissWorkout(uuid: UUID) throws {
        let targetUUID: UUID = uuid
        let descriptor = FetchDescriptor<ImportedWorkout>(
            predicate: #Predicate<ImportedWorkout> { item in
                item.workoutUUID == targetUUID
            }
        )
        
        if let existing = try modelContext.fetch(descriptor).first {
            existing.dismiss()
        } else {
            let record = ImportedWorkout(workoutUUID: uuid, isDismissed: true)
            modelContext.insert(record)
        }
        
        try modelContext.save()
    }
    
    /// Dismisses multiple workouts at once
    func dismissWorkouts(uuids: [UUID]) throws {
        for uuid in uuids {
            let targetUUID: UUID = uuid
            let descriptor = FetchDescriptor<ImportedWorkout>(
                predicate: #Predicate<ImportedWorkout> { item in
                    item.workoutUUID == targetUUID
                }
            )
            
            if let existing = try modelContext.fetch(descriptor).first {
                existing.dismiss()
            } else {
                let record = ImportedWorkout(workoutUUID: uuid, isDismissed: true)
                modelContext.insert(record)
            }
        }
        try modelContext.save()
    }
    
    /// Restores a previously dismissed workout so it can be claimed
    func restoreWorkout(uuid: UUID) throws {
        let targetUUID: UUID = uuid
        let descriptor = FetchDescriptor<ImportedWorkout>(
            predicate: #Predicate<ImportedWorkout> { item in
                item.workoutUUID == targetUUID
            }
        )
        
        if let existing = try modelContext.fetch(descriptor).first {
            existing.restore()
            try modelContext.save()
        }
    }
    
    // MARK: - Claim Workout

    /// Creates a WorkoutSession from a claimed HealthKit workout
    /// - Parameters:
    ///   - workout: The HKWorkout to claim
    ///   - roomTemperature: Room temperature in Fahrenheit (nil means unheated)
    ///   - sessionTypeId: The session type UUID (optional)
    ///   - perceivedEffort: User's perceived effort level
    ///   - notes: User notes (optional)
    ///   - duplicateUUIDs: UUIDs of duplicate workouts to auto-dismiss
    /// - Returns: The created WorkoutSession
    @discardableResult
    func claimWorkout(
        _ workout: HKWorkout,
        roomTemperature: Int?,
        sessionTypeId: UUID?,
        perceivedEffort: PerceivedEffort,
        notes: String?,
        duplicateUUIDs: [UUID] = []
    ) throws -> WorkoutSession {
        // Determine workout type from HKWorkout
        let workoutTypeRaw: String
        switch workout.workoutActivityType {
        case .yoga: workoutTypeRaw = "yoga"
        case .pilates: workoutTypeRaw = "pilates"
        case .barre: workoutTypeRaw = "barre"
        default: workoutTypeRaw = "yoga"  // Fallback
        }

        // Detect source from bundle identifier
        let source = WorkoutSource.from(bundleIdentifier: workout.sourceRevision.source.bundleIdentifier)

        // Create the WorkoutSession
        let session = WorkoutSession(
            workoutUUID: workout.uuid,
            startDate: workout.startDate,
            roomTemperature: roomTemperature
        )
        session.endDate = workout.endDate
        session.sessionTypeId = sessionTypeId
        session.workoutTypeRaw = workoutTypeRaw
        session.perceivedEffort = perceivedEffort
        session.userNotes = notes
        session.source = source

        // Store related workout UUIDs if there are duplicates
        if !duplicateUUIDs.isEmpty {
            session.relatedWorkoutUUIDs = duplicateUUIDs
        }

        modelContext.insert(session)

        // Remove from ImportedWorkout dismissed list if it was there
        let workoutUUID: UUID = workout.uuid
        let descriptor = FetchDescriptor<ImportedWorkout>(
            predicate: #Predicate<ImportedWorkout> { item in
                item.workoutUUID == workoutUUID
            }
        )
        if let importedRecord = try modelContext.fetch(descriptor).first {
            modelContext.delete(importedRecord)
        }

        // Auto-dismiss duplicate workouts so they don't appear in claim list
        if !duplicateUUIDs.isEmpty {
            try dismissWorkouts(uuids: duplicateUUIDs)
        }

        try modelContext.save()

        return session
    }
    
    // MARK: - Heart Rate Data

    /// Fetches heart rate samples for a workout
    func fetchHeartRateSamples(for workout: HKWorkout) async throws -> [HKQuantitySample] {
        try await HealthKitUtility.fetchHeartRateSamples(healthStore: healthStore, for: workout)
    }

    /// Computes average heart rate from samples
    func computeAverageHeartRate(samples: [HKQuantitySample]) -> Double {
        HealthKitUtility.computeAverageHeartRate(samples: samples)
    }
    
    // MARK: - Private Helpers
    
    /// Fetches workouts of specified types from the past N days (inclusive of full Nth day)
    /// - Parameters:
    ///   - lookbackDays: Number of days to look back (nil means unlimited/all time)
    ///   - types: Set of HKWorkoutActivityTypes to fetch
    private func fetchWorkouts(lookbackDays: Int?, types: Set<HKWorkoutActivityType>) async throws -> [HKWorkout] {
        guard !types.isEmpty else { return [] }
        
        let endDate = Date()
        
        // Build OR predicate for multiple workout types
        let typePredicates = types.map { HKQuery.predicateForWorkouts(with: $0) }
        let workoutTypePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: typePredicates)
        
        // Build final predicate - add date filter only if lookbackDays is specified
        let finalPredicate: NSPredicate
        if let lookbackDays = lookbackDays {
            let calendar = Calendar.current
            // Use start of today to ensure the entire Nth day is included
            // e.g., if lookbackDays=7 and today is Wednesday 3pm, startDate will be
            // last Wednesday 12:00am (not 3pm), so a 9am class that day is included
            let startOfToday = calendar.startOfDay(for: endDate)
            guard let startDate = calendar.date(byAdding: .day, value: -lookbackDays, to: startOfToday) else {
                return []
            }
            
            let datePredicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: endDate,
                options: .strictStartDate
            )
            finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                workoutTypePredicate,
                datePredicate
            ])
        } else {
            // Unlimited lookback - only filter by workout type
            finalPredicate = workoutTypePredicate
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: finalPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    /// Fetches workouts of specified types starting from an explicit date
    /// - Parameters:
    ///   - startDate: Fetch workouts on or after this date
    ///   - types: Set of HKWorkoutActivityTypes to fetch
    private func fetchWorkouts(startDate: Date, types: Set<HKWorkoutActivityType>) async throws -> [HKWorkout] {
        guard !types.isEmpty else { return [] }

        let endDate = Date()

        // Build OR predicate for multiple workout types
        let typePredicates = types.map { HKQuery.predicateForWorkouts(with: $0) }
        let workoutTypePredicate = NSCompoundPredicate(orPredicateWithSubpredicates: typePredicates)

        // Add date filter
        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        let finalPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            workoutTypePredicate,
            datePredicate
        ])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: finalPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    /// Gets UUIDs of workouts that have already been claimed as WorkoutSessions
    private func fetchClaimedWorkoutUUIDs() throws -> Set<UUID> {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.deletedAt == nil
            }
        )
        let sessions = try modelContext.fetch(descriptor)
        return Set(sessions.compactMap { $0.workoutUUID })
    }

    /// Gets UUIDs of workouts that were dismissed as duplicates (stored in relatedWorkoutUUIDs)
    private func fetchRelatedWorkoutUUIDs() throws -> Set<UUID> {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.deletedAt == nil && session.relatedWorkoutUUIDsJSON != nil
            }
        )
        let sessions = try modelContext.fetch(descriptor)
        var relatedUUIDs = Set<UUID>()
        for session in sessions {
            if let related = session.relatedWorkoutUUIDs {
                relatedUUIDs.formUnion(related)
            }
        }
        return relatedUUIDs
    }
    
    /// Gets all ImportedWorkout records
    private func fetchImportedWorkoutRecords() throws -> [ImportedWorkout] {
        let descriptor = FetchDescriptor<ImportedWorkout>(
            predicate: #Predicate<ImportedWorkout> { item in
                item.deletedAt == nil
            }
        )
        return try modelContext.fetch(descriptor)
    }
}
