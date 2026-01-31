//
//  SessionRepository.swift
//  heatlab
//
//  Unified data access layer for sessions with HealthKit integration
//  iOS is read-only: pulls synced data from CloudKit, never writes to Watch-owned records
//

import HealthKit
import SwiftData
import Observation
import Foundation

/// Result of fetching sessions with tier-based filtering
struct SessionFetchResult {
    /// Sessions visible to the user (filtered by tier)
    let visibleSessions: [SessionWithStats]

    /// All sessions (for counting hidden sessions in free tier)
    let allSessions: [SessionWithStats]

    /// Explicit hidden count (when known without fetching all sessions)
    private let _hiddenCount: Int?

    /// Number of sessions hidden due to free tier limit
    var hiddenSessionCount: Int {
        _hiddenCount ?? (allSessions.count - visibleSessions.count)
    }

    /// Whether there are sessions hidden by the free tier limit
    var hasHiddenSessions: Bool {
        hiddenSessionCount > 0
    }

    init(visibleSessions: [SessionWithStats], allSessions: [SessionWithStats], hiddenCount: Int? = nil) {
        self.visibleSessions = visibleSessions
        self.allSessions = allSessions
        self._hiddenCount = hiddenCount
    }
}

@Observable
final class SessionRepository {
    private let healthStore = HKHealthStore()
    private var modelContext: ModelContext
    
    /// Free tier history limit in days
    static let freeTierHistoryDays = 7
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func requestHealthKitAuthorization() async throws {
        let typesToRead: Set<HKObjectType> = [
            .workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned)
        ]
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }
    
    /// Fetch sessions with tier-based filtering
    /// - Parameter isPro: Whether user has Pro subscription (unlimited history)
    /// - Returns: SessionFetchResult with visible sessions and hidden count
    func fetchSessionsWithStats(isPro: Bool) async throws -> SessionFetchResult {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        if isPro {
            // Pro: fetch all sessions
            let allSessions = try await fetchSessionsWithStats(from: nil)
            return SessionFetchResult(visibleSessions: allSessions, allSessions: allSessions)
        }

        // Free tier: fetch only last 7 days at query level (avoids N+1 HealthKit queries)
        let cutoffDate = calendar.date(
            byAdding: .day,
            value: -Self.freeTierHistoryDays,
            to: startOfToday
        ) ?? startOfToday
        let visibleSessions = try await fetchSessionsWithStats(from: cutoffDate)

        // For hidden count, we still need total count (lightweight query, no HealthKit)
        let totalCount = try fetchTotalSessionCount()

        return SessionFetchResult(
            visibleSessions: visibleSessions,
            allSessions: visibleSessions,  // Don't fetch hidden sessions just to count them
            hiddenCount: totalCount - visibleSessions.count
        )
    }

    /// Fetch sessions within a date range with HealthKit stats
    /// - Parameters:
    ///   - startDate: Only fetch sessions on or after this date (nil = fetch all)
    ///   - endDate: Only fetch sessions before this date (defaults to now)
    /// - Returns: Array of sessions enriched with HealthKit stats
    func fetchSessionsWithStats(from startDate: Date?, to endDate: Date = Date()) async throws -> [SessionWithStats] {
        // Fetch all non-deleted sessions, then filter by date in Swift
        // (Swift Predicates can't capture local Date variables)
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.deletedAt == nil
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )

        var sessions = try modelContext.fetch(descriptor)

        // Apply date filter if specified
        if let start = startDate {
            sessions = sessions.filter { $0.startDate >= start }
        }

        // For each session, fetch corresponding HKWorkout and HR samples
        var results: [SessionWithStats] = []
        for session in sessions {
            guard let workoutUUID = session.workoutUUID else {
                // Skip sessions without a linked workout
                continue
            }
            let workout = try await fetchWorkout(uuid: workoutUUID)
            let hrSamples = try await fetchHeartRateSamples(for: workout)
            let stats = computeStats(hrSamples: hrSamples, workout: workout, session: session)
            results.append(SessionWithStats(session: session, workout: workout, stats: stats))
        }
        return results
    }

    /// Lightweight count of total non-deleted sessions (no HealthKit queries)
    func fetchTotalSessionCount() throws -> Int {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.deletedAt == nil }
        )
        return try modelContext.fetchCount(descriptor)
    }

    /// Fetch the most recent session date (lightweight, no HealthKit)
    func fetchMostRecentSessionDate() throws -> Date? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.startDate
    }
    
    /// Fetch all sessions without tier filtering (internal use)
    func fetchAllSessionsWithStats() async throws -> [SessionWithStats] {
        // 1. Fetch WorkoutSession metadata from SwiftData (exclude soft-deleted)
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { session in
                session.deletedAt == nil
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let sessions = try modelContext.fetch(descriptor)
        
        // 2. For each session, fetch corresponding HKWorkout and HR samples
        var results: [SessionWithStats] = []
        for session in sessions {
            guard let workoutUUID = session.workoutUUID else {
                // Skip sessions without a linked workout
                continue
            }
            let workout = try await fetchWorkout(uuid: workoutUUID)
            let hrSamples = try await fetchHeartRateSamples(for: workout)
            let stats = computeStats(hrSamples: hrSamples, workout: workout, session: session)
            results.append(SessionWithStats(session: session, workout: workout, stats: stats))
        }
        return results
    }
    
    func fetchSession(id: UUID) async throws -> SessionWithStats? {
        let predicate = #Predicate<WorkoutSession> { session in
            session.id == id && session.deletedAt == nil
        }
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: predicate)
        
        guard let session = try modelContext.fetch(descriptor).first,
              let workoutUUID = session.workoutUUID else {
            return nil
        }
        
        let workout = try await fetchWorkout(uuid: workoutUUID)
        let hrSamples = try await fetchHeartRateSamples(for: workout)
        let stats = computeStats(hrSamples: hrSamples, workout: workout, session: session)
        return SessionWithStats(session: session, workout: workout, stats: stats)
    }
    
    /// Fetches heart rate samples for a specific session
    /// Returns an array of heart rate data points with timestamps relative to session start
    func fetchHeartRateDataPoints(for session: WorkoutSession) async throws -> [HeartRateDataPoint] {
        guard let workoutUUID = session.workoutUUID,
              let workout = try await fetchWorkout(uuid: workoutUUID) else {
            return []
        }
        
        let hrSamples = try await fetchHeartRateSamples(for: workout)
        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let sessionStartDate = session.startDate
        
        return hrSamples.map { sample in
            let hrValue = sample.quantity.doubleValue(for: hrUnit)
            let timeOffset = sample.startDate.timeIntervalSince(sessionStartDate)
            return HeartRateDataPoint(heartRate: hrValue, timeOffset: timeOffset)
        }
    }
    
    private func fetchWorkout(uuid: UUID) async throws -> HKWorkout? {
        let predicate = HKQuery.predicateForObject(with: uuid)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples?.first as? HKWorkout)
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchHeartRateSamples(for workout: HKWorkout?) async throws -> [HKQuantitySample] {
        guard let workout = workout else { return [] }
        return try await HealthKitUtility.fetchHeartRateSamples(healthStore: healthStore, for: workout)
    }
    
    private func computeStats(hrSamples: [HKQuantitySample], workout: HKWorkout?, session: WorkoutSession) -> SessionStats {
        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let hrValues = hrSamples.map { $0.quantity.doubleValue(for: hrUnit) }
        
        // Use manual duration override if present, otherwise use workout duration
        let duration: TimeInterval
        if let manualDuration = session.manualDurationOverride {
            duration = manualDuration
        } else if let workoutDuration = workout?.duration, workoutDuration > 0 {
            duration = workoutDuration
        } else {
            duration = session.endDate?.timeIntervalSince(session.startDate) ?? 0
        }
        
        return SessionStats(
            averageHR: hrValues.isEmpty ? 0 : hrValues.reduce(0, +) / Double(hrValues.count),
            maxHR: hrValues.max() ?? 0,
            minHR: hrValues.min() ?? 0,
            calories: workout?.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0,
            duration: duration
        )
    }
}

