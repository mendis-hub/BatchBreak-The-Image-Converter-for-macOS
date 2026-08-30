//
//  QualitySlider.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-08-30.
//

import SwiftUI

struct QualitySlider: View {
    @Binding var value: Double // 0.0 to 1.0
    
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
                
                // Fully Rounded Capsule Handle Thumb (Matching background track)
                Capsule()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 2.5, x: 0, y: 1)
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.12), lineWidth: 0.8)
                    )
                    .frame(width: thumbWidth, height: trackHeight - 4)
                    .offset(x: thumbOffset + 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let locationX = gesture.location.x - (thumbWidth / 2)
                                let newValue = min(max(0, locationX / availableWidth), 1.0)
                                value = Double(newValue)
                            }
                    )
            }
            .frame(height: trackHeight)
        }
        .frame(width: 150, height: 24)
    }
}
