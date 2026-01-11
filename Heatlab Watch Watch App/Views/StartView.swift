//
//  StartView.swift
//  Heatlab Watch Watch App
//
//  Initial view to start a workout session
//

import SwiftUI

struct StartView: View {
    @Environment(WorkoutManager.self) var workoutManager
    @State private var isStarting = false
    
    var body: some View {
        VStack(spacing: 20) {
            // App icon/branding
            Image(systemName: "flame.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Heat Lab")
                .font(.title2.bold())
            
            Text("Hot Yoga Tracking")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button {
                startWorkout()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Session")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isStarting)
        }
        .padding()
    }
    
    private func startWorkout() {
        isStarting = true
        Task {
            do {
                try await workoutManager.requestAuthorization()
                try await workoutManager.startWorkout()
            } catch {
                print("Failed to start workout: \(error)")
            }
            isStarting = false
        }
    }
}

#Preview {
    StartView()
        .environment(WorkoutManager())
}

