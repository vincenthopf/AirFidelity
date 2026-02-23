import SwiftUI

@main
struct AirFidelityApp: App {
    @StateObject private var deviceManager = AudioDeviceManager()

    init() {
        QualityNotificationManager.requestPermission()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(deviceManager: deviceManager)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    /// Menu bar icon — uses SF Symbols, shows codec info when enabled.
    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            if deviceManager.isBluetoothOutputConnected {
                Image(systemName: iconName)
                    .symbolRenderingMode(.hierarchical)
            } else {
                Image(systemName: "headphones")
                    .symbolRenderingMode(.hierarchical)
                    .opacity(0.3)
            }

            if PreferencesManager.shared.showCodecInMenuBar,
               let codecInfo = deviceManager.currentCodecInfo {
                Text(codecInfo.codecName)
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
    }

    private var iconName: String {
        switch deviceManager.qualityState {
        case .highQuality: "headphones"
        case .callMode: "phone.fill"
        case .disconnected: "headphones"
        case .unknown: "questionmark.circle"
        }
    }
}
