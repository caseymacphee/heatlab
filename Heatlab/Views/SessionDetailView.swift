//
//  SessionDetailView.swift
//  heatlab
//
//  Detailed view for a single session
//

import SwiftUI
import SwiftData
import HealthKit

struct SessionDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @Environment(UserSettings.self) var settings
    let session: SessionWithStats
    let baselineEngine: BaselineEngine
    
    @State private var isGeneratingSummary = false
    @State private var localAiSummary: String?
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var heartRateDataPoints: [HeartRateDataPoint] = []
    @State private var isLoadingHeartRate = false
    
    // Edit state
    @State private var editedDuration: TimeInterval = 0
    @State private var maxDuration: TimeInterval = 0
    @State private var editedTemperature: Int = 95
    @State private var editedSessionTypeId: UUID?
    @State private var editedNotes: String = ""
    @State private var editedPerceivedEffort: PerceivedEffort = .none
    @State private var hapticGenerator: UIImpactFeedbackGenerator?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isEditing {
                    editModeContent
                } else {
                    viewModeContent
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                    }
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }
        }
        .onAppear {
            // Update baseline when viewing session
            baselineEngine.updateBaseline(for: session.session, averageHR: session.stats.averageHR)
            // Load heart rate data
            Task {
                await loadHeartRateData()
            }
        }
        .alert("Delete Session", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSession()
            }
        } message: {
            Text("Are you sure you want to delete this session? This action cannot be undone.")
        }
    }
    
    @ViewBuilder
    private var viewModeContent: some View {
        VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(settings.sessionTypeName(for: session.session.sessionTypeId) ?? "Heated Class")
                        .font(.title2.bold())
                    Text(session.session.startDate.formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Stats Grid - Left to right, top to bottom: Duration, Temperature, Avg HR, Calories/HR Range
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(
                        title: "Duration",
                        value: formatDuration(session.stats.duration),
                        icon: .clock,
                        iconColor: .blue
                    )
                    StatCard(
                        title: "Temperature",
                        value: Temperature(fahrenheit: session.session.roomTemperature).formatted(unit: settings.temperatureUnit),
                        systemIcon: "thermometer.medium",
                        iconColor: .orange
                    )
                    StatCard(
                        title: "Avg HR",
                        value: "\(Int(session.stats.averageHR)) bpm",
                        icon: .heart,
                        iconColor: .red
                    )
                    // Show Calories if enabled, otherwise show Heart Rate Range if available
                    if settings.showCaloriesInApp {
                        StatCard(
                            title: "Calories",
                            value: "\(Int(session.stats.calories)) kcal",
                            icon: .fire,
                            iconColor: .orange
                        )
                    } else if session.stats.minHR > 0 {
                        StatCard(
                            title: "HR Range",
                            value: "\(Int(session.stats.minHR))-\(Int(session.stats.maxHR)) bpm",
                            systemIcon: "waveform.path.ecg",
                            iconColor: .purple
                        )
                    }
                }
                
                // Heart Rate Chart
                if !heartRateDataPoints.isEmpty {
                    HeartRateChartView(
                        dataPoints: heartRateDataPoints,
                        minHR: session.stats.minHR > 0 ? session.stats.minHR : 0,
                        maxHR: session.stats.maxHR,
                        averageHR: session.stats.averageHR
                    )
                } else if isLoadingHeartRate {
                    VStack {
                        ProgressView()
                            .padding()
                        Text("Loading heart rate data...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Baseline Comparison
                BaselineComparisonView(comparison: baselineEngine.compareToBaseline(session: session))
                
                // AI Summary Section (only show when AI available or existing summary)
                if SummaryGenerator.isAvailable || session.session.aiSummary != nil {
                    aiSummarySection
                }
                
                // Perceived Effort (always shown)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Perceived Effort")
                        .font(.headline)
                    Text(session.session.perceivedEffort.displayName)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Notes (always shown)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    if let notes = session.session.userNotes, !notes.isEmpty {
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No notes")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Delete button
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Image(icon: .trash)
                        Text("Delete Session")
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
    }

    @ViewBuilder
    private var editModeContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Duration Editor
            DurationTimelineSlider(
                maxDuration: maxDuration,
                selectedDuration: $editedDuration
            )
            
            // Temperature Editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Temperature")
                    .font(.headline)

                HStack(spacing: 0) {
                    Picker("Temperature", selection: $editedTemperature) {
                        ForEach(70...120, id: \.self) { temp in
                            Text("\(temp)°").tag(temp)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 120)
                    .clipped()
                    .onChange(of: editedTemperature) { _, _ in
                        hapticGenerator?.impactOccurred()
                    }

                    Spacer()

                    // Visual temperature indicator
                    VStack(spacing: 12) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 40))
                            .foregroundStyle(temperatureColor(for: editedTemperature))

                        Text("\(editedTemperature)°\(settings.temperatureUnit == .fahrenheit ? "F" : "C")")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(temperatureColor(for: editedTemperature))

                        Text(temperatureLabel(for: editedTemperature))
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
            
            // Session Type Editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Session Type")
                    .font(.headline)
                Menu {
                    Button("None") {
                        editedSessionTypeId = nil
                    }
                    ForEach(settings.manageableSessionTypes) { type in
                        Button(type.name) {
                            editedSessionTypeId = type.id
                        }
                    }
                } label: {
                    HStack {
                        Text(settings.sessionTypeName(for: editedSessionTypeId) ?? "None")
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

            // Perceived Effort Editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Perceived Effort")
                    .font(.headline)
                Menu {
                    ForEach(PerceivedEffort.allCases, id: \.self) { effort in
                        Button(effort.displayName) {
                            editedPerceivedEffort = effort
                        }
                    }
                } label: {
                    HStack {
                        Text(editedPerceivedEffort.displayName)
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

            // Notes Editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.headline)
                ZStack(alignment: .topLeading) {
                    if editedNotes.isEmpty {
                        Text("Add notes about this session...")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                    }
                    TextEditor(text: $editedNotes)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                )
            }
            
            // Delete button
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Image(icon: .trash)
                    Text("Delete Session")
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func startEditing() {
        // Initialize edit state from session
        // Use original workout duration as max (before any manual override)
        if let workout = session.workout, workout.duration > 0 {
            maxDuration = workout.duration
        } else if let endDate = session.session.endDate {
            maxDuration = endDate.timeIntervalSince(session.session.startDate)
        } else {
            // Fallback to current duration if no workout/endDate
            maxDuration = session.stats.duration
        }

        // Start with current duration (which may already be clipped)
        editedDuration = session.stats.duration

        editedTemperature = session.session.roomTemperature
        editedSessionTypeId = session.session.sessionTypeId
        editedNotes = session.session.userNotes ?? ""
        editedPerceivedEffort = session.session.perceivedEffort

        // Prepare haptic generator for temperature picker
        hapticGenerator = UIImpactFeedbackGenerator(style: .light)
        hapticGenerator?.prepare()

        isEditing = true
    }
    
    private func saveChanges() {
        session.session.markUpdated()

        // Update duration - only set override if significantly different from max (within 1 second tolerance)
        let tolerance: TimeInterval = 1.0
        if editedDuration > tolerance && abs(editedDuration - maxDuration) > tolerance {
            session.session.manualDurationOverride = editedDuration
        } else {
            // Reset to original duration
            session.session.manualDurationOverride = nil
        }

        // Update other fields
        session.session.roomTemperature = editedTemperature
        session.session.sessionTypeId = editedSessionTypeId
        session.session.userNotes = editedNotes.isEmpty ? nil : editedNotes
        session.session.perceivedEffort = editedPerceivedEffort

        try? modelContext.save()
        isEditing = false

        // Clean up haptic generator
        hapticGenerator = nil

        // Reload heart rate data to reflect duration changes
        Task {
            await loadHeartRateData()
        }
    }
    
    private func deleteSession() {
        session.session.softDelete()
        try? modelContext.save()
        dismiss()
    }
    
    @ViewBuilder
    private var aiSummarySection: some View {
        let displaySummary = localAiSummary ?? session.session.aiSummary
        
        if let summary = displaySummary {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(icon: .sparkles)
                        .foregroundStyle(.purple)
                    Text("AI Summary")
                        .font(.headline)
                    Spacer()
                    // Only show refresh button if AI is available
                    if SummaryGenerator.isAvailable {
                        Button {
                            generateSummary()
                        } label: {
                            Image(icon: .arrowPath)
                                .font(.caption)
                        }
                        .disabled(isGeneratingSummary)
                    }
                }

                Text(summary)
                    .font(.body)
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if SummaryGenerator.isAvailable {
            // Generate summary button - only when AI is available
            Button {
                generateSummary()
            } label: {
                HStack {
                    if isGeneratingSummary {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(icon: .sparkles)
                    }
                    Text(isGeneratingSummary ? "Generating..." : "Generate AI Summary")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.opacity(0.1))
                .foregroundStyle(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isGeneratingSummary)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func generateSummary() {
        guard !isGeneratingSummary else { return }
        
        isGeneratingSummary = true
        let comparison = baselineEngine.compareToBaseline(session: session)
        let typeName = settings.sessionTypeName(for: session.session.sessionTypeId)
        
        Task {
            do {
                let generator = SummaryGenerator()
                let summary = try await generator.generateSummary(for: session, comparison: comparison, sessionTypeName: typeName)
                
                // Update the session with the summary
                await MainActor.run {
                    session.session.aiSummary = summary
                    localAiSummary = summary
                    try? modelContext.save()
                    isGeneratingSummary = false
                }
            } catch {
                print("Failed to generate summary: \(error)")
                await MainActor.run {
                    isGeneratingSummary = false
                }
            }
        }
    }
    
    private func loadHeartRateData() async {
        await MainActor.run {
            isLoadingHeartRate = true
        }

        do {
            let repository = SessionRepository(modelContext: modelContext)
            var dataPoints = try await repository.fetchHeartRateDataPoints(for: session.session)

            // Filter heart rate data points based on manual duration override
            if let manualDuration = session.session.manualDurationOverride {
                dataPoints = dataPoints.filter { $0.timeOffset <= manualDuration }
            }

            await MainActor.run {
                heartRateDataPoints = dataPoints
                isLoadingHeartRate = false
            }
        } catch {
            print("Failed to load heart rate data: \(error)")
            await MainActor.run {
                heartRateDataPoints = []
                isLoadingHeartRate = false
            }
        }
    }

    private func temperatureColor(for temp: Int) -> Color {
        switch temp {
        case ..<85: return .blue
        case 85..<95: return .green
        case 95..<105: return .orange
        default: return .red
        }
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
        SessionDetailView(
            session: SessionWithStats(
                session: {
                    let s = HeatSession(startDate: Date(), roomTemperature: 102)
                    s.sessionTypeId = SessionTypeConfig.DefaultTypeID.heatedVinyasa
                    s.aiSummary = "Great session! You maintained a strong, consistent effort throughout this heated vinyasa class. Your heart rate stayed in your typical range for 102°F sessions."
                    return s
                }(),
                workout: nil,
                stats: SessionStats(averageHR: 145, maxHR: 168, minHR: 95, calories: 387, duration: 2732)
            ),
            baselineEngine: BaselineEngine(modelContext: try! ModelContainer(for: HeatSession.self).mainContext)
        )
    }
    .environment(UserSettings())
}
