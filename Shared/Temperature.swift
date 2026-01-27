//
//  Temperature.swift
//  heatlab
//
//  Temperature unit conversion and formatting utilities
//

import Foundation

/// Temperature unit preference
enum TemperatureUnit: String, CaseIterable, Codable {
    case fahrenheit = "°F"
    case celsius = "°C"
    
    var displayName: String {
        switch self {
        case .fahrenheit: return "Fahrenheit"
        case .celsius: return "Celsius"
        }
    }
    
    /// Range for heated session temperature input
    var inputRange: ClosedRange<Int> {
        switch self {
        case .fahrenheit: return 80...115
        case .celsius: return 27...46
        }
    }
    
    /// Default heated session temperature
    var defaultTemperature: Int {
        switch self {
        case .fahrenheit: return 95
        case .celsius: return 35
        }
    }
}

/// Temperature value with conversion support
/// Internally stores Fahrenheit as the canonical unit
struct Temperature {
    let fahrenheit: Int
    
    /// Convert to Celsius
    var celsius: Int {
        Int(round(Double(fahrenheit - 32) * 5.0 / 9.0))
    }
    
    /// Get formatted string with unit symbol
    func formatted(unit: TemperatureUnit) -> String {
        switch unit {
        case .fahrenheit: return "\(fahrenheit)°F"
        case .celsius: return "\(celsius)°C"
        }
    }
    
    /// Get numeric value in specified unit
    func value(for unit: TemperatureUnit) -> Int {
        switch unit {
        case .fahrenheit: return fahrenheit
        case .celsius: return celsius
        }
    }
    
    /// Create Temperature from user input in their preferred unit
    /// Converts to Fahrenheit for storage
    static func fromUserInput(_ value: Int, unit: TemperatureUnit) -> Temperature {
        switch unit {
        case .fahrenheit:
            return Temperature(fahrenheit: value)
        case .celsius:
            let f = Int(round(Double(value) * 9.0 / 5.0 + 32))
            return Temperature(fahrenheit: f)
        }
    }
    
    /// Create from stored Fahrenheit value
    init(fahrenheit: Int) {
        self.fahrenheit = fahrenheit
    }
}

// MARK: - Convenience Extensions

extension Int {
    /// Convert this value (assumed Fahrenheit) to a Temperature
    var asTemperature: Temperature {
        Temperature(fahrenheit: self)
    }
}

