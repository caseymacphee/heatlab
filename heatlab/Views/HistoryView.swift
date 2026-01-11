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
    @State private var sessions: [SessionWithStats] = []
    @State private var isLoading = true
    @State private var selectedSession: SessionWithStats?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading sessions...")
            } else if sessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions Yet",
                    systemImage: "flame",
                    description: Text("Complete your first hot yoga session on your Apple Watch to see it here.")
                )
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
    }
    
    private func loadSessions() async {
        isLoading = true
        let repo = SessionRepository(modelContext: modelContext)
        sessions = (try? await repo.fetchSessionsWithStats()) ?? []
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: HeatSession.self, inMemory: true)
}

