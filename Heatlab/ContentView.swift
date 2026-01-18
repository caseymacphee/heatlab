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
    @Environment(CloudKitStatus.self) var cloudKitStatus
    @State private var selectedTab = 0

    var body: some View {
        // Always show main content - never block on iCloud
        ZStack(alignment: .top) {
            tabView

            // Show non-blocking banner when iCloud unavailable
            if !cloudKitStatus.isAvailable {
                SyncBannerView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: cloudKitStatus.isAvailable)
    }

    private var tabView: some View {
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

/// Non-blocking banner showing sync status
private struct SyncBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "icloud.slash")
                .font(.caption)
            Text("Sign into iCloud to sync sessions from Watch")
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top, 8)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: HeatSession.self, inMemory: true)
        .environment(UserSettings())
        .environment(CloudKitStatus())
}
