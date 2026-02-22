import SwiftUI

/// Popover content shown when clicking the menu bar icon.
struct MenuBarView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @ObservedObject var preferences: PreferencesManager = .shared
    @State private var availableInputs: [(name: String, uid: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status header
            statusSection

            Divider()

            // Device info
            deviceInfoSection

            Divider()

            // Controls
            controlsSection

            Divider()

            // Settings
            settingsSection
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            availableInputs = deviceManager.availableInputDevices()
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(deviceManager.qualityState.rawValue)
                .font(.headline)
            Spacer()
        }
    }

    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledRow(label: "Output", value: deviceManager.currentOutputDeviceName)
            LabeledRow(label: "Input", value: deviceManager.currentInputDeviceName)
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Fix Now") {
                deviceManager.fixNow()
            }
            .disabled(deviceManager.qualityState == .disconnected)

            Picker("Input Device", selection: $preferences.preferredInputDeviceUID) {
                Text("Automatic (Built-in)").tag("")
                ForEach(availableInputs, id: \.uid) { input in
                    Text(input.name).tag(input.uid)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: preferences.preferredInputDeviceUID) { _, newValue in
                if !newValue.isEmpty {
                    deviceManager.selectPreferredInput(uid: newValue)
                }
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Auto-switch input", isOn: $preferences.autoSwitchingEnabled)

            Toggle("Launch at login", isOn: $preferences.launchAtLogin)
                .onChange(of: preferences.launchAtLogin) { _, enabled in
                    LaunchAtLoginManager.setEnabled(enabled)
                }

            HStack {
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch deviceManager.qualityState {
        case .highQuality: .green
        case .callMode: .orange
        case .disconnected: .gray
        case .unknown: .yellow
        }
    }
}

/// Simple label: value row for device info display.
private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)
            Text(value)
                .fontWeight(.medium)
        }
        .font(.callout)
    }
}
