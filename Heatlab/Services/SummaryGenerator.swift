//
//  SummaryGenerator.swift
//  heatlab
//
//  Generates AI summaries for sessions using Foundation Models
//

import Foundation
import FoundationModels

@available(iOS 26.0, *)
@Observable
final class SummaryGenerator {
    private var session: LanguageModelSession?
    
    init() {
        // Session will be created lazily when needed
    }
    
    @MainActor
    func generateSummary(for sessionWithStats: SessionWithStats, comparison: BaselineComparison, sessionTypeName: String? = nil) async throws -> String {
        // Create a new session if needed
        if session == nil {
            session = LanguageModelSession()
        }
        
        guard let session = session else {
            throw SummaryError.sessionUnavailable
        }
        
        let prompt = buildPrompt(sessionWithStats: sessionWithStats, comparison: comparison, sessionTypeName: sessionTypeName)
        let response = try await session.respond(to: prompt)
        return response.content
    }
    
    private func buildPrompt(sessionWithStats: SessionWithStats, comparison: BaselineComparison, sessionTypeName: String?) -> String {
        let stats = sessionWithStats.stats
        let heatSession = sessionWithStats.session
        
        let comparisonText: String
        switch comparison {
        case .typical:
            comparisonText = "typical effort compared to baseline"
        case .higherEffort(percentAbove: let percent):
            comparisonText = "\(Int(percent))% higher effort than usual"
        case .lowerEffort(percentBelow: let percent):
            comparisonText = "\(Int(percent))% lower effort than usual"
        case .insufficientData:
            comparisonText = "no baseline comparison available yet"
        }
        
        return """
        Generate a brief, friendly 2-3 sentence summary of this heated yoga session.
        
        Class: \(sessionTypeName ?? "Heated Class")
        Room Temperature: \(heatSession.roomTemperature)°F
        Duration: \(Int(stats.duration / 60)) minutes
        Average Heart Rate: \(Int(stats.averageHR)) bpm
        Max Heart Rate: \(Int(stats.maxHR)) bpm
        Calories: \(Int(stats.calories))
        Baseline Comparison: \(comparisonText)
        
        Focus on how this session compares to their usual at similar temperatures. Be encouraging but not over-the-top.
        """
    }
    
    /// Check if the device supports Foundation Models
    static var isAvailable: Bool {
        // Foundation Models require iOS 26+ and Apple Silicon
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
}

enum SummaryError: LocalizedError {
    case sessionUnavailable
    case generationFailed
    
    var errorDescription: String? {
        switch self {
        case .sessionUnavailable:
            return "AI summary generation is not available on this device."
        case .generationFailed:
            return "Failed to generate summary. Please try again."
        }
    }
}

// Fallback for devices that don't support Foundation Models
struct SummaryGeneratorFallback {
    static func generateBasicSummary(for sessionWithStats: SessionWithStats, comparison: BaselineComparison, sessionTypeName: String? = nil) -> String {
        let stats = sessionWithStats.stats
        let heatSession = sessionWithStats.session
        
        let durationMinutes = Int(stats.duration / 60)
        let typeName = sessionTypeName ?? "heated yoga"
        
        var summary = "You completed a \(durationMinutes)-minute \(typeName) session at \(heatSession.roomTemperature)°F. "
        
        switch comparison {
        case .typical:
            summary += "Your effort was consistent with your usual performance at this temperature."
        case .higherEffort(percentAbove: let percent):
            summary += "You pushed \(Int(percent))% harder than your typical session at this heat level."
        case .lowerEffort(percentBelow: let percent):
            summary += "This was a lighter session, \(Int(percent))% below your usual effort."
        case .insufficientData:
            summary += "Keep practicing to build your baseline for this temperature range."
        }
        
        return summary
    }
}

