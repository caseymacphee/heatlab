//
//  FilterPillRow.swift
//  heatlab
//
//  Compact horizontal filter pills for Analysis view
//

import SwiftUI

struct FilterPillRow: View {
    @Binding var selectedTemperature: TemperatureBucket?
    @Binding var selectedClassType: UUID?
    @Environment(UserSettings.self) var settings

    var hasActiveFilters: Bool {
        selectedTemperature != nil || selectedClassType != nil
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Temperature filter pill
                Menu {
                    Button("All Temperatures") {
                        selectedTemperature = nil
                    }
                    Divider()
                    ForEach(TemperatureBucket.allCases, id: \.self) { bucket in
                        Button(bucket.displayName) {
                            selectedTemperature = bucket
                        }
                    }
                } label: {
                    FilterPill(
                        title: selectedTemperature?.displayName ?? "Temperature",
                        isActive: selectedTemperature != nil,
                        icon: SFSymbol.thermometer
                    )
                }

                // Class type filter pill
                Menu {
                    Button("All Classes") {
                        selectedClassType = nil
                    }
                    Divider()
                    ForEach(settings.visibleSessionTypes, id: \.id) { sessionType in
                        Button(sessionType.name) {
                            selectedClassType = sessionType.id
                        }
                    }
                } label: {
                    FilterPill(
                        title: selectedClassTypeName ?? "Class",
                        isActive: selectedClassType != nil,
                        icon: SFSymbol.yoga
                    )
                }

                // Clear filters button (only when filters active)
                if hasActiveFilters {
                    Button {
                        withAnimation {
                            selectedTemperature = nil
                            selectedClassType = nil
                        }
                    } label: {
                        Image(systemName: SFSymbol.xmark)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var selectedClassTypeName: String? {
        guard let id = selectedClassType else { return nil }
        return settings.sessionTypeName(for: id)
    }
}

struct FilterPill: View {
    let title: String
    let isActive: Bool
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
            }
            Text(title)
                .font(.subheadline)
            Image(systemName: SFSymbol.chevronDown)
                .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.HeatLab.coral.opacity(0.15) : Color(.systemGray6))
        .foregroundStyle(isActive ? Color.HeatLab.coral : .primary)
        .clipShape(Capsule())
    }
}

#Preview {
    VStack {
        FilterPillRow(
            selectedTemperature: .constant(nil),
            selectedClassType: .constant(nil)
        )

        FilterPillRow(
            selectedTemperature: .constant(.hot),
            selectedClassType: .constant(nil)
        )
    }
    .padding()
    .environment(UserSettings())
}
