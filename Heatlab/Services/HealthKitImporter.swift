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
    
    /// Number of days to look back for importable workouts (free tier)
    static let freeTierLookbackDays: Int = 7
    
    /// Pro tier has unlimited lookback (nil means no date restriction)
    static let proTierLookbackDays: Int? = nil
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
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
    
    /// Fetches workouts that haven't been claimed or dismissed
    /// - Parameters:
    ///   - isPro: Whether user has Pro subscription (allows unlimited lookback)
    ///   - enabledTypes: Set of workout type strings (e.g., "yoga", "pilates", "barre") to fetch
    ///   - includeDismissed: If true, includes previously dismissed workouts
    /// - Returns: Array of claimable workouts sorted by date (newest first)
    func fetchClaimableWorkouts(isPro: Bool, enabledTypes: Set<String>, includeDismissed: Bool = false) async throws -> [ClaimableWorkout] {
        // Convert string types to HKWorkoutActivityType
        let hkTypes = enabledTypes.compactMap { rawToHKType($0) }
        guard !hkTypes.isEmpty else { return [] }
        
        // 1. Fetch workouts from HealthKit (lookback depends on tier)
        // Pro tier has unlimited lookback (nil), free tier has limited days
        let lookbackDays: Int? = isPro ? Self.proTierLookbackDays : Self.freeTierLookbackDays
        let workouts = try await fetchWorkouts(lookbackDays: lookbackDays, types: Set(hkTypes))
        
        // 2. Get UUIDs of already claimed workouts (existing WorkoutSessions)
        let claimedUUIDs = try fetchClaimedWorkoutUUIDs()
        
        // 3. Get ImportedWorkout records to check dismissed status
        let importedRecords = try fetchImportedWorkoutRecords()
        let dismissedUUIDs = Set(importedRecords.filter { $0.isDismissed }.compactMap { $0.workoutUUID })
        
        // 4. Filter and map to ClaimableWorkout
        var claimable: [ClaimableWorkout] = []
        
        for workout in workouts {
            // Skip if already claimed as a WorkoutSession
            if claimedUUIDs.contains(workout.uuid) {
                continue
            }
            
            let isDismissed = dismissedUUIDs.contains(workout.uuid)
            
            // Skip dismissed unless includeDismissed is true
            if isDismissed && !includeDismissed {
                continue
            }
            
            claimable.append(ClaimableWorkout(
                id: workout.uuid,
                workout: workout,
                isDismissed: isDismissed
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
    /// - Returns: The created WorkoutSession
    @discardableResult
    func claimWorkout(
        _ workout: HKWorkout,
        roomTemperature: Int?,
        sessionTypeId: UUID?,
        perceivedEffort: PerceivedEffort,
        notes: String?
    ) throws -> WorkoutSession {
        // Determine workout type from HKWorkout
        let workoutTypeRaw: String
        switch workout.workoutActivityType {
        case .yoga: workoutTypeRaw = "yoga"
        case .pilates: workoutTypeRaw = "pilates"
        case .barre: workoutTypeRaw = "barre"
        default: workoutTypeRaw = "yoga"  // Fallback
        }
        
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
        
        try modelContext.save()
        
        return session
    }
    
    // MARK: - Heart Rate Data
    
    /// Fetches heart rate samples for a workout
    func fetchHeartRateSamples(for workout: HKWorkout) async throws -> [HKQuantitySample] {
        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }
    
    /// Computes average heart rate from samples
    func computeAverageHeartRate(samples: [HKQuantitySample]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let hrValues = samples.map { $0.quantity.doubleValue(for: hrUnit) }
        return hrValues.reduce(0, +) / Double(hrValues.count)
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
