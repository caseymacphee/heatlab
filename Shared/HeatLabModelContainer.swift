//
//  HeatLabModelContainer.swift
//  heatlab
//
//  Shared CloudKit configuration
//  Note: Model containers are defined inline in each app's entry point
//  (HeatlabApp.swift for iOS, HeatlabWatchApp.swift for watchOS)
//  to keep platform-specific models explicit.
//

import Foundation

// MARK: - CloudKit Configuration

/// CloudKit container identifier for iOS automatic sync
enum CloudKitConfig {
    static let containerID = "iCloud.com.macpheelabs.heatlab"
}


