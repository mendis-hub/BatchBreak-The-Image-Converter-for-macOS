//
//  PhotoCardView.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-08-30.
//

import SwiftUI
import AppKit
import QuickLook

struct PhotoCardView: View {
    let item: PhotoItem
    let format: OutputFormat
    let quality: Double
    let isSelected: Bool
    let onSelect: (Bool) -> Void
    let onQuickLook: () -> Void
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
                                .stroke(isSelected ? Color.blue : Color.primary.opacity(0.08), lineWidth: isSelected ? 2.5 : 1)
                        )
                        .shadow(color: isSelected ? Color.blue.opacity(0.25) : Color.black.opacity(0.06), radius: isSelected ? 8 : 6, x: 0, y: 3)
                    
                    // Selected Checkmark Badge (Top Left)
                    if isSelected {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.white, Color.blue)
                                .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                                .padding(8)
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                    
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
                    .foregroundStyle(isSelected ? .blue : .primary)
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
        .contentShape(Rectangle())
        .onTapGesture {
            let isCommand = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
            onSelect(isCommand)
        }
        .overlay(
            PhotoContextMenuOverlay(
                onRightClickSelect: {
                    if !isSelected {
                        onSelect(false)
                    }
                },
                onQuickLook: onQuickLook,
                onShowOriginal: showOriginal,
                onCopyImage: copyImage,
                onCopyFilePath: copyFilePath,
                onDelete: onDelete
            )
        )
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
    
    // MARK: - Actions
    
    private func showOriginal() {
        item.withSecurityScopedAccess {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }
    }
    
    private func copyFilePath() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.url.path, forType: .string)
    }
    
    private func copyImage() {
        item.withSecurityScopedAccess {
            if let image = NSImage(contentsOf: item.url) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([image])
            } else if let thumbnail = loadedImage {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([thumbnail])
            }
        }
    }
}

// MARK: - Native AppKit Context Menu Overlay
struct PhotoContextMenuOverlay: NSViewRepresentable {
    let onRightClickSelect: () -> Void
    let onQuickLook: () -> Void
    let onShowOriginal: () -> Void
    let onCopyImage: () -> Void
    let onCopyFilePath: () -> Void
    let onDelete: () -> Void
    
    func makeNSView(context: Context) -> RightClickNSView {
        let view = RightClickNSView()
        view.onRightClickSelect = onRightClickSelect
        view.onQuickLook = onQuickLook
        view.onShowOriginal = onShowOriginal
        view.onCopyImage = onCopyImage
        view.onCopyFilePath = onCopyFilePath
        view.onDelete = onDelete
        return view
    }
    
    func updateNSView(_ nsView: RightClickNSView, context: Context) {
        nsView.onRightClickSelect = onRightClickSelect
        nsView.onQuickLook = onQuickLook
        nsView.onShowOriginal = onShowOriginal
        nsView.onCopyImage = onCopyImage
        nsView.onCopyFilePath = onCopyFilePath
        nsView.onDelete = onDelete
    }
    
    class RightClickNSView: NSView {
        var onRightClickSelect: (() -> Void)?
        var onQuickLook: (() -> Void)?
        var onShowOriginal: (() -> Void)?
        var onCopyImage: (() -> Void)?
        var onCopyFilePath: (() -> Void)?
        var onDelete: (() -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? {
            if let currentEvent = NSApp.currentEvent,
               currentEvent.type == .rightMouseDown || currentEvent.type == .rightMouseUp {
                return self
            }
            return nil
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            onRightClickSelect?()
            
            let menu = NSMenu()
            menu.autoenablesItems = false
            
            // 1. Quick Look
            let quickLookItem = NSMenuItem(title: "Quick Look", action: #selector(quickLookAction), keyEquivalent: "")
            quickLookItem.target = self
            menu.addItem(quickLookItem)
            
            // 2. Show Original
            let showOriginalItem = NSMenuItem(title: "Show Original", action: #selector(showOriginalAction), keyEquivalent: "")
            showOriginalItem.target = self
            menu.addItem(showOriginalItem)
            
            // 3. Copy Options Submenu
            let copyMenu = NSMenu()
            copyMenu.autoenablesItems = false
            
            let copyImageItem = NSMenuItem(title: "Copy Image", action: #selector(copyImageAction), keyEquivalent: "")
            copyImageItem.target = self
            copyMenu.addItem(copyImageItem)
            
            let copyPathItem = NSMenuItem(title: "Copy File Path", action: #selector(copyFilePathAction), keyEquivalent: "")
            copyPathItem.target = self
            copyMenu.addItem(copyPathItem)
            
            let copyOptionsItem = NSMenuItem(title: "Copy Options", action: nil, keyEquivalent: "")
            copyOptionsItem.submenu = copyMenu
            menu.addItem(copyOptionsItem)
            
            // 4. Separator
            menu.addItem(.separator())
            
            // 5. Delete (Red text)
            let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteAction), keyEquivalent: "")
            deleteItem.target = self
            
            let redColor = NSColor.systemRed
            let redAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: redColor,
                .font: NSFont.menuFont(ofSize: 13)
            ]
            deleteItem.attributedTitle = NSAttributedString(string: "Delete", attributes: redAttrs)
            
            menu.addItem(deleteItem)
            
            return menu
        }
        
        @objc private func quickLookAction() {
            onQuickLook?()
        }
        
        @objc private func showOriginalAction() {
            onShowOriginal?()
        }
        
        @objc private func copyImageAction() {
            onCopyImage?()
        }
        
        @objc private func copyFilePathAction() {
            onCopyFilePath?()
        }
        
        @objc private func deleteAction() {
            onDelete?()
        }
    }
}
