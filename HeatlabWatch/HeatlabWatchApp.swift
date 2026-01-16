//
//  HeatlabWatchApp.swift
//  HeatlabWatch
//
//  Heat Lab Watch App - Workout tracking companion
//  Local-first architecture: saves locally, syncs opportunistically to CloudKit
//

import SwiftUI
import SwiftData

@main
struct HeatlabWatchApp: App {
    // Local-only container - Watch is source of truth, syncs via SyncEngine
    let modelContainer = createWatchModelContainer()
    @State private var workoutManager = WorkoutManager()
    @State private var userSettings = UserSettings()
    @State private var syncEngine = SyncEngine()
    
    init() {
        // Configure WatchConnectivity relay to receive settings from iPhone
        WatchConnectivityRelay.shared.configure(settings: userSettings)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutManager)
                .environment(userSettings)
                .environment(syncEngine)
        }
        .modelContainer(modelContainer)
    }
}
