//
//  SettingsView.swift
//  BatchBreak
//
//  Created by Antigravity on 2026-09-04.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // MARK: - Header
                    HStack(spacing: 14) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BatchBreak Settings")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            
                            Text("Configure application behavior and defaults")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    // MARK: - 1, 2, 3: System Integration Section
                    SettingsSection(title: "System Integration", icon: "macwindow") {
                        // 1. Enable/Disable Launch at Login
                        SettingsRow(
                            title: "Launch at Login",
                            subtitle: "Automatically start BatchBreak when you log in",
                            icon: "arrow.clockwise.circle.fill",
                            iconColor: .blue
                        ) {
                            Toggle("", isOn: Binding(
                                get: { settings.isLaunchAtLoginEnabled },
                                set: { settings.setLaunchAtLogin(enabled: $0) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                        }
                        
                        Divider()
                            .padding(.leading, 40)
                        
                        // 2. Show/Hide app on the Dock
                        SettingsRow(
                            title: "Show App in Dock",
                            subtitle: settings.showMenuBarIcon
                                ? "Keep app icon in Dock when all windows are closed"
                                : "Must stay enabled when menu bar icon is hidden",
                            icon: "dock.rectangle",
                            iconColor: .indigo
                        ) {
                            Toggle("", isOn: $settings.showInDock)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .disabled(!settings.showMenuBarIcon)
                        }
                        
                        Divider()
                            .padding(.leading, 40)
                        
                        // 3. Show/Hide menu bar icon
                        SettingsRow(
                            title: "Show Menu Bar Icon",
                            subtitle: settings.showInDock
                                ? "Display quick drag-and-drop icon in the menu bar"
                                : "Must stay enabled when Dock icon is hidden",
                            icon: "menubar.rectangle",
                            iconColor: .teal
                        ) {
                            Toggle("", isOn: $settings.showMenuBarIcon)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .disabled(!settings.showInDock)
                        }
                        
                        Divider()
                            .padding(.leading, 40)
                        
                        // 4. Fully close app on window close
                        SettingsRow(
                            title: "Quit App on Close",
                            subtitle: "Completely exit BatchBreak when closing the window",
                            icon: "power",
                            iconColor: .red
                        ) {
                            Toggle("", isOn: $settings.quitAppOnClose)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                    }
                    
                    // MARK: - 5: Appearance Section
                    SettingsSection(title: "Appearance", icon: "paintbrush.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose how BatchBreak appears on your Mac")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                AppearanceOptionCard(
                                    title: "System",
                                    icon: "circle.lefthalf.filled",
                                    isSelected: settings.appearance == .system
                                ) {
                                    settings.appearance = .system
                                }
                                
                                AppearanceOptionCard(
                                    title: "Light",
                                    icon: "sun.max.fill",
                                    isSelected: settings.appearance == .light
                                ) {
                                    settings.appearance = .light
                                }
                                
                                AppearanceOptionCard(
                                    title: "Dark",
                                    icon: "moon.fill",
                                    isSelected: settings.appearance == .dark
                                ) {
                                    settings.appearance = .dark
                                }
                            }
                        }
                    }
                    
                    // MARK: - 6: Default Quality Percentage Section
                    SettingsSection(title: "Default Quality", icon: "slider.horizontal.3") {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Default Compression Quality")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                    
                                    Text("Initial quality percentage when adding images")
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("\(Int((settings.defaultQuality * 100).rounded()))%")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            
                            HStack(spacing: 12) {
                                Text("10%")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                
                                Slider(
                                    value: Binding(
                                        get: { settings.defaultQuality * 100 },
                                        set: { settings.defaultQuality = ($0.rounded()) / 100.0 }
                                    ),
                                    in: 10...100,
                                    step: 1
                                )
                                
                                Text("100%")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Preset quality quick buttons
                            HStack(spacing: 8) {
                                Text("Presets:")
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundStyle(.secondary)
                                
                                ForEach([50, 75, 80, 90, 100], id: \.self) { preset in
                                    Button("\(preset)%") {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                            settings.defaultQuality = Double(preset) / 100.0
                                        }
                                    }
                                    .buttonStyle(.glass)
                                    .buttonBorderShape(.capsule)
                                    .controlSize(.mini)
                                    .opacity(Int((settings.defaultQuality * 100).rounded()) == preset ? 1.0 : 0.75)
                                }
                            }
                        }
                    }
                }
                .padding(22)
            }
        }
        .frame(width: 480, height: 570)
        .background(Color(NSColor.windowBackgroundColor))
        .preferredColorScheme(settings.resolvedColorScheme)
        .onAppear {
            settings.refreshLaunchAtLoginStatus()
        }
    }
}

// MARK: - Helper Views
private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.leading, 4)
            
            VStack(spacing: 12) {
                content()
            }
            .padding(14)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            )
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let trailing: () -> Content
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            trailing()
        }
    }
}

private struct AppearanceOptionCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(height: 28)
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}
