//
//  HeatlabWatchApp.swift
//  HeatlabWatch
//
//  Heat Lab Watch App - Workout tracking companion
//  Local-first architecture: saves locally, syncs to iPhone via WatchConnectivity
//

import SwiftUI
import SwiftData

@main
struct HeatlabWatchApp: App {
    // Local-only container with OutboxItem for reliable sync
    let modelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            UserBaseline.self,
            OutboxItem.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Local only - syncs to iPhone via WatchConnectivity
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create Watch ModelContainer: \(error)")
        }
    }()
    
    @State private var workoutManager = WorkoutManager()
    @State private var userSettings = UserSettings()
    @State private var syncEngine = SyncEngine()
    @State private var subscriptionManager = SubscriptionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutManager)
                .environment(userSettings)
                .environment(syncEngine)
                .environment(subscriptionManager)
                .task {
                    // Check subscription status on app launch
                    // watchOS shares entitlements with iOS via same Apple ID
                    await subscriptionManager.start()
                }
                .onAppear {
                    // Configure WatchConnectivity relay with settings and modelContext
                    let modelContext = modelContainer.mainContext
                    WatchConnectivityRelay.shared.configure(settings: userSettings, modelContext: modelContext)
                }
        }
        .modelContainer(modelContainer)
    }
}
