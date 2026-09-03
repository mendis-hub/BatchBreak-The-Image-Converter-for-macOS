//
//  BatchBreakApp.swift
//  BatchBreak
//
//  Created by Kanishka Madusanka on 2026-08-30.
//

import SwiftUI
import AppKit

extension Notification.Name {
    static let showAboutSheet = Notification.Name("showAboutSheet")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar icon and drag-and-drop popup
        MenuBarManager.shared.setup()
    }
    
    // Keep app running in menu bar even after main window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // When dock icon is clicked, reopen main window if hidden
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainWindowManager.shared.showMainWindow()
            return false // Prevent system from creating a duplicate window
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        MenuBarManager.shared.teardown()
    }
}

@main
struct BatchBreakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Window("BatchBreak", id: "main") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            // Remove "New Window" (Cmd+N) so user cannot accidentally create duplicate windows
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appInfo) {
                Button("About BatchBreak") {
                    NotificationCenter.default.post(name: .showAboutSheet, object: nil)
                }
            }
        }
    }
}
