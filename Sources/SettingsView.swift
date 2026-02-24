import SwiftUI
import Sparkle
import UserNotifications

/// Settings window content, shown via Cmd+, or the gear icon in the popover.
struct SettingsView: View {
    @ObservedObject var updaterViewModel: UpdaterViewModel

    var body: some View {
        TabView {
            GeneralSettingsTab(updaterViewModel: updaterViewModel)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            NotificationSettingsTab()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 440, height: 280)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @ObservedObject private var preferences: PreferencesManager = .shared
    @ObservedObject var updaterViewModel: UpdaterViewModel

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Auto-switch input when Bluetooth headphones connect", isOn: $preferences.autoSwitchingEnabled)

                Toggle("Launch at login", isOn: $preferences.launchAtLogin)
                    .onChange(of: preferences.launchAtLogin) { _, enabled in
                        LaunchAtLoginManager.setEnabled(enabled)
                    }
            }

            Section("Menu Bar") {
                Toggle("Show codec name next to icon", isOn: $preferences.showCodecInMenuBar)
            }

            Section("Updates") {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updaterViewModel.updater.automaticallyChecksForUpdates },
                    set: { updaterViewModel.updater.automaticallyChecksForUpdates = $0 }
                ))

                Button("Check for Updates...") {
                    updaterViewModel.updater.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Notifications Tab

private struct NotificationSettingsTab: View {
    @ObservedObject private var preferences: PreferencesManager = .shared
    @State private var permissionDenied = false

    var body: some View {
        Form {
            Section {
                Toggle("Notify when audio quality drops", isOn: $preferences.notifyOnQualityDrop)
                    .onChange(of: preferences.notifyOnQualityDrop) { _, enabled in
                        if enabled { requestPermissionIfNeeded() }
                    }
                Toggle("Notify when audio quality restores", isOn: $preferences.notifyOnQualityRestore)
                    .onChange(of: preferences.notifyOnQualityRestore) { _, enabled in
                        if enabled { requestPermissionIfNeeded() }
                    }
            } header: {
                Text("Quality Alerts")
            } footer: {
                if permissionDenied {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Notifications are blocked.")
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                    .font(.caption)
                } else {
                    Text("Notifications require permission in System Settings → Notifications.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { checkPermissionStatus() }
    }

    private func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            DispatchQueue.main.async {
                permissionDenied = !granted
            }
        }
    }

    private func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                permissionDenied = settings.authorizationStatus == .denied
            }
        }
    }
}

// MARK: - About Tab

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "headphones")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("AirFidelity")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Keep your Bluetooth headphones sounding good on macOS.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Link("View on GitHub", destination: URL(string: "https://github.com/vincehopf/AirFidelity")!)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
