//
//  AppUpdaterManager.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-10-08.
//

import SwiftUI
import Combine
import Sparkle

@MainActor
final class AppUpdaterManager: ObservableObject {
    static let shared = AppUpdaterManager()
    
    private(set) var updaterController: SPUStandardUpdaterController?
    
    @Published var canCheckForUpdates: Bool = false
    
    private init() {}
    
    func configure(with controller: SPUStandardUpdaterController) {
        self.updaterController = controller
        
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    var automaticallyChecksForUpdates: Bool {
        get { updaterController?.updater.automaticallyChecksForUpdates ?? true }
        set { updaterController?.updater.automaticallyChecksForUpdates = newValue }
    }
    
    var automaticallyDownloadsUpdates: Bool {
        get { updaterController?.updater.automaticallyDownloadsUpdates ?? false }
        set { updaterController?.updater.automaticallyDownloadsUpdates = newValue }
    }
    
    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
}
