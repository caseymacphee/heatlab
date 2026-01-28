//
//  SessionInsightCard.swift
//  heatlab
//
//  Unified insight card for SessionDetailView combining:
//  - Baseline comparison (temperature + class type)
//  - AI insight (Pro) or upsell (Free)
//  - Key stats row
//
//  Follows the SummaryCard pattern from AnalysisView
//

import SwiftUI

struct SessionInsightCard: View {
    @Environment(UserSettings.self) var settings

    let session: SessionWithStats
    let temperatureComparison: BaselineComparison
    let classTypeComparison: BaselineComparison?
    let isPro: Bool
    let aiInsight: String?
    let isGeneratingInsight: Bool
    let onRefreshTap: () -> Void
    let onUpgradeTap: () -> Void

    /// Apple Intelligence availability status
    private var aiAvailable: Bool {
        SummaryGenerator.isAvailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Baseline Section
            baselineSection
                .padding()

            // AI Section (only when platform supports AI)
            // - Free users: show upsell
            // - Pro users: show/generate AI content
            if aiAvailable {
                Divider()
                    .padding(.horizontal)

                aiSection
                    .padding()
            }

            Divider()
                .padding(.horizontal)

            // Stats Row
            statsRow
                .padding()
        }
        .background(Color.hlSurface)
        .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
    }

    // MARK: - Baseline Section

    private var baselineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Temperature baseline
            baselineRow(
                icon: SFSymbol.thermometer,
                text: temperatureComparisonText,
                isInsufficient: isInsufficientData(temperatureComparison)
            )

            // Class type baseline (if available)
            if let classComparison = classTypeComparison {
                baselineRow(
                    icon: settings.sessionType(for: session.session.sessionTypeId)?.icon ?? SFSymbol.yoga,
                    text: classComparisonText(classComparison),
                    isInsufficient: isInsufficientData(classComparison)
                )
            }
        }
    }

    private func baselineRow(icon: String, text: String, isInsufficient: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(isInsufficient ? .secondary : Color.hlAccent)
                .font(.body)
                .frame(width: 24, alignment: .center)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(isInsufficient ? .secondary : .primary)
        }
    }

    private func isInsufficientData(_ comparison: BaselineComparison) -> Bool {
        if case .insufficientData = comparison {
            return true
        }
        return false
    }

    private var temperatureComparisonText: String {
        switch temperatureComparison {
        case .typical(let bucket):
            return bucket.isHeated ? "Typical avg HR for this temperature" : "Typical avg HR for unheated"
        case .higherEffort(let percent, _):
            return "\(Int(percent))% higher avg HR than usual for this temp"
        case .lowerEffort(let percent, _):
            return "\(Int(percent))% lower avg HR than usual for this temp"
        case .insufficientData(let needed, _):
            return "Need \(needed) more session\(needed == 1 ? "" : "s") at this temp for baseline"
        }
    }

    private func classComparisonText(_ comparison: BaselineComparison) -> String {
        let typeName = settings.sessionTypeName(for: session.session.sessionTypeId) ?? "this class type"
        switch comparison {
        case .typical:
            return "Typical avg HR for \(typeName)"
        case .higherEffort(let percent, _):
            return "\(Int(percent))% higher avg HR than typical \(typeName)"
        case .lowerEffort(let percent, _):
            return "\(Int(percent))% lower avg HR than typical \(typeName)"
        case .insufficientData(let needed, _):
            return "Need \(needed) more \(typeName) session\(needed == 1 ? "" : "s") for baseline"
        }
    }

    // MARK: - AI Section

    @ViewBuilder
    private var aiSection: some View {
        if isPro {
            proAISection
        } else {
            freeAISection
        }
    }

    @ViewBuilder
    private var proAISection: some View {
        if let insight = aiInsight {
            // AI insight available
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: SFSymbol.sparkles)
                        .foregroundStyle(Color.hlAccent)
                    Text("AI Insight")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if aiAvailable {
                        Button(action: onRefreshTap) {
                            Image(systemName: SFSymbol.refresh)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(isGeneratingInsight)
                    }
                }

                ExpandableText(insight)
            }
        } else if isGeneratingInsight {
            // Generating insight - show spinner
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: SFSymbol.sparkles)
                        .foregroundStyle(Color.hlAccent)
                    Text("AI Insight")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Text("Generating insight...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if aiAvailable {
            // AI available but no insight yet - generate button
            Button(action: onRefreshTap) {
                HStack(spacing: 6) {
                    Image(systemName: SFSymbol.sparkles)
                        .foregroundStyle(Color.hlAccent)
                    Text("Generate AI Insight")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.hlAccent)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        // If AI not available and no cached insight, section is hidden
    }

    private var freeAISection: some View {
        Button(action: onUpgradeTap) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock AI insights")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.hlAccent)
                    Text("Get personalized feedback on this session")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: SFSymbol.chevronRight)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            // Duration
            statItem(
                label: "Duration",
                value: formatDuration(session.stats.duration)
            )

            Spacer(minLength: 0)

            // Temperature
            statItem(
                label: "Temp",
                value: temperatureValue
            )

            Spacer(minLength: 0)

            // Avg HR
            statItem(
                label: "Avg HR",
                value: session.stats.averageHR > 0
                    ? "\(Int(session.stats.averageHR)) bpm"
                    : "--"
            )

            Spacer(minLength: 0)

            // Calories OR HR Range (conditional)
            if settings.showCaloriesInApp {
                statItem(
                    label: "Calories",
                    value: session.stats.calories > 0
                        ? "\(Int(session.stats.calories))"
                        : "--"
                )
            } else {
                statItem(
                    label: "HR Range",
                    value: hrRangeValue
                )
            }
        }
    }

    private var hrRangeValue: String {
        let minHR = session.stats.minHR
        let maxHR = session.stats.maxHR
        guard minHR > 0, maxHR > 0, minHR != maxHR else { return "--" }
        return "\(Int(minHR))–\(Int(maxHR))"
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
        }
    }

    private var temperatureValue: String {
        if let temp = session.session.roomTemperature {
            return Temperature(fahrenheit: temp).formatted(unit: settings.temperatureUnit)
        }
        return "--"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

#Preview("Pro - With AI Insight") {
    SessionInsightCard(
        session: SessionWithStats(
            session: {
                let s = WorkoutSession(workoutUUID: UUID(), startDate: Date(), roomTemperature: 102)
                s.sessionTypeId = SessionTypeConfig.DefaultTypeID.vinyasa
                return s
            }(),
            workout: nil,
            stats: SessionStats(averageHR: 142, maxHR: 168, minHR: 95, calories: 387, duration: 2732)
        ),
        temperatureComparison: .lowerEffort(percentBelow: 8, bucket: .veryHot),
        classTypeComparison: .typical(bucket: .veryHot),
        isPro: true,
        aiInsight: "Your heart rate of 142 bpm was 8% lower than your baseline for 100-104°F sessions. This indicates excellent heat adaptation.",
        isGeneratingInsight: false,
        onRefreshTap: {},
        onUpgradeTap: {}
    )
    .padding()
    .background(Color.hlBackground)
    .environment(UserSettings())
}

#Preview("Pro - Generating") {
    SessionInsightCard(
        session: SessionWithStats(
            session: {
                let s = WorkoutSession(workoutUUID: UUID(), startDate: Date(), roomTemperature: 102)
                s.sessionTypeId = SessionTypeConfig.DefaultTypeID.vinyasa
                return s
            }(),
            workout: nil,
            stats: SessionStats(averageHR: 142, maxHR: 168, minHR: 95, calories: 387, duration: 2732)
        ),
        temperatureComparison: .typical(bucket: .veryHot),
        classTypeComparison: nil,
        isPro: true,
        aiInsight: nil,
        isGeneratingInsight: true,
        onRefreshTap: {},
        onUpgradeTap: {}
    )
    .padding()
    .background(Color.hlBackground)
    .environment(UserSettings())
}

#Preview("Free - Upsell") {
    SessionInsightCard(
        session: SessionWithStats(
            session: {
                let s = WorkoutSession(workoutUUID: UUID(), startDate: Date(), roomTemperature: 102)
                s.sessionTypeId = SessionTypeConfig.DefaultTypeID.vinyasa
                return s
            }(),
            workout: nil,
            stats: SessionStats(averageHR: 142, maxHR: 168, minHR: 95, calories: 387, duration: 2732)
        ),
        temperatureComparison: .higherEffort(percentAbove: 12, bucket: .veryHot),
        classTypeComparison: .insufficientData(sessionsNeeded: 2, bucket: .veryHot),
        isPro: false,
        aiInsight: nil,
        isGeneratingInsight: false,
        onRefreshTap: {},
        onUpgradeTap: {}
    )
    .padding()
    .background(Color.hlBackground)
    .environment(UserSettings())
}

#Preview("Insufficient Data - Both Baselines") {
    SessionInsightCard(
        session: SessionWithStats(
            session: {
                let s = WorkoutSession(workoutUUID: UUID(), startDate: Date(), roomTemperature: 102)
                s.sessionTypeId = SessionTypeConfig.DefaultTypeID.vinyasa
                return s
            }(),
            workout: nil,
            stats: SessionStats(averageHR: 142, maxHR: 168, minHR: 95, calories: 387, duration: 2732)
        ),
        temperatureComparison: .insufficientData(sessionsNeeded: 2, bucket: .veryHot),
        classTypeComparison: .insufficientData(sessionsNeeded: 3, bucket: .veryHot),
        isPro: true,
        aiInsight: nil,
        isGeneratingInsight: false,
        onRefreshTap: {},
        onUpgradeTap: {}
    )
    .padding()
    .background(Color.hlBackground)
    .environment(UserSettings())
}
