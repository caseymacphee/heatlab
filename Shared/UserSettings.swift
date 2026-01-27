//
//  UserSettings.swift
//  heatlab
//
//  User preferences stored via AppStorage
//

import SwiftUI

/// Observable user settings with persistence via AppStorage
@Observable
final class UserSettings {
    /// Temperature display unit preference
    /// Stored via UserDefaults, synced across app launches
    var temperatureUnit: TemperatureUnit {
        get {
            access(keyPath: \.temperatureUnit)
            if let rawValue = UserDefaults.standard.string(forKey: "temperatureUnit"),
               let unit = TemperatureUnit(rawValue: rawValue) {
                return unit
            }
            return .fahrenheit
        }
        set {
            withMutation(keyPath: \.temperatureUnit) {
                UserDefaults.standard.set(newValue.rawValue, forKey: "temperatureUnit")
            }
        }
    }
    
    /// Last used room temperature (stored in user's preferred unit)
    /// Used as default for next session
    var lastRoomTemperature: Int {
        get {
            access(keyPath: \.lastRoomTemperature)
            let stored = UserDefaults.standard.integer(forKey: "lastRoomTemperature")
            return stored > 0 ? stored : temperatureUnit.defaultTemperature
        }
        set {
            withMutation(keyPath: \.lastRoomTemperature) {
                UserDefaults.standard.set(newValue, forKey: "lastRoomTemperature")
            }
        }
    }
    
    // MARK: - Calories Display Settings
    
    /// Whether to show calories burned in the iOS app (Dashboard, Session Detail, Session Row)
    /// Default: true
    var showCaloriesInApp: Bool {
        get {
            access(keyPath: \.showCaloriesInApp)
            // Default to true if not set
            if UserDefaults.standard.object(forKey: "showCaloriesInApp") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "showCaloriesInApp")
        }
        set {
            withMutation(keyPath: \.showCaloriesInApp) {
                UserDefaults.standard.set(newValue, forKey: "showCaloriesInApp")
            }
        }
    }
    
    /// Whether to show calories burned on Apple Watch (Active Session, Post-Session Confirmation)
    /// Default: false - keeps Watch UI clean and wellness-focused
    var showCaloriesOnWatch: Bool {
        get {
            access(keyPath: \.showCaloriesOnWatch)
            return UserDefaults.standard.bool(forKey: "showCaloriesOnWatch")
        }
        set {
            withMutation(keyPath: \.showCaloriesOnWatch) {
                UserDefaults.standard.set(newValue, forKey: "showCaloriesOnWatch")
            }
        }
    }
    
    // MARK: - Session Type Configuration
    
    /// Configured session types (defaults + custom)
    /// Stored as JSON in UserDefaults
    var sessionTypeConfigs: [SessionTypeConfig] {
        get {
            access(keyPath: \.sessionTypeConfigs)
            guard let data = UserDefaults.standard.data(forKey: "sessionTypeConfigs"),
                  let configs = try? JSONDecoder().decode([SessionTypeConfig].self, from: data) else {
                return SessionTypeConfig.defaults
            }
            return configs
        }
        set {
            withMutation(keyPath: \.sessionTypeConfigs) {
                if let data = try? JSONEncoder().encode(newValue) {
                    UserDefaults.standard.set(data, forKey: "sessionTypeConfigs")
                }
            }
        }
    }
    
    /// Session types that are visible on the Watch picker (non-deleted AND visible)
    var visibleSessionTypes: [SessionTypeConfig] {
        sessionTypeConfigs.filter { !$0.isDeleted && $0.isVisible }
    }
    
    /// Session types shown in iOS settings UI (non-deleted only)
    var manageableSessionTypes: [SessionTypeConfig] {
        sessionTypeConfigs.filter { !$0.isDeleted }
    }
    
    /// Unique workout types from all visible session types
    /// Used by HealthKitImporter to filter claim portal
    var enabledWorkoutTypes: Set<String> {
        Set(visibleSessionTypes.map { $0.hkActivityTypeRaw })
    }
    
    /// Get the display name for a session type ID
    func sessionTypeName(for id: UUID?) -> String? {
        guard let id else { return nil }
        return sessionTypeConfigs.first { $0.id == id }?.name
    }
    
    /// Get the session type config for a given ID
    func sessionType(for id: UUID?) -> SessionTypeConfig? {
        guard let id else { return nil }
        return sessionTypeConfigs.first { $0.id == id }
    }
    
    /// Add a new custom session type with specified workout type
    func addCustomType(name: String, workoutType: String = "yoga") {
        var configs = sessionTypeConfigs
        configs.append(SessionTypeConfig.custom(name: name, hkActivityTypeRaw: workoutType))
        sessionTypeConfigs = configs
    }
    
    /// Soft delete a custom session type (no-op for defaults)
    func softDeleteCustomType(id: UUID) {
        var configs = sessionTypeConfigs
        guard let index = configs.firstIndex(where: { $0.id == id && !$0.isDefault }) else { return }
        configs[index].isDeleted = true
        sessionTypeConfigs = configs
    }
    
    /// Toggle visibility of a session type on the Watch
    func setVisibility(id: UUID, visible: Bool) {
        var configs = sessionTypeConfigs
        guard let index = configs.firstIndex(where: { $0.id == id }) else { return }
        configs[index].isVisible = visible
        sessionTypeConfigs = configs
    }
    
    // MARK: - WatchConnectivity Serialization
    
    /// Serialize settings for WatchConnectivity transfer
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "showCaloriesInApp": showCaloriesInApp,
            "showCaloriesOnWatch": showCaloriesOnWatch,
            "temperatureUnit": temperatureUnit.rawValue,
            "lastRoomTemperature": lastRoomTemperature
        ]
        
        if let configsData = try? JSONEncoder().encode(sessionTypeConfigs) {
            dict["sessionTypeConfigs"] = configsData
        }
        
        return dict
    }
    
    /// Apply settings received from WatchConnectivity
    func apply(from dict: [String: Any]) {
        if let showCaloriesInApp = dict["showCaloriesInApp"] as? Bool {
            self.showCaloriesInApp = showCaloriesInApp
        }
        if let showCaloriesOnWatch = dict["showCaloriesOnWatch"] as? Bool {
            self.showCaloriesOnWatch = showCaloriesOnWatch
        }
        if let tempUnitRaw = dict["temperatureUnit"] as? String,
           let unit = TemperatureUnit(rawValue: tempUnitRaw) {
            self.temperatureUnit = unit
        }
        if let lastTemp = dict["lastRoomTemperature"] as? Int {
            self.lastRoomTemperature = lastTemp
        }
        if let configsData = dict["sessionTypeConfigs"] as? Data,
           let configs = try? JSONDecoder().decode([SessionTypeConfig].self, from: configsData) {
            self.sessionTypeConfigs = configs
        }
    }
    
    init() {}
}

