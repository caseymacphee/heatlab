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
    @Environment(SubscriptionManager.self) var subscriptionManager
    @EnvironmentObject var wcReceiver: WatchConnectivityReceiver
    @Binding var navigationPath: NavigationPath
    @State private var sessions: [SessionWithStats] = []
    @State private var hiddenSessionCount: Int = 0
    @State private var isLoading = true
    @State private var filter = SessionFilter()
    @State private var showingFilterSheet = false
    @State private var claimableWorkoutCount: Int = 0
    @State private var showingClaimList = false
    @State private var showingPaywall = false

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
                return filter.selectedTemperatureBuckets.contains(session.session.temperatureBucket)
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
            result.sort { ($0.session.roomTemperature ?? 0) > ($1.session.roomTemperature ?? 0) }
        case .tempAsc:
            result.sort { ($0.session.roomTemperature ?? 0) < ($1.session.roomTemperature ?? 0) }
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
                    List {
                        ForEach(filteredSessions) { session in
                            NavigationLink(value: session) {
                                SessionRowView(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Show upgrade banner if there are hidden sessions
                        if hiddenSessionCount > 0 {
                            Section {
                                HistoryLimitBanner(sessionCount: hiddenSessionCount) {
                                    showingPaywall = true
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ImportToolbarButton(count: claimableWorkoutCount) {
                    showingClaimList = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                FilterToolbarButton(filter: $filter, showingFilterSheet: $showingFilterSheet)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            SessionFilterSheet(filter: $filter)
        }
        .navigationDestination(for: SessionWithStats.self) { session in
            SessionDetailView(
                session: session,
                baselineEngine: BaselineEngine(modelContext: modelContext)
            )
        }
        .navigationDestination(isPresented: $showingClaimList) {
            ClaimListView()
        }
        .onChange(of: navigationPath.count) { oldCount, newCount in
            // Reset showingClaimList when navigation path is cleared (e.g., when switching tabs)
            if newCount == 0 && oldCount > 0 {
                showingClaimList = false
            }
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
        
        // Fetch sessions with tier-based filtering
        if let result = try? await repo.fetchSessionsWithStats(isPro: subscriptionManager.isPro) {
            sessions = result.visibleSessions
            hiddenSessionCount = result.hiddenSessionCount
        } else {
            sessions = []
            hiddenSessionCount = 0
        }

        print("📊 HistoryView - Visible sessions: \(sessions.count)")
        print("📊 HistoryView - Hidden sessions: \(hiddenSessionCount)")
        print("📊 HistoryView - Sessions with HR: \(sessions.filter { $0.stats.averageHR > 0 }.count)")
        
        // Check for claimable workouts from Apple Health
        let importer = HealthKitImporter(modelContext: modelContext)
        do {
            claimableWorkoutCount = try await importer.claimableWorkoutCount(isPro: subscriptionManager.isPro)
        } catch {
            claimableWorkoutCount = 0
        }

        isLoading = false
    }
}

// MARK: - Import Toolbar Button

struct ImportToolbarButton: View {
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.down")
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.HeatLab.coral)
                        .clipShape(Capsule())
                }
            }
        }
        .tint(count > 0 ? Color.HeatLab.coral : .primary)
    }
}

#Preview {
    NavigationStack {
        HistoryView(navigationPath: .constant(NavigationPath()))
    }
    .modelContainer(for: WorkoutSession.self, inMemory: true)
    .environment(UserSettings())
    .environment(SubscriptionManager())
    .environmentObject(WatchConnectivityReceiver.shared)
}

#Preview("With Filter Sheet") {
    SessionFilterSheet(filter: .constant(SessionFilter()))
        .environment(UserSettings())
}

