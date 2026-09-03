//
//  MenuBarManager.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-09-03.
//

import SwiftUI
import AppKit

final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem?
    private var dropPanel: NSPanel?
    private let dropViewState = MenuBarDropViewState()
    private var clickMonitor: Any?
    private var localClickMonitor: Any?
    private var dragEventMonitor: Any?
    private var dragCheckTimer: Timer?
    private var lastDragChangeCount: Int = -1
    
    private(set) var isPanelVisible: Bool = false
    
    var isCursorInsidePanel: Bool {
        guard let panel = dropPanel else { return false }
        return panel.frame.contains(NSEvent.mouseLocation)
    }
    
    private override init() {
        super.init()
    }
    
    func setup() {
        guard statusItem == nil else { return }
        
        // Initial state of the system drag pasteboard
        lastDragChangeCount = NSPasteboard(name: .drag).changeCount
        
        // Create status bar item with variable width
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.appearance = nil
            button.window?.appearance = nil
            button.image = createStatusItemIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "BatchBreak - Drag and drop your files here to convert"
            
            // Register button for drag types as well
            button.registerForDraggedTypes([
                .fileURL,
                NSPasteboard.PasteboardType("public.file-url"),
                NSPasteboard.PasteboardType("NSFilenamesPboardType")
            ])
            
            // Add custom overlay view for drag-and-drop & click handling
            let overlay = MenuBarStatusItemOverlayView()
            overlay.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(overlay)
            
            // Pin overlay firmly to button bounds using Auto Layout
            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                overlay.topAnchor.constraint(equalTo: button.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
            
            overlay.onDragEntered = { [weak self] in
                self?.showDropPanel()
            }
            overlay.onDropURLs = { [weak self] urls in
                self?.handleDrop(urls: urls)
            }
            overlay.onClick = { [weak self] in
                self?.toggleDropPanel()
            }
            overlay.onRightClick = { [weak self] in
                self?.showContextMenu()
            }
        }
        self.statusItem = item
        
        setupDropPanel()
        startDragMonitoring()
    }
    
    func ensureSystemAppearance() {
        if let button = statusItem?.button {
            button.appearance = nil
            button.window?.appearance = nil
        }
    }
    
    func teardown() {
        stopDragMonitoring()
        removeClickMonitor()
        dropViewState.reset()
        dropPanel?.close()
        dropPanel = nil
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
    
    // MARK: - Global Drag Monitoring (Auto Popup Below Menu Bar on Drag Start)
    private func startDragMonitoring() {
        // 1. High-frequency timer running in .common modes (ticks even during event tracking loops)
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkDragPasteboard()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.dragCheckTimer = timer
        
        // 2. Global mouse event monitor for dragged events
        dragEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            self?.checkDragPasteboard()
        }
    }
    
    private func stopDragMonitoring() {
        dragCheckTimer?.invalidate()
        dragCheckTimer = nil
        
        if let monitor = dragEventMonitor {
            NSEvent.removeMonitor(monitor)
            dragEventMonitor = nil
        }
    }
    
    private func checkDragPasteboard() {
        let isLeftMouseDown = (NSEvent.pressedMouseButtons & 1) != 0
        guard isLeftMouseDown else { return }
        
        // Only trigger if the panel is not already presented
        guard !isPanelVisible else { return }
        
        let pb = NSPasteboard(name: .drag)
        let count = pb.changeCount
        guard count != lastDragChangeCount else { return }
        
        let types = pb.types ?? []
        let hasFileTypes = types.contains(.fileURL) ||
                           types.contains(NSPasteboard.PasteboardType("public.file-url")) ||
                           types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        
        if hasFileTypes {
            lastDragChangeCount = count
            // User just started dragging files! Pop up the drop box right below the menu bar icon
            showDropPanel()
        }
    }
    
    // MARK: - Drop Panel Configuration
    private func setupDropPanel() {
        let panelSize = MenuBarDropView.panelSize
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        // Position above normal windows and status bar so it is always accessible while dragging
        panel.level = .popUpMenu
        // CRITICAL: Prevent macOS from hiding the panel when Finder or other apps are active
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        
        let dropView = MenuBarDropView(
            state: dropViewState,
            onDropURLs: { [weak self] urls in
                self?.handleDrop(urls: urls)
            },
            onOpenApp: { [weak self] in
                self?.hideDropPanel()
                MainWindowManager.shared.showMainWindow()
            },
            onOpenSettings: { [weak self] in
                self?.hideDropPanel()
                SettingsWindowManager.shared.showSettingsWindow()
            },
            onDismiss: { [weak self] in
                self?.hideDropPanel()
            }
        )
        
        let hostingView = NSHostingView(rootView: dropView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 18
        hostingView.layer?.masksToBounds = false
        panel.contentView = hostingView
        self.dropPanel = panel
    }
    
    // MARK: - Show / Hide / Toggle
    func toggleDropPanel() {
        if isPanelVisible {
            hideDropPanel()
        } else {
            showDropPanel()
        }
    }
    
    func showDropPanel() {
        guard let panel = dropPanel else { return }
        // Reset state only when reopening so user always sees the clean drop area\
        dropViewState.reset()
        
        if let button = statusItem?.button {
            positionPanelUnderStatusItem(panel, relativeTo: button)
        }
        
        if !isPanelVisible {
            panel.alphaValue = 0
            panel.hasShadow = true
            panel.invalidateShadow()
            panel.orderFrontRegardless()
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 1.0
            } completionHandler: {
                panel.invalidateShadow()
            }
            
            DispatchQueue.main.async {
                panel.invalidateShadow()
            }
            
            isPanelVisible = true
            setupClickMonitor()
        }
    }
    
    func hideDropPanel() {
        guard let panel = dropPanel, isPanelVisible else { return }
        removeClickMonitor()
        isPanelVisible = false
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            if !self.isPanelVisible {
                panel.orderOut(nil)
                // Reset state only AFTER the panel is completely invisible and dismissed
                self.dropViewState.reset()
            }
        })
    }
    
    // MARK: - Outside Click Monitor (Dismisses only when user clicks outside the window)
    private func setupClickMonitor() {
        // 1. Global monitor for mouse clicks occurring in other applications
        if clickMonitor == nil {
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                guard let self = self, self.isPanelVisible else { return }
                let mouseLocation = NSEvent.mouseLocation
                
                // Keep open if mouse click is inside drop panel
                if let panel = self.dropPanel, panel.frame.contains(mouseLocation) {
                    return
                }
                
                // Keep open if click is on the status item button itself
                if let button = self.statusItem?.button, let window = button.window {
                    let buttonFrame = button.convert(button.bounds, to: nil)
                    let screenRect = window.convertToScreen(buttonFrame)
                    if screenRect.contains(mouseLocation) {
                        return
                    }
                }
                
                // User clicked outside the popup window -> Dismiss
                DispatchQueue.main.async {
                    self.hideDropPanel()
                }
            }
        }
        
        // 2. Local monitor for mouse clicks occurring inside BatchBreak windows
        if localClickMonitor == nil {
            localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self, self.isPanelVisible else { return event }
                let mouseLocation = NSEvent.mouseLocation
                
                if let panel = self.dropPanel, panel.frame.contains(mouseLocation) {
                    return event
                }
                if let button = self.statusItem?.button, let window = button.window {
                    let buttonFrame = button.convert(button.bounds, to: nil)
                    let screenRect = window.convertToScreen(buttonFrame)
                    if screenRect.contains(mouseLocation) {
                        return event
                    }
                }
                
                // User clicked outside the popup window -> Dismiss
                DispatchQueue.main.async {
                    self.hideDropPanel()
                }
                return event
            }
        }
    }
    
    private func removeClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }
    
    // MARK: - Handle Dropped URLs
    func handleDrop(urls: [URL]) {
        hideDropPanel()
        MainWindowManager.shared.openWithFiles(urls: urls)
    }
    
    // MARK: - Context Menu
    func showContextMenu() {
        hideDropPanel()
        guard let button = statusItem?.button else { return }
        
        let menu = NSMenu()
        
        let openItem = NSMenuItem(title: "Open BatchBreak", action: #selector(openAppFromMenu), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let aboutItem = NSMenuItem(title: "About BatchBreak", action: #selector(openAboutFromMenu), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit BatchBreak", action: #selector(quitAppFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        if let event = NSApp.currentEvent {
            NSMenu.popUpContextMenu(menu, with: event, for: button)
        }
    }
    
    @objc private func openAppFromMenu() {
        MainWindowManager.shared.showMainWindow()
    }
    
    @objc private func openSettingsFromMenu() {
        SettingsWindowManager.shared.showSettingsWindow()
    }
    
    @objc private func openAboutFromMenu() {
        MainWindowManager.shared.showMainWindow()
        NotificationCenter.default.post(name: .showAboutSheet, object: nil)
    }
    
    @objc private func quitAppFromMenu() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Positioning Drop Panel Under Status Item
    private func positionPanelUnderStatusItem(_ panel: NSPanel, relativeTo button: NSStatusBarButton) {
        let panelWidth = MenuBarDropView.cardWidth
        let panelHeight = MenuBarDropView.cardHeight
        let gapFromStatusBar: CGFloat = 8
        
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        if let window = button.window {
            let buttonFrame = button.convert(button.bounds, to: nil)
            let screenRect = window.convertToScreen(buttonFrame)
            x = screenRect.midX - (panelWidth / 2)
            y = screenRect.minY - panelHeight - gapFromStatusBar
            
            if let screen = window.screen ?? NSScreen.main {
                let screenFrame = screen.visibleFrame
                if x < screenFrame.minX + 10 {
                    x = screenFrame.minX + 10
                } else if x + panelWidth > screenFrame.maxX - 10 {
                    x = screenFrame.maxX - panelWidth - 10
                }
                if y < screenFrame.minY + 10 {
                    y = screenFrame.minY + 10
                }
            }
        } else if let screen = NSScreen.main ?? NSScreen.screens.first {
            let screenFrame = screen.visibleFrame
            x = screenFrame.maxX - panelWidth - 20
            y = screenFrame.maxY - panelHeight - 12
        }
        
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
    
    // MARK: - Icon Generator
    private func createStatusItemIcon() -> NSImage {
        let targetSize = NSSize(width: 18, height: 18)
        
        // 1. Try loading custom menu bar icon symbol from Asset Catalog
        if let customImage = NSImage(named: "MenuBarIcon") {
            let image = customImage.copy() as! NSImage
            image.size = targetSize
            image.isTemplate = true
            return image
        }
        
        // 2. Native SF Symbol fallback that matches the app concept
        if let symbol = NSImage(systemSymbolName: "photo.stack", accessibilityDescription: "BatchBreak") {
            symbol.isTemplate = true
            return symbol
        }
        
        let fallback = NSImage(size: targetSize)
        fallback.isTemplate = true
        return fallback
    }
}

// MARK: - Overlay View on Status Item Button
final class MenuBarStatusItemOverlayView: NSView {
    var onDragEntered: (() -> Void)?
    var onDropURLs: (([URL]) -> Void)?
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    
    private var isDraggingOver = false
    
    override init(frame frameRect: NSRect = .zero) {
        super.init(frame: frameRect)
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ])
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isDraggingOver {
            let rect = bounds.insetBy(dx: 2, dy: 2)
            let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
            NSColor.controlAccentColor.withAlphaComponent(0.35).setFill()
            path.fill()
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
    
    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }
    
    // MARK: - Drag and Drop Protocol
    
    private func canAcceptDrag(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: nil) {
            return true
        }
        let types = pasteboard.types ?? []
        return types.contains(.fileURL) ||
               types.contains(NSPasteboard.PasteboardType("public.file-url")) ||
               types.contains(NSPasteboard.PasteboardType("NSFilenamesPboardType"))
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canAcceptDrag(sender) else { return [] }
        isDraggingOver = true
        needsDisplay = true
        (superview as? NSStatusBarButton)?.highlight(true)
        onDragEntered?()
        return .copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canAcceptDrag(sender) else { return [] }
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDraggingOver = false
        needsDisplay = true
        (superview as? NSStatusBarButton)?.highlight(false)
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return canAcceptDrag(sender)
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDraggingOver = false
        needsDisplay = true
        (superview as? NSStatusBarButton)?.highlight(false)
        
        let urls = extractURLs(from: sender)
        guard !urls.isEmpty else { return false }
        onDropURLs?(urls)
        return true
    }
    
    private func extractURLs(from sender: NSDraggingInfo) -> [URL] {
        let pasteboard = sender.draggingPasteboard
        
        // 1. Try reading NSURLs directly with file URL filter
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            return urls
        }
        
        // 2. Try general NSURL reading
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            let fileUrls = urls.filter { $0.isFileURL }
            if !fileUrls.isEmpty { return fileUrls }
        }
        
        // 3. Fallback to NSFilenamesPboardType property list
        if let paths = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            return paths.map { URL(fileURLWithPath: $0) }
        }
        
        return []
    }
}
