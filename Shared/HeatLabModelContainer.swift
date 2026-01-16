//
//  HeatLabModelContainer.swift
//  heatlab
//
//  Platform-specific SwiftData container configuration
//  Watch: Local-only (source of truth for writes, manual CloudKit sync)
//  iOS: CloudKit-enabled (pull-only, receives synced data)
//

import SwiftData
import Foundation

// MARK: - CloudKit Configuration

/// CloudKit-related constants
enum CloudKitConfig {
    static let containerID = "iCloud.com.macpheelabs.heatlab"
    
    /// Record type names (must match CloudKit schema)
    enum RecordType {
        static let session = "HeatSession"
        static let baseline = "UserBaseline"
    }
}

// MARK: - Schema

/// Creates the shared schema for all models
private func createSchema() -> Schema {
    Schema([
        HeatSession.self,
        UserBaseline.self
    ])
}

// MARK: - Watch Model Container (Local-Only)

/// Creates the Watch model container with local-only storage
/// The Watch is the single writer - it saves locally first, then syncs to CloudKit via SyncEngine
func createWatchModelContainer() -> ModelContainer {
    let schema = createSchema()
    let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none  // LOCAL ONLY - SyncEngine handles CloudKit manually
    )
    
    do {
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Could not create Watch ModelContainer: \(error)")
    }
}

// MARK: - iOS Model Container (CloudKit Pull)

/// Creates the iOS model container with CloudKit sync enabled
/// iOS is read-only - it pulls data from CloudKit but never writes to records the Watch owns
func createiOSModelContainer() -> ModelContainer {
    let schema = createSchema()
    let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .private(CloudKitConfig.containerID)
    )
    
    do {
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Could not create iOS ModelContainer: \(error)")
    }
}


