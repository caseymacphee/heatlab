//
//  SessionFilterView.swift
//  heatlab
//
//  Filter and sort controls for session history
//

import SwiftUI

// MARK: - Filter Models

enum SessionSortOption: String, CaseIterable, Identifiable {
    case dateDesc = "Newest First"
    case dateAsc = "Oldest First"
    case tempDesc = "Hottest First"
    case tempAsc = "Coolest First"
    case classType = "Class Type"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dateDesc: return "arrow.down"
        case .dateAsc: return "arrow.up"
        case .tempDesc: return SFSymbol.thermometer
        case .tempAsc: return SFSymbol.thermometer
        case .classType: return SFSymbol.yoga
        }
    }
}

struct SessionFilter: Equatable {
    var selectedClassTypes: Set<UUID> = []
    var selectedTemperatureBuckets: Set<TemperatureBucket> = []
    var startDate: Date?
    var endDate: Date?
    var sortOption: SessionSortOption = .dateDesc

    var hasActiveFilters: Bool {
        !selectedClassTypes.isEmpty ||
        !selectedTemperatureBuckets.isEmpty ||
        startDate != nil ||
        endDate != nil
    }

    var activeFilterCount: Int {
        var count = 0
        if !selectedClassTypes.isEmpty { count += 1 }
        if !selectedTemperatureBuckets.isEmpty { count += 1 }
        if startDate != nil || endDate != nil { count += 1 }
        return count
    }

    mutating func clear() {
        selectedClassTypes.removeAll()
        selectedTemperatureBuckets.removeAll()
        startDate = nil
        endDate = nil
    }
}

// MARK: - Filter Sheet View

struct SessionFilterSheet: View {
    @Binding var filter: SessionFilter
    @Environment(\.dismiss) var dismiss
    @Environment(UserSettings.self) var userSettings

    var body: some View {
        NavigationStack {
            Form {
                // Sort Section
                Section("Sort By") {
                    ForEach(SessionSortOption.allCases) { option in
                        Button {
                            filter.sortOption = option
                        } label: {
                            HStack {
                                Label(option.rawValue, systemImage: option.icon)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if filter.sortOption == option {
                                    Image(systemName: SFSymbol.checkmark)
                                        .foregroundStyle(Color.HeatLab.coral)
                                }
                            }
                        }
                    }
                }

                // Class Type Section
                Section("Class Type") {
                    ForEach(userSettings.manageableSessionTypes) { sessionType in
                        Button {
                            toggleClassType(sessionType.id)
                        } label: {
                            HStack {
                                Text(sessionType.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if filter.selectedClassTypes.contains(sessionType.id) {
                                    Image(systemName: SFSymbol.checkmark)
                                        .foregroundStyle(Color.HeatLab.coral)
                                }
                            }
                        }
                    }
                }

                // Temperature Section
                Section("Temperature") {
                    ForEach(TemperatureBucket.allCases, id: \.self) { bucket in
                        Button {
                            toggleTemperatureBucket(bucket)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(colorForBucket(bucket))
                                    .frame(width: 12, height: 12)
                                Text(bucket.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if filter.selectedTemperatureBuckets.contains(bucket) {
                                    Image(systemName: SFSymbol.checkmark)
                                        .foregroundStyle(Color.HeatLab.coral)
                                }
                            }
                        }
                    }
                }

                // Date Range Section
                Section("Date Range") {
                    DatePicker(
                        "From",
                        selection: Binding(
                            get: { filter.startDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date())! },
                            set: { filter.startDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .onChange(of: filter.startDate) { _, newValue in
                        if newValue == nil {
                            // Already nil, do nothing
                        }
                    }

                    DatePicker(
                        "To",
                        selection: Binding(
                            get: { filter.endDate ?? Date() },
                            set: { filter.endDate = $0 }
                        ),
                        displayedComponents: .date
                    )

                    if filter.startDate != nil || filter.endDate != nil {
                        Button("Clear Date Range", role: .destructive) {
                            filter.startDate = nil
                            filter.endDate = nil
                        }
                    }
                }

                // Clear All Filters
                if filter.hasActiveFilters {
                    Section {
                        Button("Clear All Filters", role: .destructive) {
                            filter.clear()
                        }
                    }
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func toggleClassType(_ id: UUID) {
        if filter.selectedClassTypes.contains(id) {
            filter.selectedClassTypes.remove(id)
        } else {
            filter.selectedClassTypes.insert(id)
        }
    }

    private func toggleTemperatureBucket(_ bucket: TemperatureBucket) {
        if filter.selectedTemperatureBuckets.contains(bucket) {
            filter.selectedTemperatureBuckets.remove(bucket)
        } else {
            filter.selectedTemperatureBuckets.insert(bucket)
        }
    }

    private func colorForBucket(_ bucket: TemperatureBucket) -> Color {
        switch bucket {
        case .unheated: return .gray
        case .warm: return Color.HeatLab.tempWarm
        case .hot: return Color.HeatLab.tempHot
        case .veryHot: return Color.HeatLab.tempVeryHot
        case .extreme: return Color.HeatLab.tempExtreme
        }
    }
}

// MARK: - Filter Toolbar Button

struct FilterToolbarButton: View {
    @Binding var filter: SessionFilter
    @Binding var showingFilterSheet: Bool

    var body: some View {
        Button {
            showingFilterSheet = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle\(filter.hasActiveFilters ? ".fill" : "")")
                if filter.hasActiveFilters {
                    Text("\(filter.activeFilterCount)")
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
        .tint(filter.hasActiveFilters ? Color.HeatLab.coral : .primary)
    }
}

// MARK: - Active Filters Bar

struct ActiveFiltersBar: View {
    @Binding var filter: SessionFilter
    @Environment(UserSettings.self) var userSettings

    var body: some View {
        if filter.hasActiveFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HeatLabSpacing.xs) {
                    // Class type chips
                    ForEach(Array(filter.selectedClassTypes), id: \.self) { typeId in
                        if let name = userSettings.sessionTypeName(for: typeId) {
                            FilterChip(label: name) {
                                filter.selectedClassTypes.remove(typeId)
                            }
                        }
                    }

                    // Temperature chips
                    ForEach(Array(filter.selectedTemperatureBuckets), id: \.self) { bucket in
                        FilterChip(label: bucket.displayName, color: colorForBucket(bucket)) {
                            filter.selectedTemperatureBuckets.remove(bucket)
                        }
                    }

                    // Date range chip
                    if filter.startDate != nil || filter.endDate != nil {
                        FilterChip(label: dateRangeLabel) {
                            filter.startDate = nil
                            filter.endDate = nil
                        }
                    }
                }
                .padding(.horizontal, HeatLabSpacing.md)
                .padding(.vertical, HeatLabSpacing.xs)
            }
            .background(Color(.systemGray6))
        }
    }

    private var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short

        if let start = filter.startDate, let end = filter.endDate {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else if let start = filter.startDate {
            return "From \(formatter.string(from: start))"
        } else if let end = filter.endDate {
            return "Until \(formatter.string(from: end))"
        }
        return "Date"
    }

    private func colorForBucket(_ bucket: TemperatureBucket) -> Color {
        switch bucket {
        case .unheated: return .gray
        case .warm: return Color.HeatLab.tempWarm
        case .hot: return Color.HeatLab.tempHot
        case .veryHot: return Color.HeatLab.tempVeryHot
        case .extreme: return Color.HeatLab.tempExtreme
        }
    }
}

struct FilterChip: View {
    let label: String
    var color: Color = Color.HeatLab.coral
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)

            Button {
                onRemove()
            } label: {
                Image(systemName: SFSymbol.xmark)
                    .font(.caption2)
                    .fontWeight(.bold)
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, HeatLabSpacing.sm)
        .padding(.vertical, HeatLabSpacing.xxs)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

#Preview {
    SessionFilterSheet(filter: .constant(SessionFilter()))
        .environment(UserSettings())
}
