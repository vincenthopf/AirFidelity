import Foundation
import SwiftUI

/// Manages user preferences. Injectable UserDefaults for testability.
final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    private let defaults: UserDefaults

    @Published var autoSwitchingEnabled: Bool {
        didSet { defaults.set(autoSwitchingEnabled, forKey: Keys.autoSwitching) }
    }
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }
    @Published var preferredInputDeviceUID: String {
        didSet { defaults.set(preferredInputDeviceUID, forKey: Keys.preferredInput) }
    }

    private enum Keys {
        static let autoSwitching = "autoSwitchingEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let preferredInput = "preferredInputDeviceUID"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Default to true for auto-switching if never set
        if defaults.object(forKey: Keys.autoSwitching) == nil {
            self.autoSwitchingEnabled = true
        } else {
            self.autoSwitchingEnabled = defaults.bool(forKey: Keys.autoSwitching)
        }
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.preferredInputDeviceUID = defaults.string(forKey: Keys.preferredInput) ?? ""
    }

    /// Reset all preferences to defaults. Used in tests.
    func resetToDefaults() {
        autoSwitchingEnabled = true
        launchAtLogin = false
        preferredInputDeviceUID = ""
    }
}
