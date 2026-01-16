//
//  iCloudPromptView.swift
//  heatlab
//
//  Informational view about iCloud sync (for settings)
//  NOT a blocker - just explains sync setup
//

import SwiftUI

/// Informational view explaining iCloud setup for sync
/// Can be accessed from settings when user wants to enable sync
struct iCloudPromptView: View {
    @Environment(CloudKitStatus.self) var cloudKitStatus
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status icon
                Image(systemName: cloudKitStatus.isAvailable ? "checkmark.icloud.fill" : "icloud.slash")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: cloudKitStatus.isAvailable ? [.green, .mint] : [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(spacing: 12) {
                    Text(cloudKitStatus.isAvailable ? "iCloud Connected" : "iCloud Offline")
                        .font(.title.bold())
                    
                    Text(cloudKitStatus.isAvailable
                         ? "Sessions from your Apple Watch will automatically sync to this device."
                         : "Sign into iCloud to sync sessions from your Apple Watch.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if !cloudKitStatus.isAvailable {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Open Settings", systemImage: "1.circle.fill")
                        Label("Tap your name at the top", systemImage: "2.circle.fill")
                        Label("Sign in with your Apple ID", systemImage: "3.circle.fill")
                        Label("Enable iCloud Drive", systemImage: "4.circle.fill")
                    }
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                } else {
                    // Show sync info when connected
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Sessions sync automatically", systemImage: "arrow.triangle.2.circlepath")
                        Label("Watch is the source of truth", systemImage: "applewatch")
                        Label("iOS displays synced data", systemImage: "iphone")
                    }
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
        }
        .navigationTitle("Sync Status")
    }
}

#Preview {
    NavigationStack {
        iCloudPromptView()
            .environment(CloudKitStatus())
    }
}

