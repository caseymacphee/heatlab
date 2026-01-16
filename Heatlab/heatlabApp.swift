//
//  heatlabApp.swift
//  heatlab
//
//  Heat Lab - Hot Yoga Tracking App
//  iOS is read-only: pulls synced data from CloudKit, never writes to Watch-owned records
//  Also receives fast-lane sync via WatchConnectivity when Watch is reachable
//

import SwiftUI
import SwiftData

@main
struct heatlabApp: App {
    // iOS uses CloudKit-enabled container for automatic pull sync
    let modelContainer = createiOSModelContainer()
    @State private var userSettings = UserSettings()
    @State private var cloudKitStatus = CloudKitStatus()
    
    // WatchConnectivity receiver for fast-lane sync from Watch
    @StateObject private var wcReceiver = WatchConnectivityReceiver.shared
    
    init() {
        // Configure WatchConnectivity receiver with model context
        let context = modelContainer.mainContext
        WatchConnectivityReceiver.shared.configure(modelContext: context)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(userSettings)
                .environment(cloudKitStatus)
                .environmentObject(wcReceiver)
                .onAppear {
                    // Send current settings to Watch when app opens
                    wcReceiver.sendSettingsToWatch(userSettings)
                }
        }
        .modelContainer(modelContainer)
    }
}
