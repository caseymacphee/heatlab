//
//  GettingStartedCard.swift
//  heatlab
//
//  Onboarding card for empty Dashboard - guides users to start their first session
//

import SwiftUI

struct GettingStartedCard: View {
    let claimableCount: Int
    let onStartWatch: () -> Void
    let onClaimWorkouts: () -> Void
    
    /// When claimable workouts exist, make that the primary action (instant content)
    private var claimIsPrimary: Bool { claimableCount > 0 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Get your first session in")
                .font(.headline)
            
            Text("Track on Apple Watch, or claim a recent workout from Apple Health.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Stacked buttons (full-width, clear hierarchy)
            VStack(spacing: 10) {
                if claimIsPrimary {
                    // Claim is primary when claimable workouts exist (instant content)
                    claimButton(isPrimary: true)
                    watchButton(isPrimary: false)
                } else {
                    // Watch is primary when no claimable workouts
                    watchButton(isPrimary: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .heatLabCard()
    }
    
    @ViewBuilder
    private func watchButton(isPrimary: Bool) -> some View {
        if isPrimary {
            Button(action: onStartWatch) {
                Label("Start on Watch", systemImage: "applewatch")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.hlAccent)
            .controlSize(.large)
        } else {
            Button(action: onStartWatch) {
                Label("Start on Watch", systemImage: "applewatch")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
    
    @ViewBuilder
    private func claimButton(isPrimary: Bool) -> some View {
        if isPrimary {
            Button(action: onClaimWorkouts) {
                HStack {
                    Text("Claim workouts")
                    
                    // Count badge
                    Text("\(claimableCount)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.25))
                        )
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.hlAccent)
            .controlSize(.large)
        } else {
            Button(action: onClaimWorkouts) {
                HStack {
                    Text("Claim workouts")
                    
                    // Count badge
                    Text("\(claimableCount)")
                        .font(.caption.bold())
                        .foregroundStyle(Color.hlAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.hlAccent.opacity(0.15))
                        )
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

// MARK: - Watch Instructions Sheet

struct WatchInstructionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 24) {
                    // Tip: class type setup
                    HStack(spacing: 12) {
                        Image(systemName: "gearshape")
                            .font(.body)
                            .foregroundStyle(Color.hlAccent)

                        Text("**Tip:** Go to **Settings** to add or remove class types — they'll appear on your watch when starting a session.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.hlAccent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    InstructionRow(
                        number: 1,
                        title: "Open HeatLab on Apple Watch",
                        subtitle: "Find the app in your watch's app grid"
                    )

                    InstructionRow(
                        number: 2,
                        title: "Tap \"Start Session\"",
                        subtitle: "Set your temperature and begin tracking"
                    )

                    InstructionRow(
                        number: 3,
                        title: "We'll sync automatically",
                        subtitle: "Your session will appear here when complete"
                    )
                }
                .padding(.horizontal)

                Spacer()
                
                Button("Got it") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.hlAccent)
                .controlSize(.large)
                .padding(.bottom, 32)
            }
            .navigationTitle("Start a Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: SFSymbol.xmark)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct InstructionRow: View {
    let number: Int
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Number badge
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.hlAccent)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("With Claimable (Claim Primary)") {
    GettingStartedCard(
        claimableCount: 3,
        onStartWatch: {},
        onClaimWorkouts: {}
    )
    .padding()
    .background(Color.hlBackground)
}

#Preview("No Claimable (Watch Primary)") {
    GettingStartedCard(
        claimableCount: 0,
        onStartWatch: {},
        onClaimWorkouts: {}
    )
    .padding()
    .background(Color.hlBackground)
}

#Preview("Watch Instructions") {
    WatchInstructionsSheet()
}
