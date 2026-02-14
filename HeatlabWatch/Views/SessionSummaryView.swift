//
//  SessionSummaryView.swift
//  Heatlab Watch Watch App
//
//  Post-workout summary with stats, streak, affirmation, and peak zone
//  Shown after session confirmation save animation completes
//

import SwiftUI
import HealthKit

struct SessionSummaryView: View {
    @Environment(UserSettings.self) var settings

    let session: WorkoutSession
    let workout: HKWorkout
    let sessionTypeName: String
    let streak: Int
    let monthlySessionCount: Int
    let onDone: () -> Void

    @State private var canDismiss = false

    private var avgHR: Int? {
        guard let avg = workout.statistics(for: HKQuantityType(.heartRate))?
            .averageQuantity()?
            .doubleValue(for: HKUnit.count().unitDivided(by: .minute())) else { return nil }
        return Int(avg)
    }

    private var maxHR: Int? {
        guard let max = workout.statistics(for: HKQuantityType(.heartRate))?
            .maximumQuantity()?
            .doubleValue(for: HKUnit.count().unitDivided(by: .minute())) else { return nil }
        return Int(max)
    }

    private var calories: Int? {
        guard let cal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie()) else { return nil }
        return Int(cal)
    }

    /// Peak zone reached (if max HR setting is available)
    private var peakZone: HeartRateZone? {
        guard let maxHRSetting = settings.estimatedMaxHR,
              let sessionMaxHR = maxHR else { return nil }
        return HeartRateZone.zone(for: Double(sessionMaxHR), maxHR: maxHRSetting)
    }

    /// Random affirmation from curated list
    private var affirmation: String {
        SessionSummaryView.affirmations.randomElement() ?? "Great work."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.hlAccent)

                Text("Session Complete")
                    .font(.headline)
                    .foregroundStyle(Color.watchTextPrimary)

                Text(sessionTypeName)
                    .font(.subheadline)
                    .foregroundStyle(Color.watchTextSecondary)

                // Stats grid
                HStack(spacing: 16) {
                    VStack {
                        Text(formatDuration(workout.duration))
                            .font(.title3.bold())
                            .foregroundStyle(Color.watchTextPrimary)
                        Text("Duration")
                            .font(.caption2)
                            .foregroundStyle(Color.watchTextSecondary)
                    }

                    if let avgHR {
                        VStack {
                            HStack(spacing: 2) {
                                Image(systemName: SFSymbol.heartFill)
                                    .foregroundStyle(Color.HeatLab.heartRate)
                                    .font(.caption)
                                Text("\(avgHR)")
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.watchTextPrimary)
                            }
                            Text("Avg BPM")
                                .font(.caption2)
                                .foregroundStyle(Color.watchTextSecondary)
                        }
                    }

                    if settings.showCaloriesOnWatch, let calories {
                        VStack {
                            HStack(spacing: 2) {
                                Image(systemName: SFSymbol.fireFill)
                                    .foregroundStyle(Color.HeatLab.calories)
                                    .font(.caption)
                                Text("\(calories)")
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.watchTextPrimary)
                            }
                            Text("Cal")
                                .font(.caption2)
                                .foregroundStyle(Color.watchTextSecondary)
                        }
                    }
                }
                .padding(.vertical, 4)

                // Temperature
                if let temp = session.roomTemperature {
                    let display = Temperature(fahrenheit: temp)
                    Text("\(display.value(for: settings.temperatureUnit))\(settings.temperatureUnit.rawValue)")
                        .font(.caption.bold())
                        .foregroundStyle(Color.HeatLab.temperature(fahrenheit: temp))
                }

                Divider()

                // Peak zone
                if let zone = peakZone {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(zone.color)
                        Text("Peak: \(zone.label)")
                            .font(.caption)
                            .foregroundStyle(Color.watchTextSecondary)
                    }
                }

                // Affirmation
                Text(affirmation)
                    .font(.caption)
                    .foregroundStyle(Color.watchTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)

                // Streak badge
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: SFSymbol.fireFill)
                            .font(.caption2)
                            .foregroundStyle(Color.hlAccent)
                        Text("\(streak)-week streak")
                            .font(.caption.bold())
                            .foregroundStyle(Color.hlAccent)
                    }
                    .padding(.vertical, 4)
                }

                // Monthly count
                if monthlySessionCount > 1 {
                    Text("That's \(monthlySessionCount) sessions this month. Keep building.")
                        .font(.caption2)
                        .foregroundStyle(Color.watchTextTertiary)
                        .multilineTextAlignment(.center)
                }

                // Done button
                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.hlAccent.opacity(0.85))
                .disabled(!canDismiss)
                .padding(.top, 8)
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .seconds(3))
                canDismiss = true
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Affirmations

    static let affirmations = [
        "Strong session! Your body is adapting.",
        "Another heat session in the books.",
        "Consistency is the key \u{2014} keep showing up.",
        "Your cardiovascular system thanks you.",
        "Building heat resilience, one session at a time.",
        "Great work. Recovery starts now.",
        "You showed up. That's what matters.",
        "Heat adaptation is a practice \u{2014} you're practicing.",
        "Sweat is your body's superpower.",
        "Every session makes you more resilient."
    ]
}

#Preview {
    Text("Session Summary Preview")
}
