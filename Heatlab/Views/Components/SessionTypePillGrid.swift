//
//  SessionTypePillGrid.swift
//  heatlab
//
//  Pill grid for selecting session type (toggle behavior)
//

import SwiftUI

struct SessionTypePillGrid: View {
    let sessionTypes: [SessionTypeConfig]
    @Binding var selectedTypeId: UUID?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(sessionTypes) { type in
                SessionTypePill(
                    name: type.name,
                    isSelected: selectedTypeId == type.id,
                    action: {
                        selectedTypeId = selectedTypeId == type.id ? nil : type.id
                    }
                )
            }
        }
    }
}

private struct SessionTypePill: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                }
                Text(name)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.hlAccent.opacity(0.15) : Color.hlSurface2)
            .foregroundStyle(isSelected ? Color.hlAccent : .primary)
            .clipShape(RoundedRectangle(cornerRadius: HLRadius.chip))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        SessionTypePillGrid(
            sessionTypes: SessionTypeConfig.defaults,
            selectedTypeId: .constant(nil)
        )

        SessionTypePillGrid(
            sessionTypes: SessionTypeConfig.defaults,
            selectedTypeId: .constant(SessionTypeConfig.DefaultTypeID.vinyasa)
        )
    }
    .padding()
    .background(Color.hlBackground)
}
