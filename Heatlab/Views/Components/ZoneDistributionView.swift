//
//  ZoneDistributionView.swift
//  heatlab
//
//  Compact horizontal bar chart + zone detail rows for heart rate zone distribution
//

import SwiftUI

struct ZoneDistributionView: View {
    let distribution: ZoneDistribution

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Zones")
                .font(.headline)

            // Individual horizontal bars per zone, sorted by time spent
            let sorted = distribution.sortedByTimeSpent
            let maxPct = sorted.first?.percentage ?? 1.0

            VStack(spacing: 8) {
                ForEach(sorted) { entry in
                    HStack(spacing: 10) {
                        // Proportional bar
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(entry.zone.color)
                                .frame(width: max(4, geo.size.width * (entry.percentage / maxPct)))
                        }
                        .frame(height: 20)

                        // Zone label + percentage
                        Text(entry.zone.label)
                            .font(.subheadline.bold())
                            .frame(width: 52, alignment: .leading)

                        Text(formattedPercentage(entry.percentage))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            // Peak zone + most time callouts
            if let peak = distribution.peakZone, let dominant = distribution.dominantZone {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    if let peakEntry = distribution.entries.first(where: { $0.zone == peak }) {
                        let bpmRange = peak.bpmRange(maxHR: distribution.maxHR)
                        Text("Peak: \(peak.label) (\(Int(bpmRange.upperBound)) bpm) for \(formattedDuration(peakEntry.duration))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let dominantEntry = distribution.entries.first(where: { $0.zone == dominant }) {
                        Text("Most time: \(dominant.label) (\(formattedDuration(dominantEntry.duration)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .heatLabCard()
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }

    private func formattedPercentage(_ pct: Double) -> String {
        "\(Int((pct * 100).rounded()))%"
    }
}

#Preview {
    ZoneDistributionView(
        distribution: ZoneDistribution(
            maxHR: 190,
            entries: [
                .init(zone: .zone1, duration: 120, percentage: 0.07),
                .init(zone: .zone2, duration: 360, percentage: 0.20),
                .init(zone: .zone3, duration: 720, percentage: 0.40),
                .init(zone: .zone4, duration: 480, percentage: 0.27),
                .init(zone: .zone5, duration: 120, percentage: 0.07),
            ]
        )
    )
    .padding()
}
