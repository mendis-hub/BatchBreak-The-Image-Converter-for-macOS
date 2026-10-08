//
//  AppSettings.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-09-04.
//

import SwiftUI
import AppKit
import ServiceManagement
import Combine

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let showInDock = "showInDock"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let appAppearance = "appAppearance"
        static let defaultQuality = "defaultQuality"
        static let quitAppOnClose = "quitAppOnClose"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
    
    @Published var isLaunchAtLoginEnabled: Bool = false
    
    @Published var showInDock: Bool {
        didSet {
            userDefaults.set(showInDock, forKey: Keys.showInDock)
            updateDockVisibility()
        }
    }
    
    @Published var showMenuBarIcon: Bool {
        didSet {
            userDefaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
            updateMenuBarVisibility()
        }
    }
    
    @Published var quitAppOnClose: Bool {
        didSet {
            userDefaults.set(quitAppOnClose, forKey: Keys.quitAppOnClose)
        }
    }
    
    @Published var appearance: AppAppearance {
        didSet {
            userDefaults.set(appearance.rawValue, forKey: Keys.appAppearance)
            updateAppearance()
        }
    }
    
    @Published var defaultQuality: Double {
        didSet {
            userDefaults.set(defaultQuality, forKey: Keys.defaultQuality)
        }
    }
    
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            userDefaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }
    
    @Published var resolvedColorScheme: ColorScheme = .dark
    
    private var systemThemeObserver: Any?
    
    private init() {
        let storedShowInDock = userDefaults.object(forKey: Keys.showInDock) as? Bool ?? true
        let storedShowMenuBarIcon = userDefaults.object(forKey: Keys.showMenuBarIcon) as? Bool ?? true
        let storedQuitAppOnClose = userDefaults.bool(forKey: Keys.quitAppOnClose)
        let storedAppearanceRaw = userDefaults.string(forKey: Keys.appAppearance) ?? AppAppearance.system.rawValue
        let storedQuality = userDefaults.object(forKey: Keys.defaultQuality) as? Double ?? 0.80
        let storedHasCompletedOnboarding = userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
        
        let initialAppearance = AppAppearance(rawValue: storedAppearanceRaw) ?? .system
        self.showInDock = storedShowInDock
        self.showMenuBarIcon = storedShowMenuBarIcon
        self.quitAppOnClose = storedQuitAppOnClose
        self.appearance = initialAppearance
        self.defaultQuality = storedQuality
        self.hasCompletedOnboarding = storedHasCompletedOnboarding
        
        switch initialAppearance {
        case .system:
            self.resolvedColorScheme = Self.isSystemInDarkMode ? .dark : .light
        case .light:
            self.resolvedColorScheme = .light
        case .dark:
            self.resolvedColorScheme = .dark
        }
        
        setupSystemThemeObserver()
    }
    
    deinit {
        if let observer = systemThemeObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
    }
    
    private func setupSystemThemeObserver() {
        systemThemeObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.appearance == .system else { return }
                self.updateAppearance()
            }
        }
    }
    
    func applyInitialSettings() {
        refreshLaunchAtLoginStatus()
        updateDockVisibility()
        updateMenuBarVisibility()
        updateAppearance()
    }
    
    // MARK: - Onboarding
    func completeOnboarding(launchAtLogin: Bool, showMenuBarIcon: Bool) {
        self.hasCompletedOnboarding = true
        self.showMenuBarIcon = showMenuBarIcon
        setLaunchAtLogin(enabled: launchAtLogin)
        updateMenuBarVisibility()
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        updateMenuBarVisibility()
    }
    
    // MARK: - Launch At Login
    func refreshLaunchAtLoginStatus() {
        isLaunchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
    }
    
    func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Launch at login toggle error: \(error.localizedDescription)")
        }
        refreshLaunchAtLoginStatus()
    }
    
    // MARK: - Dock Visibility
    func updateDockVisibility() {
        guard let app: NSApplication = NSApp else { return }
        if showInDock {
            if app.activationPolicy() != .regular {
                app.setActivationPolicy(.regular)
            }
        } else {
            // Only hide from Dock if no normal application windows are visible
            let hasVisibleNormalWindows = app.windows.contains { window in
                window.isVisible && !(window is NSPanel) && window.className != "NSStatusBarWindow" && window.canBecomeKey
            }
            if !hasVisibleNormalWindows {
                if app.activationPolicy() != .accessory {
                    app.setActivationPolicy(.accessory)
                }
            } else {
                if app.activationPolicy() != .regular {
                    app.setActivationPolicy(.regular)
                }
            }
        }
    }
    
    // MARK: - Menu Bar Visibility
    func updateMenuBarVisibility() {
        // Do not show menu bar icon until user completes onboarding / clicks Get Started
        guard hasCompletedOnboarding else {
            MenuBarManager.shared.teardown()
            return
        }
        
        if showMenuBarIcon {
            MenuBarManager.shared.setup()
        } else {
            MenuBarManager.shared.teardown()
        }
    }
    
    // MARK: - System Appearance Detection
    private static var isSystemInDarkMode: Bool {
        if let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
            return style.caseInsensitiveCompare("dark") == .orderedSame
        }
        if let app: NSApplication = NSApp {
            return app.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        return false
    }
    
    // MARK: - Appearance
    func updateAppearance() {
        guard let app: NSApplication = NSApp else { return }
        
        let targetAppearance: NSAppearance?
        switch appearance {
        case .system:
            targetAppearance = nil
            resolvedColorScheme = Self.isSystemInDarkMode ? .dark : .light
            
        case .light:
            targetAppearance = NSAppearance(named: .aqua)
            resolvedColorScheme = .light
            
        case .dark:
            targetAppearance = NSAppearance(named: .darkAqua)
            resolvedColorScheme = .dark
        }
        
        app.appearance = targetAppearance
        
        for window in app.windows {
            // Crucial: The macOS menu bar status item window must ALWAYS follow system appearance
            if window.className == "NSStatusBarWindow" || window.className.contains("StatusBar") {
                window.appearance = nil
            } else {
                window.appearance = targetAppearance
            }
        }
        
        MenuBarManager.shared.ensureSystemAppearance()
    }
}
