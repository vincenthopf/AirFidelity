import Foundation
import UserNotifications

/// Manages macOS notifications for audio quality state changes.
///
/// Decision logic is decoupled from delivery: in production, `deliverNotification`
/// calls UNUserNotificationCenter. In tests, a closure captures the output.
final class QualityNotificationManager {
    private let preferences: PreferencesManager
    private let deliver: (String, String) -> Void

    /// Production initializer — delivers via UNUserNotificationCenter.
    convenience init(preferences: PreferencesManager) {
        self.init(preferences: preferences) { title, body in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = nil

            let request = UNNotificationRequest(
                identifier: "com.vincehopf.AirFidelity.quality.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    /// Test initializer — uses a custom delivery closure.
    init(preferences: PreferencesManager, deliver: @escaping (String, String) -> Void) {
        self.preferences = preferences
        self.deliver = deliver
    }

    /// Call this when the quality state changes. Fires a notification if appropriate.
    func qualityDidChange(from oldState: AudioQualityState, to newState: AudioQualityState, deviceName: String) {
        guard oldState != newState else { return }

        // Don't notify for transitions involving disconnected state
        guard oldState != .disconnected, newState != .disconnected else { return }

        if newState == .callMode && oldState == .highQuality && preferences.notifyOnQualityDrop {
            deliver(
                "Audio quality reduced",
                "\(deviceName) switched to call mode"
            )
        } else if newState == .highQuality && oldState == .callMode && preferences.notifyOnQualityRestore {
            deliver(
                "Audio quality restored",
                "\(deviceName) back to stereo"
            )
        }
    }

    /// Request notification permission. Call once at app launch.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }
}
