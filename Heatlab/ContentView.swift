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
                DashboardView()
            }
            .tabItem {
                Label("Home", icon: selectedTab == 0 ? .homeSolid : .home)
            }
            .tag(0)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("Sessions", icon: selectedTab == 1 ? .bars3Solid : .bars3)
            }
            .tag(1)

            NavigationStack {
                AnalysisView()
            }
            .tabItem {
                Label("Analysis", icon: selectedTab == 2 ? .chartBarSolid : .chartBar)
            }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", icon: selectedTab == 3 ? .cog6ToothSolid : .cog6Tooth)
            }
            .tag(3)
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: HeatSession.self, inMemory: true)
        .environment(UserSettings())
        .environment(CloudKitStatus())
}
