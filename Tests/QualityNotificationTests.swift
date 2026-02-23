import XCTest
@testable import AirFidelity

final class QualityNotificationTests: XCTestCase {
    var defaults: UserDefaults!
    var prefs: PreferencesManager!
    var notificationManager: QualityNotificationManager!
    var sentNotifications: [(title: String, body: String)] = []

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.vincehopf.AirFidelity.notifTests")!
        defaults.removePersistentDomain(forName: "com.vincehopf.AirFidelity.notifTests")
        prefs = PreferencesManager(defaults: defaults)

        sentNotifications = []
        notificationManager = QualityNotificationManager(preferences: prefs) { [weak self] title, body in
            self?.sentNotifications.append((title: title, body: body))
        }
    }

    override func tearDown() {
        notificationManager = nil
        prefs = nil
        defaults = nil
        super.tearDown()
    }

    func testNoNotificationWhenDisabled() {
        prefs.notifyOnQualityDrop = false
        notificationManager.qualityDidChange(from: .highQuality, to: .callMode, deviceName: "AirPods Pro")
        XCTAssertTrue(sentNotifications.isEmpty)
    }

    func testNotifiesOnQualityDrop() {
        prefs.notifyOnQualityDrop = true
        notificationManager.qualityDidChange(from: .highQuality, to: .callMode, deviceName: "AirPods Pro")
        XCTAssertEqual(sentNotifications.count, 1)
        XCTAssertTrue(sentNotifications[0].title.contains("reduced"))
    }

    func testNotifiesOnQualityRestore() {
        prefs.notifyOnQualityRestore = true
        notificationManager.qualityDidChange(from: .callMode, to: .highQuality, deviceName: "AirPods Pro")
        XCTAssertEqual(sentNotifications.count, 1)
        XCTAssertTrue(sentNotifications[0].title.contains("restored"))
    }

    func testNoNotificationForSameState() {
        prefs.notifyOnQualityDrop = true
        prefs.notifyOnQualityRestore = true
        notificationManager.qualityDidChange(from: .highQuality, to: .highQuality, deviceName: "AirPods Pro")
        XCTAssertTrue(sentNotifications.isEmpty)
    }

    func testNoNotificationForDisconnect() {
        prefs.notifyOnQualityDrop = true
        notificationManager.qualityDidChange(from: .highQuality, to: .disconnected, deviceName: "AirPods Pro")
        XCTAssertTrue(sentNotifications.isEmpty, "Disconnect is not a quality drop — device was removed")
    }

    func testNoNotificationFromDisconnectedState() {
        prefs.notifyOnQualityRestore = true
        notificationManager.qualityDidChange(from: .disconnected, to: .highQuality, deviceName: "AirPods Pro")
        XCTAssertTrue(sentNotifications.isEmpty, "Connecting at high quality is normal, not a restore event")
    }

    func testBodyIncludesDeviceName() {
        prefs.notifyOnQualityDrop = true
        notificationManager.qualityDidChange(from: .highQuality, to: .callMode, deviceName: "Sony WH-1000XM5")
        XCTAssertTrue(sentNotifications[0].body.contains("Sony WH-1000XM5"))
    }
}
