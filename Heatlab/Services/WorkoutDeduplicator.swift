//
//  WorkoutDeduplicator.swift
//  heatlab
//
//  Detects and groups duplicate workouts from different sources (Strava, Garmin, Oura, Whoop, Apple Watch).
//  Selects the best workout per group based on HR sample density and vendor priority.
//

import HealthKit
import Foundation

/// Represents a group of duplicate workouts
struct DuplicateGroup {
    /// The primary workout to use (best HR data or highest priority source)
    let primary: HKWorkout
    /// Other workouts in this group that are duplicates of the primary
    let duplicates: [HKWorkout]

    /// All workout UUIDs in this group (primary + duplicates)
    var allUUIDs: [UUID] {
        [primary.uuid] + duplicates.map { $0.uuid }
    }

    /// UUIDs of duplicate workouts (excludes primary)
    var duplicateUUIDs: [UUID] {
        duplicates.map { $0.uuid }
    }
}

/// Service for detecting and grouping duplicate workouts from HealthKit
final class WorkoutDeduplicator {
    private let healthStore: HKHealthStore

    /// Minimum overlap ratio to consider workouts as duplicates (80%)
    private let overlapThreshold: Double = 0.8

    /// Time tolerance in seconds for "exact" start time match
    private let exactMatchTolerance: TimeInterval = 1.0

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    // MARK: - Public API

    /// Groups workouts into duplicate clusters and returns groups with primary workout selected
    /// - Parameter workouts: Array of HKWorkout objects to deduplicate
    /// - Returns: Array of DuplicateGroup, one per unique workout event
    func groupDuplicates(_ workouts: [HKWorkout]) async -> [DuplicateGroup] {
        guard !workouts.isEmpty else { return [] }

        // Build clusters of overlapping workouts
        var clusters: [[HKWorkout]] = []
        var processed = Set<UUID>()

        for workout in workouts {
            guard !processed.contains(workout.uuid) else { continue }

            // Find all workouts that overlap with this one
            var cluster = [workout]
            processed.insert(workout.uuid)

            for other in workouts {
                guard !processed.contains(other.uuid) else { continue }
                if areDuplicates(workout, other) {
                    cluster.append(other)
                    processed.insert(other.uuid)
                }
            }

            // Also check if any workout in the cluster overlaps with remaining workouts
            // (transitive closure - if A overlaps B and B overlaps C, they're all in the same group)
            var changed = true
            while changed {
                changed = false
                for existing in cluster {
                    for other in workouts {
                        guard !processed.contains(other.uuid) else { continue }
                        if areDuplicates(existing, other) {
                            cluster.append(other)
                            processed.insert(other.uuid)
                            changed = true
                        }
                    }
                }
            }

            clusters.append(cluster)
        }

        // Select primary workout for each cluster
        var groups: [DuplicateGroup] = []
        for cluster in clusters {
            if cluster.count == 1 {
                // No duplicates
                groups.append(DuplicateGroup(primary: cluster[0], duplicates: []))
            } else {
                // Select best workout as primary
                let primary = await selectPrimary(from: cluster)
                let duplicates = cluster.filter { $0.uuid != primary.uuid }
                groups.append(DuplicateGroup(primary: primary, duplicates: duplicates))
            }
        }

        return groups
    }

    /// Check if two workouts are duplicates of each other
    /// - Returns: true if workouts represent the same real-world activity
    func areDuplicates(_ a: HKWorkout, _ b: HKWorkout) -> Bool {
        // Must be same workout type
        guard a.workoutActivityType == b.workoutActivityType else { return false }

        // Fast path: exact start time match (within tolerance)
        let startDelta = abs(a.startDate.timeIntervalSince(b.startDate))
        if startDelta < exactMatchTolerance {
            return true
        }

        // Overlap path: check if workouts overlap by at least 80%
        let overlapRatio = calculateOverlapRatio(a, b)
        return overlapRatio >= overlapThreshold
    }

    /// Calculate the overlap ratio between two workouts
    /// - Returns: Ratio of overlap to shorter workout duration (0.0 to 1.0)
    func calculateOverlapRatio(_ a: HKWorkout, _ b: HKWorkout) -> Double {
        let overlapStart = max(a.startDate, b.startDate)
        let overlapEnd = min(a.endDate, b.endDate)

        let overlapSeconds = max(0, overlapEnd.timeIntervalSince(overlapStart))
        let minDuration = min(a.duration, b.duration)

        guard minDuration > 0 else { return 0 }
        return overlapSeconds / minDuration
    }

    // MARK: - Private Helpers

    /// Select the primary workout from a group of duplicates
    /// Priority: HR sample density > vendor priority
    private func selectPrimary(from workouts: [HKWorkout]) async -> HKWorkout {
        guard workouts.count > 1 else { return workouts[0] }

        // Fetch HR sample counts for all workouts
        var workoutsWithData: [(workout: HKWorkout, density: Double, source: WorkoutSource)] = []

        for workout in workouts {
            let sampleCount = await fetchHRSampleCount(for: workout)
            let durationMinutes = workout.duration / 60.0
            let density = durationMinutes > 0 ? Double(sampleCount) / durationMinutes : 0
            let source = WorkoutSource.from(bundleIdentifier: workout.sourceRevision.source.bundleIdentifier)

            workoutsWithData.append((workout, density, source))
        }

        // Sort by HR density (descending), then by source priority (ascending rawValue = higher priority)
        let sorted = workoutsWithData.sorted { a, b in
            // If meaningful density difference (> 0.1 samples/min), prefer higher density
            if abs(a.density - b.density) > 0.1 {
                return a.density > b.density
            }
            // Otherwise use vendor priority
            return a.source.rawValue < b.source.rawValue
        }

        return sorted.first!.workout
    }

    /// Fetch the count of HR samples associated with a workout
    private func fetchHRSampleCount(for workout: HKWorkout) async -> Int {
        do {
            let samples = try await HealthKitUtility.fetchHeartRateSamples(
                healthStore: healthStore,
                for: workout
            )
            return samples.count
        } catch {
            return 0
        }
    }
}
