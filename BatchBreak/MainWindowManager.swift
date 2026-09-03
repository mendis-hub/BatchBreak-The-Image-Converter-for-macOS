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
    
    private override init() {
        super.init()
    }
    
    func register(window: NSWindow) {
        // Never register the splash window as the main window
        if window.identifier?.rawValue == "BatchBreakSplashWindow" {
            return
        }
        
        guard self.mainWindow !== window else { return }
        
        // If an existing main window is already registered, close any newcomer to prevent duplicates
        if let existing = self.mainWindow, existing !== window {
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
    
    func showMainWindow() {
        // While showing and interacting with the main window, ensure regular activation policy
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        
        let activateWindow = { (window: NSWindow) in
            window.alphaValue = 1.0
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            
            // Re-assert frontmost order on the next runloop turn once activation policy finishes propagating
            DispatchQueue.main.async {
                window.orderFrontRegardless()
                window.makeKeyAndOrderFront(nil)
                NSRunningApplication.current.activate(options: [.activateAllWindows])
                if #available(macOS 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
        
        if let window = mainWindow {
            // Dismiss any accidental duplicate windows
            for otherWindow in NSApp.windows {
                if otherWindow !== window && otherWindow.identifier?.rawValue != "BatchBreakSplashWindow" && !(otherWindow is NSPanel) && otherWindow.className != "NSStatusBarWindow" && otherWindow.canBecomeKey {
                    otherWindow.orderOut(nil)
                    otherWindow.close()
                }
            }
            activateWindow(window)
            return
        }
        
        // Fallback: locate main application window if reference wasn't captured yet
        var foundMain: NSWindow?
        for window in NSApp.windows {
            if window.identifier?.rawValue == "BatchBreakSplashWindow" || window.className.contains("Splash") {
                continue
            }
            if !(window is NSPanel) && window.className != "NSStatusBarWindow" && window.canBecomeKey {
                if foundMain == nil {
                    foundMain = window
                    register(window: window)
                } else {
                    // Duplicate found, close it
                    window.orderOut(nil)
                    window.close()
                }
            }
        }
        
        if let window = foundMain {
            activateWindow(window)
        } else {
            // Broadcast notification in case SwiftUI can handle reopening
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
        }
    }
    
    func openWithFiles(urls: [URL]) {
        showMainWindow()
        // Allow the window a slight beat to be visible and active before posting files
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .openWithDroppedFiles, object: urls)
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
