import SwiftUI

/// Settings window content, shown via Cmd+, or the gear icon in the popover.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
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
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Notifications Tab

private struct NotificationSettingsTab: View {
    @ObservedObject private var preferences: PreferencesManager = .shared

    var body: some View {
        Form {
            Section {
                Toggle("Notify when audio quality drops", isOn: $preferences.notifyOnQualityDrop)
                Toggle("Notify when audio quality restores", isOn: $preferences.notifyOnQualityRestore)
            } header: {
                Text("Quality Alerts")
            } footer: {
                Text("Notifications require permission in System Settings → Notifications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
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
