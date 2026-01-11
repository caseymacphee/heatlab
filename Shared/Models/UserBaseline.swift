//
//  UserBaseline.swift
//  heatlab
//
//  Tracks user's baseline heart rate per temperature bucket
//

import SwiftData
import Foundation

@Model
final class UserBaseline {
    var temperatureBucketRaw: String  // Store raw value for SwiftData compatibility
    var averageHR: Double
    var sessionCount: Int
    var lastUpdated: Date
    
    var temperatureBucket: TemperatureBucket {
        get { TemperatureBucket(rawValue: temperatureBucketRaw) ?? .hot }
        set { temperatureBucketRaw = newValue.rawValue }
    }
    
    init(temperatureBucket: TemperatureBucket, averageHR: Double, sessionCount: Int, lastUpdated: Date) {
        self.temperatureBucketRaw = temperatureBucket.rawValue
        self.averageHR = averageHR
        self.sessionCount = sessionCount
        self.lastUpdated = lastUpdated
    }
}

