//
//  ZoneCalculator.swift
//  heatlab
//
//  Computes heart rate zone distributions and assigns zones to data points
//

import Foundation

enum ZoneCalculator {

    /// Estimated max heart rate using the 220-age formula
    static func maxHeartRate(age: Int) -> Double {
        Double(220 - age)
    }

    /// Compute zone distribution from heart rate samples.
    ///
    /// Time-weighted: each sample's duration is the gap to the next sample.
    /// The last sample extends to sessionDuration.
    static func computeDistribution(
        hrSamples: [HeartRateDataPoint],
        maxHR: Double,
        sessionDuration: TimeInterval
    ) -> ZoneDistribution {
        guard !hrSamples.isEmpty, maxHR > 0, sessionDuration > 0 else {
            return ZoneDistribution(maxHR: maxHR, entries: [])
        }

        let sorted = hrSamples.sorted { $0.timeOffset < $1.timeOffset }
        var zoneDurations: [HeartRateZone: TimeInterval] = [:]

        for (index, sample) in sorted.enumerated() {
            let sampleEnd: TimeInterval
            if index + 1 < sorted.count {
                sampleEnd = sorted[index + 1].timeOffset
            } else {
                sampleEnd = sessionDuration
            }

            let duration = max(0, sampleEnd - sample.timeOffset)
            let zone = HeartRateZone.zone(for: sample.heartRate, maxHR: maxHR)
            zoneDurations[zone, default: 0] += duration
        }

        let totalDuration = zoneDurations.values.reduce(0, +)
        let entries = HeartRateZone.allCases.compactMap { zone -> ZoneDistribution.Entry? in
            let duration = zoneDurations[zone] ?? 0
            guard duration > 0 else { return nil }
            return ZoneDistribution.Entry(
                zone: zone,
                duration: duration,
                percentage: totalDuration > 0 ? duration / totalDuration : 0
            )
        }

        return ZoneDistribution(maxHR: maxHR, entries: entries)
    }

    /// Assign zones to each data point for chart coloring
    static func assignZones(
        to dataPoints: [HeartRateDataPoint],
        maxHR: Double
    ) -> [ZonedHeartRateDataPoint] {
        guard maxHR > 0 else { return [] }
        return dataPoints.map { point in
            ZonedHeartRateDataPoint(
                heartRate: point.heartRate,
                timeOffset: point.timeOffset,
                zone: HeartRateZone.zone(for: point.heartRate, maxHR: maxHR)
            )
        }
    }
}
