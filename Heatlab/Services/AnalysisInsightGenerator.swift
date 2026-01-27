//
//  AnalysisInsightGenerator.swift
//  heatlab
//
//  Generates AI insights for analysis views using Foundation Models
//

import Foundation
import FoundationModels
import Observation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Apple Intelligence Availability

/// Detailed availability status for Apple Intelligence features
enum AppleIntelligenceStatus {
    /// Apple Intelligence is available and ready to use
    case available
    /// Device hardware supports AI, but iOS needs to be updated to 18.1+
    case needsOSUpdate
    /// Device hardware does not support Apple Intelligence (older than iPhone 15 Pro)
    case hardwareNotSupported
    /// Running on simulator (AI not available)
    case simulator
    
    var isAvailable: Bool {
        self == .available
    }
    
    /// User-facing hint for unavailable states
    var unavailableHint: String? {
        switch self {
        case .available:
            return nil
        case .needsOSUpdate:
            return "Update to iOS 18.1 to enable"
        case .hardwareNotSupported:
            return "Not available on this device"
        case .simulator:
            return "Not available in simulator"
        }
    }
    
    /// Full disclaimer for footnotes
    var disclaimer: String? {
        switch self {
        case .available:
            return nil
        case .needsOSUpdate:
            return "Requires iOS 18.1 or later. Update your device to enable AI insights."
        case .hardwareNotSupported:
            return "Requires an Apple Intelligence–compatible device (e.g., iPhone 15 Pro or later)."
        case .simulator:
            return "Apple Intelligence is not available in the simulator."
        }
    }
}

/// Helper to determine Apple Intelligence availability with detailed status
enum AppleIntelligenceChecker {
    /// Minimum iOS version required for Apple Intelligence
    private static let minimumOSVersion = OperatingSystemVersion(majorVersion: 18, minorVersion: 1, patchVersion: 0)
    
    /// iPhone models that support Apple Intelligence (A17 Pro or later)
    /// iPhone 15 Pro: iPhone16,1
    /// iPhone 15 Pro Max: iPhone16,2
    /// iPhone 16: iPhone17,3
    /// iPhone 16 Plus: iPhone17,4
    /// iPhone 16 Pro: iPhone17,1
    /// iPhone 16 Pro Max: iPhone17,2
    private static let supportedIPhoneModels: Set<String> = [
        "iPhone16,1", "iPhone16,2",  // iPhone 15 Pro, 15 Pro Max
        "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4"  // iPhone 16 series
    ]
    
    /// Get the current device's machine identifier
    private static var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    /// Check if running on simulator
    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        #endif
    }
    
    /// Check if current iOS version meets minimum requirement
    private static var hasRequiredOSVersion: Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(minimumOSVersion)
    }
    
    /// Check if device hardware supports Apple Intelligence
    private static var hasRequiredHardware: Bool {
        let machine = machineIdentifier
        
        // On simulator, check the simulated device
        if isSimulator {
            // Simulators report "x86_64" or "arm64" - can't determine simulated device model easily
            // For simulator, we'll assume hardware is supported to test the flow
            return true
        }
        
        // Check if it's a supported iPhone model
        if supportedIPhoneModels.contains(machine) {
            return true
        }
        
        // Also support future iPhone models (iPhone18,x, etc.)
        if machine.hasPrefix("iPhone") {
            // Extract the major version number
            let versionPart = machine.dropFirst(6) // Remove "iPhone"
            if let majorVersion = Int(versionPart.prefix(while: { $0.isNumber })) {
                // iPhone17 and later support Apple Intelligence
                // (iPhone16,1 and iPhone16,2 are special cases - 15 Pro models)
                if majorVersion >= 17 {
                    return true
                }
                // For iPhone16,x only 16,1 and 16,2 (15 Pro models) are supported
                if majorVersion == 16 {
                    return supportedIPhoneModels.contains(machine)
                }
            }
        }
        
        return false
    }
    
    /// Get detailed availability status
    static var status: AppleIntelligenceStatus {
        // Check simulator first
        if isSimulator {
            return .simulator
        }
        
        // Check hardware support
        if !hasRequiredHardware {
            return .hardwareNotSupported
        }
        
        // Check OS version
        if !hasRequiredOSVersion {
            return .needsOSUpdate
        }
        
        // Final check: is the model actually available?
        // This catches edge cases like user having AI disabled in settings
        if SystemLanguageModel.default.isAvailable {
            return .available
        }
        
        // If we get here, hardware and OS are good but AI still not available
        // This could be due to user settings, region, or other factors
        // Treat as needs OS update since that's the most actionable
        return .needsOSUpdate
    }
}

@Observable
final class AnalysisInsightGenerator {
    private var session: LanguageModelSession?
    
    init() {
        // Session will be created lazily when needed
    }
    
    /// Check if Apple Intelligence is available on this device
    /// Returns false on simulators since AI models don't work there
    static var isAvailable: Bool {
        AppleIntelligenceChecker.status.isAvailable
    }
    
    /// Get detailed availability status for UI messaging
    static var availabilityStatus: AppleIntelligenceStatus {
        AppleIntelligenceChecker.status
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
        Generate a brief, insightful 2-3 sentence analysis of this user's heated practice data.
        
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
