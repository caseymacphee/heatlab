//
//  SessionRowView.swift
//  heatlab
//
//  Row view for session list
//

import SwiftUI

struct SessionRowView: View {
    let session: SessionWithStats
    
    var body: some View {
        HStack(spacing: 12) {
            // Heat indicator
            Circle()
                .fill(temperatureGradient)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.white)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                // Date and class type
                HStack {
                    Text(session.session.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                    
                    if let classType = session.session.classType {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(classType.shortName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Quick stats
                HStack(spacing: 16) {
                    Label(formatDuration(session.stats.duration), systemImage: "clock")
                    Label("\(Int(session.stats.averageHR)) bpm", systemImage: "heart.fill")
                        .foregroundStyle(.red)
                    Label("\(Int(session.stats.calories)) cal", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Temperature badge
            TemperatureBadge(temperature: session.session.roomTemperature, size: .small)
        }
        .padding(.vertical, 4)
    }
    
    private var temperatureGradient: LinearGradient {
        let temp = session.session.roomTemperature
        let colors: [Color]
        switch temp {
        case ..<90: colors = [.yellow, .orange]
        case 90..<100: colors = [.orange, .red]
        case 100..<105: colors = [.red, .pink]
        default: colors = [.pink, .purple]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
}

#Preview {
    List {
        SessionRowView(session: SessionWithStats(
            session: {
                let s = HeatSession(startDate: Date(), roomTemperature: 102)
                s.classType = .heatedVinyasa
                return s
            }(),
            workout: nil,
            stats: SessionStats(averageHR: 145, maxHR: 168, minHR: 95, calories: 387, duration: 2732)
        ))
    }
}

