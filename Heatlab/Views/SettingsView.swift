//
//  SettingsView.swift
//  heatlab
//
//  App settings including temperature unit preference
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(UserSettings.self) var settings
    @Environment(SubscriptionManager.self) var subscriptionManager
    @State private var showingAddTypeSheet = false
    @State private var showingPaywall = false
    @State private var showingAgeSheet = false
    @State private var isRestoring = false
    
    /// Whether Apple Intelligence is available on this device
    private var isAIAvailable: Bool {
        AnalysisInsightGenerator.isAvailable
    }
    
    /// Send current settings to Watch
    private func syncSettingsToWatch() {
        WatchConnectivityReceiver.shared.sendSettingsToWatch(settings)
    }
    
    var body: some View {
        @Bindable var settings = settings
        
        List {
            // Subscription Section
            Section {
                if subscriptionManager.isPro {
                    // Pro status row
                    HStack {
                        Label {
                            Text("Heatlab Pro")
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.hlProHighlight)
                        }
                        Spacer()
                        Text("Active")
                            .foregroundStyle(.secondary)
                    }
                    
                    // Manage subscription link
                    Button {
                        Task {
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                try? await AppStore.showManageSubscriptions(in: windowScene)
                            }
                        }
                    } label: {
                        HStack {
                            Text("Manage Subscription")
                            Spacer()
                            Image(systemName: SFSymbol.externalLink)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // Upgrade prompt
                    Button {
                        showingPaywall = true
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Pro")
                                        .foregroundStyle(.primary)
                                    Text("Unlimited history, AI insights\(isAIAvailable ? "" : "*") & more")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.hlProHighlight)
                            }
                            Spacer()
                            Image(systemName: SFSymbol.chevronRight)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                // Restore purchases
                Button {
                    isRestoring = true
                    Task {
                        await subscriptionManager.restorePurchases()
                        isRestoring = false
                    }
                } label: {
                    HStack {
                        Text("Restore Purchases")
                        Spacer()
                        if isRestoring {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isRestoring)
            } header: {
                Text("Subscription")
            }
            
            // Temperature Unit Section
            Section {
                Picker("Temperature Unit", selection: $settings.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Temperature")
            } footer: {
                Text("Choose how temperatures are displayed throughout the app.")
            }
            
            // Display Preferences Section
            Section {
                Toggle("Show Calories in App", isOn: $settings.showCaloriesInApp)
                Toggle("Show Calories on Watch", isOn: $settings.showCaloriesOnWatch)
            } header: {
                Text("Display Preferences")
            } footer: {
                Text("Some practitioners prefer to opt out of this exercise metrics.")
            }
            
            // Heart Rate Zones Section
            Section {
                Button {
                    showingAgeSheet = true
                } label: {
                    HStack {
                        Text("Age")
                        Spacer()
                        if let age = settings.userAge {
                            Text("\(age)")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not Set")
                                .foregroundStyle(.tertiary)
                        }
                        Image(systemName: SFSymbol.chevronRight)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                if let maxHR = settings.estimatedMaxHR {
                    HStack {
                        Text("Estimated Max HR")
                        Spacer()
                        Text("\(Int(maxHR)) bpm")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Heart Rate Zones")
            } footer: {
                Text("Heart rate zones are calculated using the 220-age formula. Set your age to see zone breakdowns in session details.")
            }

            // Session Types Section
            Section {
                ForEach(settings.manageableSessionTypes) { typeConfig in
                    SessionTypeRow(
                        typeConfig: typeConfig,
                        onToggleVisibility: { visible in
                            settings.setVisibility(id: typeConfig.id, visible: visible)
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if typeConfig.canDelete {
                            Button(role: .destructive) {
                                settings.softDeleteCustomType(id: typeConfig.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                
                Button {
                    showingAddTypeSheet = true
                } label: {
                    Label("Add Custom Type", systemImage: SFSymbol.add)
                }
            } header: {
                Text("Session Types")
            } footer: {
                Text("Toggle visibility to show/hide types on Apple Watch and in the claim portal. Swipe left on custom types to delete.")
            }
            
            // About Section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                
                Link(destination: URL(string: "https://macpheelabs.com")!) {
                    HStack {
                        Text("MacPhee Labs")
                        Spacer()
                        Image(systemName: SFSymbol.externalLink)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Legal Section
            Section("Legal") {
                Link(destination: URL(string: "https://macpheelabs.com/heatlab/terms")!) {
                    HStack {
                        Text("Terms of Use")
                        Spacer()
                        Image(systemName: SFSymbol.externalLink)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://macpheelabs.com/heatlab/privacy")!) {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: SFSymbol.externalLink)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.hlBackground)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingAgeSheet) {
            AgeEntrySheet()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingAddTypeSheet) {
            AddCustomTypeSheet { name, workoutType in
                settings.addCustomType(name: name, workoutType: workoutType)
                syncSettingsToWatch()
            }
        }
        // Sync Watch-relevant settings when they change
        .onChange(of: settings.showCaloriesOnWatch) { _, _ in
            syncSettingsToWatch()
        }
        .onChange(of: settings.temperatureUnit) { _, _ in
            syncSettingsToWatch()
        }
        .onChange(of: settings.sessionTypeConfigs) { _, _ in
            syncSettingsToWatch()
        }
    }
}

// MARK: - Session Type Row

private struct SessionTypeRow: View {
    let typeConfig: SessionTypeConfig
    let onToggleVisibility: (Bool) -> Void
    
    @State private var isVisible: Bool
    
    init(typeConfig: SessionTypeConfig, onToggleVisibility: @escaping (Bool) -> Void) {
        self.typeConfig = typeConfig
        self.onToggleVisibility = onToggleVisibility
        self._isVisible = State(initialValue: typeConfig.isVisible)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(typeConfig.name)
                HStack(spacing: 4) {
                    Text(typeConfig.workoutType.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if typeConfig.isDefault {
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Default")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Visibility toggle
            Toggle("", isOn: $isVisible)
                .labelsHidden()
                .onChange(of: isVisible) { _, newValue in
                    onToggleVisibility(newValue)
                }
        }
    }
}

// MARK: - Add Custom Type Sheet

private struct AddCustomTypeSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var workoutType = "yoga"
    
    let onAdd: (String, String) -> Void
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Session Type Name")
                }
                
                Section {
                    Picker("Workout Type", selection: $workoutType) {
                        ForEach(WorkoutTypeRaw.allCases, id: \.rawValue) { type in
                            Text(type.displayName).tag(type.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Apple Health Workout Type")
                } footer: {
                    Text("This determines how the workout is recorded in Apple Health.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.hlBackground)
            .navigationTitle("Add Custom Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onAdd(trimmedName, workoutType)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(UserSettings())
    .environment(SubscriptionManager())
}

