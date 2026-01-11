//
//  HeatLabModelContainer.swift
//  heatlab
//
//  Shared SwiftData container configuration with CloudKit sync
//

import SwiftData
import Foundation

/// Creates the shared model container for both iOS and Watch apps
/// Configured to sync via CloudKit private database
func createSharedModelContainer() -> ModelContainer {
    let schema = Schema([
        HeatSession.self,
        UserBaseline.self
    ])
    
    let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .private("iCloud.com.macpheelabs.heatlab")
    )
    
    do {
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}

