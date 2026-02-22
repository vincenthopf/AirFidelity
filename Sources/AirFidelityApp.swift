import SwiftUI

@main
struct AirFidelityApp: App {
    @StateObject private var deviceManager = AudioDeviceManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(deviceManager: deviceManager)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    /// Menu bar icon — uses SF Symbols, shows only when BT audio is connected.
    private var menuBarLabel: some View {
        Group {
            if deviceManager.isBluetoothOutputConnected {
                Image(systemName: iconName)
                    .symbolRenderingMode(.hierarchical)
            } else {
                // Empty view hides the menu bar item when no BT audio connected.
                // Note: MenuBarExtra always shows an icon — we use a minimal
                // representation when inactive. Full hiding requires
                // programmatic MenuBarExtra visibility toggling.
                Image(systemName: "headphones")
                    .symbolRenderingMode(.hierarchical)
                    .opacity(0.3)
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
