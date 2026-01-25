//
//  SyncInfoView.swift
//  Heatlab Watch Watch App
//
//  Informational view about sync status (for settings)
//  NOT a blocker - just explains sync features
//

import SwiftUI

/// Shows detailed sync status information
/// Can be accessed from settings to check sync health
struct SyncInfoView: View {
    @Environment(SyncEngine.self) var syncEngine
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status icon
                Image(systemName: statusIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(statusColor)
                
                Text(statusTitle)
                    .font(.headline)
                
                Text(statusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Divider()
                    .padding(.vertical, 4)
                
                // Sync details
                VStack(alignment: .leading, spacing: 8) {
                    if syncEngine.pendingSessionCount > 0 {
                        Label("\(syncEngine.pendingSessionCount) session\(syncEngine.pendingSessionCount == 1 ? "" : "s") pending", systemImage: "clock")
                    }
                    
                    if let lastSync = syncEngine.lastSyncDate {
                        Label("Last sync: \(lastSync.formatted(date: .omitted, time: .shortened))", systemImage: "arrow.clockwise")
                    }
                    
                    if let error = syncEngine.lastError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    
                    // Phone reachability indicator
                    Label(
                        syncEngine.isPhoneReachable ? "iPhone connected" : "iPhone not reachable",
                        systemImage: syncEngine.isPhoneReachable ? "iphone" : "iphone.slash"
                    )
                    .foregroundStyle(syncEngine.isPhoneReachable ? .green : .secondary)
                }
                .font(.caption)
                
                // Manual sync button
                Button {
                    Task {
                        await syncEngine.syncPending(from: modelContext)
                    }
                } label: {
                    HStack {
                        if syncEngine.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text("Sync Now")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(syncEngine.isSyncing || !syncEngine.isPhoneReachable)
                .padding(.top, 8)
                
                // Help text when phone not reachable
                if !syncEngine.isPhoneReachable && syncEngine.pendingSessionCount > 0 {
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("Sessions will sync automatically when your iPhone is nearby and the HeatLab app is running.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .navigationTitle("Sync Status")
    }
    
    private var statusIcon: String {
        if syncEngine.isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if !syncEngine.isPhoneReachable {
            return "iphone.slash"
        } else if syncEngine.pendingSessionCount > 0 {
            return "arrow.triangle.2.circlepath"
        } else {
            return "checkmark.circle"
        }
    }
    
    private var statusColor: Color {
        if syncEngine.isSyncing {
            return .blue
        } else if !syncEngine.isPhoneReachable {
            return .orange
        } else if syncEngine.pendingSessionCount > 0 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var statusTitle: String {
        if syncEngine.isSyncing {
            return "Syncing..."
        } else if !syncEngine.isPhoneReachable {
            return "iPhone Not Reachable"
        } else if syncEngine.pendingSessionCount > 0 {
            return "Sync Pending"
        } else {
            return "All Synced"
        }
    }
    
    private var statusDescription: String {
        if !syncEngine.isPhoneReachable {
            return "Sessions are saved locally. They'll sync when your iPhone is nearby."
        } else if syncEngine.pendingSessionCount > 0 {
            return "Some sessions are waiting to sync to your iPhone."
        } else {
            return "All sessions are synced to your iPhone."
        }
    }
}

// Keep old name for backwards compatibility during migration
@available(*, deprecated, renamed: "SyncInfoView")
typealias iCloudPromptView = SyncInfoView

#Preview {
    SyncInfoView()
        .environment(SyncEngine())
}

