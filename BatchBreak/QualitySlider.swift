//
//  QualitySlider.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-08-30.
//

import SwiftUI
import AppKit
import AudioToolbox

struct QualitySlider: View {
    @Binding var value: Double // 0.0 to 1.0
    @State private var isDragging: Bool = false
    @State private var isHovered: Bool = false
    @State private var lastFeedbackPercent: Int = -1
    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let trackHeight: CGFloat = 24
            let thumbWidth: CGFloat = 22
            let availableWidth = max(totalWidth - thumbWidth - 4, 1)
            let thumbOffset = CGFloat(value) * availableWidth
            
            ZStack(alignment: .leading) {
                // Background Track Capsule
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
                    )
                
                // Vertical Tick Marks inside the track
                HStack(spacing: 3) {
                    ForEach(0..<Int(totalWidth / 4.5), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(Color.primary.opacity(0.18))
                            .frame(width: 1, height: 11)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipped()
                .padding(.horizontal, 6)
                
                // Apple Native Liquid Glass Handle Thumb
                Capsule()
                    .fill(Color.clear)
                    .frame(width: thumbWidth, height: trackHeight - 4)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .shadow(color: Color.black.opacity(isDragging ? 0.22 : 0.14), radius: isDragging ? 4 : 2, x: 0, y: 1)
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.15), lineWidth: 0.8)
                    )
                    .offset(x: thumbOffset + 2)
            }
            .frame(height: trackHeight)
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let locationX = gesture.location.x - (thumbWidth / 2)
                        let newValue = min(max(0, locationX / availableWidth), 1.0)
                        let currentPercent = Int((newValue * 100).rounded())
                        
                        if lastFeedbackPercent != currentPercent {
                            lastFeedbackPercent = currentPercent
                            playSliderFeedback()
                        }
                        
                        value = Double(newValue)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onAppear {
                lastFeedbackPercent = Int((value * 100).rounded())
            }
        }
        .frame(width: 150, height: 24)
    }
    
    // MARK: - Audio & Haptic Feedback
    private func playSliderFeedback() {
        AudioServicesPlaySystemSound(1104)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }
}

#Preview {
    QualitySlider(value: .constant(0.8))
        .padding()
}
