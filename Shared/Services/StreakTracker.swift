//
//  StreakTracker.swift
//  heatlab
//
//  Pure computation service for streak and session count tracking
//  Derives from WorkoutSession timestamps — no persistence needed
//

import Foundation

enum StreakTracker {

    /// Count consecutive weeks (Mon–Sun) with at least one heated session, walking back from the current week.
    /// Current week counts if it has a session; if not, counting starts from the previous week.
    /// Returns 0 if no consecutive heated weeks found.
    static func currentStreak(from sessions: [WorkoutSession]) -> Int {
        let calendar = Calendar.current
        let now = Date()

        // Filter to heated sessions only (roomTemperature != nil) and not deleted
        let heatedDates = sessions
            .filter { $0.roomTemperature != nil && $0.deletedAt == nil }
            .map { $0.startDate }

        guard !heatedDates.isEmpty else { return 0 }

        // Build a set of (year, weekOfYear) that have at least one heated session
        var weeksWithSessions: Set<WeekKey> = []
        for date in heatedDates {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            if let year = components.yearForWeekOfYear, let week = components.weekOfYear {
                weeksWithSessions.insert(WeekKey(year: year, week: week))
            }
        }

        // Start from current week
        let currentComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard var year = currentComponents.yearForWeekOfYear, var week = currentComponents.weekOfYear else { return 0 }

        let currentWeekKey = WeekKey(year: year, week: week)

        // If current week has no session, start counting from previous week
        if !weeksWithSessions.contains(currentWeekKey) {
            (year, week) = previousWeek(year: year, week: week, calendar: calendar)
        }

        // Walk backwards counting consecutive weeks
        var streak = 0
        while weeksWithSessions.contains(WeekKey(year: year, week: week)) {
            streak += 1
            (year, week) = previousWeek(year: year, week: week, calendar: calendar)
        }

        return streak
    }

    /// Count sessions in the current calendar month (all sessions, not just heated).
    static func sessionsThisMonth(from sessions: [WorkoutSession]) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        return sessions.filter { session in
            session.deletedAt == nil
                && calendar.component(.month, from: session.startDate) == currentMonth
                && calendar.component(.year, from: session.startDate) == currentYear
        }.count
    }

    // MARK: - Private Helpers

    private struct WeekKey: Hashable {
        let year: Int
        let week: Int
    }

    private static func previousWeek(year: Int, week: Int, calendar: Calendar) -> (Int, Int) {
        // Get a date in the current week, subtract 7 days, extract week components
        var components = DateComponents()
        components.yearForWeekOfYear = year
        components.weekOfYear = week
        components.weekday = calendar.firstWeekday // Monday for ISO

        guard let date = calendar.date(from: components),
              let prevDate = calendar.date(byAdding: .day, value: -7, to: date) else {
            // Fallback: simple decrement
            if week > 1 {
                return (year, week - 1)
            } else {
                return (year - 1, 52)
            }
        }

        let prevComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: prevDate)
        return (prevComponents.yearForWeekOfYear ?? year - 1, prevComponents.weekOfYear ?? 52)
    }
}
