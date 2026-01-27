//
//  ClaimDetailView.swift
//  heatlab
//
//  Detail view for claiming an Apple Health workout
//  User fills in session details before saving
//

import SwiftUI
import SwiftData
import HealthKit

struct ClaimDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(UserSettings.self) var settings
    
    let workout: ClaimableWorkout
    let onClaimed: () -> Void
    
    // Edit state
    @State private var isHeated: Bool = true  // Default to heated
    @State private var temperature: Int = 95
    @State private var sessionTypeId: UUID? = nil
    @State private var perceivedEffort: PerceivedEffort = .none
    @State private var notes: String = ""
    @State private var hapticGenerator: UIImpactFeedbackGenerator?
    
    // Loading state
    @State private var isSaving = false
    @State private var heartRateData: [HKQuantitySample] = []
    @State private var isLoadingHR = false
    
    private var averageHR: Double {
        guard !heartRateData.isEmpty else { return 0 }
        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        let hrValues = heartRateData.map { $0.quantity.doubleValue(for: hrUnit) }
        return hrValues.reduce(0, +) / Double(hrValues.count)
    }
    
    private var maxHR: Double {
        guard !heartRateData.isEmpty else { return 0 }
        let hrUnit = HKUnit.count().unitDivided(by: .minute())
        return heartRateData.map { $0.quantity.doubleValue(for: hrUnit) }.max() ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Workout Info Header (read-only)
                workoutInfoSection
                
                // Heart Rate Preview (if available)
                if isLoadingHR {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading heart rate data...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.hlSurface)
                    .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
                } else if averageHR > 0 {
                    heartRatePreviewSection
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Editable Fields
                heatedToggleSection
                
                if isHeated {
                    temperatureSection
                }
                
                sessionTypeSection
                perceivedEffortSection
                notesSection
                
                // Save Button
                saveButton
            }
            .padding()
        }
        .background(Color.hlBackground)
        .navigationTitle("Claim Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .onAppear {
            hapticGenerator = UIImpactFeedbackGenerator(style: .light)
            hapticGenerator?.prepare()
            
            // Set default session type if available
            if let defaultType = settings.visibleSessionTypes.first {
                sessionTypeId = defaultType.id
            }
        }
        .task {
            await loadHeartRateData()
        }
        .interactiveDismissDisabled(isSaving)
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var workoutInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date and time
            HStack {
                Image(systemName: workout.icon)
                    .font(.title)
                    .foregroundStyle(Color.hlAccent)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.workoutTypeName)
                        .font(.title2.bold())
                    Text(workout.startDate.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Duration",
                    value: formatDuration(workout.duration),
                    systemIcon: SFSymbol.clock
                )
                
                StatCard(
                    title: "Calories",
                    value: workout.calories > 0 ? "\(Int(workout.calories)) kcal" : "--",
                    systemIcon: SFSymbol.fireFill
                )
            }
        }
        .heatLabCard()
    }
    
    @ViewBuilder
    private var heartRatePreviewSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Avg HR",
                value: "\(Int(averageHR)) bpm",
                systemIcon: SFSymbol.heartFill
            )
            
            StatCard(
                title: "Max HR",
                value: "\(Int(maxHR)) bpm",
                systemIcon: SFSymbol.waveform
            )
        }
    }
    
    @ViewBuilder
    private var heatedToggleSection: some View {
        Toggle("Heated Session", isOn: $isHeated.animation(.easeInOut(duration: 0.2)))
            .tint(Color.hlAccent)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
    }
    
    @ViewBuilder
    private var temperatureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temperature")
                .font(.headline)
            
            HStack(spacing: 0) {
                Picker("Temperature", selection: $temperature) {
                    ForEach(70...120, id: \.self) { temp in
                        Text("\(temp)°").tag(temp)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80, height: 120)
                .clipped()
                .onChange(of: temperature) { _, _ in
                    hapticGenerator?.impactOccurred()
                }
                
                Spacer()
                
                // Visual temperature indicator
                VStack(spacing: 12) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 40))
                        .foregroundStyle(temperatureColor(for: temperature))
                    
                    Text("\(temperature)°\(settings.temperatureUnit == .fahrenheit ? "F" : "C")")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(temperatureColor(for: temperature))
                    
                    Text(temperatureLabel(for: temperature))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    @ViewBuilder
    private var sessionTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Type")
                .font(.headline)
            Menu {
                Button("None") {
                    sessionTypeId = nil
                }
                ForEach(settings.manageableSessionTypes) { type in
                    Button(type.name) {
                        sessionTypeId = type.id
                    }
                }
            } label: {
                HStack {
                    Text(settings.sessionTypeName(for: sessionTypeId) ?? "None")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
            }
        }
    }
    
    @ViewBuilder
    private var perceivedEffortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Perceived Effort")
                .font(.headline)
            Menu {
                ForEach(PerceivedEffort.allCases, id: \.self) { effort in
                    Button(effort.displayName) {
                        perceivedEffort = effort
                    }
                }
            } label: {
                HStack {
                    Text(perceivedEffort.displayName)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
            }
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add notes about this session...")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                }
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
    }
    
    @ViewBuilder
    private var saveButton: some View {
        Button {
            saveWorkout()
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: SFSymbol.checkmark)
                }
                Text(isSaving ? "Saving..." : "Save Session")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.hlAccent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
        }
        .disabled(isSaving)
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func loadHeartRateData() async {
        isLoadingHR = true
        
        let importer = HealthKitImporter(modelContext: modelContext)
        do {
            heartRateData = try await importer.fetchHeartRateSamples(for: workout.workout)
        } catch {
            print("Failed to load heart rate data: \(error)")
        }
        
        isLoadingHR = false
    }
    
    private func saveWorkout() {
        isSaving = true
        
        let importer = HealthKitImporter(modelContext: modelContext)
        
        do {
            // Claim the workout and create a WorkoutSession
            let session = try importer.claimWorkout(
                workout.workout,
                roomTemperature: isHeated ? temperature : nil,
                sessionTypeId: sessionTypeId,
                perceivedEffort: perceivedEffort,
                notes: notes.isEmpty ? nil : notes
            )
            
            // Update baseline with the session's heart rate
            // Use the workout's startDate to maintain proper chronological ordering
            if averageHR > 0 {
                let baselineEngine = BaselineEngine(modelContext: modelContext)
                baselineEngine.updateBaseline(for: session, averageHR: averageHR)
            }
            
            isSaving = false
            onClaimed()
        } catch {
            print("Failed to claim workout: \(error)")
            isSaving = false
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
    
    private func temperatureColor(for temp: Int) -> Color {
        Color.HeatLab.temperature(fahrenheit: temp)
    }
    
    private func temperatureLabel(for temp: Int) -> String {
        switch temp {
        case ..<85: return "Cool"
        case 85..<95: return "Warm"
        case 95..<105: return "Hot"
        default: return "Very Hot"
        }
    }
}

#Preview {
    NavigationStack {
        // Note: This preview won't work without a real HKWorkout
        Text("ClaimDetailView requires a real HKWorkout")
    }
    .environment(UserSettings())
}
