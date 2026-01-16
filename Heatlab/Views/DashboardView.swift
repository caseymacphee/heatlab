//
//  DashboardView.swift
//  heatlab
//
//  Main dashboard with overview stats
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(UserSettings.self) var settings
    @EnvironmentObject var wcReceiver: WatchConnectivityReceiver
    @State private var sessions: [SessionWithStats] = []
    @State private var isLoading = true
    @State private var overallStats: OverallStats?
    
    private let calculator = TrendCalculator()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with flame
                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Heatlab")
                        .font(.largeTitle.bold())
                    
                    Text("Track your Practice")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 20)
                
                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                } else if let stats = overallStats, stats.totalSessions > 0 {
                    // Overall Stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Progress")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            DashboardStatCard(
                                title: "Total Sessions",
                                value: "\(stats.totalSessions)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            DashboardStatCard(
                                title: "Total Time",
                                value: stats.formattedTotalDuration,
                                icon: "clock.fill",
                                color: .blue
                            )
                            if settings.showCaloriesInApp {
                                DashboardStatCard(
                                    title: "Calories Burned",
                                    value: "\(Int(stats.totalCalories))",
                                    icon: "flame.fill",
                                    color: .orange
                                )
                            }
                            DashboardStatCard(
                                title: "Avg HR",
                                value: "\(Int(stats.averageHR)) bpm",
                                icon: "heart.fill",
                                color: .red
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Recent Session
                    if let recent = sessions.first {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Session")
                                    .font(.headline)
                                Spacer()
                                Text(recent.session.startDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            SessionRowView(session: recent)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                } else {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "figure.yoga")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        
                        Text("Ready to begin?")
                            .font(.title3.bold())
                        
                        Text("Start a session on your Apple Watch to begin tracking.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // Quick tip
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text("Tip")
                            .font(.headline)
                    }
                    Text("Track your heated yoga sessions to see how your body adapts over time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .onChange(of: wcReceiver.lastReceivedDate) {
            Task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        let repo = SessionRepository(modelContext: modelContext)
        sessions = (try? await repo.fetchSessionsWithStats()) ?? []
        overallStats = calculator.calculateOverallStats(sessions: sessions)
        isLoading = false
    }
}

struct DashboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2.bold())
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
    .modelContainer(for: HeatSession.self, inMemory: true)
    .environment(UserSettings())
    .environmentObject(WatchConnectivityReceiver.shared)
}

