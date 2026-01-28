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
    
    // Reset counters to force NavigationStack recreation when switching tabs
    @State private var homeResetCounter = 0
    @State private var sessionsResetCounter = 0
    @State private var analysisResetCounter = 0
    @State private var settingsResetCounter = 0
    
    // Reset trigger for Analysis filters
    @State private var analysisResetTrigger = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                DashboardView(selectedTab: $selectedTab, navigationPath: $homePath)
            }
            .id("home-\(homeResetCounter)")
            .tabItem {
                Label("Home", systemImage: selectedTab == 0 ? SFSymbol.homeFill : SFSymbol.home)
            }
            .tag(0)

            NavigationStack(path: $analysisPath) {
                AnalysisView(resetTrigger: analysisResetTrigger)
            }
            .id("analysis-\(analysisResetCounter)")
            .tabItem {
                Label("Analysis", systemImage: selectedTab == 1 ? SFSymbol.analysisFill : SFSymbol.analysis)
            }
            .tag(1)

            NavigationStack(path: $sessionsPath) {
                HistoryView(navigationPath: $sessionsPath)
            }
            .id("sessions-\(sessionsResetCounter)")
            .tabItem {
                Label("Sessions", systemImage: SFSymbol.sessions)
            }
            .tag(2)

            NavigationStack(path: $settingsPath) {
                SettingsView()
            }
            .id("settings-\(settingsResetCounter)")
            .tabItem {
                Label("Settings", systemImage: selectedTab == 3 ? SFSymbol.settingsFill : SFSymbol.settings)
            }
            .tag(3)
        }
        .tint(.accentColor)
        .background(Color.hlBackground.ignoresSafeArea())
        .onChange(of: selectedTab) { oldValue, newValue in
            // Reset navigation when switching to a tab
            // This ensures we always pop to root when switching tabs
            // If clicking the same tab while in a nested view, reset that tab's navigation
            if oldValue == newValue {
                // User clicked the same tab - reset its navigation if it has nested views
                switch newValue {
                case 0:
                    if !homePath.isEmpty {
                        homePath = NavigationPath()
                        homeResetCounter += 1
                    }
                case 1:
                    if !analysisPath.isEmpty {
                        analysisPath = NavigationPath()
                        analysisResetCounter += 1
                        analysisResetTrigger = UUID()
                    }
                case 2:
                    if !sessionsPath.isEmpty {
                        sessionsPath = NavigationPath()
                        sessionsResetCounter += 1
                    }
                case 3:
                    if !settingsPath.isEmpty {
                        settingsPath = NavigationPath()
                        settingsResetCounter += 1
                    }
                default:
                    break
                }
                return
            }
            
            // Reset navigation paths and increment reset counter to force NavigationStack recreation
            // This ensures clean state - user always returns to root view
            // The .id() modifier forces NavigationStack to recreate, ensuring clean navigation state
            switch newValue {
            case 0:
                homePath = NavigationPath()
                homeResetCounter += 1
            case 1:
                analysisPath = NavigationPath()
                analysisResetCounter += 1
                analysisResetTrigger = UUID()
            case 2:
                sessionsPath = NavigationPath()
                sessionsResetCounter += 1
            case 3:
                settingsPath = NavigationPath()
                settingsResetCounter += 1
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
