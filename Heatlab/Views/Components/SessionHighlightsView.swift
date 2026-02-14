//
//  SessionHighlightsView.swift
//  heatlab
//
//  Contextual highlights for a session: records, baseline comparisons, peak zone, near-records
//  Returns EmptyView when no highlights are notable
//

import SwiftUI

struct SessionHighlightsView: View {
    @Environment(UserSettings.self) var settings

    let session: SessionWithStats
    let records: [PersonalRecord]
    let allSessions: [SessionWithStats]
    let temperatureComparison: BaselineComparison
    let classTypeComparison: BaselineComparison?

    private var highlights: [Highlight] {
        computeHighlights()
    }

    var body: some View {
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Highlights")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(highlights) { highlight in
                        HStack(spacing: 10) {
                            Image(systemName: highlight.icon)
                                .font(.body)
                                .foregroundStyle(highlight.iconColor)
                                .frame(width: 24)

                            Text(highlight.text)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .heatLabCard()
        }
    }

    // MARK: - Highlight Computation

    private struct Highlight: Identifiable {
        let id = UUID()
        let icon: String
        let iconColor: Color
        let text: String
    }

    private func computeHighlights() -> [Highlight] {
        var items: [Highlight] = []

        // 1. Records broken
        for record in records {
            if let text = recordText(for: record) {
                items.append(Highlight(
                    icon: "trophy.fill",
                    iconColor: Color.hlAccent,
                    text: text
                ))
            }
        }

        // 2. Baseline comparisons (temperature + class type)
        items.append(contentsOf: baselineHighlights())

        // 3. Highest max HR this month
        if session.stats.maxHR > 0 {
            let calendar = Calendar.current
            let month = calendar.component(.month, from: session.session.startDate)
            let year = calendar.component(.year, from: session.session.startDate)
            let monthSessions = allSessions.filter { sws in
                sws.session.id != session.session.id
                    && calendar.component(.month, from: sws.session.startDate) == month
                    && calendar.component(.year, from: sws.session.startDate) == year
                    && sws.stats.maxHR > 0
            }
            let monthMax = monthSessions.map(\.stats.maxHR).max() ?? 0
            if session.stats.maxHR > monthMax && !monthSessions.isEmpty {
                items.append(Highlight(
                    icon: "heart.fill",
                    iconColor: Color.HeatLab.heartRate,
                    text: "Highest max HR this month (\(Int(session.stats.maxHR)) bpm)"
                ))
            }
        }

        // 4. Close to a record (within 10%)
        if records.isEmpty {
            items.append(contentsOf: nearRecordHighlights())
        }

        // 5. Peak zone reached
        if let zoneDistribution = session.zoneDistribution {
            if let zone5Entry = zoneDistribution.entries.first(where: { $0.zone == .zone5 }), zone5Entry.duration > 0 {
                let minutes = Int(zone5Entry.duration / 60)
                let seconds = Int(zone5Entry.duration.truncatingRemainder(dividingBy: 60))
                let timeStr = minutes > 0 ? "\(minutes):\(String(format: "%02d", seconds))" : "\(seconds)s"
                items.append(Highlight(
                    icon: "bolt.fill",
                    iconColor: HeartRateZone.zone5.color,
                    text: "Hit Zone 5 for \(timeStr) \u{2014} peak effort!"
                ))
            }
        }

        return Array(items.prefix(5))
    }

    // MARK: - Baseline Highlights

    private func baselineHighlights() -> [Highlight] {
        var items: [Highlight] = []

        // Temperature baseline
        switch temperatureComparison {
        case .typical(let bucket):
            // Only show "typical" if there are other sessions at this temperature
            let otherCount = allSessions.filter {
                $0.session.id != session.session.id
                    && $0.session.temperatureBucket == bucket
            }.count
            if otherCount > 0 {
                let text = bucket.isHeated ? "Typical avg HR for this temperature" : "Typical avg HR for unheated"
                items.append(Highlight(icon: SFSymbol.thermometer, iconColor: Color.hlAccent, text: text))
            }
        case .higherEffort(let percent, _):
            items.append(Highlight(icon: SFSymbol.thermometer, iconColor: Color.hlAccent, text: "\(Int(percent))% higher avg HR than usual for this temp"))
        case .lowerEffort(let percent, _):
            items.append(Highlight(icon: SFSymbol.thermometer, iconColor: Color.hlAccent, text: "\(Int(percent))% lower avg HR than usual for this temp"))
        case .insufficientData:
            break // Don't show in highlights
        }

        // Class type baseline
        if let classComparison = classTypeComparison {
            let typeName = settings.sessionTypeName(for: session.session.sessionTypeId) ?? "this class type"
            let classIcon = settings.sessionType(for: session.session.sessionTypeId)?.icon ?? SFSymbol.yoga

            switch classComparison {
            case .typical:
                // Only show "typical" if there are other sessions of this type
                let otherCount = allSessions.filter {
                    $0.session.id != session.session.id
                        && $0.session.sessionTypeId == session.session.sessionTypeId
                }.count
                if otherCount > 0 {
                    items.append(Highlight(icon: classIcon, iconColor: Color.hlAccent, text: "Typical avg HR for \(typeName)"))
                }
            case .higherEffort(let percent, _):
                items.append(Highlight(icon: classIcon, iconColor: Color.hlAccent, text: "\(Int(percent))% higher avg HR than typical \(typeName)"))
            case .lowerEffort(let percent, _):
                items.append(Highlight(icon: classIcon, iconColor: Color.hlAccent, text: "\(Int(percent))% lower avg HR than typical \(typeName)"))
            case .insufficientData:
                break // Don't show in highlights
            }
        }

        return items
    }

    private func recordText(for record: PersonalRecord) -> String? {
        let scopeLabel = record.scope == "overall" ? "" : " in a \(record.scope) session"
        switch record.recordType {
        case "highest_max_hr":
            return "New record! Highest max HR\(scopeLabel) (\(Int(record.value)) bpm)"
        case "most_calories":
            return "New record! Most calories\(scopeLabel) (\(Int(record.value)) cal)"
        case "longest_zone4plus":
            let minutes = Int(record.value / 60)
            let seconds = Int(record.value.truncatingRemainder(dividingBy: 60))
            let timeStr = minutes > 0 ? "\(minutes)m \(seconds)s" : "\(seconds)s"
            return "New record! Longest time in Zone 4+\(scopeLabel) (\(timeStr))"
        default:
            return nil
        }
    }

    private func nearRecordHighlights() -> [Highlight] {
        var items: [Highlight] = []

        // Check if close to calorie record
        let calorieRecords = allSessions.map(\.stats.calories).filter { $0 > 0 }
        if let maxCalories = calorieRecords.max(), session.stats.calories > 0 {
            let threshold = maxCalories * 0.9
            if session.stats.calories >= threshold && session.stats.calories < maxCalories {
                let diff = Int(maxCalories - session.stats.calories)
                items.append(Highlight(
                    icon: "target",
                    iconColor: .secondary,
                    text: "Just \(diff) cal short of your calorie record"
                ))
            }
        }

        // Check if close to max HR record
        let hrRecords = allSessions.map(\.stats.maxHR).filter { $0 > 0 }
        if let maxHRRecord = hrRecords.max(), session.stats.maxHR > 0 {
            let threshold = maxHRRecord * 0.9
            if session.stats.maxHR >= threshold && session.stats.maxHR < maxHRRecord {
                let diff = Int(maxHRRecord - session.stats.maxHR)
                items.append(Highlight(
                    icon: "target",
                    iconColor: .secondary,
                    text: "Just \(diff) bpm short of your max HR record"
                ))
            }
        }

        return items
    }
}
