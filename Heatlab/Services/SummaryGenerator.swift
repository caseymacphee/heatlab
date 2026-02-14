//
//  SummaryGenerator.swift
//  heatlab
//
//  Generates AI summaries for sessions using Foundation Models
//

import Foundation
import FoundationModels
import Observation

@Observable
final class SummaryGenerator {
    private var session: LanguageModelSession?
    
    init() {
        // Session will be created lazily when needed
    }
    
    /// Check if Apple Intelligence is available on this device
    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }
    
    /// Generate a summary with basic context (backward compatible)
    @MainActor
    func generateSummary(for sessionWithStats: SessionWithStats, comparison: BaselineComparison, sessionTypeName: String? = nil, temperatureUnit: TemperatureUnit = .fahrenheit) async throws -> String {
        try await generateSummary(
            for: sessionWithStats,
            temperatureComparison: comparison,
            classTypeComparison: nil,
            sessionTypeName: sessionTypeName,
            temperatureBaselines: [],
            classTypeBaselines: [],
            temperatureUnit: temperatureUnit
        )
    }

    /// Generate a summary with full context including both baseline dimensions
    @MainActor
    func generateSummary(
        for sessionWithStats: SessionWithStats,
        temperatureComparison: BaselineComparison,
        classTypeComparison: BaselineComparison?,
        sessionTypeName: String?,
        temperatureBaselines: [UserBaseline],
        classTypeBaselines: [SessionTypeBaseline],
        temperatureUnit: TemperatureUnit = .fahrenheit
    ) async throws -> String {
        // Check availability first
        guard Self.isAvailable else {
            throw SummaryError.aiNotAvailable
        }

        // Create a new session if needed
        if session == nil {
            session = LanguageModelSession()
        }

        guard let session = session else {
            throw SummaryError.sessionUnavailable
        }

        let prompt = buildEnhancedPrompt(
            sessionWithStats: sessionWithStats,
            temperatureComparison: temperatureComparison,
            classTypeComparison: classTypeComparison,
            sessionTypeName: sessionTypeName,
            temperatureBaselines: temperatureBaselines,
            classTypeBaselines: classTypeBaselines,
            temperatureUnit: temperatureUnit
        )
        let response = try await session.respond(to: prompt)
        return response.content
    }

    private func buildEnhancedPrompt(
        sessionWithStats: SessionWithStats,
        temperatureComparison: BaselineComparison,
        classTypeComparison: BaselineComparison?,
        sessionTypeName: String?,
        temperatureBaselines: [UserBaseline],
        classTypeBaselines: [SessionTypeBaseline],
        temperatureUnit: TemperatureUnit
    ) -> String {
        let stats = sessionWithStats.stats
        let workoutSession = sessionWithStats.session

        // Temperature comparison text
        let tempComparisonText: String
        switch temperatureComparison {
        case .typical(let bucket):
            tempComparisonText = bucket.isHeated
                ? "typical effort compared to baseline at this temperature (\(bucket.displayName(for: temperatureUnit)))"
                : "typical effort compared to non-heated session baseline"
        case .higherEffort(let percent, let bucket):
            tempComparisonText = "\(Int(percent))% higher effort than usual for \(bucket.displayName(for: temperatureUnit))"
        case .lowerEffort(let percent, let bucket):
            tempComparisonText = "\(Int(percent))% lower effort than usual for \(bucket.displayName(for: temperatureUnit))"
        case .insufficientData(_, let bucket):
            tempComparisonText = "no temperature baseline available yet for \(bucket.displayName(for: temperatureUnit))"
        }

        // Class type comparison text
        var classComparisonText = ""
        if let classComparison = classTypeComparison {
            switch classComparison {
            case .typical:
                classComparisonText = "\nClass Type Comparison: typical effort for \(sessionTypeName ?? "this class type")"
            case .higherEffort(let percent, _):
                classComparisonText = "\nClass Type Comparison: \(Int(percent))% higher effort than typical \(sessionTypeName ?? "session")"
            case .lowerEffort(let percent, _):
                classComparisonText = "\nClass Type Comparison: \(Int(percent))% lower effort than typical \(sessionTypeName ?? "session")"
            case .insufficientData:
                classComparisonText = "\nClass Type Comparison: no class baseline available yet"
            }
        }

        // Temperature info
        let temperatureInfo: String
        if let temp = workoutSession.roomTemperature {
            let formattedTemp = Temperature(fahrenheit: temp).formatted(unit: temperatureUnit)
            temperatureInfo = "Room Temperature: \(formattedTemp) (\(workoutSession.temperatureBucket.displayName(for: temperatureUnit)))"
        } else {
            temperatureInfo = "Room Temperature: Not heated"
        }

        // User notes context
        var notesContext = ""
        if let notes = workoutSession.userNotes, !notes.isEmpty {
            notesContext = "\nUser Notes: \"\(notes)\""
        }

        // Perceived effort context
        var effortContext = ""
        if workoutSession.perceivedEffort != .none {
            effortContext = "\nUser's Perceived Effort: \(workoutSession.perceivedEffort.displayName)"
        }

        // Other temperature baselines for cross-reference
        var otherTempBaselines = ""
        let relevantTempBaselines = temperatureBaselines.filter {
            $0.temperatureBucket != workoutSession.temperatureBucket && $0.sessionCount >= 3
        }
        if !relevantTempBaselines.isEmpty {
            let baselineStrings = relevantTempBaselines.map {
                "\($0.temperatureBucket.displayName(for: temperatureUnit)): \(Int($0.averageHR)) bpm avg"
            }
            otherTempBaselines = "\nUser's Other Temperature Baselines: \(baselineStrings.joined(separator: ", "))"
        }

        // Other class baselines for cross-reference
        var otherClassBaselines = ""
        if let currentTypeId = workoutSession.sessionTypeId {
            let relevantClassBaselines = classTypeBaselines.filter {
                $0.sessionTypeId != currentTypeId && $0.sessionCount >= 3
            }
            if !relevantClassBaselines.isEmpty {
                // Note: We don't have access to session type names here, so just show HR
                let baselineStrings = relevantClassBaselines.prefix(3).map {
                    "\(Int($0.averageHR)) bpm avg (\($0.sessionCount) sessions)"
                }
                otherClassBaselines = "\nUser's Other Class Type Baselines: \(baselineStrings.joined(separator: ", "))"
            }
        }

        // Zone distribution context
        var zoneContext = ""
        if let zoneDist = sessionWithStats.zoneDistribution, !zoneDist.entries.isEmpty {
            let zoneLines = zoneDist.sortedByTimeSpent.prefix(3).map { entry in
                let pct = Int((entry.percentage * 100).rounded())
                let mins = Int(entry.duration / 60)
                return "\(entry.zone.label) (\(entry.zone.intensityLabel)): \(pct)% (\(mins)m)"
            }
            zoneContext = "\nZone Distribution: \(zoneLines.joined(separator: ", "))"
            if let dominant = zoneDist.dominantZone {
                zoneContext += "\nDominant Zone: \(dominant.label) (\(dominant.intensityLabel))"
            }
            zoneContext += "\nMax HR for Zones: \(Int(zoneDist.maxHR)) bpm"
        }

        let sessionType = workoutSession.roomTemperature == nil ? "session" : "heated session"

        return """
        Generate a brief, insightful 2-3 sentence summary of this \(sessionType).

        Class: \(sessionTypeName ?? "Class")
        \(temperatureInfo)
        Duration: \(Int(stats.duration / 60)) minutes
        Average Heart Rate: \(Int(stats.averageHR)) bpm
        Max Heart Rate: \(Int(stats.maxHR)) bpm
        Min Heart Rate: \(stats.minHR > 0 ? "\(Int(stats.minHR)) bpm" : "N/A")
        Calories: \(Int(stats.calories))
        Temperature Baseline Comparison: \(tempComparisonText)\(classComparisonText)\(notesContext)\(effortContext)\(otherTempBaselines)\(otherClassBaselines)\(zoneContext)

        Guidelines:
        - Focus on meaningful observations from the data
        - If both temperature and class type comparisons are available, synthesize them (e.g., "typical for Vinyasa, but lower than usual for this temperature" or vice versa)
        - If user notes mention how they felt, acknowledge that context
        - If perceived effort doesn't match HR data, gently note the discrepancy
        - Compare to other baselines only if it provides useful context
        - If zone data available, comment on what the zone distribution reveals about session intensity
        - Be encouraging and fact-focused, not over-the-top positive
        - Keep it conversational and actionable
        """
    }
}

enum SummaryError: LocalizedError {
    case aiNotAvailable
    case sessionUnavailable
    case generationFailed
    
    var errorDescription: String? {
        switch self {
        case .aiNotAvailable:
            return "Apple Intelligence is not available on this device."
        case .sessionUnavailable:
            return "AI summary generation is not available."
        case .generationFailed:
            return "Failed to generate summary. Please try again."
        }
    }
}
