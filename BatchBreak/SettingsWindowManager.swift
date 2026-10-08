//
//  SettingsWindowManager.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-09-04.
//

import SwiftUI
import AppKit

@MainActor
final class SettingsWindowManager: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowManager()
    
    private var window: NSWindow?
    
    var currentWindow: NSWindow? { window }
    
    private override init() {
        super.init()
    }
    
    func showSettingsWindow() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        
        let activateSettingsWindow = { (targetWindow: NSWindow) in
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
            positionWindowAlignedToMainWindow(existingWindow)
            activateSettingsWindow(existingWindow)
            return
        }
        
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.identifier = NSUserInterfaceItemIdentifier("BatchBreakSettingsWindow")
        newWindow.title = "Settings"
        newWindow.styleMask = [.titled, .closable, .miniaturizable]
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.setContentSize(NSSize(width: 480, height: 570))
        
        positionWindowAlignedToMainWindow(newWindow)
        
        self.window = newWindow
        activateSettingsWindow(newWindow)
    }
    
    private func positionWindowAlignedToMainWindow(_ settingsWindow: NSWindow) {
        var mainWindow = MainWindowManager.shared.mainWindow
        if mainWindow == nil || !(mainWindow?.isVisible ?? false) {
            mainWindow = NSApp.windows.first(where: {
                $0.isVisible && MainWindowManager.shared.isMainWindowCandidate($0) && $0 !== settingsWindow
            })
        }
        
        guard let main = mainWindow, main.isVisible else {
            settingsWindow.center()
            return
        }
        
        let mainFrame = main.frame
        let settingsSize = settingsWindow.frame.size
        
        var newX = mainFrame.midX - (settingsSize.width / 2)
        var newY = mainFrame.midY - (settingsSize.height / 2)
        
        if let screen = main.screen ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            newX = max(visibleFrame.minX + 10, min(newX, visibleFrame.maxX - settingsSize.width - 10))
            newY = max(visibleFrame.minY + 10, min(newY, visibleFrame.maxY - settingsSize.height - 10))
        }
        
        settingsWindow.setFrameOrigin(NSPoint(x: newX, y: newY))
    }
    
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            AppSettings.shared.updateDockVisibility()
        }
    }
}
