//
//  SessionConfirmationView.swift
//  Heatlab Watch Watch App
//
//  Post-workout view to capture room temperature and class type
//

import SwiftUI
import SwiftData
import HealthKit

struct SessionConfirmationView: View {
    @Environment(\.modelContext) var modelContext
    @State private var temperature: Int = 95  // Default to common hot yoga temp
    @State private var classType: ClassType?
    @State private var isSaving = false
    
    let workout: HKWorkout
    let onComplete: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                Text("Session Complete")
                    .font(.headline)
                    .foregroundStyle(.green)
                
                // Summary stats
                HStack(spacing: 16) {
                    VStack {
                        Text(formatDuration(workout.duration))
                            .font(.title3.bold())
                        Text("Duration")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                        VStack {
                            Text("\(Int(calories))")
                                .font(.title3.bold())
                            Text("Calories")
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
                
                TemperatureDialView(temperature: $temperature)
                    .frame(height: 100)
                
                Divider()
                
                // Class Type (Optional) - Compact grid
                Text("Class Type (Optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(ClassType.allCases, id: \.self) { type in
                        Button {
                            classType = classType == type ? nil : type
                        } label: {
                            Text(type.shortName)
                                .font(.caption2)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(classType == type ? .orange : .gray)
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
                        Text("Save Session")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSaving)
                .padding(.top, 8)
            }
            .padding(.horizontal, 4)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func saveSession() {
        isSaving = true
        
        let session = HeatSession(startDate: workout.startDate, roomTemperature: temperature)
        session.endDate = workout.endDate
        session.workoutUUID = workout.uuid
        session.classType = classType
        
        modelContext.insert(session)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save session: \(error)")
        }
        
        isSaving = false
        onComplete()
    }
}

#Preview {
    // Note: Cannot preview with HKWorkout directly
    Text("Session Confirmation Preview")
}

