//
//  AnalysisInsightGenerator.swift
//  heatlab
//
//  Generates AI insights for analysis views using Foundation Models
//

import Foundation
import FoundationModels
import Observation

@Observable
final class AnalysisInsightGenerator {
    private var session: LanguageModelSession?
    
    init() {
        // Session will be created lazily when needed
    }
    
    /// Check if Apple Intelligence is available on this device
    /// Returns false on simulators since AI models don't work there
    static var isAvailable: Bool {
        // Check if running on simulator
        #if targetEnvironment(simulator)
        return false
        #else
        // Also check at runtime in case compile-time check doesn't catch it
        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            return false
        }
        return SystemLanguageModel.default.isAvailable
        #endif
    }
    
    @MainActor
    func generateInsight(
        for result: AnalysisResult,
        temperatureName: String?,
        classTypeName: String?
    ) async throws -> String {
        // Check availability first
        guard Self.isAvailable else {
            throw AnalysisInsightError.aiNotAvailable
        }
        
        // Create a new session if needed
        if session == nil {
            session = LanguageModelSession()
        }
        
        guard let session = session else {
            throw AnalysisInsightError.sessionUnavailable
        }
        
        let prompt = buildPrompt(
            result: result,
            temperatureName: temperatureName,
            classTypeName: classTypeName
        )
        
        let response = try await session.respond(to: prompt)
        return response.content
    }
    
    private func buildPrompt(
        result: AnalysisResult,
        temperatureName: String?,
        classTypeName: String?
    ) -> String {
        let current = result.comparison.current
        let previous = result.comparison.previous
        let period = result.filters.period
        
        // Build filter context
        var filterContext = ""
        if let temp = temperatureName {
            filterContext += "Temperature range: \(temp)\n"
        }
        if let classType = classTypeName {
            filterContext += "Class type: \(classType)\n"
        }
        if filterContext.isEmpty {
            filterContext = "All sessions (no filters)\n"
        }
        
        // Build current period stats
        let currentStats = """
        \(period.currentLabel):
        - Sessions: \(current.sessionCount)
        - Total Duration: \(Int(current.totalDuration / 60)) minutes
        - Average Heart Rate: \(current.avgHeartRate > 0 ? "\(Int(current.avgHeartRate)) bpm" : "N/A")
        - Total Calories: \(current.totalCalories > 0 ? "\(Int(current.totalCalories))" : "N/A")
        - Average Temperature: \(Int(current.avgTemperature))°F
        """
        
        // Build previous period stats if available
        var previousStats = ""
        if let prev = previous, prev.sessionCount > 0 {
            previousStats = """
            
            \(period.previousLabel):
            - Sessions: \(prev.sessionCount)
            - Total Duration: \(Int(prev.totalDuration / 60)) minutes
            - Average Heart Rate: \(prev.avgHeartRate > 0 ? "\(Int(prev.avgHeartRate)) bpm" : "N/A")
            - Total Calories: \(prev.totalCalories > 0 ? "\(Int(prev.totalCalories))" : "N/A")
            
            Changes:
            - Session count: \(result.comparison.sessionCountDelta.map { $0 > 0 ? "+\($0)" : "\($0)" } ?? "N/A")
            - Avg HR change: \(result.comparison.avgHRDelta.map { String(format: "%.1f%%", $0) } ?? "N/A")
            - Duration change: \(result.comparison.durationDelta.map { String(format: "%.1f%%", $0) } ?? "N/A")
            """
        }
        
        // Build acclimation context if available
        var acclimationContext = ""
        if let acclimation = result.acclimation {
            let direction = acclimation.direction == .improving ? "improving" : "stable"
            acclimationContext = """
            
            Heat Acclimation Status:
            - Direction: \(direction)
            - HR change from first sessions: \(String(format: "%.1f%%", acclimation.percentChange))
            - Total sessions analyzed: \(acclimation.sessionCount)
            """
        }
        
        return """
        Generate a brief, insightful 2-3 sentence analysis of this user's heated yoga practice data.
        
        \(filterContext)
        \(currentStats)\(previousStats)\(acclimationContext)
        
        Guidelines:
        - Focus on meaningful patterns: improvement, consistency, or areas of opportunity
        - If comparing periods, highlight the most significant change
        - If acclimation data shows improvement, mention heat adaptation progress
        - Lower average heart rate at the same temperature indicates better heat tolerance
        - Be encouraging but grounded in the data - avoid generic praise
        - If there's insufficient data for comparison, acknowledge what they've accomplished so far
        - Keep it conversational and actionable
        """
    }
}

enum AnalysisInsightError: LocalizedError {
    case aiNotAvailable
    case sessionUnavailable
    case generationFailed
    case insufficientData
    
    var errorDescription: String? {
        switch self {
        case .aiNotAvailable:
            return "Apple Intelligence is not available on this device."
        case .sessionUnavailable:
            return "AI insight generation is not available."
        case .generationFailed:
            return "Failed to generate insight. Please try again."
        case .insufficientData:
            return "Not enough data to generate meaningful insights."
        }
    }
}
