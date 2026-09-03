//
//  MenuBarDropView.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-09-03.
//

import SwiftUI
import AppKit
import Combine

final class MenuBarDropViewState: ObservableObject {
    @Published var isTargeted: Bool = false
    @Published var isSuccessFlashed: Bool = false
    
    func reset() {
        isTargeted = false
        isSuccessFlashed = false
    }
}

struct MenuBarDropView: View {
    static let cardWidth: CGFloat = 286
    static let cardHeight: CGFloat = 216
    
    static var panelSize: CGSize {
        CGSize(width: cardWidth, height: cardHeight)
    }
    
    @ObservedObject var state: MenuBarDropViewState
    let onDropURLs: ([URL]) -> Void
    let onOpenApp: () -> Void
    let onDismiss: () -> Void
    
    @AppStorage("selectedOutputFormat") private var selectedOutputFormatRaw: String = OutputFormat.jpeg.rawValue
    
    private var selectedFormat: OutputFormat {
        get { OutputFormat(rawValue: selectedOutputFormatRaw) ?? .jpeg }
        nonmutating set { selectedOutputFormatRaw = newValue.rawValue }
    }
    
    var body: some View {
        cardContent
            .frame(width: Self.cardWidth, height: Self.cardHeight)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                // Specular Liquid Glass Edge Highlight
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.40), location: 0.0),
                                .init(color: Color.white.opacity(0.12), location: 0.35),
                                .init(color: Color.clear, location: 0.65),
                                .init(color: Color.white.opacity(0.08), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                // Subtle contrast stroke
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            // Make the entire card area receptive to dropped URLs
            .dropDestination(for: URL.self) { items, _ in
                handleDrop(items)
                return true
            } isTargeted: { targeted in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    state.isTargeted = targeted
                }
            }
            .onAppear {
                state.reset()
            }
    }
    
    private var cardContent: some View {
        VStack(spacing: 10) {
            // Header Bar
            HStack(spacing: 8) {
                if let _ = NSImage(named: "MenuBarIcon") {
                    Image("MenuBarIcon")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.accentColor)
                } else if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                } else {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                
                Text("BatchBreak")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button(action: onOpenApp) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Open BatchBreak")
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Close")
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            
            // Drop Target Box
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(state.isTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        state.isTargeted ? Color.accentColor : Color.primary.opacity(0.16),
                        style: StrokeStyle(lineWidth: state.isTargeted ? 2 : 1.5, dash: state.isTargeted ? [] : [6, 4])
                    )
                
                if state.isSuccessFlashed {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.green)
                        
                        Text("Opening in BatchBreak...")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    VStack(spacing: 5) {
                        if state.isTargeted {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                                .scaleEffect(1.15)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: state.isTargeted)
                        } else {
                            Image(systemName: "plus.viewfinder")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(Color.secondary)
                        }
                        
                        Text(state.isTargeted ? "Drop to Convert" : "Drop your files here")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(state.isTargeted ? Color.accentColor : Color.primary)
                        
                        // Output Formats Badges
                        HStack(spacing: 4) {
                            ForEach(OutputFormat.allCases) { format in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedFormat = format
                                    }
                                } label: {
                                    Text(format.rawValue)
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2.5)
                                        .background(
                                            selectedFormat == format
                                                ? Color.accentColor
                                                : Color.primary.opacity(0.06)
                                        )
                                        .foregroundStyle(
                                            selectedFormat == format
                                                ? Color.white
                                                : Color.secondary
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .help("Convert to \(format.rawValue)")
                                .onHover { inside in
                                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(height: 114)
            .padding(.horizontal, 12)
            
            // Bottom Action Bar
            HStack {
                Button(action: onOpenApp) {
                    Text("Open Window")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                
                Spacer()
                
                Button(action: {
                    NSApp.terminate(nil)
                }) {
                    Text("Quit")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }
    
    private func handleDrop(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            state.isSuccessFlashed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDropURLs(urls)
        }
    }
}
