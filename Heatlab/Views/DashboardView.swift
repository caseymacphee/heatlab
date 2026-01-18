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
    @State private var weekComparison: PeriodComparison?
    @State private var selectedSession: SessionWithStats?
    
    private let analysisCalculator = AnalysisCalculator()
    
    /// Sessions from the last 7 days
    private var recentSessions: [SessionWithStats] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.session.startDate >= sevenDaysAgo }
    }
    
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
                } else if let comparison = weekComparison, comparison.current.sessionCount > 0 {
                    // This Week Stats using ComparisonCard
                    ComparisonCard(comparison: comparison, period: .week)
                    
                    // Recent Sessions (last 7 days)
                    if !recentSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Sessions")
                                .font(.headline)
                            
                            VStack(spacing: 8) {
                                ForEach(recentSessions) { session in
                                    Button {
                                        selectedSession = session
                                    } label: {
                                        SessionRowView(session: session, useRelativeTime: true)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
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
        .navigationDestination(item: $selectedSession) { session in
            SessionDetailView(
                session: session,
                baselineEngine: BaselineEngine(modelContext: modelContext)
            )
        }
    }
    
    private func loadData() async {
        isLoading = true
        let repo = SessionRepository(modelContext: modelContext)
        sessions = (try? await repo.fetchSessionsWithStats()) ?? []
        
        // Calculate week comparison using AnalysisCalculator
        weekComparison = analysisCalculator.comparePeriods(sessions: sessions, period: .week)
        
        isLoading = false
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

