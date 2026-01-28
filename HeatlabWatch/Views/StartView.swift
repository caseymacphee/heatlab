//
//  StartView.swift
//  Heatlab Watch Watch App
//
//  Initial view to start a workout session
//  Session type selection determines the HKWorkoutActivityType
//

import SwiftUI
import HealthKit

struct StartView: View {
    @Environment(WorkoutManager.self) var workoutManager
    @Environment(UserSettings.self) var settings
    
    @State private var selectedTypeId: UUID?
    
    /// Visible session types from settings
    private var visibleTypes: [SessionTypeConfig] {
        settings.visibleSessionTypes
    }
    
    /// The currently selected session type config
    private var selectedType: SessionTypeConfig? {
        guard let id = selectedTypeId else { return nil }
        return visibleTypes.first { $0.id == id }
    }
    
    /// Convert raw string to HKWorkoutActivityType
    private func hkActivityType(for raw: String) -> HKWorkoutActivityType {
        switch raw {
        case "yoga": return .yoga
        case "pilates": return .pilates
        case "barre": return .barre
        default: return .yoga
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Session type picker (if there are visible types)
                if !visibleTypes.isEmpty {
                    HStack(spacing: 6) {
                        Text("Session Type")
                            .font(.headline)
                            .foregroundStyle(Color.hlMuted)  
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(visibleTypes) { typeConfig in
                            SessionTypeButton(
                                name: typeConfig.name,
                                isSelected: selectedTypeId == typeConfig.id,
                                action: {
                                    // Toggle selection
                                    selectedTypeId = selectedTypeId == typeConfig.id ? nil : typeConfig.id
                                }
                            )
                        }
                    }

                    Text("Edit session types in iPhone Settings")
                        .font(.caption2)
                        .foregroundStyle(Color.hlMuted.opacity(0.7))
                }
                
                // Start button
                Button {
                    startWorkout()
                } label: {
                    HStack {
                        ZStack {
                            // Fixed width container for icon/spinner
                            Image(systemName: SFSymbol.playFill)
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
                .tint(.accentColor)
                .disabled(workoutManager.phase != .idle)
                .padding(.top, 8)
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
    }
    
    private func startWorkout() {
        print("👆 startWorkout() tapped, selectedTypeId: \(String(describing: selectedTypeId))")
        
        // Determine the HKWorkoutActivityType based on selection
        let activityType: HKWorkoutActivityType
        if let selected = selectedType {
            activityType = hkActivityType(for: selected.hkActivityTypeRaw)
            print("👆 using session type '\(selected.name)' -> \(activityType.rawValue)")
        } else {
            activityType = .yoga  // Default to yoga if no type selected
            print("👆 no session type selected, defaulting to yoga")
        }
        
        // Store the selected type ID for the confirmation view
        workoutManager.selectedSessionTypeId = selectedTypeId
        
        Task { @MainActor in
            do {
                print("👆 calling requestAuthorization...")
                try await workoutManager.requestAuthorization()
                print("👆 calling start(activityType: \(activityType.rawValue))...")
                try await workoutManager.start(activityType: activityType)
                print("👆 start() completed successfully")
            } catch {
                print("❌ Failed to start workout: \(error)")
            }
        }
    }
}

// Helper view for session type selection buttons
private struct SessionTypeButton: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                }
                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.hlAccent : Color.gray.opacity(0.3))
            .foregroundStyle(isSelected ? .white : .gray)
            .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    StartView()
        .environment(WorkoutManager())
        .environment(UserSettings())
}
