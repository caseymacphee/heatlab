//
//  ActiveSessionView.swift
//  Heatlab Watch Watch App
//
//  Displays live workout metrics during a session
//  Supports vertical paging: swipe up for heart rate chart
//

import SwiftUI

struct ActiveSessionView: View {
    @Environment(WorkoutManager.self) var workoutManager
    @Environment(UserSettings.self) var settings
    @State private var showingEndConfirmation = false
    @State private var selectedPage = 0
    @State private var pausedLabelOpacity: Double = 1.0

    private var isPaused: Bool {
        workoutManager.phase == .paused
    }

    private var isEnding: Bool {
        workoutManager.phase == .ending
    }

    var body: some View {
        TabView(selection: $selectedPage) {
            // Page 1: Metrics & Controls
            metricsPage
                .tag(0)

            // Page 2: Heart Rate Chart
            chartPage
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
        .confirmationDialog("End Session?", isPresented: $showingEndConfirmation) {
            Button("End", role: .destructive) {
                endWorkout()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Metrics Page

    private var metricsPage: some View {
        VStack(spacing: 8) {
            // Paused indicator
            if isPaused {
                Text("PAUSED")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.yellow)
                    .opacity(pausedLabelOpacity)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pausedLabelOpacity = 0.4
                        }
                    }
                    .onDisappear {
                        pausedLabelOpacity = 1.0
                    }
            }

            // Elapsed Time
            Text(formatElapsedTime(workoutManager.elapsedTime))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(isPaused ? .yellow : .white)
                .monospacedDigit()
                .opacity(isPaused ? 0.7 : 1.0)

            // Metrics row
            HStack(spacing: 20) {
                // Heart Rate
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: SFSymbol.heartFill)
                            .foregroundStyle(Color.HeatLab.heartRate)
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
                            Image(systemName: SFSymbol.fireFill)
                                .foregroundStyle(Color.HeatLab.calories)
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
                    Image(systemName: isPaused ? SFSymbol.playFill : SFSymbol.pauseFill)
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
                        Image(systemName: SFSymbol.stopFill)
                            .font(.title3)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(isEnding)
            }

            // Page indicator hint
            Image(systemName: "chevron.compact.down")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding()
    }

    // MARK: - Chart Page

    private var chartPage: some View {
        VStack(spacing: 8) {
            // Page indicator hint
            Image(systemName: "chevron.compact.up")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // Current HR display
            HStack(spacing: 4) {
                Image(systemName: SFSymbol.heartFill)
                    .foregroundStyle(Color.HeatLab.heartRate)
                Text(workoutManager.heartRate > 0 ? "\(Int(workoutManager.heartRate))" : "--")
                    .font(.title2.bold())
                Text("BPM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Heart Rate Chart
            WatchHeartRateChartView(
                dataPoints: workoutManager.hrHistory
            )
            .frame(height: 100)
            .padding(.horizontal, 4)

            // Stats row
            HStack(spacing: 16) {
                if let avgHR = averageHR {
                    VStack(spacing: 2) {
                        Text("\(Int(avgHR))")
                            .font(.caption.bold())
                        Text("Avg")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                if let maxHR = maxHR {
                    VStack(spacing: 2) {
                        Text("\(Int(maxHR))")
                            .font(.caption.bold())
                        Text("Max")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Computed Properties

    private var averageHR: Double? {
        guard !workoutManager.hrHistory.isEmpty else { return nil }
        let sum = workoutManager.hrHistory.reduce(0) { $0 + $1.heartRate }
        return sum / Double(workoutManager.hrHistory.count)
    }

    private var maxHR: Double? {
        workoutManager.hrHistory.map { $0.heartRate }.max()
    }

    // MARK: - Helpers

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
