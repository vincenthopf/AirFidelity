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

    @Published var showCodecInMenuBar: Bool {
        didSet { defaults.set(showCodecInMenuBar, forKey: Keys.showCodecInMenuBar) }
    }
    @Published var notifyOnQualityDrop: Bool {
        didSet { defaults.set(notifyOnQualityDrop, forKey: Keys.notifyOnQualityDrop) }
    }
    @Published var notifyOnQualityRestore: Bool {
        didSet { defaults.set(notifyOnQualityRestore, forKey: Keys.notifyOnQualityRestore) }
    }
    @Published var deviceInputMapping: [String: String] {
        didSet { defaults.set(deviceInputMapping, forKey: Keys.deviceInputMapping) }
    }

    private enum Keys {
        static let autoSwitching = "autoSwitchingEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let preferredInput = "preferredInputDeviceUID"
        static let showCodecInMenuBar = "showCodecInMenuBar"
        static let notifyOnQualityDrop = "notifyOnQualityDrop"
        static let notifyOnQualityRestore = "notifyOnQualityRestore"
        static let deviceInputMapping = "deviceInputMapping"
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
        self.showCodecInMenuBar = defaults.bool(forKey: Keys.showCodecInMenuBar)
        self.notifyOnQualityDrop = defaults.bool(forKey: Keys.notifyOnQualityDrop)
        self.notifyOnQualityRestore = defaults.bool(forKey: Keys.notifyOnQualityRestore)
        self.deviceInputMapping = (defaults.dictionary(forKey: Keys.deviceInputMapping) as? [String: String]) ?? [:]
    }

    /// Reset all preferences to defaults. Used in tests.
    func resetToDefaults() {
        autoSwitchingEnabled = true
        launchAtLogin = false
        preferredInputDeviceUID = ""
        showCodecInMenuBar = false
        notifyOnQualityDrop = false
        notifyOnQualityRestore = false
        deviceInputMapping = [:]
    }
}
