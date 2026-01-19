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
    @Environment(UserSettings.self) var userSettings
    @EnvironmentObject var wcReceiver: WatchConnectivityReceiver
    @State private var sessions: [SessionWithStats] = []
    @State private var isLoading = true
    @State private var selectedSession: SessionWithStats?
    @State private var filter = SessionFilter()
    @State private var showingFilterSheet = false

    private var filteredSessions: [SessionWithStats] {
        var result = sessions

        // Filter by class type
        if !filter.selectedClassTypes.isEmpty {
            result = result.filter { session in
                guard let typeId = session.session.sessionTypeId else { return false }
                return filter.selectedClassTypes.contains(typeId)
            }
        }

        // Filter by temperature bucket
        if !filter.selectedTemperatureBuckets.isEmpty {
            result = result.filter { session in
                filter.selectedTemperatureBuckets.contains(session.session.temperatureBucket)
            }
        }

        // Filter by date range
        if let startDate = filter.startDate {
            result = result.filter { $0.session.startDate >= startDate }
        }
        if let endDate = filter.endDate {
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: endDate) ?? endDate
            result = result.filter { $0.session.startDate < endOfDay }
        }

        // Sort
        switch filter.sortOption {
        case .dateDesc:
            result.sort { $0.session.startDate > $1.session.startDate }
        case .dateAsc:
            result.sort { $0.session.startDate < $1.session.startDate }
        case .tempDesc:
            result.sort { $0.session.roomTemperature > $1.session.roomTemperature }
        case .tempAsc:
            result.sort { $0.session.roomTemperature < $1.session.roomTemperature }
        case .classType:
            result.sort {
                let name0 = userSettings.sessionTypeName(for: $0.session.sessionTypeId) ?? ""
                let name1 = userSettings.sessionTypeName(for: $1.session.sessionTypeId) ?? ""
                return name0 < name1
            }
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            ActiveFiltersBar(filter: $filter)

            Group {
                if isLoading {
                    Spacer()
                    ProgressView("Loading sessions...")
                    Spacer()
                } else if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("No Sessions Yet", systemImage: SFSymbol.fireFill)
                    } description: {
                        Text("Complete your first hot yoga session on your Apple Watch to see it here.")
                    }
                } else if filteredSessions.isEmpty {
                    ContentUnavailableView {
                        Label("No Matching Sessions", systemImage: "line.3.horizontal.decrease.circle")
                    } description: {
                        Text("Try adjusting your filters to see more sessions.")
                    } actions: {
                        Button("Clear Filters") {
                            filter.clear()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    List(filteredSessions) { session in
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
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FilterToolbarButton(filter: $filter, showingFilterSheet: $showingFilterSheet)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            SessionFilterSheet(filter: $filter)
        }
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

#Preview("With Filter Sheet") {
    SessionFilterSheet(filter: .constant(SessionFilter()))
        .environment(UserSettings())
}

