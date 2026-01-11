//
//  Heatlab_WatchApp.swift
//  Heatlab Watch Watch App
//
//  Heat Lab Watch App - Workout tracking companion
//

import SwiftUI
import SwiftData

@main
struct Heatlab_Watch_Watch_AppApp: App {
    let sharedModelContainer = createSharedModelContainer()
    @State private var workoutManager = WorkoutManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(workoutManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
