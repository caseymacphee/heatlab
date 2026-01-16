//
//  StartView.swift
//  Heatlab Watch Watch App
//
//  Initial view to start a workout session
//

import SwiftUI

struct StartView: View {
    @Environment(WorkoutManager.self) var workoutManager
    
    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            
            // App icon/branding
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Heatlab")
                .font(.title3.bold())
            
            Text("Track your Practice")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Spacer(minLength: 0)
            
            Button {
                startWorkout()
            } label: {
                HStack {
                    ZStack {
                        // Fixed width container for icon/spinner
                        Image(systemName: "play.fill")
                            .opacity(workoutManager.phase == .starting ? 0 : 1)
                        
                        if workoutManager.phase == .starting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    Text("Start Session")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(workoutManager.phase != .idle)
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
    
    private func startWorkout() {
        print("👆 startWorkout() tapped")
        Task { @MainActor in
            do {
                print("👆 calling requestAuthorization...")
                try await workoutManager.requestAuthorization()
                print("👆 calling start()...")
                try await workoutManager.start()
                print("👆 start() completed successfully")
            } catch {
                print("❌ Failed to start workout: \(error)")
            }
        }
    }
}

#Preview {
    StartView()
        .environment(WorkoutManager())
}
