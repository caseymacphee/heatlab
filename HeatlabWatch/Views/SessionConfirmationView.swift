//
//  SessionConfirmationView.swift
//  Heatlab Watch Watch App
//
//  Post-workout view to capture room temperature and effort
//  Session type is pre-selected in StartView before the workout
//  Local-first: Session saves immediately, sync happens in background
//

import SwiftUI
import SwiftData
import HealthKit
import WatchKit

struct SessionConfirmationView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(UserSettings.self) var settings
    @Environment(SyncEngine.self) var syncEngine
    @State private var isHeated: Bool = true  // Default to heated session
    @State private var temperatureInput: Int = 95
    @State private var selectedEffort: PerceivedEffort = .moderate
    @State private var isSaving = false
    @State private var showSavedAnimation = false
    @Namespace private var temperatureDialNamespace
    
    let workout: HKWorkout
    let selectedSessionTypeId: UUID?  // Pre-selected in StartView
    let onComplete: () -> Void

    /// Display name: session type name if selected, otherwise workout type in title case
    private var sessionTypeDisplayName: String {
        if let typeId = selectedSessionTypeId,
           let typeName = settings.sessionTypeName(for: typeId) {
            return typeName
        }
        // Fallback to workout activity type in title case
        return workout.workoutActivityType.displayName
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                Text("Session Complete")
                    .font(.headline)
                    .foregroundStyle(Color.hlAccent)

                Text(sessionTypeDisplayName)
                    .font(.subheadline)
                    .foregroundStyle(Color.watchTextSecondary)

                // Summary stats
                HStack(spacing: 16) {
                    VStack {
                        Text(formatDuration(workout.duration))
                            .font(.title3.bold())
                            .foregroundStyle(Color.watchTextPrimary)
                        Text("Duration")
                            .font(.caption2)
                            .foregroundStyle(Color.watchTextSecondary)
                    }

                    if let avgHR = workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                        VStack {
                            HStack(spacing: 2) {
                                Image(systemName: SFSymbol.heartFill)
                                    .foregroundStyle(Color.HeatLab.heartRate)
                                    .font(.caption)
                                Text("\(Int(avgHR))")
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.watchTextPrimary)
                            }
                            Text("Avg BPM")
                                .font(.caption2)
                                .foregroundStyle(Color.watchTextSecondary)
                        }
                    }

                    // Show calories if enabled
                    if settings.showCaloriesOnWatch,
                       let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        VStack {
                            HStack(spacing: 2) {
                                Image(systemName: SFSymbol.fireFill)
                                    .foregroundStyle(Color.HeatLab.calories)
                                    .font(.caption)
                                Text("\(Int(calories))")
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.watchTextPrimary)
                            }
                            Text("Cal")
                                .font(.caption2)
                                .foregroundStyle(Color.watchTextSecondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Heated Session Toggle
                Toggle("Heated Session", isOn: $isHeated)
                    .tint(Color.hlAccent)
                
                // Temperature Dial (only shown when heated)
                if isHeated {
                    Divider()

                    Text("Temperature")
                        .font(.caption)
                        .foregroundStyle(Color.watchTextSecondary)
                    
                    TemperatureDialView(temperature: $temperatureInput, unit: settings.temperatureUnit)
                        .frame(height: 100)
                        .padding(.bottom, 20)
                        .prefersDefaultFocus(in: temperatureDialNamespace)
                }
                
                Divider()

                // Perceived Effort - Wheel Picker
                Text("Perceived Effort")
                    .font(.caption)
                    .foregroundStyle(Color.watchTextSecondary)

                EffortWheelPicker(selection: $selectedEffort)
                    .frame(height: 44)

                // Save Button
                Button {
                    saveSession()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isSaving ? "Saving..." : "Save Session")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.hlAccent.opacity(0.85))
                .disabled(isSaving)
                .padding(.top, 8)
            }
            .padding(.horizontal, 4)
        }
        .focusScope(temperatureDialNamespace)
        .onAppear {
            // Initialize with last used temperature or default for unit
            temperatureInput = settings.lastRoomTemperature
        }
        .overlay {
            if showSavedAnimation {
                SavedAnimationOverlay {
                    onComplete()
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func saveSession() {
        guard !isSaving else { return }  // Prevent double-tap
        isSaving = true
        
        // Determine temperature based on heated selection (nil = unheated)
        let roomTemperature: Int? = isHeated
            ? Temperature.fromUserInput(temperatureInput, unit: settings.temperatureUnit).fahrenheit
            : nil
        
        // Create session with pending sync state
        // workoutUUID is now required - it's the unique key for upserts
        let session = WorkoutSession(workoutUUID: workout.uuid, startDate: workout.startDate, roomTemperature: roomTemperature)
        session.endDate = workout.endDate
        session.sessionTypeId = selectedSessionTypeId  // Pre-selected in StartView
        session.perceivedEffort = selectedEffort
        // Set workout type from session type config (or fallback to yoga)
        if let sessionTypeId = selectedSessionTypeId,
           let sessionType = settings.sessionType(for: sessionTypeId) {
            session.workoutTypeRaw = sessionType.hkActivityTypeRaw
        }
        // syncState is .pending by default - ready for background sync
        
        modelContext.insert(session)
        
        do {
            try modelContext.save()
            // Remember temperature for next session (only if heated)
            if isHeated {
                settings.lastRoomTemperature = temperatureInput
            }

            // Trigger background sync (fire and forget - don't block exit)
            Task {
                await syncEngine.syncPending(from: modelContext)
            }

            // Show saved animation, then exit
            withAnimation(.easeOut(duration: 0.3)) {
                showSavedAnimation = true
            }
        } catch {
            print("Failed to save session: \(error)")
            isSaving = false  // Re-enable button only on error so user can retry
        }
    }
}

// Circular wheel picker - tap left/right sides to cycle, wraps around
private struct EffortWheelPicker: View {
    @Binding var selection: PerceivedEffort

    // Exclude .none since users wouldn't navigate here just to skip rating
    private let efforts = PerceivedEffort.allCases.filter { $0 != .none }

    private var currentIndex: Int {
        efforts.firstIndex(of: selection) ?? 2  // Default to moderate
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left tap zone - go previous
            Button {
                let newIndex = wrappedIndex(currentIndex - 1)
                WKInterfaceDevice.current().play(.click)
                withAnimation(.easeInOut(duration: 0.15)) {
                    selection = efforts[newIndex]
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.caption2)
                    Text(efforts[wrappedIndex(currentIndex - 1)].shortName)
                        .font(.caption2)
                }
                .foregroundStyle(Color.watchTextSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Center - current selection
            Text(selection.shortName)
                .font(.caption.bold())
                .foregroundStyle(Color.watchTextPrimary)
                .frame(width: 56, height: 36)
                .background(Color.hlAccent.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Right tap zone - go next
            Button {
                let newIndex = wrappedIndex(currentIndex + 1)
                WKInterfaceDevice.current().play(.click)
                withAnimation(.easeInOut(duration: 0.15)) {
                    selection = efforts[newIndex]
                }
            } label: {
                HStack(spacing: 4) {
                    Text(efforts[wrappedIndex(currentIndex + 1)].shortName)
                        .font(.caption2)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(Color.watchTextSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func wrappedIndex(_ index: Int) -> Int {
        let count = efforts.count
        return ((index % count) + count) % count
    }
}

// Animated checkmark overlay shown after saving
private struct SavedAnimationOverlay: View {
    let onDismiss: () -> Void

    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkOpacity: Double = 0
    @State private var ringProgress: CGFloat = 0

    var body: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ZStack {
                    // Animated ring
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(Color.hlAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    // Checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Color.hlAccent)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                }

                Text("Saved")
                    .font(.headline)
                    .foregroundStyle(Color.watchTextPrimary)
                    .opacity(checkmarkOpacity)
            }
        }
        .onAppear {
            // Ring draws first
            withAnimation(.easeOut(duration: 0.4)) {
                ringProgress = 1.0
            }

            // Checkmark pops in after ring completes
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.35)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }

            // Haptic feedback
            WKInterfaceDevice.current().play(.success)

            // Auto-dismiss after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                onDismiss()
            }
        }
    }
}

// MARK: - HKWorkoutActivityType Display Name

private extension HKWorkoutActivityType {
    /// Title case display name for common workout types
    var displayName: String {
        switch self {
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .barre: return "Barre"
        case .mindAndBody: return "Mind & Body"
        default: return "Workout"
        }
    }
}

#Preview {
    // Note: Cannot preview with HKWorkout directly
    Text("Session Confirmation Preview")
}
