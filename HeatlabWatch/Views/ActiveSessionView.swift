//
//  ActiveSessionView.swift
//  Heatlab Watch Watch App
//
//  Displays live workout metrics during a session
//

import SwiftUI

struct ActiveSessionView: View {
    @Environment(WorkoutManager.self) var workoutManager
    @Environment(UserSettings.self) var settings
    @State private var showingEndConfirmation = false
    
    private var isPaused: Bool {
        workoutManager.phase == .paused
    }
    
    private var isEnding: Bool {
        workoutManager.phase == .ending
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Elapsed Time
            Text(formatElapsedTime(workoutManager.elapsedTime))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            
            // Metrics row
            HStack(spacing: 20) {
                // Heart Rate
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(icon: .heart)
                            .foregroundStyle(.red)
                        Text(workoutManager.heartRate > 0 ? "\(Int(workoutManager.heartRate))" : "--")
                            .font(.title3.bold())
                    }
                    Text("BPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Calories (if enabled)
                if settings.showCaloriesOnWatch {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(icon: .fire)
                                .foregroundStyle(.orange)
                            Text(workoutManager.activeCalories > 0 ? "\(Int(workoutManager.activeCalories))" : "--")
                                .font(.title3.bold())
                        }
                        Text("Cal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Control Buttons
            HStack(spacing: 16) {
                // Pause/Resume Button
                Button {
                    if isPaused {
                        workoutManager.resume()
                    } else {
                        workoutManager.pause()
                    }
                } label: {
                    Image(icon: isPaused ? .playCircle : .pauseCircle)
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .tint(isPaused ? .green : .yellow)
                .disabled(isEnding)

                // End Button
                Button {
                    showingEndConfirmation = true
                } label: {
                    if isEnding {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(icon: .stopCircle)
                            .font(.title3)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(isEnding)
            }
        }
        .padding()
        .confirmationDialog("End Session?", isPresented: $showingEndConfirmation) {
            Button("End", role: .destructive) {
                endWorkout()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private func formatElapsedTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func endWorkout() {
        Task {
            do {
                try await workoutManager.end()
            } catch {
                print("Failed to end workout: \(error)")
            }
        }
    }
}

#Preview {
    ActiveSessionView()
        .environment(WorkoutManager())
        .environment(UserSettings())
}
