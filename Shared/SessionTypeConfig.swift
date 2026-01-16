//
//  SessionTypeConfig.swift
//  heatlab
//
//  Configuration for session/class types with visibility and soft-delete support
//

import Foundation

/// Configuration for a session type (e.g., "Heated Vinyasa", "Power")
/// Supports both built-in default types and user-created custom types
struct SessionTypeConfig: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let isDefault: Bool      // true for built-in types
    var isVisible: Bool      // whether to show on Watch picker
    var isDeleted: Bool      // soft delete - only meaningful for custom types
    
    /// Default types cannot be deleted, only hidden
    var canDelete: Bool { !isDefault }
    
    // MARK: - Canonical UUIDs for Default Types
    // These are constant across all installations for future server-side analytics
    enum DefaultTypeID {
        static let heatedVinyasa = UUID(uuidString: "A1B2C3D4-1111-1111-1111-000000000001")!
        static let power         = UUID(uuidString: "A1B2C3D4-1111-1111-1111-000000000002")!
        static let sculpt        = UUID(uuidString: "A1B2C3D4-1111-1111-1111-000000000003")!
        static let hotHour       = UUID(uuidString: "A1B2C3D4-1111-1111-1111-000000000004")!
    }
    
    /// Default session types available to all users
    static let defaults: [SessionTypeConfig] = [
        SessionTypeConfig(
            id: DefaultTypeID.heatedVinyasa,
            name: "Heated Vinyasa",
            isDefault: true,
            isVisible: true,
            isDeleted: false
        ),
        SessionTypeConfig(
            id: DefaultTypeID.power,
            name: "Power",
            isDefault: true,
            isVisible: true,
            isDeleted: false
        ),
        SessionTypeConfig(
            id: DefaultTypeID.sculpt,
            name: "Sculpt",
            isDefault: true,
            isVisible: true,
            isDeleted: false
        ),
        SessionTypeConfig(
            id: DefaultTypeID.hotHour,
            name: "Hot Hour",
            isDefault: true,
            isVisible: true,
            isDeleted: false
        ),
    ]
    
    /// Create a new custom session type
    static func custom(name: String) -> SessionTypeConfig {
        SessionTypeConfig(
            id: UUID(),
            name: name,
            isDefault: false,
            isVisible: true,
            isDeleted: false
        )
    }
}
