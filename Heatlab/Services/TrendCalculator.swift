//
//  TrendCalculator.swift
//  heatlab
//
//  Calculates trends over time for intensity and acclimation
//

import Observation
import Foundation

@Observable
final class TrendCalculator {
    
    /// Get trend data for a specific temperature bucket
    func calculateIntensityTrend(sessions: [SessionWithStats], bucket: TemperatureBucket) -> [TrendPoint] {
        let filtered = sessions
            .filter { $0.session.temperatureBucket == bucket && $0.stats.averageHR > 0 }
            .sorted { $0.session.startDate < $1.session.startDate }
        
        return filtered.map { session in
            TrendPoint(
                date: session.session.startDate,
                value: session.stats.averageHR,
                temperature: session.session.roomTemperature
            )
        }
    }
    
    /// Calculate acclimation signal - is user adapting to this heat level?
    func calculateAcclimation(sessions: [SessionWithStats], bucket: TemperatureBucket) -> AcclimationSignal? {
        let filtered = sessions
            .filter { $0.session.temperatureBucket == bucket && $0.stats.averageHR > 0 }
            .sorted { $0.session.startDate < $1.session.startDate }
        
        guard filtered.count >= 5 else { return nil }
        
        let firstFive = filtered.prefix(5).map { $0.stats.averageHR }
        let lastFive = filtered.suffix(5).map { $0.stats.averageHR }
        
        let earlyAvg = firstFive.reduce(0, +) / Double(firstFive.count)
        let recentAvg = lastFive.reduce(0, +) / Double(lastFive.count)
        
        guard earlyAvg > 0 else { return nil }
        
        let change = (recentAvg - earlyAvg) / earlyAvg
        return AcclimationSignal(
            percentChange: change * 100,
            direction: change < -0.03 ? .improving : .stable,
            sessionCount: filtered.count
        )
    }
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let temperature: Int
}

struct AcclimationSignal {
    let percentChange: Double
    let direction: Direction
    let sessionCount: Int
    
    enum Direction {
        case improving
        case stable
    }
    
    var displayText: String {
        switch direction {
        case .improving:
            return "Adapting well! Your avg HR at this heat is \(Int(abs(percentChange)))% lower than when you started."
        case .stable:
            return "Consistent performance at this temperature over \(sessionCount) sessions."
        }
    }
    
    var icon: String {
        switch direction {
        case .improving: return "arrow.down.heart.fill"
        case .stable: return "equal.circle.fill"
        }
    }
}

