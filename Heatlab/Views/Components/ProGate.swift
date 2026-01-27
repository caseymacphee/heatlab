//
//  ProGate.swift
//  heatlab
//
//  View modifier and components for gating Pro features
//

import SwiftUI

// MARK: - ProGate View

/// A view that shows content for Pro users, or an upgrade prompt for free users
struct ProGate<Content: View>: View {
    @Environment(SubscriptionManager.self) var subscriptionManager
    
    let feature: ProFeature
    @ViewBuilder let content: () -> Content
    
    @State private var showingPaywall = false
    
    var body: some View {
        if subscriptionManager.isPro {
            content()
        } else {
            UpgradePromptCard(feature: feature) {
                showingPaywall = true
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - Upgrade Prompt Card

/// A card that prompts users to upgrade to Pro for a specific feature
struct UpgradePromptCard: View {
    let feature: ProFeature
    let onTap: () -> Void
    
    /// Apple Intelligence availability status
    private var aiStatus: AppleIntelligenceStatus {
        AnalysisInsightGenerator.availabilityStatus
    }
    
    /// Get the unavailable hint for this feature (if applicable)
    private var unavailableHint: String? {
        guard feature.hasDeviceRequirements else { return nil }
        return aiStatus.unavailableHint
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: feature.iconName)
                    .font(.title2)
                    .foregroundStyle(Color.hlAccent.opacity(0.7))
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(feature.shortDescription)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        
                        ProBadge()
                    }
                    
                    Text("Upgrade to unlock this feature")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Show hint if feature not available on this device (with specific reason)
                    if let hint = unavailableHint {
                        Text(hint)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                Image(systemName: SFSymbol.chevronRight)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: HLRadius.card)
                    .fill(Color.hlAccent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HLRadius.card)
                    .strokeBorder(Color.hlAccent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inline Upgrade Banner

/// A compact banner for inline upgrade prompts (e.g., in lists)
struct UpgradeInlineBanner: View {
    let message: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(Color.hlAccent)
                
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("Upgrade")
                    .font(.caption.bold())
                    .foregroundStyle(Color.hlAccent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.hlAccent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: HLRadius.chip))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pro Badge

/// Small badge indicating a Pro feature
struct ProBadge: View {
    var style: ProBadgeStyle = .default
    
    enum ProBadgeStyle {
        case `default`
        case compact
        case lock
    }
    
    var body: some View {
        switch style {
        case .default:
            Text("PRO")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.hlAccent)
                .clipShape(Capsule())
            
        case .compact:
            Text("PRO")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.hlAccent)
                .clipShape(Capsule())
            
        case .lock:
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundStyle(Color.hlAccent)
        }
    }
}

// MARK: - History Limit Banner

/// Banner shown in history view when free users scroll past 7-day limit
struct HistoryLimitBanner: View {
    let sessionCount: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.hlAccent)
                    
                    Text("\(sessionCount) older session\(sessionCount == 1 ? "" : "s") hidden")
                        .font(.subheadline.bold())
                    
                    Spacer()
                }
                
                Text("Upgrade to Pro for unlimited session history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Spacer()
                    Text("View Plans")
                        .font(.caption.bold())
                        .foregroundStyle(Color.hlAccent)
                    Image(systemName: SFSymbol.chevronRight)
                        .font(.caption2)
                        .foregroundStyle(Color.hlAccent)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: HLRadius.card)
                    .fill(Color.hlAccent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HLRadius.card)
                    .strokeBorder(Color.hlAccent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Period Lock Indicator

/// Indicator shown on locked period options in picker
struct PeriodLockIndicator: View {
    let period: AnalysisPeriod
    let isPro: Bool
    
    private var isLocked: Bool {
        !isPro && period.requiresPro
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(period.rawValue)
            if isLocked {
                ProBadge(style: .lock)
            }
        }
    }
}

// MARK: - View Extension for Pro Gating

extension View {
    /// Gates this view behind Pro subscription
    func proGated(feature: ProFeature) -> some View {
        ProGate(feature: feature) {
            self
        }
    }
}

// MARK: - Previews

#Preview("Upgrade Prompt Card") {
    VStack(spacing: 16) {
        UpgradePromptCard(feature: .aiInsights) { }
        UpgradePromptCard(feature: .periodComparisons) { }
        UpgradePromptCard(feature: .unlimitedHistory) { }
    }
    .padding()
}

#Preview("Inline Banner") {
    VStack(spacing: 16) {
        UpgradeInlineBanner(message: "View sessions older than 7 days") { }
    }
    .padding()
}

#Preview("Pro Badge") {
    HStack(spacing: 16) {
        ProBadge(style: .default)
        ProBadge(style: .compact)
        ProBadge(style: .lock)
    }
    .padding()
}

#Preview("History Limit Banner") {
    HistoryLimitBanner(sessionCount: 15) { }
        .padding()
}
