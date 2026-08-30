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
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct BatchBreakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About BatchBreak") {
                    NotificationCenter.default.post(name: .showAboutSheet, object: nil)
                }
            }
        }
    }
}
