//
//  InsightSignalComputer.swift
//  heatlab
//
//  Pre-computes all signals into Encodable structs for the AI insight pipeline
//

import Foundation

// MARK: - Signal Types

struct InsightSignals: Encodable {
    let period: PeriodSignal
    let sessions: [SessionSignal]
    let baselines: BaselineSignals
    let signals: ComputedSignals
    let zones: ZoneSignals?
}

struct PeriodSignal: Encodable {
    let label: String
    let sessionCount: Int
    let totalDurationMinutes: Int
    let avgHeartRate: Int
    let avgTemperatureFahrenheit: Int
    let totalCalories: Int
}

struct SessionSignal: Encodable {
    let date: String
    let avgHR: Int
    let maxHR: Int
    let durationMinutes: Int
    let temperatureFahrenheit: Int
    let temperatureBucket: String
    let sessionType: String?
    let zones: SessionZoneSignal?
}

struct SessionZoneSignal: Encodable {
    let dominantZone: String
    let zone1Pct: Int
    let zone2Pct: Int
    let zone3Pct: Int
    let zone4Pct: Int
    let zone5Pct: Int
}

struct BaselineSignals: Encodable {
    let temperature: [BaselineEntry]
    let sessionType: [BaselineEntry]

    struct BaselineEntry: Encodable {
        let name: String
        let avgHR: Int
        let sessionCount: Int
    }
}

struct ComputedSignals: Encodable {
    let consecutiveImprovementStreak: Int
    let currentVsBaselineDelta: Double?
    let varianceThisPeriod: Double
    let variancePreviousPeriod: Double?
    let bestHRByTemp: [String: Int]
}

struct ZoneSignals: Encodable {
    let zone1Pct: Int
    let zone2Pct: Int
    let zone3Pct: Int
    let zone4Pct: Int
    let zone5Pct: Int
    let dominantZone: String
    let peakZone: String
}

// MARK: - Computer

enum InsightSignalComputer {

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    static func compute(
        result: AnalysisResult,
        allSessions: [SessionWithStats],
        temperatureBaselines: [UserBaseline],
        sessionTypeBaselines: [SessionTypeBaseline],
        sessionTypes: [SessionTypeConfig],
        userAge: Int?,
        temperatureUnit: TemperatureUnit
    ) -> InsightSignals {
        let current = result.comparison.current

        // Period signal
        let periodSignal = PeriodSignal(
            label: result.filters.period.currentLabel,
            sessionCount: current.sessionCount,
            totalDurationMinutes: Int(current.totalDuration / 60),
            avgHeartRate: Int(current.avgHeartRate),
            avgTemperatureFahrenheit: Int(current.avgTemperature),
            totalCalories: Int(current.totalCalories)
        )

        // Session signals
        let sessionSignals: [SessionSignal] = result.trendPoints.sorted { $0.date < $1.date }.map { point in
            let sessionWithStats = result.sessionMap[point.date]
            let typeName = point.sessionTypeId.flatMap { id in sessionTypes.first { $0.id == id }?.name }

            var zoneSignal: SessionZoneSignal? = nil
            if let dist = sessionWithStats?.zoneDistribution, !dist.entries.isEmpty {
                zoneSignal = SessionZoneSignal(
                    dominantZone: dist.dominantZone?.label ?? "N/A",
                    zone1Pct: pct(dist, .zone1),
                    zone2Pct: pct(dist, .zone2),
                    zone3Pct: pct(dist, .zone3),
                    zone4Pct: pct(dist, .zone4),
                    zone5Pct: pct(dist, .zone5)
                )
            }

            return SessionSignal(
                date: dateFormatter.string(from: point.date),
                avgHR: Int(point.value),
                maxHR: Int(sessionWithStats?.stats.maxHR ?? 0),
                durationMinutes: Int(point.duration / 60),
                temperatureFahrenheit: point.temperature,
                temperatureBucket: point.temperatureBucket.displayName(for: temperatureUnit),
                sessionType: typeName,
                zones: zoneSignal
            )
        }

        // Baseline signals
        let tempBaselineEntries = temperatureBaselines.map {
            BaselineSignals.BaselineEntry(
                name: $0.temperatureBucket.displayName(for: temperatureUnit),
                avgHR: Int($0.averageHR),
                sessionCount: $0.sessionCount
            )
        }

        let typeBaselineEntries = sessionTypeBaselines.compactMap { baseline -> BaselineSignals.BaselineEntry? in
            let name = sessionTypes.first { $0.id == baseline.sessionTypeId }?.name ?? "Unknown"
            return BaselineSignals.BaselineEntry(
                name: name,
                avgHR: Int(baseline.averageHR),
                sessionCount: baseline.sessionCount
            )
        }

        let baselineSignals = BaselineSignals(
            temperature: tempBaselineEntries,
            sessionType: typeBaselineEntries
        )

        // Computed signals
        let sortedPoints = result.trendPoints.sorted { $0.date < $1.date }
        let streak = computeImprovementStreak(points: sortedPoints)
        let baselineDelta = computeBaselineDelta(
            current: current,
            bucket: result.filters.temperatureBucket,
            baselines: temperatureBaselines
        )
        let variance = computeVariance(points: sortedPoints)
        let previousVariance: Double?
        if let prev = result.comparison.previous, prev.sessionCount > 0 {
            let prevPoints = allSessions.filter { session in
                session.session.startDate >= prev.periodStart && session.session.startDate < prev.periodEnd
                && session.stats.averageHR > 0
            }.map { $0.stats.averageHR }
            previousVariance = stddev(prevPoints)
        } else {
            previousVariance = nil
        }

        let bestHR = computeBestHRByTemp(sessions: allSessions, temperatureUnit: temperatureUnit)

        let computedSignals = ComputedSignals(
            consecutiveImprovementStreak: streak,
            currentVsBaselineDelta: baselineDelta,
            varianceThisPeriod: variance,
            variancePreviousPeriod: previousVariance,
            bestHRByTemp: bestHR
        )

        // Zone signals (aggregate across period)
        var zoneSignals: ZoneSignals? = nil
        if userAge != nil {
            let sessionsWithZones = allSessions.filter { session in
                result.trendPoints.contains { $0.date == session.session.startDate }
            }.compactMap { $0.zoneDistribution }

            if !sessionsWithZones.isEmpty {
                var totalDurations: [HeartRateZone: TimeInterval] = [:]
                var total: TimeInterval = 0
                for dist in sessionsWithZones {
                    for entry in dist.entries {
                        totalDurations[entry.zone, default: 0] += entry.duration
                        total += entry.duration
                    }
                }

                let z1 = Int(((totalDurations[.zone1] ?? 0) / max(total, 1)) * 100)
                let z2 = Int(((totalDurations[.zone2] ?? 0) / max(total, 1)) * 100)
                let z3 = Int(((totalDurations[.zone3] ?? 0) / max(total, 1)) * 100)
                let z4 = Int(((totalDurations[.zone4] ?? 0) / max(total, 1)) * 100)
                let z5 = Int(((totalDurations[.zone5] ?? 0) / max(total, 1)) * 100)

                let dominant = totalDurations.max { $0.value < $1.value }?.key ?? .zone3
                let peak = totalDurations.filter { $0.value > 0 }.max { $0.key < $1.key }?.key ?? dominant

                zoneSignals = ZoneSignals(
                    zone1Pct: z1, zone2Pct: z2, zone3Pct: z3, zone4Pct: z4, zone5Pct: z5,
                    dominantZone: dominant.label,
                    peakZone: peak.label
                )
            }
        }

        return InsightSignals(
            period: periodSignal,
            sessions: sessionSignals,
            baselines: baselineSignals,
            signals: computedSignals,
            zones: zoneSignals
        )
    }

    // MARK: - Helpers

    private static func pct(_ dist: ZoneDistribution, _ zone: HeartRateZone) -> Int {
        Int(((dist.entries.first { $0.zone == zone }?.percentage ?? 0) * 100).rounded())
    }

    private static func computeImprovementStreak(points: [TrendPoint]) -> Int {
        guard points.count >= 2 else { return 0 }
        var streak = 0
        for i in stride(from: points.count - 1, through: 1, by: -1) {
            if points[i].value < points[i - 1].value {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private static func computeBaselineDelta(
        current: PeriodStats,
        bucket: TemperatureBucket?,
        baselines: [UserBaseline]
    ) -> Double? {
        guard current.avgHeartRate > 0 else { return nil }
        let targetBucket = bucket ?? .unheated
        guard let baseline = baselines.first(where: { $0.temperatureBucket == targetBucket }),
              baseline.averageHR > 0 else {
            return nil
        }
        return current.avgHeartRate - baseline.averageHR
    }

    private static func computeVariance(points: [TrendPoint]) -> Double {
        let values = points.map { $0.value }
        return stddev(values)
    }

    private static func stddev(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let sumSquares = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return (sumSquares / Double(values.count - 1)).squareRoot()
    }

    private static func computeBestHRByTemp(
        sessions: [SessionWithStats],
        temperatureUnit: TemperatureUnit
    ) -> [String: Int] {
        var best: [String: Int] = [:]
        for session in sessions where session.stats.averageHR > 0 {
            let bucketName = session.session.temperatureBucket.displayName(for: temperatureUnit)
            let hr = Int(session.stats.averageHR)
            if let existing = best[bucketName] {
                if hr < existing { best[bucketName] = hr }
            } else {
                best[bucketName] = hr
            }
        }
        return best
    }
}
