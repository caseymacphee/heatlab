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
                temperature: session.session.roomTemperature ?? 0,
                duration: session.stats.duration,
                temperatureBucket: session.session.temperatureBucket,
                sessionTypeId: session.session.sessionTypeId
            )
        }
    }
    
    /// Calculate acclimation signal - is user adapting to this temperature?
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
    
    // MARK: - EWMA Calculation
    
    /// Calculate EWMA (Exponentially Weighted Moving Average) smoothed points
    /// Returns empty array if not enough points for the given period
    func calculateEWMA(points: [TrendPoint], period: AnalysisPeriod) -> [TrendPoint] {
        guard points.count >= minimumPoints(for: period) else { return [] }
        
        let alpha = ewmaAlpha(for: period)
        var ewma = points[0].value
        
        return points.map { point in
            ewma = alpha * point.value + (1 - alpha) * ewma
            return TrendPoint(
                date: point.date,
                value: ewma,
                temperature: point.temperature,
                duration: point.duration,
                temperatureBucket: point.temperatureBucket,
                sessionTypeId: point.sessionTypeId
            )
        }
    }
    
    /// Minimum number of points required to show trend line for a period
    private func minimumPoints(for period: AnalysisPeriod) -> Int {
        switch period {
        case .week: return 4
        case .month: return 6
        case .threeMonth: return 8
        case .year: return 12
        }
    }
    
    /// EWMA alpha (smoothing factor) based on period
    /// Alpha = 2 / (span + 1) where span is the effective number of sessions
    private func ewmaAlpha(for period: AnalysisPeriod) -> Double {
        switch period {
        case .week:
            // Span ~3 sessions: alpha = 2/(3+1) = 0.5
            return 0.5
        case .month:
            // Span ~5 sessions: alpha = 2/(5+1) ≈ 0.33
            return 0.33
        case .threeMonth:
            // Span ~10 sessions: alpha = 2/(10+1) ≈ 0.18
            return 0.18
        case .year:
            // Span ~20 sessions: alpha = 2/(20+1) ≈ 0.095
            return 0.095
        }
    }
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let temperature: Int
    
    // Additional metadata for tooltips
    let duration: TimeInterval
    let temperatureBucket: TemperatureBucket
    let sessionTypeId: UUID?
    
    /// Convenience initializer for basic trend points (without tooltip metadata)
    init(date: Date, value: Double, temperature: Int, duration: TimeInterval = 0, temperatureBucket: TemperatureBucket = .unheated, sessionTypeId: UUID? = nil) {
        self.date = date
        self.value = value
        self.temperature = temperature
        self.duration = duration
        self.temperatureBucket = temperatureBucket
        self.sessionTypeId = sessionTypeId
    }
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
            return "Your avg HR at this heat is \(Int(abs(percentChange)))% lower than when you started."
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

