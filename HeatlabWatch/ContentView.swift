//
//  ContentView.swift
//  Heatlab Watch Watch App
//
//  Main navigation controller for the Watch app
//  Local-first: Always shows workout content, syncs opportunistically
//

import SwiftUI
import SwiftData
import HealthKit

struct ContentView: View {
    @Environment(WorkoutManager.self) var workoutManager
    @Environment(SyncEngine.self) var syncEngine
    @Environment(UserSettings.self) var settings
    @Environment(\.modelContext) var modelContext
    @Environment(\.scenePhase) var scenePhase

    @State private var summarySession: WorkoutSession?

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
            if let session = summarySession, let workout = workoutManager.completedWorkout {
                // Show post-workout summary after confirmation save
                let allSessions = fetchLocalSessions()
                let typeName = settings.sessionTypeName(for: session.sessionTypeId) ?? session.workoutTypeDisplayName
                SessionSummaryView(
                    session: session,
                    workout: workout,
                    sessionTypeName: typeName,
                    streak: StreakTracker.currentStreak(from: allSessions),
                    monthlySessionCount: StreakTracker.sessionsThisMonth(from: allSessions)
                ) {
                    summarySession = nil
                    workoutManager.reset()
                }
            } else if let workout = workoutManager.completedWorkout {
                SessionConfirmationView(
                    workout: workout,
                    selectedSessionTypeId: workoutManager.selectedSessionTypeId
                ) { session in
                    summarySession = session
                }
            } else {
                // Fallback if no workout (shouldn't happen)
                StartView()
            }
        }
    }

    /// Fetch all local sessions for streak computation (lightweight, no HealthKit)
    private func fetchLocalSessions() -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

#Preview {
    ContentView()
        .environment(WorkoutManager())
        .environment(SyncEngine())
}
