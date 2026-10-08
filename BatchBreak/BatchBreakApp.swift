//
//  BatchBreakApp.swift
//  BatchBreak
//
//  Created by Kanishka Madusanka on 2026-08-30.
//

import SwiftUI
import AppKit
import Combine
import Sparkle

extension Notification.Name {
    static let showAboutSheet = Notification.Name("showAboutSheet")
}

// MARK: - Sparkle Update View Model & View

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    
    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater
    
    init(updater: SPUUpdater) {
        self.updater = updater
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }
    
    var body: some View {
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Apply initial user settings (Dock, Menu Bar, Appearance, Launch at Login)
        AppSettings.shared.applyInitialSettings()
        
        // Show splash screen on first launch
        if !AppSettings.shared.hasCompletedOnboarding {
            SplashWindowManager.shared.showSplashWindow()
        }
    }
    
    // Keep app running even after main window is closed, unless user enabled quitAppOnClose
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return AppSettings.shared.quitAppOnClose
    }
    
    // When dock icon is clicked, reopen main window (or splash screen if not yet completed)
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !AppSettings.shared.hasCompletedOnboarding {
            SplashWindowManager.shared.showSplashWindow()
            return false
        }
        
        MainWindowManager.shared.showMainWindow()
        return false // Prevent system from focusing secondary windows (like Settings) or duplicating
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        MenuBarManager.shared.teardown()
    }
}

@main
struct BatchBreakApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var settings = AppSettings.shared
    
    private let updaterController: SPUStandardUpdaterController
    
    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updaterController = controller
        AppUpdaterManager.shared.configure(with: controller)
    }
    
    var body: some Scene {
        Window("BatchBreak", id: "main") {
            ContentView()
                .preferredColorScheme(settings.resolvedColorScheme)
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
                Button("Welcome to BatchBreak") {
                    SplashWindowManager.shared.showSplashWindow()
                }
            }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    SettingsWindowManager.shared.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
