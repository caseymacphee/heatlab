//
//  DurationTimelineSlider.swift
//  heatlab
//
//  Timeline slider for adjusting session duration
//

import SwiftUI

struct DurationTimelineSlider: View {
    let maxDuration: TimeInterval // Full session duration
    @Binding var selectedDuration: TimeInterval // Currently selected duration

    @State private var isDragging: Bool = false

    private let sliderHeight: CGFloat = 48
    private let indicatorWidth: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Duration display
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Duration")
                        .font(.headline)
                    Text("Drag to adjust session length")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(formatDuration(selectedDuration))
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.blue)
            }

            // Timeline bar
            GeometryReader { geometry in
                let width = geometry.size.width

                // Calculate progress (0 to 1)
                let progress = selectedDuration / maxDuration
                let fillWidth = width * CGFloat(progress)

                ZStack(alignment: .leading) {
                    // Background bar (full duration)
                    RoundedRectangle(cornerRadius: sliderHeight / 2)
                        .fill(Color(.systemGray5))
                        .frame(height: sliderHeight)

                    // Active portion (selected duration) - fills to the edge
                    RoundedRectangle(cornerRadius: sliderHeight / 2)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(sliderHeight / 2, fillWidth), height: sliderHeight)

                    // Vertical indicator line at the end of active portion
                    if fillWidth > sliderHeight / 2 && fillWidth < width - sliderHeight / 2 {
                        RoundedRectangle(cornerRadius: indicatorWidth / 2)
                            .fill(Color.white)
                            .frame(width: indicatorWidth, height: sliderHeight * 0.6)
                            .offset(x: fillWidth)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let newPosition = max(0, min(width, value.location.x))
                            let newProgress = newPosition / width
                            selectedDuration = max(0, min(maxDuration, maxDuration * Double(newProgress)))
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: sliderHeight)

            // Time labels
            HStack {
                Text("0:00")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatDuration(maxDuration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    @Previewable @State var duration: TimeInterval = 120
    
    VStack {
        DurationTimelineSlider(
            maxDuration: 3600,
            selectedDuration: $duration
        )
        .padding()
        
        Text("Selected: \(Int(duration)) seconds")
    }
}
