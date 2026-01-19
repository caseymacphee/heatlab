//
//  BaselineEngine.swift
//  heatlab
//
//  Calculates and compares user's personal baselines by temperature bucket
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
    
    /// Updates baseline for the temperature bucket this session falls into
    func updateBaseline(for session: HeatSession, averageHR: Double) {
        guard averageHR > 0 else { return }
        
        let bucket = session.temperatureBucket
        let bucketRaw = bucket.rawValue
        
        let descriptor = FetchDescriptor<UserBaseline>(
            predicate: #Predicate { $0.temperatureBucketRaw == bucketRaw }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            // Rolling average
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
    
    /// Compares a session's HR to the user's baseline at that temperature range
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
            return .insufficientData(sessionsNeeded: sessionsNeeded)
        }
        
        guard baseline.averageHR > 0 else {
            return .insufficientData(sessionsNeeded: 3)
        }
        
        let deviation = (session.stats.averageHR - baseline.averageHR) / baseline.averageHR
        switch deviation {
        case ..<(-0.05): return .lowerEffort(percentBelow: abs(deviation * 100))
        case (-0.05)...0.05: return .typical
        default: return .higherEffort(percentAbove: deviation * 100)
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
    case typical
    case higherEffort(percentAbove: Double)
    case lowerEffort(percentBelow: Double)
    case insufficientData(sessionsNeeded: Int)
    
    var displayText: String {
        switch self {
        case .typical:
            return "Typical effort for this temperature"
        case .higherEffort(let percent):
            return "Pushed \(Int(percent))% harder than usual"
        case .lowerEffort(let percent):
            return "Easier session, \(Int(percent))% below your average"
        case .insufficientData(let needed):
            return "Need \(needed) more sessions at this temp for baseline"
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

