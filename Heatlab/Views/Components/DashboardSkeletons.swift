//
//  DashboardSkeletons.swift
//  heatlab
//
//  Skeleton preview components for empty Dashboard state
//  Shows users what they'll see after their first session
//

import SwiftUI

// MARK: - Skeleton Colors
// Lighter than disabled content to read as "placeholder" not "locked"

private let skeletonFill = Color.secondary.opacity(0.18)
private let skeletonFillLight = Color.secondary.opacity(0.10)

// MARK: - Skeleton Card Style
// Lighter than real cards to feel like preview, not disabled content

private struct SkeletonCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(HeatLabSpacing.md)
            .background(Color.hlSurface.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
    }
}

private extension View {
    func skeletonCard() -> some View {
        modifier(SkeletonCardModifier())
    }
}

// MARK: - Skeleton Bar Shape

private struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var light: Bool = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(light ? skeletonFillLight : skeletonFill)
            .frame(width: width, height: height)
    }
}

// MARK: - Insight Card Skeleton

struct InsightCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header (real, no chevron - not tappable)
            HStack {
                Image(systemName: SFSymbol.sparkles)
                    .foregroundStyle(Color.hlAccent.opacity(0.4))
                Text("Insight")
                    .font(.subheadline.bold())
                    .foregroundStyle(.tertiary)
            }
            
            // Body: 2 grey bars (varying widths)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBar(width: 220, height: 12)
                SkeletonBar(width: 160, height: 12)
            }
            
            // Footer: lighter grey bar
            SkeletonBar(width: 80, height: 10, light: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(LinearGradient.insight.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
    }
}

// MARK: - Stats Card Skeleton ("Past 7 Days")

struct StatsCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header (real but muted)
            Text("Past 7 Days")
                .font(.headline)
                .foregroundStyle(.tertiary)
            
            // 2x2 grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatItemSkeleton(title: "Sessions", systemIcon: SFSymbol.yoga)
                StatItemSkeleton(title: "Avg Temp", systemIcon: SFSymbol.thermometer)
                StatItemSkeleton(title: "Avg HR", systemIcon: SFSymbol.heartFill)
                StatItemSkeleton(title: "HR Range", systemIcon: SFSymbol.waveform)
            }
        }
        .skeletonCard()
    }
}

private struct StatItemSkeleton: View {
    let title: String
    let systemIcon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label row (real, but muted)
            HStack(spacing: 4) {
                Image(systemName: systemIcon)
                    .font(.caption)
                    .foregroundStyle(.quaternary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.quaternary)
            }
            
            // Value: grey rounded rectangle
            SkeletonBar(width: 50, height: 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Session Row Skeleton

struct SessionRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Left icon: grey circle
            Circle()
                .fill(skeletonFill)
                .frame(width: 40, height: 40)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBar(width: 120, height: 14)
                SkeletonBar(width: 180, height: 10, light: true)
            }
            
            Spacer()
            
            // Temperature pill placeholder
            SkeletonBar(width: 44, height: 22)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recent Sessions Skeleton

struct RecentSessionsSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row (real but muted)
            Text("Recent Sessions")
                .font(.headline)
                .foregroundStyle(.tertiary)
            
            // 2 placeholder rows
            VStack(spacing: 8) {
                SessionRowSkeleton()
                SessionRowSkeleton()
            }
        }
        .skeletonCard()
    }
}

// MARK: - Dashboard Preview Section

struct DashboardPreviewSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header (cleaner than "Preview — ...")
            Text("After your first session")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            
            InsightCardSkeleton()
            StatsCardSkeleton()
            RecentSessionsSkeleton()
        }
    }
}

// MARK: - Previews

#Preview("All Skeletons") {
    ScrollView {
        VStack(spacing: 20) {
            DashboardPreviewSection()
        }
        .padding()
    }
    .background(Color.hlBackground)
}

#Preview("Insight Card Skeleton") {
    InsightCardSkeleton()
        .padding()
        .background(Color.hlBackground)
}

#Preview("Stats Card Skeleton") {
    StatsCardSkeleton()
        .padding()
        .background(Color.hlBackground)
}

#Preview("Recent Sessions Skeleton") {
    RecentSessionsSkeleton()
        .padding()
        .background(Color.hlBackground)
}
