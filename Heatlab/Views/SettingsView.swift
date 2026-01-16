//
//  SettingsView.swift
//  heatlab
//
//  App settings including temperature unit preference
//

import SwiftUI

struct SettingsView: View {
    @Environment(UserSettings.self) var settings
    @State private var showingAddTypeAlert = false
    @State private var newTypeName = ""
    
    /// Send current settings to Watch
    private func syncSettingsToWatch() {
        WatchConnectivityReceiver.shared.sendSettingsToWatch(settings)
    }
    
    var body: some View {
        @Bindable var settings = settings
        
        List {
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
                Text("Choose how temperatures are displayed throughout the app. Sessions are always stored in Fahrenheit internally.")
            }
            
            // Display Preferences Section
            Section {
                Toggle("Show Calories in App", isOn: $settings.showCaloriesInApp)
                Toggle("Show Calories on Watch", isOn: $settings.showCaloriesOnWatch)
            } header: {
                Text("Display Preferences")
            } footer: {
                Text("Some practitioners prefer to focus on the meditative aspects of their practice rather than exercise metrics.")
            }
            
            // Session Types Section
            Section {
                ForEach(settings.manageableSessionTypes) { typeConfig in
                    SessionTypeRow(
                        typeConfig: typeConfig,
                        onToggleVisibility: { visible in
                            settings.setVisibility(id: typeConfig.id, visible: visible)
                        },
                        onDelete: typeConfig.canDelete ? {
                            settings.softDeleteCustomType(id: typeConfig.id)
                        } : nil
                    )
                }
                
                Button {
                    newTypeName = ""
                    showingAddTypeAlert = true
                } label: {
                    Label("Add Custom Type", systemImage: "plus.circle")
                }
            } header: {
                Text("Session Types")
            } footer: {
                Text("Toggle visibility to show/hide types on Apple Watch. Default types cannot be removed.")
            }
            
            // Preview Section
            Section("Preview") {
                HStack {
                    Text("Hot Yoga Room")
                    Spacer()
                    TemperatureBadge(temperature: 102, unit: settings.temperatureUnit)
                }
                
                HStack {
                    Text("Very Hot Room")
                    Spacer()
                    TemperatureBadge(temperature: 108, unit: settings.temperatureUnit)
                }
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
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Add Custom Type", isPresented: $showingAddTypeAlert) {
            TextField("Type Name", text: $newTypeName)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                let trimmedName = newTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty {
                    settings.addCustomType(name: trimmedName)
                    syncSettingsToWatch()
                }
            }
        } message: {
            Text("Enter a name for your custom session type.")
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
    let onDelete: (() -> Void)?
    
    @State private var isVisible: Bool
    
    init(typeConfig: SessionTypeConfig, onToggleVisibility: @escaping (Bool) -> Void, onDelete: (() -> Void)?) {
        self.typeConfig = typeConfig
        self.onToggleVisibility = onToggleVisibility
        self.onDelete = onDelete
        self._isVisible = State(initialValue: typeConfig.isVisible)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(typeConfig.name)
                if typeConfig.isDefault {
                    Text("Default")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Visibility toggle
            Toggle("", isOn: $isVisible)
                .labelsHidden()
                .onChange(of: isVisible) { _, newValue in
                    onToggleVisibility(newValue)
                }
            
            // Delete button (only for custom types)
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(UserSettings())
}

