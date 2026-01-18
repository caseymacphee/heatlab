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
    @State private var dragStartPosition: CGFloat = 0
    
    private let sliderHeight: CGFloat = 60
    private let indicatorWidth: CGFloat = 4
    private let handleSize: CGFloat = 24
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Duration display
            HStack {
                Text("Duration")
                    .font(.headline)
                Spacer()
                Text(formatDuration(selectedDuration))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            
            // Timeline bar
            GeometryReader { geometry in
                let width = geometry.size.width
                let maxPosition = width - handleSize / 2
                let minPosition = handleSize / 2
                
                // Calculate position based on selected duration
                let position = minPosition + (maxPosition - minPosition) * CGFloat(selectedDuration / maxDuration)
                
                ZStack(alignment: .leading) {
                    // Background bar (full duration)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: sliderHeight)
                    
                    // Active portion (selected duration)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: position, height: sliderHeight)
                    
                    // Draggable indicator line with handle
                    HStack(spacing: 0) {
                        // Vertical line
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: indicatorWidth, height: sliderHeight)
                        
                        // Handle circle for dragging
                        Circle()
                            .fill(Color.blue)
                            .frame(width: handleSize, height: handleSize)
                            .overlay {
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: handleSize, height: handleSize)
                            }
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .offset(x: position - handleSize / 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStartPosition = position
                            }
                            let newPosition = max(minPosition, min(maxPosition, dragStartPosition + value.translation.width))
                            let progress = (newPosition - minPosition) / (maxPosition - minPosition)
                            selectedDuration = max(0, min(maxDuration, maxDuration * Double(progress)))
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
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
