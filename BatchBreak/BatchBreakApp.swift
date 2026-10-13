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
        // Ensure regular activation policy for foreground app operation
        NSApp.setActivationPolicy(.regular)
        
        // Apply initial user settings (Dock, Menu Bar, Appearance, Launch at Login)
        AppSettings.shared.applyInitialSettings()
        
        // Register this app as the system service provider for Finder contextual menu
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        
        // Show splash screen on first launch or bring main window to the front
        if !AppSettings.shared.hasCompletedOnboarding {
            SplashWindowManager.shared.showSplashWindow()
        } else {
            MainWindowManager.shared.showMainWindow()
        }
    }
    
    // MARK: - App & Document Lifecycle
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        return true
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
        
        if let window = MainWindowManager.shared.mainWindow {
            MainWindowManager.shared.activate(window: window)
            return false
        }
        
        MainWindowManager.shared.showMainWindow()
        // If no windows were visible, return true to permit system window-opening fallback
        return !flag
    }
    
    // MARK: - Finder File Opening & Context Menu Service
    
    // Handle opening files from Finder (e.g., "Open With" or system file open events)
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        NSApp.setActivationPolicy(.regular)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else { return }
        MainWindowManager.shared.openWithFiles(urls: urls)
        sender.reply(toOpenOrPrint: .success)
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        NSApp.setActivationPolicy(.regular)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        
        guard !urls.isEmpty else { return }
        MainWindowManager.shared.openWithFiles(urls: urls)
    }
    
    // Invoked by macOS system Services / Finder Quick Actions ("Convert with BatchBreak")
    @objc func openFilesInBatchBreak(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        var urls: [URL] = []
        
        // Read file URLs directly from pasteboard objects
        if let fileURLs = pboard.readObjects(forClasses: [NSURL.self], options: [
            NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly: true
        ]) as? [URL], !fileURLs.isEmpty {
            urls.append(contentsOf: fileURLs)
        } else if let items = pboard.pasteboardItems {
            for item in items {
                if let urlString = item.string(forType: .fileURL), let url = URL(string: urlString) {
                    urls.append(url)
                }
            }
        }
        
        // Fallback for filenames pasteboard type
        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if urls.isEmpty, let filenames = pboard.propertyList(forType: filenamesType) as? [String] {
            urls = filenames.map { URL(fileURLWithPath: $0) }
        }
        
        guard !urls.isEmpty else { return }
        
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSRunningApplication.current.activate(options: [.activateAllWindows])
            NSApp.activate(ignoringOtherApps: true)
            MainWindowManager.shared.openWithFiles(urls: urls)
        }
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
        WindowGroup("BatchBreak", id: "main") {
            ContentView()
                .preferredColorScheme(settings.resolvedColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            // Provide explicit menu command to open main window
            CommandGroup(replacing: .newItem) {
                Button("Open BatchBreak") {
                    MainWindowManager.shared.showMainWindow()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
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
