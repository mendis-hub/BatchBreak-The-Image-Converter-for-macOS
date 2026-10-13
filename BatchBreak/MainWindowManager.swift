//
//  MainWindowManager.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-09-03.
//

import SwiftUI
import AppKit

extension Notification.Name {
    static let openWithDroppedFiles = Notification.Name("openWithDroppedFiles")
    static let openMainWindow = Notification.Name("openMainWindow")
}

final class MainWindowManager: NSObject, NSWindowDelegate {
    static let shared = MainWindowManager()
    
    // Hold a strong reference so the window isn't deallocated when ordered out before onboarding completes
    private(set) var mainWindow: NSWindow?
    
    // Handler to invoke SwiftUI openWindow for the main window when needed
    var openWindowHandler: (() -> Void)?
    
    // Queue of pending file URLs to open if main window is loading or transitioning
    private var pendingURLs: [URL] = []
    
    func popPendingFiles() -> [URL]? {
        guard !pendingURLs.isEmpty else { return nil }
        let urls = pendingURLs
        pendingURLs.removeAll()
        return urls
    }
    
    func isMainWindowCandidate(_ window: NSWindow) -> Bool {
        // Exclude utility panels, status bar, and windows that cannot become key
        if window is NSPanel || window.className == "NSStatusBarWindow" || !window.canBecomeKey {
            return false
        }
        
        // Exclude splash window
        if window.identifier?.rawValue == "BatchBreakSplashWindow" || window.className.contains("Splash") || window.title.contains("Welcome") {
            return false
        }
        
        // Exclude settings window
        if window.identifier?.rawValue == "BatchBreakSettingsWindow" || window.title == "Settings" || window.className.contains("Settings") {
            return false
        }
        if let settingsWindow = SettingsWindowManager.shared.currentWindow, window === settingsWindow {
            return false
        }
        
        return true
    }
    
    private override init() {
        super.init()
    }
    
    private func createMainWindow() -> NSWindow {
        let contentView = ContentView()
            .preferredColorScheme(AppSettings.shared.resolvedColorScheme)
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.identifier = NSUserInterfaceItemIdentifier("BatchBreakMainWindow")
        window.title = "BatchBreak"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 400)
        window.setContentSize(NSSize(width: 900, height: 572))
        window.center()
        return window
    }
    
    func register(window: NSWindow) {
        // Never register splash or settings windows as the main window
        guard isMainWindowCandidate(window) else { return }
        
        guard self.mainWindow !== window else { return }
        
        // If an existing main window is already registered and still valid, close any newcomer to prevent duplicates
        if let existing = self.mainWindow, existing !== window, isMainWindowCandidate(existing) {
            window.orderOut(nil)
            window.close()
            return
        }
        
        if window.identifier == nil {
            window.identifier = NSUserInterfaceItemIdentifier("BatchBreakMainWindow")
        }
        window.isReleasedWhenClosed = false
        self.mainWindow = window
        window.delegate = self
        
        // If onboarding is not completed yet, keep main window hidden until onboarding completes
        if !AppSettings.shared.hasCompletedOnboarding {
            window.orderOut(nil)
            DispatchQueue.main.async {
                if !AppSettings.shared.hasCompletedOnboarding {
                    window.orderOut(nil)
                }
            }
        } else {
            activate(window: window)
            // Deliver any pending files that were queued before window registration
            if let toDeliver = popPendingFiles(), !toDeliver.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NotificationCenter.default.post(name: .openWithDroppedFiles, object: toDeliver)
                }
            }
        }
    }
    
    // Intercept window close button so the app stays running in menu bar and leaves Dock if configured,
    // or quits completely if quitAppOnClose is enabled
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if AppSettings.shared.quitAppOnClose {
            NSApp.terminate(nil)
            return true
        }
        sender.orderOut(nil)
        DispatchQueue.main.async {
            AppSettings.shared.updateDockVisibility()
        }
        return false
    }
    
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            AppSettings.shared.updateDockVisibility()
        }
    }
    
    func activate(window: NSWindow) {
        window.alphaValue = 1.0
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        
        // Elevate window level temporarily so it immediately displays above Finder
        window.level = .floating
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.arrangeInFront(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        
        // Re-assert normal window level after presentation so it behaves as a standard window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            window.level = .normal
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    func showMainWindow() {
        // While showing and interacting with the main window, ensure regular activation policy
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        
        if let window = mainWindow, isMainWindowCandidate(window) {
            // Dismiss any accidental duplicate main windows (leaving settings and splash windows untouched)
            for otherWindow in NSApp.windows {
                if otherWindow !== window && isMainWindowCandidate(otherWindow) {
                    otherWindow.orderOut(nil)
                    otherWindow.close()
                }
            }
            activate(window: window)
            return
        }
        
        // Reset invalid reference if any
        self.mainWindow = nil
        
        // Fallback: locate main application window if reference wasn't captured yet
        var foundMain: NSWindow?
        for window in NSApp.windows {
            guard isMainWindowCandidate(window) else {
                continue
            }
            if foundMain == nil {
                foundMain = window
                register(window: window)
            } else {
                // Duplicate main window found, close it
                window.orderOut(nil)
                window.close()
            }
        }
        
        if let window = foundMain {
            activate(window: window)
        } else {
            // No main window exists yet (e.g. cold launch via Finder context menu / Service)
            // Create and present the main window directly via NSHostingController
            let window = createMainWindow()
            register(window: window)
            activate(window: window)
        }
    }
    
    func openWithFiles(urls: [URL]) {
        guard !urls.isEmpty else { return }
        pendingURLs.append(contentsOf: urls)
        showMainWindow()
        
        // If window is already registered, deliver after a slight delay
        if mainWindow != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self, let toDeliver = self.popPendingFiles(), !toDeliver.isEmpty else { return }
                NotificationCenter.default.post(name: .openWithDroppedFiles, object: toDeliver)
            }
        }
    }
}

// Helper NSViewRepresentable using viewDidMoveToWindow for immediate, rock-solid window capture
struct WindowAccessor: NSViewRepresentable {
    let onWindowFound: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = AccessorNSView()
        view.onWindowFound = onWindowFound
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let accessorView = nsView as? AccessorNSView {
            accessorView.onWindowFound = onWindowFound
            if let window = accessorView.window {
                onWindowFound(window)
            }
        }
    }
    
    private class AccessorNSView: NSView {
        var onWindowFound: ((NSWindow) -> Void)?
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window = window {
                onWindowFound?(window)
            }
        }
    }
}
