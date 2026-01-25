//
//  BaselineEngine.swift
//  heatlab
//
//  Calculates and compares user's personal baselines by temperature bucket
//
//  Note on Historical Imports:
//  When importing workouts from Apple Health that occurred in the past, the rolling
//  average calculation produces the same result regardless of insertion order.
//  The baseline represents the average HR across all sessions in a temperature bucket,
//  which is mathematically order-independent.
//

import SwiftData
import Observation
import Foundation

@Observable
final class BaselineEngine {
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Updates baseline for the temperature bucket this session falls into.
    /// 
    /// This method uses a rolling average that produces identical results regardless
    /// of the order sessions are added. This means historical imports from Apple Health
    /// will correctly contribute to baselines even when imported out of chronological order.
    ///
    /// - Parameters:
    ///   - session: The workout session to include in baseline calculations
    ///   - averageHR: The average heart rate for the session
    func updateBaseline(for session: WorkoutSession, averageHR: Double) {
        guard averageHR > 0 else { return }
        
        let bucket = session.temperatureBucket
        let bucketRaw = bucket.rawValue
        
        let descriptor = FetchDescriptor<UserBaseline>(
            predicate: #Predicate { $0.temperatureBucketRaw == bucketRaw }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            // Rolling average: mathematically equivalent to sum(all HRs) / count
            // Order of insertion does not affect the final result
            let newAvg = (existing.averageHR * Double(existing.sessionCount) + averageHR) / Double(existing.sessionCount + 1)
            existing.averageHR = newAvg
            existing.sessionCount += 1
            existing.updatedAt = Date()
        } else {
            let baseline = UserBaseline(
                temperatureBucket: bucket,
                averageHR: averageHR,
                sessionCount: 1,
                lastUpdated: Date()
            )
            modelContext.insert(baseline)
        }
        
        try? modelContext.save()
    }
    
    /// Recalculates all baselines from scratch using the provided sessions.
    /// 
    /// Use this method when importing multiple historical workouts to ensure
    /// baselines accurately reflect all sessions. This is more accurate than
    /// calling updateBaseline() multiple times when bulk importing.
    ///
    /// - Parameter sessions: All sessions with their stats to include in baseline calculation
    func recalculateBaselines(sessions: [SessionWithStats]) {
        // Clear existing baselines
        let existingBaselines = allBaselines()
        for baseline in existingBaselines {
            modelContext.delete(baseline)
        }
        
        // Group sessions by temperature bucket
        var bucketData: [TemperatureBucket: (totalHR: Double, count: Int)] = [:]
        
        for session in sessions {
            // Skip deleted sessions and sessions without valid data
            guard session.session.deletedAt == nil,
                  session.stats.averageHR > 0 else {
                continue
            }
            
            let bucket = session.session.temperatureBucket
            let existing = bucketData[bucket] ?? (totalHR: 0, count: 0)
            bucketData[bucket] = (
                totalHR: existing.totalHR + session.stats.averageHR,
                count: existing.count + 1
            )
        }
        
        // Create new baselines
        for (bucket, data) in bucketData {
            let averageHR = data.totalHR / Double(data.count)
            let baseline = UserBaseline(
                temperatureBucket: bucket,
                averageHR: averageHR,
                sessionCount: data.count,
                lastUpdated: Date()
            )
            modelContext.insert(baseline)
        }
        
        try? modelContext.save()
    }
    
    /// Compares a session's HR to the user's baseline for that temperature
    func compareToBaseline(session: SessionWithStats) -> BaselineComparison {
        let bucket = session.session.temperatureBucket
        let bucketRaw = bucket.rawValue
        
        let descriptor = FetchDescriptor<UserBaseline>(
            predicate: #Predicate { $0.temperatureBucketRaw == bucketRaw }
        )
        
        guard let baseline = try? modelContext.fetch(descriptor).first,
              baseline.sessionCount >= 3 else {
            let currentCount = (try? modelContext.fetch(descriptor).first?.sessionCount) ?? 0
            let sessionsNeeded = max(1, 3 - currentCount)
            return .insufficientData(sessionsNeeded: sessionsNeeded, bucket: bucket)
        }
        
        guard baseline.averageHR > 0 else {
            return .insufficientData(sessionsNeeded: 3, bucket: bucket)
        }
        
        let deviation = (session.stats.averageHR - baseline.averageHR) / baseline.averageHR
        switch deviation {
        case ..<(-0.05): return .lowerEffort(percentBelow: abs(deviation * 100), bucket: bucket)
        case (-0.05)...0.05: return .typical(bucket: bucket)
        default: return .higherEffort(percentAbove: deviation * 100, bucket: bucket)
        }
    }
    
    /// Gets baseline for a specific temperature bucket
    func baseline(for bucket: TemperatureBucket) -> UserBaseline? {
        let bucketRaw = bucket.rawValue
        let descriptor = FetchDescriptor<UserBaseline>(
            predicate: #Predicate { $0.temperatureBucketRaw == bucketRaw }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Gets all baselines
    func allBaselines() -> [UserBaseline] {
        let descriptor = FetchDescriptor<UserBaseline>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

enum BaselineComparison {
    case typical(bucket: TemperatureBucket)
    case higherEffort(percentAbove: Double, bucket: TemperatureBucket)
    case lowerEffort(percentBelow: Double, bucket: TemperatureBucket)
    case insufficientData(sessionsNeeded: Int, bucket: TemperatureBucket)
    
    var displayText: String {
        switch self {
        case .typical(let bucket):
            return bucket.isHeated 
                ? "Typical effort for this temperature"
                : "Typical effort for unheated sessions"
        case .higherEffort(let percent, _):
            return "Pushed \(Int(percent))% harder than usual"
        case .lowerEffort(let percent, _):
            return "Easier session, \(Int(percent))% below your average"
        case .insufficientData(let needed, let bucket):
            return bucket.isHeated
                ? "Need \(needed) more sessions at this temp for baseline"
                : "Need \(needed) more unheated sessions for baseline"
        }
    }
    
    var systemIcon: String {
        switch self {
        case .typical: return SFSymbol.minusFill
        case .higherEffort: return SFSymbol.arrowUpFill
        case .lowerEffort: return SFSymbol.arrowDownFill
        case .insufficientData: return "chart.line.uptrend.xyaxis.circle"
        }
    }
    
    var color: String {
        switch self {
        case .typical: return "blue"
        case .higherEffort: return "orange"
        case .lowerEffort: return "green"
        case .insufficientData: return "gray"
        }
    }
}

