//
//  SessionRowView.swift
//  heatlab
//
//  Row view for session list
//

import SwiftUI

struct SessionRowView: View {
    @Environment(UserSettings.self) var settings
    let session: SessionWithStats
    
    private var className: String {
        settings.sessionTypeName(for: session.session.sessionTypeId) ?? "Session"
    }
    
    private var sessionIcon: String {
        settings.sessionType(for: session.session.sessionTypeId)?.icon ?? SFSymbol.yoga
    }
    
    private var timeString: String {
        formatSessionDate(session.session.startDate)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Workout type icon
            Image(systemName: sessionIcon)
                .font(.title3)
                .foregroundStyle(Color.hlAccent)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                // Primary: Class name
                Text(className)
                    .font(.headline)
                
                // Secondary: Time • duration • HR
                HStack(spacing: 0) {
                    Text(timeString)
                    Text(" • ")
                    Text(formatDuration(session.stats.duration))
                    Text(" • ")
                    Text(session.stats.averageHR > 0 ? "\(Int(session.stats.averageHR)) bpm" : "-- bpm")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Temperature badge
            TemperatureBadge(
                temperature: session.session.roomTemperature,
                unit: settings.temperatureUnit,
                size: .small
            )
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
    
    /// Custom date formatting for scannable session lists:
    /// - < 6 hours: relative ("5 minutes ago", "2 hours ago")
    /// - 6-48 hours: "Today 6:12 PM" / "Yesterday 7:05 AM"
    /// - 2-7 days: "Mon 6:12 PM"
    /// - > 7 days: "Jan 3, 6:12 PM"
    private func formatSessionDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let hoursDiff = calendar.dateComponents([.hour], from: date, to: now).hour ?? 0
        
        // < 6 hours: use RelativeDateTimeFormatter for granular output
        if hoursDiff < 6 {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: date, relativeTo: now)
        }
        
        // 6-48 hours: "Today 6:12 PM" / "Yesterday 7:05 AM"
        if calendar.isDateInToday(date) {
            return "Today " + date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday " + date.formatted(date: .omitted, time: .shortened)
        }
        
        // 2-7 days: "Mon 6:12 PM"
        let daysDiff = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if daysDiff <= 7 {
            let weekday = date.formatted(.dateTime.weekday(.abbreviated))
            let time = date.formatted(date: .omitted, time: .shortened)
            return "\(weekday) \(time)"
        }
        
        // > 7 days: "Jan 3, 6:12 PM"
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}

#Preview {
    List {
        SessionRowView(session: SessionWithStats(
            session: {
                let s = WorkoutSession(workoutUUID: UUID(), startDate: Date(), roomTemperature: 102)
                s.sessionTypeId = SessionTypeConfig.DefaultTypeID.vinyasa
                return s
            }(),
            workout: nil,
            stats: SessionStats(averageHR: 145, maxHR: 168, minHR: 95, calories: 387, duration: 2732)
        ))
        SessionRowView(session: SessionWithStats(
            session: {
                let s = WorkoutSession(workoutUUID: UUID(), startDate: Date(), roomTemperature: nil)
                s.sessionTypeId = SessionTypeConfig.DefaultTypeID.vinyasa
                return s
            }(),
            workout: nil,
            stats: SessionStats(averageHR: 130, maxHR: 155, minHR: 85, calories: 320, duration: 2400)
        ))
    }
    .environment(UserSettings())
}
