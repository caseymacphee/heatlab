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
    func generateSummary(for sessionWithStats: SessionWithStats, comparison: BaselineComparison, sessionTypeName: String? = nil) async throws -> String {
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
