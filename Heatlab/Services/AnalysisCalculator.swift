//
//  AnalysisCalculator.swift
//  heatlab
//
//  Multi-dimensional analysis with period comparisons (WoW, MoM, YoY)
//

import Observation
import Foundation

// MARK: - Analysis Types

/// Time period for comparisons
enum AnalysisPeriod: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "1M"
    case threeMonth = "3M"
    case year = "1Y"
    
    var id: String { rawValue }
    
    var comparisonLabel: String {
        switch self {
        case .week: return "vs Previous 7 Days"
        case .month: return "vs Previous Month"
        case .threeMonth: return "vs Previous 3 Months"
        case .year: return "vs Previous Year"
        }
    }

    var currentLabel: String {
        switch self {
        case .week: return "Past 7 Days"
        case .month: return "Past Month"
        case .threeMonth: return "Past 3 Months"
        case .year: return "Past Year"
        }
    }

    var previousLabel: String {
        switch self {
        case .week: return "Previous 7 Days"
        case .month: return "Previous Month"
        case .threeMonth: return "Previous 3 Months"
        case .year: return "Previous Year"
        }
    }
    
    /// Whether this period requires Pro subscription
    var requiresPro: Bool {
        switch self {
        case .week: return false
        case .month, .threeMonth, .year: return true
        }
    }
    
    /// Periods available for free users
    static var freePeriods: [AnalysisPeriod] {
        [.week]
    }
    
    /// Check if a period is available for the given subscription status
    static func isAvailable(_ period: AnalysisPeriod, isPro: Bool) -> Bool {
        isPro || !period.requiresPro
    }
}

/// Filters for slicing analysis data
struct AnalysisFilters: Equatable {
    var temperatureBucket: TemperatureBucket?  // nil = all temperatures (including unheated)
    var sessionTypeId: UUID?                   // nil = all class types
    var period: AnalysisPeriod = .week
    
    static let `default` = AnalysisFilters(temperatureBucket: nil, sessionTypeId: nil, period: .week)
}

/// Aggregate stats for a time period
struct PeriodStats {
    let periodStart: Date
    let periodEnd: Date
    let sessionCount: Int
    let totalDuration: TimeInterval
    let totalCalories: Double
    let avgHeartRate: Double
    let maxHeartRate: Double
    let avgTemperature: Double
    
    var formattedDuration: String {
        let hours = Int(totalDuration / 3600)
        let minutes = Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }
    
    static let empty = PeriodStats(
        periodStart: Date(),
        periodEnd: Date(),
        sessionCount: 0,
        totalDuration: 0,
        totalCalories: 0,
        avgHeartRate: 0,
        maxHeartRate: 0,
        avgTemperature: 0
    )
}

/// Comparison between current and previous periods
struct PeriodComparison {
    let current: PeriodStats
    let previous: PeriodStats?
    
    /// Change in session count (absolute)
    var sessionCountDelta: Int? {
        guard let prev = previous else { return nil }
        return current.sessionCount - prev.sessionCount
    }
    
    /// Percentage change in average HR (negative = improvement)
    var avgHRDelta: Double? {
        guard let prev = previous, prev.avgHeartRate > 0 else { return nil }
        return ((current.avgHeartRate - prev.avgHeartRate) / prev.avgHeartRate) * 100
    }
    
    /// Percentage change in total duration
    var durationDelta: Double? {
        guard let prev = previous, prev.totalDuration > 0 else { return nil }
        return ((current.totalDuration - prev.totalDuration) / prev.totalDuration) * 100
    }
    
    /// Percentage change in calories
    var caloriesDelta: Double? {
        guard let prev = previous, prev.totalCalories > 0 else { return nil }
        return ((current.totalCalories - prev.totalCalories) / prev.totalCalories) * 100
    }
    
    /// Absolute change in average temperature (in Fahrenheit)
    var avgTemperatureDelta: Double? {
        guard let prev = previous, prev.avgTemperature > 0 else { return nil }
        return current.avgTemperature - prev.avgTemperature
    }
}

/// Complete analysis result for a view
struct AnalysisResult {
    let filters: AnalysisFilters
    let comparison: PeriodComparison
    let trendPoints: [TrendPoint]
    let acclimation: AcclimationSignal?
    /// Mapping from TrendPoint date to SessionWithStats for navigation
    let sessionMap: [Date: SessionWithStats]
    
    /// Whether there's enough data to show meaningful analysis
    var hasData: Bool {
        comparison.current.sessionCount > 0
    }
    
    /// Whether there's enough data to show period comparison
    var hasComparison: Bool {
        comparison.previous != nil && (comparison.previous?.sessionCount ?? 0) > 0
    }
}

// MARK: - Analysis Calculator

@Observable
final class AnalysisCalculator {

    private let calendar = Calendar.current
    private let trendCalculator = TrendCalculator()
    
    // MARK: - Filtering
    
    /// Filter sessions by temperature bucket and class type
    func filterSessions(_ sessions: [SessionWithStats], with filters: AnalysisFilters) -> [SessionWithStats] {
        sessions.filter { session in
            // Filter by temperature bucket if specified
            if let bucket = filters.temperatureBucket {
                guard session.session.temperatureBucket == bucket else { return false }
            }

            // Filter by class type if specified
            if let typeId = filters.sessionTypeId {
                guard session.session.sessionTypeId == typeId else { return false }
            }

            // Allow sessions without HR data (they'll show in charts with 0 values)
            // This lets users see all their sessions even if HR tracking failed

            return true
        }
    }
    
    // MARK: - Period Calculations
    
    /// Get the date range for a period with optional offset (0 = current, 1 = previous, etc.)
    /// Uses start of day for day-based periods to ensure full days are included
    func periodDateRange(for period: AnalysisPeriod, offset: Int = 0) -> (start: Date, end: Date) {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        switch period {
        case .week:
            // Use rolling 7-day periods (not calendar week) for consistency with Dashboard
            // Uses start of day to ensure full 7th day is included
            // offset=0: Past 7 Days (start of day 7 days ago to now)
            // offset=1: previous 7 days (start of day 14 days ago to start of day 7 days ago)
            let daysBack = 7 * (offset + 1)
            let periodEnd = offset == 0 ? now : calendar.date(byAdding: .day, value: -7 * offset, to: startOfToday) ?? startOfToday
            let periodStart = calendar.date(byAdding: .day, value: -daysBack, to: startOfToday) ?? startOfToday
            return (periodStart, min(periodEnd, now))
            
        case .month:
            // For month view, go back to same date in previous month (or N months ago for offset)
            // This handles edge cases like 31 -> 28/29 automatically via Calendar
            // offset=0: previous month same date to today (e.g., Feb 15 - March 15)
            // offset=1: two months ago to previous month same date (e.g., Jan 15 - Feb 15)
            let periodEnd = offset == 0 ? now : calendar.date(byAdding: .month, value: -offset, to: now) ?? now
            let periodStart = calendar.date(byAdding: .month, value: -(offset + 1), to: periodEnd) ?? periodEnd
            // Cap end date to today to avoid showing future dates
            let finalEnd = min(periodEnd, now)
            return (periodStart, finalEnd)
            
        case .threeMonth:
            // Rolling 3-month periods
            // offset=0: 3 months ago to today
            // offset=1: 6 months ago to 3 months ago
            let periodEnd = offset == 0 ? now : calendar.date(byAdding: .month, value: -3 * offset, to: now) ?? now
            let periodStart = calendar.date(byAdding: .month, value: -3 * (offset + 1), to: now) ?? now
            let finalEnd = min(periodEnd, now)
            return (periodStart, finalEnd)
            
        case .year:
            // Rolling year periods (not calendar year)
            // offset=0: 1 year ago to today
            // offset=1: 2 years ago to 1 year ago
            let periodEnd = offset == 0 ? now : calendar.date(byAdding: .year, value: -offset, to: now) ?? now
            let periodStart = calendar.date(byAdding: .year, value: -(offset + 1), to: now) ?? now
            let finalEnd = min(periodEnd, now)
            return (periodStart, finalEnd)
        }
    }
    
    /// Calculate aggregate stats for sessions within a time period
    func calculatePeriodStats(
        sessions: [SessionWithStats],
        period: AnalysisPeriod,
        offset: Int = 0
    ) -> PeriodStats {
        let (start, end) = periodDateRange(for: period, offset: offset)
        
        let periodSessions = sessions.filter { session in
            session.session.startDate >= start && session.session.startDate < end
        }
        
        guard !periodSessions.isEmpty else {
            return PeriodStats(
                periodStart: start,
                periodEnd: end,
                sessionCount: 0,
                totalDuration: 0,
                totalCalories: 0,
                avgHeartRate: 0,
                maxHeartRate: 0,
                avgTemperature: 0
            )
        }
        
        let totalDuration = periodSessions.reduce(0) { $0 + $1.stats.duration }
        let totalCalories = periodSessions.reduce(0) { $0 + $1.stats.calories }

        // Only include sessions with valid HR data in heart rate averages
        let sessionsWithHR = periodSessions.filter { $0.stats.averageHR > 0 }
        let avgHeartRate = sessionsWithHR.isEmpty ? 0 : sessionsWithHR.reduce(0) { $0 + $1.stats.averageHR } / Double(sessionsWithHR.count)
        let maxHeartRate = sessionsWithHR.map { $0.stats.maxHR }.max() ?? 0

        // Only include sessions with temperature data in temperature average
        let sessionsWithTemp = periodSessions.filter { $0.session.roomTemperature != nil }
        let avgTemperature = sessionsWithTemp.isEmpty ? 0 : sessionsWithTemp.reduce(0.0) { $0 + Double($1.session.roomTemperature!) } / Double(sessionsWithTemp.count)
        
        return PeriodStats(
            periodStart: start,
            periodEnd: end,
            sessionCount: periodSessions.count,
            totalDuration: totalDuration,
            totalCalories: totalCalories,
            avgHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            avgTemperature: avgTemperature
        )
    }
    
    /// Compare current period to previous period
    func comparePeriods(sessions: [SessionWithStats], period: AnalysisPeriod) -> PeriodComparison {
        let current = calculatePeriodStats(sessions: sessions, period: period, offset: 0)
        let previous = calculatePeriodStats(sessions: sessions, period: period, offset: 1)
        
        // Only include previous if it has data
        let previousIfValid = previous.sessionCount > 0 ? previous : nil
        
        return PeriodComparison(current: current, previous: previousIfValid)
    }
    
    // MARK: - Trend Calculation
    
    /// Calculate trend points for charting within the current period
    func calculateTrend(sessions: [SessionWithStats], filters: AnalysisFilters) -> [TrendPoint] {
        let (start, end) = periodDateRange(for: filters.period, offset: 0)
        
        let periodSessions = sessions
            .filter { $0.session.startDate >= start && $0.session.startDate < end }
            .filter { $0.stats.averageHR > 0 }  // Exclude sessions with 0 heart rate
            .sorted { $0.session.startDate < $1.session.startDate }
        
        return periodSessions.map { session in
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
    
    // MARK: - Full Analysis
    
    /// Perform complete analysis with current filters
    /// - Parameters:
    ///   - sessions: All available sessions
    ///   - filters: Analysis filters including period
    ///   - isPro: Whether user has Pro subscription (affects available periods)
    /// - Returns: Analysis result with period comparison and trends
    func analyze(sessions: [SessionWithStats], filters: AnalysisFilters, isPro: Bool = true) -> AnalysisResult {
        // Enforce period restriction for free users
        var effectiveFilters = filters
        if !isPro && filters.period.requiresPro {
            effectiveFilters.period = .week
        }
        
        // First filter by dimensions (temp, class type)
        let filtered = filterSessions(sessions, with: effectiveFilters)
        
        // Calculate period comparison
        let comparison = comparePeriods(sessions: filtered, period: effectiveFilters.period)
        
        // Calculate trend points for chart
        let trendPoints = calculateTrend(sessions: filtered, filters: effectiveFilters)
        
        // Create mapping from date to session for navigation
        let sessionMap = Dictionary(uniqueKeysWithValues: filtered.map { ($0.session.startDate, $0) })

        // Calculate acclimation (only meaningful when filtering by a specific temperature bucket)
        let acclimation: AcclimationSignal? = if let bucket = effectiveFilters.temperatureBucket {
            trendCalculator.calculateAcclimation(sessions: sessions, bucket: bucket)
        } else {
            nil
        }
        
        return AnalysisResult(
            filters: effectiveFilters,
            comparison: comparison,
            trendPoints: trendPoints,
            acclimation: acclimation,
            sessionMap: sessionMap
        )
    }
}
