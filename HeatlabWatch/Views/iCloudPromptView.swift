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
    @State private var isCloudAvailable = false
    
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
                    if syncEngine.totalPendingCount > 0 {
                        Label("\(syncEngine.totalPendingCount) sessions pending", systemImage: "clock")
                    }
                    
                    if let lastSync = syncEngine.lastSyncDate {
                        Label("Last sync: \(lastSync.formatted(date: .omitted, time: .shortened))", systemImage: "arrow.clockwise")
                    }
                    
                    if let error = syncEngine.lastError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
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
                .disabled(syncEngine.isSyncing)
                .padding(.top, 8)
                
                // Help text for offline mode
                if !isCloudAvailable {
                    Divider()
                        .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To enable sync:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Label("Settings", systemImage: "gear")
                        Label("Sign in", systemImage: "person.circle")
                        Label("Enable iCloud", systemImage: "checkmark.icloud")
                    }
                    .font(.caption)
                }
            }
            .padding()
        }
        .navigationTitle("Sync Status")
        .task {
            isCloudAvailable = await syncEngine.isCloudKitAvailable()
        }
    }
    
    private var statusIcon: String {
        if syncEngine.isSyncing {
            return "icloud.and.arrow.up"
        } else if !isCloudAvailable {
            return "icloud.slash"
        } else if syncEngine.totalPendingCount > 0 {
            return "icloud.and.arrow.up"
        } else {
            return "checkmark.icloud"
        }
    }
    
    private var statusColor: Color {
        if syncEngine.isSyncing {
            return .blue
        } else if !isCloudAvailable {
            return .orange
        } else if syncEngine.totalPendingCount > 0 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var statusTitle: String {
        if syncEngine.isSyncing {
            return "Syncing..."
        } else if !isCloudAvailable {
            return "Offline Mode"
        } else if syncEngine.totalPendingCount > 0 {
            return "Sync Pending"
        } else {
            return "All Synced"
        }
    }
    
    private var statusDescription: String {
        if !isCloudAvailable {
            return "Sessions are saved locally. Sign into iCloud to sync with your iPhone."
        } else if syncEngine.totalPendingCount > 0 {
            return "Some sessions are waiting to sync. This happens automatically."
        } else {
            return "All sessions are synced to iCloud and available on your iPhone."
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

