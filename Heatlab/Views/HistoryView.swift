//
//  HistoryView.swift
//  heatlab
//
//  Session history list view
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var wcReceiver: WatchConnectivityReceiver
    @State private var sessions: [SessionWithStats] = []
    @State private var isLoading = true
    @State private var selectedSession: SessionWithStats?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading sessions...")
            } else if sessions.isEmpty {
                ContentUnavailableView {
                    Label("No Sessions Yet", image: IconName.fire.rawValue)
                } description: {
                    Text("Complete your first hot yoga session on your Apple Watch to see it here.")
                }
            } else {
                List(sessions) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        SessionRowView(session: session)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Sessions")
        .navigationDestination(item: $selectedSession) { session in
            SessionDetailView(
                session: session,
                baselineEngine: BaselineEngine(modelContext: modelContext)
            )
        }
        .task {
            await loadSessions()
        }
        .refreshable {
            await loadSessions()
        }
        .onChange(of: wcReceiver.lastReceivedDate) {
            Task {
                await loadSessions()
            }
        }
    }
    
    private func loadSessions() async {
        isLoading = true
        let repo = SessionRepository(modelContext: modelContext)
        sessions = (try? await repo.fetchSessionsWithStats()) ?? []

        // DEBUG: Check session data
        print("📊 HistoryView - Total sessions: \(sessions.count)")
        print("📊 HistoryView - Sessions with HR: \(sessions.filter { $0.stats.averageHR > 0 }.count)")
        print("📊 HistoryView - Sessions without workoutUUID: \(sessions.filter { $0.session.workoutUUID == nil }.count)")

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: HeatSession.self, inMemory: true)
    .environment(UserSettings())
    .environmentObject(WatchConnectivityReceiver.shared)
}

