//
//  AnalysisInsightGenerator.swift
//  heatlab
//
//  Generates AI insights for analysis views using Foundation Models
//

import Foundation
import FoundationModels
import Observation

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
        // On simulator, delegate to the framework directly — simulator uses
        // the host Mac's models when running on macOS 26+ with Apple Intelligence enabled
        #if targetEnvironment(simulator)
        if SystemLanguageModel.default.isAvailable {
            return .available
        }
        return .simulator
        #else
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
        #endif
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
        allSessions: [SessionWithStats],
        temperatureName: String?,
        classTypeName: String?,
        temperatureBaselines: [UserBaseline],
        sessionTypeBaselines: [SessionTypeBaseline],
        sessionTypes: [SessionTypeConfig],
        userAge: Int?,
        temperatureUnit: TemperatureUnit = .fahrenheit
    ) async throws -> String {
        guard Self.isAvailable else {
            throw AnalysisInsightError.aiNotAvailable
        }

        if session == nil {
            session = LanguageModelSession()
        }

        guard let session = session else {
            throw AnalysisInsightError.sessionUnavailable
        }

        // Compute structured signals
        let signals = InsightSignalComputer.compute(
            result: result,
            allSessions: allSessions,
            temperatureBaselines: temperatureBaselines,
            sessionTypeBaselines: sessionTypeBaselines,
            sessionTypes: sessionTypes,
            userAge: userAge,
            temperatureUnit: temperatureUnit
        )

        let jsonData = try JSONEncoder().encode(signals)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        var filterContext = ""
        if let temp = temperatureName { filterContext += "Temperature filter: \(temp)\n" }
        if let classType = classTypeName { filterContext += "Class type filter: \(classType)\n" }

        let prompt = """
        Analyze this heat training data and provide a 2-3 sentence insight.

        \(filterContext)
        DATA (JSON):
        \(jsonString)

        Questions to consider:
        - What's the most surprising thing about this data?
        - What pattern here is most significant for heat adaptation?
        - If this pattern continues, what would you predict?
        \(signals.zones != nil ? "- How has Zone 4+5 time changed? What does this suggest about heat adaptation?" : "")

        Guidelines:
        - Reference specific numbers (HR values, dates, percentages) from the data
        - Lower HR at the same temperature = better heat tolerance
        - Focus on the single most meaningful pattern
        - Be encouraging but grounded — no generic praise
        - Keep it conversational and actionable
        """

        let response = try await session.respond(to: prompt)
        return response.content
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

// MARK: - Category-Based AI Insights

/// Categories for focused AI insight generation, mapping to deterministic categories
enum AIInsightCategory: String, CaseIterable {
    case recentComparison
    case temperatureAnalysis
    case sessionTypeComparison
    case periodOverPeriod
    case progression
    case acclimation

    /// Maps to the corresponding deterministic InsightCategory
    var deterministicCategory: InsightCategory {
        switch self {
        case .recentComparison: return .recentComparison
        case .temperatureAnalysis: return .temperatureAnalysis
        case .sessionTypeComparison: return .sessionTypeComparison
        case .periodOverPeriod: return .periodOverPeriod
        case .progression: return .progression
        case .acclimation: return .acclimation
        }
    }

    /// Icon to display for AI-generated insights
    var icon: String {
        SFSymbol.sparkles
    }
}

/// An AI-generated insight for a specific category
struct AIInsight: Identifiable {
    let id = UUID()
    let category: AIInsightCategory
    let text: String
    let isAIGenerated: Bool  // false if fell back to deterministic

    /// Icon to display - sparkles for AI, category icon for deterministic fallback
    var icon: String {
        isAIGenerated ? SFSymbol.sparkles : deterministicIcon
    }

    private var deterministicIcon: String {
        switch category {
        case .recentComparison: return "heart"
        case .temperatureAnalysis: return "thermometer.variable"
        case .sessionTypeComparison: return "arrow.left.arrow.right"
        case .periodOverPeriod: return "heart"
        case .progression: return "chart.line.uptrend.xyaxis"
        case .acclimation: return "waveform.path.ecg"
        }
    }
}

// MARK: - Category Context Builders

extension AnalysisInsightGenerator {

    /// Generate a focused AI insight for a specific category
    @MainActor
    func generateCategoryInsight(
        category: AIInsightCategory,
        result: AnalysisResult,
        allSessions: [SessionWithStats],
        sessionTypes: [SessionTypeConfig],
        temperatureBaselines: [UserBaseline] = [],
        sessionTypeBaselines: [SessionTypeBaseline] = [],
        userAge: Int? = nil,
        temperatureUnit: TemperatureUnit
    ) async throws -> String {
        guard Self.isAvailable else {
            throw AnalysisInsightError.aiNotAvailable
        }

        if session == nil {
            session = LanguageModelSession()
        }

        guard let session = session else {
            throw AnalysisInsightError.sessionUnavailable
        }

        // Compute structured signals
        let signals = InsightSignalComputer.compute(
            result: result,
            allSessions: allSessions,
            temperatureBaselines: temperatureBaselines,
            sessionTypeBaselines: sessionTypeBaselines,
            sessionTypes: sessionTypes,
            userAge: userAge,
            temperatureUnit: temperatureUnit
        )

        let jsonData = try JSONEncoder().encode(signals)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        // Build category-specific prompt using JSON data
        let prompt = buildCategoryPrompt(
            category: category,
            result: result,
            allSessions: allSessions,
            sessionTypes: sessionTypes,
            temperatureUnit: temperatureUnit,
            jsonData: jsonString,
            hasZones: signals.zones != nil
        )

        guard let prompt = prompt else {
            throw AnalysisInsightError.insufficientData
        }

        let response = try await session.respond(to: prompt)
        return response.content
    }

    private func buildCategoryPrompt(
        category: AIInsightCategory,
        result: AnalysisResult,
        allSessions: [SessionWithStats],
        sessionTypes: [SessionTypeConfig],
        temperatureUnit: TemperatureUnit,
        jsonData: String,
        hasZones: Bool
    ) -> String? {
        switch category {
        case .recentComparison:
            return buildRecentComparisonPrompt(result: result, temperatureUnit: temperatureUnit, sessionTypes: sessionTypes)
        case .temperatureAnalysis:
            return buildTemperatureAnalysisPrompt(result: result, allSessions: allSessions, temperatureUnit: temperatureUnit)
        case .sessionTypeComparison:
            return buildSessionTypeComparisonPrompt(result: result, allSessions: allSessions, sessionTypes: sessionTypes, temperatureUnit: temperatureUnit)
        case .periodOverPeriod:
            return buildPeriodOverPeriodPrompt(result: result, temperatureUnit: temperatureUnit)
        case .progression:
            return buildProgressionPrompt(result: result, temperatureUnit: temperatureUnit)
        case .acclimation:
            return buildAcclimationPrompt(result: result)
        }
    }

    // MARK: - Category-Specific Prompts

    private func buildRecentComparisonPrompt(
        result: AnalysisResult,
        temperatureUnit: TemperatureUnit,
        sessionTypes: [SessionTypeConfig]
    ) -> String? {
        let points = result.trendPoints.sorted { $0.date > $1.date }
        guard points.count >= 2 else { return nil }

        let latest = points[0]
        let previous = points[1]

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"

        let latestDay = formatter.string(from: latest.date)
        let previousDay = formatter.string(from: previous.date)

        let latestTemp = latest.temperature > 0
            ? Temperature(fahrenheit: latest.temperature).formatted(unit: temperatureUnit)
            : "unknown temp"
        let previousTemp = previous.temperature > 0
            ? Temperature(fahrenheit: previous.temperature).formatted(unit: temperatureUnit)
            : "unknown temp"

        // Get session type names if available from sessionMap
        let latestType = result.sessionMap[latest.date].flatMap { sessionWithStats in
            sessionWithStats.session.sessionTypeId.flatMap { id in sessionTypes.first { $0.id == id }?.name }
        } ?? "session"
        let previousType = result.sessionMap[previous.date].flatMap { sessionWithStats in
            sessionWithStats.session.sessionTypeId.flatMap { id in sessionTypes.first { $0.id == id }?.name }
        } ?? "session"

        return """
        Compare these two recent heat training sessions:

        Session 1 (\(previousDay)): \(Int(previous.value)) bpm avg, \(previousTemp), \(previousType)
        Session 2 (\(latestDay)): \(Int(latest.value)) bpm avg, \(latestTemp), \(latestType)

        In one sentence, describe what changed between these sessions. Focus on whether they're adapting well or if conditions explain the difference. Keep it conversational and actionable.
        """
    }

    private func buildTemperatureAnalysisPrompt(
        result: AnalysisResult,
        allSessions: [SessionWithStats],
        temperatureUnit: TemperatureUnit
    ) -> String? {
        // Get sessions from current period
        let periodSessions = allSessions.filter { session in
            result.trendPoints.contains { $0.date == session.session.startDate }
        }.filter { $0.stats.averageHR > 0 }

        // Group by temperature bucket
        var bucketStats: [TemperatureBucket: (count: Int, totalHR: Double)] = [:]
        for session in periodSessions {
            let bucket = session.session.temperatureBucket
            let current = bucketStats[bucket] ?? (0, 0)
            bucketStats[bucket] = (current.count + 1, current.totalHR + session.stats.averageHR)
        }

        // Need at least 2 buckets with data
        let qualifiedBuckets = bucketStats.filter { $0.value.count >= 1 }
        guard qualifiedBuckets.count >= 2 else { return nil }

        // Build bucket summary
        let bucketSummary = qualifiedBuckets
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { bucket, stats in
                let avgHR = Int(stats.totalHR / Double(stats.count))
                return "- \(bucket.displayName(for: temperatureUnit)): \(avgHR) bpm avg across \(stats.count) session\(stats.count == 1 ? "" : "s")"
            }
            .joined(separator: "\n")

        return """
        Heart rate by temperature range:

        \(bucketSummary)

        In one sentence, explain how temperature affects their heart rate. Lower HR at higher temps indicates better heat adaptation. Keep it encouraging and specific.
        """
    }

    private func buildSessionTypeComparisonPrompt(
        result: AnalysisResult,
        allSessions: [SessionWithStats],
        sessionTypes: [SessionTypeConfig],
        temperatureUnit: TemperatureUnit
    ) -> String? {
        // Get sessions from current period
        let periodSessions = allSessions.filter { session in
            result.trendPoints.contains { $0.date == session.session.startDate }
        }.filter { $0.stats.averageHR > 0 && $0.session.sessionTypeId != nil }

        // Group by session type
        var typeStats: [UUID: (count: Int, totalHR: Double)] = [:]
        for session in periodSessions {
            guard let typeId = session.session.sessionTypeId else { continue }
            let current = typeStats[typeId] ?? (0, 0)
            typeStats[typeId] = (current.count + 1, current.totalHR + session.stats.averageHR)
        }

        // Need at least 2 types with data
        let qualifiedTypes = typeStats.filter { $0.value.count >= 1 }
        guard qualifiedTypes.count >= 2 else { return nil }

        // Build type summary
        let typeSummary = qualifiedTypes
            .compactMap { typeId, stats -> String? in
                guard let name = sessionTypes.first(where: { $0.id == typeId })?.name else { return nil }
                let avgHR = Int(stats.totalHR / Double(stats.count))
                return "- \(name): \(avgHR) bpm avg across \(stats.count) session\(stats.count == 1 ? "" : "s")"
            }
            .joined(separator: "\n")

        return """
        Heart rate by class type:

        \(typeSummary)

        In one sentence, compare how different class types affect their heart rate. Keep it practical and actionable.
        """
    }

    private func buildPeriodOverPeriodPrompt(
        result: AnalysisResult,
        temperatureUnit: TemperatureUnit
    ) -> String? {
        let current = result.comparison.current
        guard let previous = result.comparison.previous, previous.sessionCount > 0 else { return nil }

        let period = result.filters.period

        let currentTemp = current.avgTemperature > 0
            ? Temperature(fahrenheit: Int(current.avgTemperature)).formatted(unit: temperatureUnit)
            : "N/A"
        let previousTemp = previous.avgTemperature > 0
            ? Temperature(fahrenheit: Int(previous.avgTemperature)).formatted(unit: temperatureUnit)
            : "N/A"

        return """
        Compare these two periods:

        \(period.previousLabel):
        - Sessions: \(previous.sessionCount)
        - Avg HR: \(previous.avgHeartRate > 0 ? "\(Int(previous.avgHeartRate)) bpm" : "N/A")
        - Avg Temp: \(previousTemp)

        \(period.currentLabel):
        - Sessions: \(current.sessionCount)
        - Avg HR: \(current.avgHeartRate > 0 ? "\(Int(current.avgHeartRate)) bpm" : "N/A")
        - Avg Temp: \(currentTemp)

        In one sentence, describe what changed between these periods. Focus on meaningful patterns like consistency, intensity changes, or progress. Keep it conversational.
        """
    }

    private func buildProgressionPrompt(
        result: AnalysisResult,
        temperatureUnit: TemperatureUnit
    ) -> String? {
        let points = result.trendPoints.sorted { $0.date < $1.date }
        guard points.count >= 2 else { return nil }

        let first = points.first!
        let last = points.last!

        let period = result.filters.period

        let firstTemp = first.temperature > 0
            ? Temperature(fahrenheit: first.temperature).formatted(unit: temperatureUnit)
            : "unknown temp"
        let lastTemp = last.temperature > 0
            ? Temperature(fahrenheit: last.temperature).formatted(unit: temperatureUnit)
            : "unknown temp"

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"

        return """
        Progress over this \(period.rawValue.lowercased()):

        First session (\(formatter.string(from: first.date))): \(Int(first.value)) bpm avg at \(firstTemp)
        Last session (\(formatter.string(from: last.date))): \(Int(last.value)) bpm avg at \(lastTemp)
        Total sessions: \(points.count)

        In one sentence, describe their progress over this period. Lower HR at similar temps indicates improving heat adaptation. Keep it encouraging and specific.
        """
    }

    private func buildAcclimationPrompt(result: AnalysisResult) -> String? {
        guard let acclimation = result.acclimation else { return nil }

        let direction = acclimation.direction == .improving ? "improving" : "stable"

        return """
        Heat acclimation status:

        - Direction: \(direction)
        - HR change from first sessions: \(String(format: "%.1f%%", acclimation.percentChange))
        - Sessions analyzed: \(acclimation.sessionCount)

        In one sentence, explain their heat adaptation progress. Lower HR over time at similar temperatures indicates successful heat acclimation. Keep it encouraging and specific.
        """
    }
}
