//
//  SessionTypeConfig.swift
//  heatlab
//
//  Configuration for session/class types with visibility and soft-delete support
//  Each session type maps to a specific HKWorkoutActivityType (yoga, pilates, barre)
//

import Foundation

/// Raw string identifiers for HealthKit workout activity types
/// Using strings for Codable compatibility across platforms
enum WorkoutTypeRaw: String, Codable, CaseIterable {
    case yoga = "yoga"
    case pilates = "pilates"
    case barre = "barre"
    
    var displayName: String {
        switch self {
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .barre: return "Barre"
        }
    }
    
    /// SF Symbol icon for this workout type
    var icon: String {
        switch self {
        case .yoga: return SFSymbol.yoga
        case .pilates: return SFSymbol.pilates
        case .barre: return SFSymbol.barre
        }
    }
}

/// Configuration for a session type (e.g., "Vinyasa", "Pilates")
/// Supports both built-in default types and user-created custom types
/// Each session type maps to a specific HKWorkoutActivityType
struct SessionTypeConfig: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let isDefault: Bool      // true for built-in types
    var isVisible: Bool      // whether to show on Watch picker and in claim portal
    var isDeleted: Bool      // soft delete - only meaningful for custom types
    var hkActivityTypeRaw: String  // "yoga", "pilates", or "barre"
    
    /// Default types cannot be deleted, only hidden
    var canDelete: Bool { !isDefault }
    
    /// The workout type as an enum (for type safety in non-HealthKit code)
    var workoutType: WorkoutTypeRaw {
        WorkoutTypeRaw(rawValue: hkActivityTypeRaw) ?? .yoga
    }
    
    /// SF Symbol icon for this session type's workout type
    var icon: String {
        workoutType.icon
    }
    
    // MARK: - Canonical UUIDs for Default Types
    // These are constant across all installations for future server-side analytics
    enum DefaultTypeID {
        static let vinyasa  = UUID(uuidString: "A1B2C3D4-1111-1111-1111-000000000001")!
        static let pilates  = UUID(uuidString: "A1B2C3D4-1111-1111-1111-000000000005")!
        static let sculpt   = UUID(uuidString: "A1B2C3D4-1111-1111-1111-000000000003")!
        static let hotHour  = UUID(uuidString: "A1B2C3D4-1111-1111-1111-000000000004")!
        static let barre    = UUID(uuidString: "A1B2C3D4-1111-1111-1111-000000000006")!
    }
    
    /// Default session types available to all users
    static let defaults: [SessionTypeConfig] = [
        SessionTypeConfig(
            id: DefaultTypeID.vinyasa,
            name: "Vinyasa",
            isDefault: true,
            isVisible: true,
            isDeleted: false,
            hkActivityTypeRaw: "yoga"
        ),
        SessionTypeConfig(
            id: DefaultTypeID.pilates,
            name: "Pilates",
            isDefault: true,
            isVisible: true,
            isDeleted: false,
            hkActivityTypeRaw: "pilates"
        ),
        SessionTypeConfig(
            id: DefaultTypeID.sculpt,
            name: "Sculpt",
            isDefault: true,
            isVisible: true,
            isDeleted: false,
            hkActivityTypeRaw: "yoga"
        ),
        SessionTypeConfig(
            id: DefaultTypeID.hotHour,
            name: "Hot Hour",
            isDefault: true,
            isVisible: true,
            isDeleted: false,
            hkActivityTypeRaw: "yoga"
        ),
        SessionTypeConfig(
            id: DefaultTypeID.barre,
            name: "Barre",
            isDefault: true,
            isVisible: false,  // Disabled by default
            isDeleted: false,
            hkActivityTypeRaw: "barre"
        ),
    ]
    
    /// Create a new custom session type with specified workout type
    static func custom(name: String, hkActivityTypeRaw: String = "yoga") -> SessionTypeConfig {
        SessionTypeConfig(
            id: UUID(),
            name: name,
            isDefault: false,
            isVisible: true,
            isDeleted: false,
            hkActivityTypeRaw: hkActivityTypeRaw
        )
    }
}
