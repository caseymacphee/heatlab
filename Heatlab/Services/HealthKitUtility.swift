//
//  HealthKitUtility.swift
//  heatlab
//
//  Shared HealthKit utilities used by SessionRepository and HealthKitImporter
//

import HealthKit

enum HealthKitUtility {

    /// Fetches heart rate samples for a workout's time range
    /// - Parameters:
    ///   - healthStore: The HKHealthStore instance to use
    ///   - startDate: Start of the time range
    ///   - endDate: End of the time range
    /// - Returns: Array of heart rate samples sorted by start date
    static func fetchHeartRateSamples(
        healthStore: HKHealthStore,
        startDate: Date,
        endDate: Date
    ) async throws -> [HKQuantitySample] {
        let hrType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
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

    /// Convenience method to fetch heart rate samples for a workout
    static func fetchHeartRateSamples(
        healthStore: HKHealthStore,
        for workout: HKWorkout
    ) async throws -> [HKQuantitySample] {
        try await fetchHeartRateSamples(
            healthStore: healthStore,
            startDate: workout.startDate,
            endDate: workout.endDate
        )
    }

    /// Fetches the user's age from HealthKit dateOfBirth
    /// Returns nil if not available or on error
    static func fetchDateOfBirth(healthStore: HKHealthStore) -> Int? {
        do {
            let components = try healthStore.dateOfBirthComponents()
            guard let year = components.year else { return nil }

            let calendar = Calendar.current
            let now = Date()
            let today = calendar.dateComponents([.year, .month, .day], from: now)

            guard let currentYear = today.year else { return nil }
            var age = currentYear - year

            // Adjust if birthday hasn't occurred yet this year
            if let birthMonth = components.month, let currentMonth = today.month {
                if birthMonth > currentMonth {
                    age -= 1
                } else if birthMonth == currentMonth, let birthDay = components.day, let currentDay = today.day {
                    if birthDay > currentDay {
                        age -= 1
                    }
                }
            }

            return age > 0 ? age : nil
        } catch {
            return nil
        }
    }

    /// Computes average heart rate from samples
    static func computeAverageHeartRate(samples: [HKQuantitySample]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let hrValues = samples.map { $0.quantity.doubleValue(for: hrUnit) }
        return hrValues.reduce(0, +) / Double(hrValues.count)
    }
}
