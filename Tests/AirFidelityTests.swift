import XCTest
@testable import AirFidelity

/// End-to-end tests for the Bluetooth audio quality fixer.
///
/// These tests drive the full state machine through MockAudioSystem,
/// simulating the complete lifecycle: BT connect → call → call end → switch back.
@MainActor
final class AirFidelityTests: XCTestCase {
    var mockSystem: MockAudioSystem!
    var preferences: PreferencesManager!
    var manager: AudioDeviceManager!

    override func setUp() {
        super.setUp()
        mockSystem = MockAudioSystem()
        // Use a dedicated UserDefaults suite so tests don't interfere
        let testDefaults = UserDefaults(suiteName: "com.vincehopf.AirFidelity.tests")!
        testDefaults.removePersistentDomain(forName: "com.vincehopf.AirFidelity.tests")
        preferences = PreferencesManager(defaults: testDefaults)

        // Set up baseline: built-in mic as default input, built-in speakers as output
        mockSystem._allInputDevices = [TestDevices.builtInMic]
        mockSystem._defaultInputDevice = TestDevices.builtInMic
        mockSystem._defaultOutputDevice = TestDevices.builtInSpeaker
    }

    override func tearDown() {
        manager = nil
        preferences = nil
        mockSystem = nil
        super.tearDown()
    }

    /// Create the manager with test-friendly timing (no delays).
    private func createManager() -> AudioDeviceManager {
        AudioDeviceManager(
            audioSystem: mockSystem,
            preferences: preferences,
            connectionDelay: 0,       // No delay in tests
            pollingInterval: 0,       // No polling in tests — we drive events manually
            cooldownDuration: 0.1,    // Short cooldown for fast tests
            debounceInterval: 0       // No debounce in most tests
        )
    }

    // MARK: - Initial State

    func testInitialStateWithNoBluetoothDevice() {
        manager = createManager()

        XCTAssertEqual(manager.qualityState, .disconnected)
        XCTAssertFalse(manager.isBluetoothOutputConnected)
        XCTAssertEqual(manager.currentOutputDeviceName, "MacBook Pro Speakers")
        XCTAssertEqual(manager.currentInputDeviceName, "MacBook Pro Microphone")
    }

    // MARK: - Bluetooth Connection → Auto-Switch

    func testBluetoothConnectAutoSwitchesInputToBuiltInMic() {
        manager = createManager()
        let airpods = TestDevices.airpodsA2DP()

        // Simulate BT headphones connecting
        mockSystem.connectBluetoothHeadphones(airpods)

        // Manager should have switched input to built-in mic
        XCTAssertTrue(mockSystem.setDefaultInputCalls.contains("BuiltInMicrophoneDevice"),
                      "Should auto-switch input to built-in mic on BT connect")

        manager.refreshState()
        XCTAssertTrue(manager.isBluetoothOutputConnected)
        XCTAssertEqual(manager.qualityState, .highQuality)
    }

    func testBluetoothConnectDoesNotSwitchWhenAutoSwitchDisabled() {
        preferences.autoSwitchingEnabled = false
        manager = createManager()
        let airpods = TestDevices.airpodsA2DP()

        mockSystem.connectBluetoothHeadphones(airpods)

        // Should NOT have called setDefaultInput
        let builtInCalls = mockSystem.setDefaultInputCalls.filter { $0 == "BuiltInMicrophoneDevice" }
        XCTAssertTrue(builtInCalls.isEmpty,
                      "Should not auto-switch when disabled")
    }

    // MARK: - Unexpected BT Mic Activation → Switch Back

    func testUnexpectedBluetoothMicActivationGetsSwitchedBack() {
        manager = createManager()
        let airpods = TestDevices.airpodsA2DP()

        // Connect BT headphones first
        mockSystem.connectBluetoothHeadphones(airpods)
        mockSystem.setDefaultInputCalls.removeAll() // Clear the initial switch call

        // Simulate macOS unexpectedly switching input to BT mic
        mockSystem.switchInputToBluetooth(airpods)

        // Should switch it back to built-in
        XCTAssertTrue(mockSystem.setDefaultInputCalls.contains("BuiltInMicrophoneDevice"),
                      "Should switch back to built-in mic when BT mic activated unexpectedly")
    }

    func testUnexpectedBluetoothMicNotSwitchedBackDuringCall() async throws {
        manager = createManager()
        let airpods = TestDevices.airpodsA2DP()

        // Connect and start a call
        mockSystem.connectBluetoothHeadphones(airpods)
        mockSystem.simulateCallStarted(on: airpods)

        // Wait for call detection to process
        try await Task.sleep(for: .milliseconds(50))

        mockSystem.setDefaultInputCalls.removeAll()

        // During a call, switching to BT mic is expected
        mockSystem.switchInputToBluetooth(airpods)

        // Should NOT switch back during active call
        let builtInCalls = mockSystem.setDefaultInputCalls.filter { $0 == "BuiltInMicrophoneDevice" }
        XCTAssertTrue(builtInCalls.isEmpty,
                      "Should not fight BT mic during active call")
    }

    // MARK: - Call Lifecycle (the critical E2E scenario)

    func testFullCallLifecycle() async throws {
        manager = createManager()
        let airpods = TestDevices.airpodsA2DP()

        // Step 1: Connect BT headphones
        mockSystem.connectBluetoothHeadphones(airpods)
        manager.refreshState()

        XCTAssertEqual(manager.qualityState, .highQuality,
                       "Should be high quality after BT connect")
        XCTAssertTrue(mockSystem.setDefaultInputCalls.contains("BuiltInMicrophoneDevice"),
                      "Should switch input to built-in on connect")

        // Step 2: Call starts — mic goes active on BT device
        mockSystem.simulateCallStarted(on: airpods)

        // Give the main actor time to process
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(manager.micMonitor.isCallActive,
                      "MicMonitor should detect call as active")
        XCTAssertEqual(manager.qualityState, .callMode,
                       "Quality state should be callMode during call")

        // Step 3: Call ends — mic goes inactive
        mockSystem.setDefaultInputCalls.removeAll()
        mockSystem.simulateCallEnded(on: airpods)

        // Wait for cooldown (0.1s) + buffer
        try await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(manager.micMonitor.isCallActive,
                       "MicMonitor should detect call as ended after cooldown")
        XCTAssertTrue(mockSystem.setDefaultInputCalls.contains("BuiltInMicrophoneDevice"),
                      "Should switch input back to built-in after call ends")

        manager.refreshState()
        XCTAssertEqual(manager.qualityState, .highQuality,
                       "Should return to high quality after call ends")
    }

    func testCallBrieflyPausesThenResumes() async throws {
        manager = createManager()
        let airpods = TestDevices.airpodsA2DP()

        mockSystem.connectBluetoothHeadphones(airpods)
        mockSystem.simulateCallStarted(on: airpods)
        try await Task.sleep(for: .milliseconds(50))

        mockSystem.setDefaultInputCalls.removeAll()

        // Mic goes inactive briefly
        mockSystem.simulateCallEnded(on: airpods)
        try await Task.sleep(for: .milliseconds(30))

        // Mic comes back before cooldown (0.1s) finishes
        mockSystem.simulateCallStarted(on: airpods)
        try await Task.sleep(for: .milliseconds(200))

        // Should NOT have switched back — call resumed
        let builtInCalls = mockSystem.setDefaultInputCalls.filter { $0 == "BuiltInMicrophoneDevice" }
        XCTAssertTrue(builtInCalls.isEmpty,
                      "Should not switch back if call resumes before cooldown")
        XCTAssertTrue(manager.micMonitor.isCallActive,
                      "Call should still be active")
    }

    // MARK: - Bluetooth Disconnect

    func testBluetoothDisconnectCleansUpState() {
        manager = createManager()
        let airpods = TestDevices.airpodsA2DP()

        mockSystem.connectBluetoothHeadphones(airpods)
        manager.refreshState()
        XCTAssertTrue(manager.isBluetoothOutputConnected)

        // Disconnect
        mockSystem.disconnectBluetoothHeadphones(airpods)
        manager.refreshState()

        XCTAssertFalse(manager.isBluetoothOutputConnected)
        XCTAssertEqual(manager.qualityState, .disconnected)
    }

    // MARK: - Codec Detection

    func testA2DPCodecDetected() {
        manager = createManager()
        let airpods = TestDevices.airpodsA2DP() // 2ch, 48kHz

        mockSystem._defaultOutputDevice = airpods
        manager.refreshState()

        XCTAssertEqual(manager.qualityState, .highQuality)
    }

    func testHFPCodecDetected() {
        manager = createManager()
        let airpods = TestDevices.airpodsHFP() // 1ch, 16kHz

        mockSystem._defaultOutputDevice = airpods
        manager.refreshState()

        XCTAssertEqual(manager.qualityState, .callMode)
    }

    // MARK: - Fix Now

    func testFixNowSwitchesToBuiltInMic() {
        manager = createManager()
        let airpods = TestDevices.airpodsA2DP()

        mockSystem.connectBluetoothHeadphones(airpods)
        mockSystem.setDefaultInputCalls.removeAll()

        // Manually set input to BT device
        mockSystem._defaultInputDevice = airpods

        manager.fixNow()

        XCTAssertTrue(mockSystem.setDefaultInputCalls.contains("BuiltInMicrophoneDevice"),
                      "Fix Now should switch to built-in mic")
    }

    func testFixNowUsesPreferredDevice() {
        manager = createManager()
        let airpods = TestDevices.airpodsA2DP()

        // Set a preferred input device (USB mic)
        mockSystem._allInputDevices.append(TestDevices.usbMic)
        preferences.preferredInputDeviceUID = "USB-Mic-UID"

        mockSystem.connectBluetoothHeadphones(airpods)
        mockSystem.setDefaultInputCalls.removeAll()

        manager.fixNow()

        XCTAssertTrue(mockSystem.setDefaultInputCalls.contains("USB-Mic-UID"),
                      "Fix Now should use preferred USB mic when configured")
    }

    // MARK: - Debouncing

    func testDuplicateEventsAreDebounced() {
        // Use a real debounce interval for this test
        manager = AudioDeviceManager(
            audioSystem: mockSystem,
            preferences: preferences,
            connectionDelay: 0,
            pollingInterval: 0,
            cooldownDuration: 0.1,
            debounceInterval: 1.0  // 1 second debounce
        )
        let airpods = TestDevices.airpodsA2DP()

        // Connect BT — triggers auto-switch (which sets lastSwitchTime)
        mockSystem.connectBluetoothHeadphones(airpods)

        // Clear and then rapidly fire input change events
        // These should ALL be debounced because lastSwitchTime was just set
        mockSystem.setDefaultInputCalls.removeAll()
        mockSystem.switchInputToBluetooth(airpods)
        mockSystem.switchInputToBluetooth(airpods)
        mockSystem.switchInputToBluetooth(airpods)

        let switchCalls = mockSystem.setDefaultInputCalls.filter { $0 == "BuiltInMicrophoneDevice" }
        XCTAssertEqual(switchCalls.count, 0,
                       "All rapid events after a switch should be debounced")
    }

    // MARK: - Available Devices

    func testAvailableInputDevicesReturnsAll() {
        mockSystem._allInputDevices = [TestDevices.builtInMic, TestDevices.usbMic]
        manager = createManager()

        let devices = manager.availableInputDevices()
        XCTAssertEqual(devices.count, 2)
        XCTAssertEqual(devices[0].name, "MacBook Pro Microphone")
        XCTAssertEqual(devices[1].name, "Blue Yeti")
    }

    // MARK: - Preferences Integration

    func testAutoSwitchToggleAffectsBehavior() {
        manager = createManager()
        let airpods = TestDevices.airpodsA2DP()

        // Initially enabled — should auto-switch
        mockSystem.connectBluetoothHeadphones(airpods)
        XCTAssertFalse(mockSystem.setDefaultInputCalls.isEmpty)

        // Disable auto-switching
        preferences.autoSwitchingEnabled = false
        mockSystem.setDefaultInputCalls.removeAll()

        // Disconnect and reconnect
        mockSystem.disconnectBluetoothHeadphones(airpods)
        manager.refreshState()
        mockSystem.connectBluetoothHeadphones(airpods)

        // Should NOT auto-switch this time
        let builtInCalls = mockSystem.setDefaultInputCalls.filter { $0 == "BuiltInMicrophoneDevice" }
        XCTAssertTrue(builtInCalls.isEmpty,
                      "Should not auto-switch after disabling preference")
    }

    // MARK: - MicrophoneUsageMonitor Unit Tests

    func testMicMonitorCooldownPreventsEarlyCallEnd() async throws {
        let monitor = MicrophoneUsageMonitor(cooldownDuration: 0.2)
        var callEndedCount = 0
        monitor.onCallEnded = { callEndedCount += 1 }

        monitor.reportMicActivity(isActive: true)
        XCTAssertTrue(monitor.isCallActive)

        monitor.reportMicActivity(isActive: false)
        // Still active — cooldown hasn't elapsed
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(monitor.isCallActive, "Should still be active before cooldown")
        XCTAssertEqual(callEndedCount, 0)

        // Wait for cooldown
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertFalse(monitor.isCallActive, "Should be inactive after cooldown")
        XCTAssertEqual(callEndedCount, 1)
    }

    func testMicMonitorResetClearsState() {
        let monitor = MicrophoneUsageMonitor(cooldownDuration: 5.0)
        monitor.reportMicActivity(isActive: true)
        XCTAssertTrue(monitor.isCallActive)

        monitor.reset()
        XCTAssertFalse(monitor.isCallActive)
    }
}
