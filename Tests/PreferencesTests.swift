import XCTest
@testable import AirFidelity

final class PreferencesTests: XCTestCase {
    var defaults: UserDefaults!
    var prefs: PreferencesManager!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "com.vincehopf.AirFidelity.prefsTests")!
        defaults.removePersistentDomain(forName: "com.vincehopf.AirFidelity.prefsTests")
        prefs = PreferencesManager(defaults: defaults)
    }

    override func tearDown() {
        prefs = nil
        defaults = nil
        super.tearDown()
    }

    // MARK: - New preferences defaults

    func testShowCodecInMenuBarDefaultsToFalse() {
        XCTAssertFalse(prefs.showCodecInMenuBar)
    }

    func testNotifyOnQualityDropDefaultsToFalse() {
        XCTAssertFalse(prefs.notifyOnQualityDrop)
    }

    func testNotifyOnQualityRestoreDefaultsToFalse() {
        XCTAssertFalse(prefs.notifyOnQualityRestore)
    }

    // MARK: - Persistence

    func testShowCodecInMenuBarPersists() {
        prefs.showCodecInMenuBar = true
        let prefs2 = PreferencesManager(defaults: defaults)
        XCTAssertTrue(prefs2.showCodecInMenuBar)
    }

    func testNotificationPrefsPersist() {
        prefs.notifyOnQualityDrop = true
        prefs.notifyOnQualityRestore = true
        let prefs2 = PreferencesManager(defaults: defaults)
        XCTAssertTrue(prefs2.notifyOnQualityDrop)
        XCTAssertTrue(prefs2.notifyOnQualityRestore)
    }

    // MARK: - Per-device input mapping

    func testPerDeviceInputMappingDefaultsToEmpty() {
        XCTAssertTrue(prefs.deviceInputMapping.isEmpty)
    }

    func testPerDeviceInputMappingPersists() {
        prefs.deviceInputMapping["AirPods-BT-UID"] = "BuiltInMicrophoneDevice"
        prefs.deviceInputMapping["Sony-BT-UID"] = "USB-Mic-UID"

        let prefs2 = PreferencesManager(defaults: defaults)
        XCTAssertEqual(prefs2.deviceInputMapping["AirPods-BT-UID"], "BuiltInMicrophoneDevice")
        XCTAssertEqual(prefs2.deviceInputMapping["Sony-BT-UID"], "USB-Mic-UID")
    }

    // MARK: - Reset

    func testResetClearsNewPreferences() {
        prefs.showCodecInMenuBar = true
        prefs.notifyOnQualityDrop = true
        prefs.notifyOnQualityRestore = true
        prefs.deviceInputMapping["test"] = "value"

        prefs.resetToDefaults()

        XCTAssertFalse(prefs.showCodecInMenuBar)
        XCTAssertFalse(prefs.notifyOnQualityDrop)
        XCTAssertFalse(prefs.notifyOnQualityRestore)
        XCTAssertTrue(prefs.deviceInputMapping.isEmpty)
    }
}
