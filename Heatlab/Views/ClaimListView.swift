//
//  ClaimListView.swift
//  heatlab
//
//  List of claimable Apple Health workouts
//  Swipe left to dismiss, tap to claim
//

import SwiftUI
import SwiftData
import HealthKit

struct ClaimListView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(UserSettings.self) var settings
    @Environment(SubscriptionManager.self) var subscriptionManager
    @Environment(\.dismiss) var dismiss
    
    @State private var workouts: [ClaimableWorkout] = []
    @State private var isLoading = true
    @State private var showDismissed = false
    @State private var errorMessage: String?
    @State private var selectedWorkout: ClaimableWorkout?
    @State private var showingPaywall = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toggle for showing dismissed workouts
            if !workouts.isEmpty || showDismissed {
                HStack {
                    Toggle("Show Dismissed", isOn: $showDismissed)
                        .font(.subheadline)
                        .tint(Color.hlAccent)
                }
                .padding(.horizontal)
                .padding(.vertical, HeatLabSpacing.sm)
                .background(Color.hlSurface2)
            }
            
            Group {
                if isLoading {
                    Spacer()
                    ProgressView("Loading workouts...")
                    Spacer()
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task { await loadWorkouts() }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if workouts.isEmpty {
                    emptyStateView
                } else {
                    workoutList
                }
            }
        }
        .navigationTitle("Claim Workouts")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadWorkouts()
        }
        .refreshable {
            await loadWorkouts()
        }
        .onChange(of: showDismissed) {
            Task { await loadWorkouts() }
        }
        .navigationDestination(item: $selectedWorkout) { workout in
            ClaimDetailView(
                workout: workout,
                onClaimed: {
                    selectedWorkout = nil
                    Task { await loadWorkouts() }
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        dismissAllRemaining()
                    } label: {
                        Label("Dismiss All Remaining", systemImage: "xmark.circle")
                    }
                    .disabled(workouts.filter { !$0.isDismissed }.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(workouts.filter { !$0.isDismissed }.isEmpty)
            }
        }
    }
    
    private var lookbackDescription: String {
        if subscriptionManager.isPro {
            return "past year"
        } else {
            return "past 7 days"
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            ContentUnavailableView {
                Label(
                    showDismissed ? "No Workouts Found" : "All Caught Up!",
                    systemImage: showDismissed ? SFSymbol.yoga : "checkmark.circle"
                )
            } description: {
                if showDismissed {
                    Text("No workouts found in the \(lookbackDescription).")
                } else {
                    Text("You've reviewed all available workouts from the \(lookbackDescription).")
                }
            } actions: {
                if !showDismissed {
                    Button("Show Dismissed") {
                        showDismissed = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Upgrade prompt for free users
            if !subscriptionManager.isPro {
                ClaimHistoryUpgradeBanner {
                    showingPaywall = true
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
    
    @ViewBuilder
    private var workoutList: some View {
        List {
            ForEach(workouts) { workout in
                Button {
                    selectedWorkout = workout
                } label: {
                    HStack {
                        ClaimableWorkoutRow(
                            workout: workout,
                            temperatureUnit: settings.temperatureUnit
                        )
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if workout.isDismissed {
                        Button {
                            restoreWorkout(workout)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                    } else {
                        Button {
                            dismissWorkout(workout)
                        } label: {
                            Label("Dismiss", systemImage: "xmark.circle")
                        }
                        .tint(.orange)
                    }
                }
            }
            
            // Upgrade prompt for free users at the end of the list
            if !subscriptionManager.isPro {
                Section {
                    ClaimHistoryUpgradeBanner {
                        showingPaywall = true
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Actions
    
    private func loadWorkouts() async {
        isLoading = true
        errorMessage = nil
        
        let importer = HealthKitImporter(modelContext: modelContext)
        
        do {
            // Request authorization if needed
            try await importer.requestAuthorization()
            
            // Fetch claimable workouts (lookback depends on subscription tier)
            workouts = try await importer.fetchClaimableWorkouts(
                isPro: subscriptionManager.isPro,
                enabledTypes: settings.enabledWorkoutTypes,
                includeDismissed: showDismissed
            )
        } catch {
            errorMessage = "Failed to load workouts: \(error.localizedDescription)"
            print("HealthKit error: \(error)")
        }
        
        isLoading = false
    }
    
    private func dismissWorkout(_ workout: ClaimableWorkout) {
        let importer = HealthKitImporter(modelContext: modelContext)
        do {
            try importer.dismissWorkout(uuid: workout.id)
            // Remove from list with animation
            withAnimation {
                workouts.removeAll { $0.id == workout.id }
            }
        } catch {
            print("Failed to dismiss workout: \(error)")
        }
    }
    
    private func restoreWorkout(_ workout: ClaimableWorkout) {
        let importer = HealthKitImporter(modelContext: modelContext)
        do {
            try importer.restoreWorkout(uuid: workout.id)
            // Update the workout's dismissed status in the list
            if workouts.contains(where: { $0.id == workout.id }) {
                // Reload to get updated state
                Task { await loadWorkouts() }
            }
        } catch {
            print("Failed to restore workout: \(error)")
        }
    }
    
    private func dismissAllRemaining() {
        let toDismiss = workouts.filter { !$0.isDismissed }
        guard !toDismiss.isEmpty else { return }
        
        let importer = HealthKitImporter(modelContext: modelContext)
        do {
            try importer.dismissWorkouts(uuids: toDismiss.map { $0.id })
            withAnimation {
                workouts.removeAll { !$0.isDismissed }
            }
        } catch {
            print("Failed to dismiss workouts: \(error)")
        }
    }
}

// MARK: - Workout Row

struct ClaimableWorkoutRow: View {
    let workout: ClaimableWorkout
    let temperatureUnit: TemperatureUnit
    
    var body: some View {
        HStack(spacing: 12) {
            // Session icon (matches workout type)
            Image(systemName: workout.icon)
                .font(.title2)
                .foregroundStyle(workout.isDismissed ? .secondary : Color.hlAccent)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                // Date
                Text(formatDate(workout.startDate))
                    .font(.headline)
                    .foregroundStyle(workout.isDismissed ? .secondary : .primary)
                
                // Duration • Calories
                HStack(spacing: 0) {
                    Text(formatDuration(workout.duration))
                    if workout.calories > 0 {
                        Text(" • ")
                        Text("\(Int(workout.calories)) cal")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Dismissed badge
            if workout.isDismissed {
                Text("Dismissed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
            } else {
                Image(systemName: SFSymbol.chevronRight)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(workout.isDismissed ? 0.7 : 1.0)
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today " + date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday " + date.formatted(date: .omitted, time: .shortened)
        }
        
        let daysDiff = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        if daysDiff <= 7 {
            let weekday = date.formatted(.dateTime.weekday(.abbreviated))
            let time = date.formatted(date: .omitted, time: .shortened)
            return "\(weekday) \(time)"
        }
        
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Claim History Upgrade Banner

/// Banner shown to free users to upsell claiming older workouts
struct ClaimHistoryUpgradeBanner: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title2)
                        .foregroundStyle(Color.hlAccent)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Claim Older Workouts")
                                .font(.subheadline.bold())
                            ProBadge(style: .compact)
                        }
                        
                        Text("Access unlimited workout history from Apple Health")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                HStack {
                    Spacer()
                    Text("View Plans")
                        .font(.caption.bold())
                        .foregroundStyle(Color.hlAccent)
                    Image(systemName: SFSymbol.chevronRight)
                        .font(.caption2)
                        .foregroundStyle(Color.hlAccent)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: HLRadius.card)
                    .fill(Color.hlAccent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HLRadius.card)
                    .strokeBorder(Color.hlAccent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ClaimListView()
    }
    .modelContainer(for: [WorkoutSession.self, ImportedWorkout.self], inMemory: true)
    .environment(UserSettings())
    .environment(SubscriptionManager())
}

#Preview("Claim History Upgrade Banner") {
    ClaimHistoryUpgradeBanner { }
        .padding()
}
