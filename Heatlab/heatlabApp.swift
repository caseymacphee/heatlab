//
//  heatlabApp.swift
//  heatlab
//
//  Heat Lab - Heat Training Tracking App
//  iOS is read-only: pulls synced data from CloudKit, never writes to Watch-owned records
//  Also receives fast-lane sync via WatchConnectivity when Watch is reachable
//

import SwiftUI
import SwiftData

@main
struct heatlabApp: App {
    // iOS uses CloudKit-enabled container for automatic pull sync
    // Defined inline to keep platform-specific models explicit
    let modelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            UserBaseline.self,
            SessionTypeBaseline.self,  // Class-type baselines (e.g., Vinyasa, Pilates)
            ImportedWorkout.self  // iOS-only: tracks dismissed Apple Health workouts
        ])
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
    }()
    @State private var userSettings = UserSettings()
    @State private var cloudKitStatus = CloudKitStatus()
    @State private var subscriptionManager = SubscriptionManager()
    
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
                .tint(.hlAccent)
                .environment(userSettings)
                .environment(cloudKitStatus)
                .environment(subscriptionManager)
                .environmentObject(wcReceiver)
                .task {
                    // Initialize subscription manager on app launch
                    await subscriptionManager.start()
                }
                .onAppear {
                    // Send current settings to Watch when app opens
                    wcReceiver.sendSettingsToWatch(userSettings)
                }
        }
        .modelContainer(modelContainer)
    }
}
