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

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Home", systemImage: selectedTab == 0 ? SFSymbol.homeFill : SFSymbol.home)
            }
            .tag(0)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("Sessions", systemImage: SFSymbol.sessions)
            }
            .tag(1)

            NavigationStack {
                AnalysisView()
            }
            .tabItem {
                Label("Analysis", systemImage: selectedTab == 2 ? SFSymbol.analysisFill : SFSymbol.analysis)
            }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: selectedTab == 3 ? SFSymbol.settingsFill : SFSymbol.settings)
            }
            .tag(3)
        }
        .tint(.accentColor)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: HeatSession.self, inMemory: true)
        .environment(UserSettings())
        .environment(CloudKitStatus())
}
