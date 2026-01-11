//
//  ActiveSessionView.swift
//  Heatlab Watch Watch App
//
//  Displays live workout metrics during a session
//

import SwiftUI

struct ActiveSessionView: View {
    @Environment(WorkoutManager.self) var workoutManager
    @State private var showingEndConfirmation = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Elapsed Time
            Text(formatElapsedTime(workoutManager.elapsedTime))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            
            // Metrics Row
            HStack(spacing: 20) {
                // Heart Rate
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("\(Int(workoutManager.heartRate))")
                            .font(.title3.bold())
                    }
                    Text("BPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // Calories
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(Int(workoutManager.activeCalories))")
                            .font(.title3.bold())
                    }
                    Text("CAL")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Control Buttons
            HStack(spacing: 16) {
                // Pause/Resume Button
                Button {
                    if workoutManager.isPaused {
                        workoutManager.resume()
                    } else {
                        workoutManager.pause()
                    }
                } label: {
                    Image(systemName: workoutManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .tint(workoutManager.isPaused ? .green : .yellow)
                
                // End Button
                Button {
                    showingEndConfirmation = true
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .confirmationDialog("End Session?", isPresented: $showingEndConfirmation) {
            Button("End Session", role: .destructive) {
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
                _ = try await workoutManager.endWorkout()
            } catch {
                print("Failed to end workout: \(error)")
            }
        }
    }
}

#Preview {
    ActiveSessionView()
        .environment(WorkoutManager())
}

