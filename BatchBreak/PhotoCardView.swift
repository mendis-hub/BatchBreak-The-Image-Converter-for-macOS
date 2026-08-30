//
//  PhotoCardView.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-08-30.
//

import SwiftUI

struct PhotoCardView: View {
    let item: PhotoItem
    let format: OutputFormat
    let quality: Double
    let onDelete: () -> Void
    
    @State private var loadedImage: NSImage? = nil
    @State private var isHovering: Bool = false
    @State private var isButtonHovered: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                // Main Thumbnail Container
                ZStack(alignment: .topTrailing) {
                    // Image thumbnail strictly bounded within 160pt height capsule
                    Color.clear
                        .frame(height: 160)
                        .overlay(
                            Group {
                                if let loadedImage = loadedImage {
                                    Image(nsImage: loadedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Rectangle()
                                        .fill(Color.primary.opacity(0.05))
                                        .overlay(
                                            ProgressView()
                                                .controlSize(.small)
                                        )
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                    
                    // Hover Delete Button - Always in hierarchy to avoid hover destroy/recreate loops
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(
                                Color.white,
                                isButtonHovered ? Color.red.opacity(0.9) : Color.black.opacity(0.7)
                            )
                            .scaleEffect(isButtonHovered ? 1.15 : 1.0)
                            .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                            .padding(8)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovering ? 1.0 : 0.0)
                    .allowsHitTesting(isHovering)
                    .onHover { inside in
                        isButtonHovered = inside
                        if inside {
                            NSCursor.pointingHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onHover { inside in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHovering = inside
                    }
                    if !inside {
                        isButtonHovered = false
                        NSCursor.arrow.set()
                    }
                }
                
                // Small file format indicator on the left bottom of photo
                Text(item.pageCount > 1 ? "\(item.fileExtension) · \(item.pageCount) pgs" : item.fileExtension)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.88))
                            .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                    )
                    .padding(.leading, 10)
                    .padding(.bottom, 10)
                    .allowsHitTesting(false)
            }
            
            // File details below image: Name and "Original Size → Output Size"
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                HStack(spacing: 4) {
                    Text(item.formattedSize)
                        .foregroundStyle(.secondary)
                    Text("→")
                        .foregroundStyle(.tertiary)
                    Text(item.formattedEstimatedSize(format: format, quality: quality))
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
        .onAppear {
            if loadedImage == nil {
                item.loadThumbnailAsync(targetSize: CGSize(width: 320, height: 320)) { img in
                    Task { @MainActor in
                        self.loadedImage = img
                    }
                }
            }
        }
    }
}
