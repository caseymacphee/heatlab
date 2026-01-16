//
//  SessionConfirmationView.swift
//  Heatlab Watch Watch App
//
//  Post-workout view to capture room temperature and class type
//  Local-first: Session saves immediately, sync happens in background
//

import SwiftUI
import SwiftData
import HealthKit

struct SessionConfirmationView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(UserSettings.self) var settings
    @Environment(SyncEngine.self) var syncEngine
    @State private var temperatureInput: Int = 95
    @State private var selectedTypeId: UUID?
    @State private var isSaving = false
    @Namespace private var temperatureDialNamespace
    
    let workout: HKWorkout
    let onComplete: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                Text("Session Complete")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.6, green: 0.75, blue: 0.55))
                
                // Summary stats
                HStack(spacing: 16) {
                    VStack {
                        Text(formatDuration(workout.duration))
                            .font(.title3.bold())
                        Text("Duration")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let avgHR = workout.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) {
                        VStack {
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                                Text("\(Int(avgHR))")
                                    .font(.title3.bold())
                            }
                            Text("Avg BPM")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Show calories if enabled
                    if settings.showCaloriesOnWatch,
                       let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        VStack {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text("\(Int(calories))")
                                    .font(.title3.bold())
                            }
                            Text("Cal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Temperature Dial (Digital Crown controlled)
                Text("Room Temperature")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TemperatureDialView(temperature: $temperatureInput, unit: settings.temperatureUnit)
                    .frame(height: 100)
                    .prefersDefaultFocus(in: temperatureDialNamespace)
                    .padding(.bottom, 8)
                
                Divider()
                
                // Session Type (Optional) - Compact grid
                if !settings.visibleSessionTypes.isEmpty {
                    Text("Session Type (Optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(settings.visibleSessionTypes) { typeConfig in
                            SessionTypeButton(
                                name: typeConfig.name,
                                isSelected: selectedTypeId == typeConfig.id,
                                action: {
                                    selectedTypeId = selectedTypeId == typeConfig.id ? nil : typeConfig.id
                                }
                            )
                        }
                    }
                }
                
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
                .tint(Color(red: 0.6, green: 0.75, blue: 0.55))
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
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func saveSession() {
        guard !isSaving else { return }  // Prevent double-tap
        isSaving = true
        
        // Convert user input to Fahrenheit for storage
        let temp = Temperature.fromUserInput(temperatureInput, unit: settings.temperatureUnit)
        
        // Create session with pending sync state
        let session = HeatSession(startDate: workout.startDate, roomTemperature: temp.fahrenheit)
        session.endDate = workout.endDate
        session.workoutUUID = workout.uuid
        session.sessionTypeId = selectedTypeId
        // syncState is .pending by default - ready for background sync
        
        modelContext.insert(session)
        
        do {
            try modelContext.save()
            // Remember temperature for next session
            settings.lastRoomTemperature = temperatureInput
            
            // Trigger background sync (fire and forget - don't block exit)
            Task {
                await syncEngine.syncPending(from: modelContext)
            }
            
            // Exit immediately - sync will complete in background
            onComplete()
        } catch {
            print("Failed to save session: \(error)")
            isSaving = false  // Re-enable button only on error so user can retry
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
            .background(isSelected ? Color.orange : Color.gray.opacity(0.3))
            .foregroundStyle(isSelected ? .white : .gray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    // Note: Cannot preview with HKWorkout directly
    Text("Session Confirmation Preview")
}
