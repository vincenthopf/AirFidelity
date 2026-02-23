import SwiftUI

/// Popover content shown when clicking the menu bar icon.
///
/// Layout: Status Hero -> Device Info -> Controls -> Footer
struct MenuBarView: View {
    @ObservedObject var deviceManager: AudioDeviceManager
    @ObservedObject var preferences: PreferencesManager = .shared
    @State private var availableInputs: [(name: String, uid: String)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusHeroSection

            GroupBox {
                deviceInfoSection
            }

            GroupBox {
                controlsSection
            }

            footerSection
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            availableInputs = deviceManager.availableInputDevices()
            // Reset stale selection if the saved device is no longer available
            let currentUID = preferences.preferredInputDeviceUID
            if !currentUID.isEmpty && !availableInputs.contains(where: { $0.uid == currentUID }) {
                preferences.preferredInputDeviceUID = ""
            }
        }
    }

    // MARK: - Status Hero

    private var statusHeroSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(deviceManager.qualityState.rawValue)
                    .font(.headline)
            }

            if let codecInfo = deviceManager.currentCodecInfo {
                Text(codecInfo.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .animation(.smooth, value: deviceManager.qualityState)
    }

    // MARK: - Device Info

    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledRow(label: "Output", value: deviceManager.currentOutputDeviceName)
            LabeledRow(label: "Input", value: deviceManager.currentInputDeviceName)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Auto-switch input", isOn: $preferences.autoSwitchingEnabled)
                .toggleStyle(.switch)

            Button(action: { deviceManager.fixNow() }) {
                Text("Fix Now")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
        .padding(.vertical, 2)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            SettingsLink {
                Image(systemName: "gear")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.caption)
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
