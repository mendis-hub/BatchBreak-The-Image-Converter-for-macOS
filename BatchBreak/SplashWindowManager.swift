//
//  SplashWindowManager.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-09-04.
//

import SwiftUI
import AppKit

@MainActor
final class SplashWindowManager: NSObject, NSWindowDelegate {
    static let shared = SplashWindowManager()
    
    private var window: NSWindow?
    
    var currentWindow: NSWindow? { window }
    
    private override init() {
        super.init()
    }
    
    func showSplashWindow() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        
        let activateSplashWindow = { (targetWindow: NSWindow) in
            targetWindow.center()
            targetWindow.orderFrontRegardless()
            targetWindow.makeKeyAndOrderFront(nil)
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            
            DispatchQueue.main.async {
                targetWindow.orderFrontRegardless()
                targetWindow.makeKeyAndOrderFront(nil)
                NSRunningApplication.current.activate(options: [.activateAllWindows])
                if #available(macOS 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
        
        if let existingWindow = window {
            if existingWindow.isMiniaturized {
                existingWindow.deminiaturize(nil)
            }
            activateSplashWindow(existingWindow)
            return
        }
        
        let splashView = SplashView()
        let hostingController = NSHostingController(rootView: splashView)
        
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.identifier = NSUserInterfaceItemIdentifier("BatchBreakSplashWindow")
        newWindow.title = "Welcome to BatchBreak"
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.styleMask = [.titled, .closable, .fullSizeContentView]
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        
        // Hide standard window buttons so the user initiates action via "Get Started"
        newWindow.standardWindowButton(.closeButton)?.isHidden = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true
        
        newWindow.setContentSize(NSSize(width: 460, height: 510))
        newWindow.center()
        
        self.window = newWindow
        activateSplashWindow(newWindow)
    }
    
    func closeSplashWindow() {
        guard let currentWindow = window else {
            MainWindowManager.shared.showMainWindow()
            return
        }
        self.window = nil
        currentWindow.delegate = nil
        currentWindow.orderOut(nil)
        currentWindow.close()
        
        DispatchQueue.main.async {
            MainWindowManager.shared.showMainWindow()
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        window = nil
        MainWindowManager.shared.showMainWindow()
    }
}
