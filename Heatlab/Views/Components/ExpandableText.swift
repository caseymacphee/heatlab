//
//  ExpandableText.swift
//  heatlab
//
//  Collapsible text component that shows 2 lines with "Show more" button if truncated
//

import SwiftUI

struct ExpandableText: View {
    let text: String
    let lineLimit: Int

    @State private var isExpanded = false
    @State private var isTruncated = false

    init(_ text: String, lineLimit: Int = 2) {
        self.text = text
        self.lineLimit = lineLimit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(isExpanded ? nil : lineLimit)
                .background(
                    // Measure if text is truncated
                    GeometryReader { visibleGeometry in
                        Text(text)
                            .font(.subheadline)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .background(
                                GeometryReader { fullGeometry in
                                    Color.clear
                                        .onAppear {
                                            isTruncated = fullGeometry.size.height > visibleGeometry.size.height + 1
                                        }
                                        .onChange(of: text) { _, _ in
                                            // Recalculate on text change
                                            isTruncated = fullGeometry.size.height > visibleGeometry.size.height + 1
                                        }
                                }
                            )
                            .hidden()
                    }
                )

            if isTruncated {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "Show less" : "Show more")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.hlAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("Short text (no truncation)") {
    ExpandableText("This is a short text that fits in two lines.")
        .padding()
}

#Preview("Long text (truncated)") {
    ExpandableText("Your heart rate of 142 bpm was 8% lower than your baseline for 100-104°F sessions. This indicates excellent heat adaptation. Your perceived effort of 'moderate' aligns well with the physiological data.")
        .padding()
}

#Preview("Very long text") {
    ExpandableText("Your heart rate of 142 bpm was 8% lower than your baseline for 100-104°F sessions, and 5% lower than your typical Vinyasa sessions. This indicates excellent heat adaptation across different class types. Your perceived effort of 'moderate' aligns well with the physiological data. Consider maintaining this intensity level for continued progress.")
        .padding()
}
