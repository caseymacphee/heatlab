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

@Observable
final class SessionRepository {
    private let healthStore = HKHealthStore()
    private var modelContext: ModelContext
    
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
    
    func fetchSessionsWithStats() async throws -> [SessionWithStats] {
        // 1. Fetch HeatSession metadata from SwiftData (exclude soft-deleted)
        let descriptor = FetchDescriptor<HeatSession>(
            predicate: #Predicate<HeatSession> { session in
                session.deletedAt == nil
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let sessions = try modelContext.fetch(descriptor)
        
        // 2. For each session, fetch corresponding HKWorkout and HR samples
        var results: [SessionWithStats] = []
        for session in sessions {
            if let workoutUUID = session.workoutUUID {
                let workout = try await fetchWorkout(uuid: workoutUUID)
                let hrSamples = try await fetchHeartRateSamples(for: workout)
                let stats = computeStats(hrSamples: hrSamples, workout: workout, session: session)
                results.append(SessionWithStats(session: session, workout: workout, stats: stats))
            } else {
                // Session without linked workout - create minimal stats
                let duration = session.manualDurationOverride ?? (session.endDate?.timeIntervalSince(session.startDate) ?? 0)
                let stats = SessionStats(
                    averageHR: 0,
                    maxHR: 0,
                    minHR: 0,
                    calories: 0,
                    duration: duration
                )
                results.append(SessionWithStats(session: session, workout: nil, stats: stats))
            }
        }
        return results
    }
    
    func fetchSession(id: UUID) async throws -> SessionWithStats? {
        let predicate = #Predicate<HeatSession> { session in
            session.id == id && session.deletedAt == nil
        }
        let descriptor = FetchDescriptor<HeatSession>(predicate: predicate)
        
        guard let session = try modelContext.fetch(descriptor).first else {
            return nil
        }
        
        if let workoutUUID = session.workoutUUID {
            let workout = try await fetchWorkout(uuid: workoutUUID)
            let hrSamples = try await fetchHeartRateSamples(for: workout)
            let stats = computeStats(hrSamples: hrSamples, workout: workout, session: session)
            return SessionWithStats(session: session, workout: workout, stats: stats)
        } else {
            let duration = session.manualDurationOverride ?? (session.endDate?.timeIntervalSince(session.startDate) ?? 0)
            let stats = SessionStats(averageHR: 0, maxHR: 0, minHR: 0, calories: 0, duration: duration)
            return SessionWithStats(session: session, workout: nil, stats: stats)
        }
    }
    
    /// Fetches heart rate samples for a specific session
    /// Returns an array of heart rate data points with timestamps relative to session start
    func fetchHeartRateDataPoints(for session: HeatSession) async throws -> [HeartRateDataPoint] {
        guard let workoutUUID = session.workoutUUID else {
            return []
        }
        
        let workout = try await fetchWorkout(uuid: workoutUUID)
        guard let workout = workout else {
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
    
    private func computeStats(hrSamples: [HKQuantitySample], workout: HKWorkout?, session: HeatSession) -> SessionStats {
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

