//
//  HeatSession.swift
//  heatlab
//
//  Shared SwiftData model for hot yoga sessions
//

import SwiftData
import Foundation

@Model
final class HeatSession {
    var id: UUID
    var workoutUUID: UUID?  // Links to HKWorkout
    var startDate: Date
    var endDate: Date?
    var roomTemperature: Int  // Degrees Fahrenheit (e.g., 95, 105)
    var classType: ClassType?
    var userNotes: String?
    var aiSummary: String?
    var createdAt: Date
    
    init(startDate: Date, roomTemperature: Int = 95) {
        self.id = UUID()
        self.startDate = startDate
        self.roomTemperature = roomTemperature
        self.createdAt = Date()
    }
    
    /// Returns a temperature bucket for baseline comparisons
    var temperatureBucket: TemperatureBucket {
        TemperatureBucket.from(temperature: roomTemperature)
    }
}

/// Temperature buckets for baseline grouping (5°F ranges)
enum TemperatureBucket: String, Codable, CaseIterable {
    case warm = "80-89°F"      // 80-89
    case hot = "90-99°F"       // 90-99
    case veryHot = "100-104°F" // 100-104
    case extreme = "105°F+"    // 105+
    
    static func from(temperature: Int) -> TemperatureBucket {
        switch temperature {
        case ..<90: return .warm
        case 90..<100: return .hot
        case 100..<105: return .veryHot
        default: return .extreme
        }
    }
    
    var displayName: String { rawValue }
}

enum ClassType: String, Codable, CaseIterable {
    case heatedVinyasa = "Heated Vinyasa"
    case power = "Power"
    case sculpt = "Sculpt"
    case hotHour = "Hot Hour"
    
    /// Short name for Watch display
    var shortName: String {
        switch self {
        case .heatedVinyasa: return "Vinyasa"
        case .power: return "Power"
        case .sculpt: return "Sculpt"
        case .hotHour: return "Hot Hour"
        }
    }
}

