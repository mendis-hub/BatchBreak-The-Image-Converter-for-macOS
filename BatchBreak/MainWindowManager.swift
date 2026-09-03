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
}

final class MainWindowManager: NSObject, NSWindowDelegate {
    static let shared = MainWindowManager()
    
    private(set) weak var mainWindow: NSWindow?
    
    private override init() {
        super.init()
    }
    
    func register(window: NSWindow) {
        guard self.mainWindow !== window else { return }
        
        // If an existing main window is already registered, close any newcomer to prevent duplicates
        if let existing = self.mainWindow, existing !== window {
            window.orderOut(nil)
            window.close()
            return
        }
        
        self.mainWindow = window
        window.delegate = self
    }
    
    // Intercept window close button so the app stays running in menu bar and leaves Dock
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        // Transition to accessory policy so the app icon disappears from the Dock
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
        return false
    }
    
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    func showMainWindow() {
        // Restore regular activation policy so the app icon appears in the Dock
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        
        if let window = mainWindow {
            // Dismiss any accidental duplicate windows
            for otherWindow in NSApp.windows {
                if otherWindow !== window && !(otherWindow is NSPanel) && otherWindow.className != "NSStatusBarWindow" && otherWindow.canBecomeKey {
                    otherWindow.orderOut(nil)
                    otherWindow.close()
                }
            }
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
            return
        }
        
        // Fallback: locate main application window if reference wasn't captured yet
        var foundMain: NSWindow?
        for window in NSApp.windows {
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
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
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

// Helper NSViewRepresentable to capture the NSWindow of a SwiftUI view
struct WindowAccessor: NSViewRepresentable {
    let onWindowFound: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                onWindowFound(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onWindowFound(window)
            }
        }
    }
}
