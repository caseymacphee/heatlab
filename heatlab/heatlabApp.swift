//
//  heatlabApp.swift
//  heatlab
//
//  Heat Lab - Hot Yoga Tracking App
//

import SwiftUI
import SwiftData

@main
struct heatlabApp: App {
    let sharedModelContainer = createSharedModelContainer()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
