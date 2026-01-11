//
//  ContentView.swift
//  Heatlab Watch Watch App
//
//  Main navigation controller for the Watch app
//

import SwiftUI
import HealthKit

struct ContentView: View {
    @Environment(WorkoutManager.self) var workoutManager
    @Environment(\.modelContext) var modelContext
    @State private var completedWorkout: HKWorkout?
    @State private var navigationState: NavigationState = .start
    
    enum NavigationState {
        case start
        case active
        case confirmation
    }
    
    var body: some View {
        NavigationStack {
            Group {
                switch navigationState {
                case .start:
                    StartView()
                case .active:
                    ActiveSessionView()
                case .confirmation:
                    if let workout = completedWorkout {
                        SessionConfirmationView(workout: workout) {
                            workoutManager.resetWorkout()
                            completedWorkout = nil
                            navigationState = .start
                        }
                    } else {
                        StartView()
                    }
                }
            }
        }
        .onChange(of: workoutManager.isActive) { _, isActive in
            if isActive {
                navigationState = .active
            }
        }
        .onChange(of: workoutManager.showingSummary) { _, showing in
            if showing {
                // Fetch the completed workout
                Task {
                    if let workout = try? await fetchLastWorkout() {
                        completedWorkout = workout
                        navigationState = .confirmation
                    }
                }
            }
        }
    }
    
    private func fetchLastWorkout() async throws -> HKWorkout? {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForWorkouts(with: .yoga)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples?.first as? HKWorkout)
            }
            workoutManager.healthStore.execute(query)
        }
    }
}

#Preview {
    ContentView()
        .environment(WorkoutManager())
}
