//
//  ContentView.swift
//  heatlab
//
//  Main tab navigation for iOS app
//  iOS is read-only: displays synced data from Watch, shows status when offline
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    // Navigation path state for each tab to enable resetting
    @State private var homePath = NavigationPath()
    @State private var sessionsPath = NavigationPath()
    @State private var analysisPath = NavigationPath()
    @State private var settingsPath = NavigationPath()
    
    // Reset trigger for Analysis filters
    @State private var analysisResetTrigger = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                DashboardView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Home", systemImage: selectedTab == 0 ? SFSymbol.homeFill : SFSymbol.home)
            }
            .tag(0)

            NavigationStack(path: $sessionsPath) {
                HistoryView()
            }
            .tabItem {
                Label("Sessions", systemImage: SFSymbol.sessions)
            }
            .tag(1)

            NavigationStack(path: $analysisPath) {
                AnalysisView(resetTrigger: analysisResetTrigger)
            }
            .tabItem {
                Label("Analysis", systemImage: selectedTab == 2 ? SFSymbol.analysisFill : SFSymbol.analysis)
            }
            .tag(2)

            NavigationStack(path: $settingsPath) {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: selectedTab == 3 ? SFSymbol.settingsFill : SFSymbol.settings)
            }
            .tag(3)
        }
        .tint(.accentColor)
        .onChange(of: selectedTab) { oldValue, newValue in
            // Reset navigation when switching to a tab
            switch newValue {
            case 0:
                homePath = NavigationPath()
            case 1:
                sessionsPath = NavigationPath()
            case 2:
                analysisPath = NavigationPath()
                analysisResetTrigger = UUID()
            case 3:
                settingsPath = NavigationPath()
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
        .environment(UserSettings())
        .environment(CloudKitStatus())
}
