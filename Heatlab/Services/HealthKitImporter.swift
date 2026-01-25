//
//  HealthKitImporter.swift
//  heatlab
//
//  Service to fetch claimable yoga workouts from Apple Health
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
    
    /// Number of days to look back for importable workouts (Pro tier)
    static let proTierLookbackDays: Int = 365
    
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
    
    /// Fetches yoga workouts that haven't been claimed or dismissed
    /// - Parameters:
    ///   - isPro: Whether user has Pro subscription (allows unlimited lookback)
    ///   - includeDismissed: If true, includes previously dismissed workouts
    /// - Returns: Array of claimable workouts sorted by date (newest first)
    func fetchClaimableWorkouts(isPro: Bool, includeDismissed: Bool = false) async throws -> [ClaimableWorkout] {
        // 1. Fetch yoga workouts from HealthKit (lookback depends on tier)
        let lookbackDays = isPro ? Self.proTierLookbackDays : Self.freeTierLookbackDays
        let yogaWorkouts = try await fetchYogaWorkouts(lookbackDays: lookbackDays)
        
        // 2. Get UUIDs of already claimed workouts (existing WorkoutSessions)
        let claimedUUIDs = try fetchClaimedWorkoutUUIDs()
        
        // 3. Get ImportedWorkout records to check dismissed status
        let importedRecords = try fetchImportedWorkoutRecords()
        let dismissedUUIDs = Set(importedRecords.filter { $0.isDismissed }.compactMap { $0.workoutUUID })
        
        // 4. Filter and map to ClaimableWorkout
        var claimable: [ClaimableWorkout] = []
        
        for workout in yogaWorkouts {
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
    /// - Parameter isPro: Whether user has Pro subscription (allows unlimited lookback)
    func claimableWorkoutCount(isPro: Bool) async throws -> Int {
        let workouts = try await fetchClaimableWorkouts(isPro: isPro, includeDismissed: false)
        return workouts.count
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
        // Create the WorkoutSession
        let session = WorkoutSession(
            workoutUUID: workout.uuid,
            startDate: workout.startDate,
            roomTemperature: roomTemperature
        )
        session.endDate = workout.endDate
        session.sessionTypeId = sessionTypeId
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
    
    /// Fetches yoga workouts from the past N days (inclusive of full Nth day)
    /// - Parameter lookbackDays: Number of days to look back
    private func fetchYogaWorkouts(lookbackDays: Int) async throws -> [HKWorkout] {
        let calendar = Calendar.current
        let endDate = Date()
        
        // Use start of today to ensure the entire Nth day is included
        // e.g., if lookbackDays=7 and today is Wednesday 3pm, startDate will be
        // last Wednesday 12:00am (not 3pm), so a 9am class that day is included
        let startOfToday = calendar.startOfDay(for: endDate)
        guard let startDate = calendar.date(byAdding: .day, value: -lookbackDays, to: startOfToday) else {
            return []
        }
        
        // Predicate for yoga workouts in the date range
        let workoutTypePredicate = HKQuery.predicateForWorkouts(with: .yoga)
        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            workoutTypePredicate,
            datePredicate
        ])
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: compoundPredicate,
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
