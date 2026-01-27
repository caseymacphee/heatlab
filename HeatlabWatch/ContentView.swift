//
//  ContentView.swift
//  Heatlab Watch Watch App
//
//  Main navigation controller for the Watch app
//  Local-first: Always shows workout content, syncs opportunistically
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @Environment(WorkoutManager.self) var workoutManager
    @Environment(SyncEngine.self) var syncEngine
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        NavigationStack {
            // Always show workout content - never block on iCloud
            workoutContent
        }
        .task {
            // Initial sync attempt on launch
            await syncEngine.syncPending(from: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Opportunistic sync when app becomes active
                Task {
                    await syncEngine.syncPending(from: modelContext)
                }
            }
        }
    }
    
    @ViewBuilder
    private var workoutContent: some View {
        switch workoutManager.phase {
        case .idle, .starting:
            StartView()
        case .running, .paused, .ending:
            ActiveSessionView()
        case .completed:
            if let workout = workoutManager.completedWorkout {
                SessionConfirmationView(
                    workout: workout,
                    selectedSessionTypeId: workoutManager.selectedSessionTypeId
                ) {
                    workoutManager.reset()
                }
            } else {
                // Fallback if no workout (shouldn't happen)
                StartView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(WorkoutManager())
        .environment(SyncEngine())
}
