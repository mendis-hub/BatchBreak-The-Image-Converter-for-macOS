//
//  SplashView.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-09-04.
//

import SwiftUI
import AppKit

struct SplashView: View {
    @ObservedObject private var settings = AppSettings.shared
    
    @State private var launchAtLogin: Bool = false
    @State private var showMenuBarIcon: Bool = true
    
    var onGetStarted: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header with App Icon & Info
            VStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 84, height: 84)
                    .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 4) {
                    Text("Welcome to BatchBreak")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("The Offline Image Converter for macOS")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Text("Batch convert, resize, and compress your photos and graphics directly on your Mac. Fast, private, and 100% offline with zero cloud processing.")
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)
            
            // MARK: - Quick Setup Options Section
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    
                    Text("Quick Setup")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                .padding(.leading, 4)
                
                VStack(spacing: 12) {
                    // Option 1: Show Menu Bar Icon (Recommended ON)
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.teal.opacity(0.15))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "menubar.rectangle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.teal)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Menu Bar Icon")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            Text("Quick drag-and-drop conversion from menu bar")
                                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $showMenuBarIcon)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    
                    Divider()
                        .padding(.leading, 44)
                    
                    // Option 2: Launch at Login (Default OFF)
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            Text("Automatically start BatchBreak when you log in")
                                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $launchAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
                .padding(14)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                )
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            
            Spacer(minLength: 20)
            
            // MARK: - Action Button & Footer Note
            VStack(spacing: 10) {
                Button(action: handleGetStarted) {
                    HStack(spacing: 8) {
                        Text("Get Started")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                
                Text("You can change these anytime in Settings (⌘,)")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 22)
        }
        .frame(width: 460, height: 510)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(settings.resolvedColorScheme)
        .onAppear {
            launchAtLogin = settings.isLaunchAtLoginEnabled
            showMenuBarIcon = settings.showMenuBarIcon
        }
    }
    
    private func handleGetStarted() {
        settings.completeOnboarding(launchAtLogin: launchAtLogin, showMenuBarIcon: showMenuBarIcon)
        if let onGetStarted = onGetStarted {
            onGetStarted()
        } else {
            SplashWindowManager.shared.closeSplashWindow()
        }
    }
}

#Preview {
    SplashView()
}
