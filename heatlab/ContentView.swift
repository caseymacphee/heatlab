//
//  ContentView.swift
//  heatlab
//
//  Main tab navigation for iOS app
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
                Label("Home", systemImage: "flame.fill")
            }
            .tag(0)
            
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("Sessions", systemImage: "list.bullet")
            }
            .tag(1)
            
            NavigationStack {
                TrendsView()
            }
            .tabItem {
                Label("Trends", systemImage: "chart.xyaxis.line")
            }
            .tag(2)
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: HeatSession.self, inMemory: true)
}
