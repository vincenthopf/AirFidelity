import Foundation
@testable import AirFidelity

/// Fully controllable mock of AudioSystemProviding for tests.
///
/// Test flow:
/// 1. Set up initial state (_allInputDevices, _defaultInput, _defaultOutput)
/// 2. Create AudioDeviceManager with this mock
/// 3. Simulate events (connectBluetooth, startCall, endCall, etc.)
/// 4. Assert on manager state and setDefaultInput calls
final class MockAudioSystem: AudioSystemProviding {
    // MARK: - Controllable state

    var _allInputDevices: [DeviceInfo] = []
    var _defaultInputDevice: DeviceInfo?
    var _defaultOutputDevice: DeviceInfo?

    /// Tracks all setDefaultInput calls for assertions.
    var setDefaultInputCalls: [String] = []

    // MARK: - Callbacks

    var onDevicesAdded: (([DeviceInfo]) -> Void)?
    var onDefaultInputChanged: (() -> Void)?
    var onDefaultOutputChanged: (() -> Void)?
    var onDeviceRunningStateChanged: (() -> Void)?

    // MARK: - Protocol conformance

    var allInputDevices: [DeviceInfo] { _allInputDevices }
    var defaultInputDevice: DeviceInfo? { _defaultInputDevice }
    var defaultOutputDevice: DeviceInfo? { _defaultOutputDevice }

    func setDefaultInput(deviceID: String) {
        setDefaultInputCalls.append(deviceID)
        // Actually update the mock state so refreshState sees the change
        if let device = _allInputDevices.first(where: { $0.id == deviceID }) {
            _defaultInputDevice = device
        }
    }

    // MARK: - Simulation helpers

    /// Simulate connecting Bluetooth headphones.
    func connectBluetoothHeadphones(
        _ device: DeviceInfo,
        asOutput: Bool = true,
        addAsInput: Bool = true
    ) {
        if asOutput {
            _defaultOutputDevice = device
        }
        if addAsInput && !_allInputDevices.contains(where: { $0.id == device.id }) {
            _allInputDevices.append(device)
        }
        onDevicesAdded?([device])
    }

    /// Simulate disconnecting Bluetooth headphones.
    func disconnectBluetoothHeadphones(_ device: DeviceInfo) {
        _allInputDevices.removeAll { $0.id == device.id }
        if _defaultOutputDevice?.id == device.id {
            _defaultOutputDevice = nil
        }
        if _defaultInputDevice?.id == device.id {
            _defaultInputDevice = nil
        }
        onDefaultOutputChanged?()
    }

    /// Simulate macOS switching input to the BT mic (what happens during calls).
    func switchInputToBluetooth(_ btDevice: DeviceInfo) {
        _defaultInputDevice = btDevice
        onDefaultInputChanged?()
    }

    /// Simulate the BT device's mic becoming active (call started).
    func simulateCallStarted(on device: DeviceInfo) {
        updateDeviceRunningState(deviceID: device.id, isRunning: true)
        onDeviceRunningStateChanged?()
    }

    /// Simulate the BT device's mic becoming inactive (call ended).
    func simulateCallEnded(on device: DeviceInfo) {
        updateDeviceRunningState(deviceID: device.id, isRunning: false)
        onDeviceRunningStateChanged?()
    }

    private func updateDeviceRunningState(deviceID: String, isRunning: Bool) {
        if let idx = _allInputDevices.firstIndex(where: { $0.id == deviceID }) {
            _allInputDevices[idx].isRunningSomewhere = isRunning
        }
        if _defaultOutputDevice?.id == deviceID {
            _defaultOutputDevice?.isRunningSomewhere = isRunning
        }
        if _defaultInputDevice?.id == deviceID {
            _defaultInputDevice?.isRunningSomewhere = isRunning
        }
    }
}

// MARK: - Test fixture devices

enum TestDevices {
    static let builtInMic = DeviceInfo(
        id: "BuiltInMicrophoneDevice",
        name: "MacBook Pro Microphone",
        transportType: .builtIn,
        inputChannels: 1
    )

    static let builtInSpeaker = DeviceInfo(
        id: "BuiltInSpeakerDevice",
        name: "MacBook Pro Speakers",
        transportType: .builtIn,
        outputChannels: 2
    )

    static func airpodsA2DP() -> DeviceInfo {
        DeviceInfo(
            id: "AirPods-BT-UID",
            name: "AirPods Pro",
            transportType: .bluetooth,
            nominalSampleRate: 48000,
            outputChannels: 2,
            inputChannels: 1
        )
    }

    static func airpodsHFP() -> DeviceInfo {
        DeviceInfo(
            id: "AirPods-BT-UID",
            name: "AirPods Pro",
            transportType: .bluetooth,
            nominalSampleRate: 16000,
            outputChannels: 1,
            inputChannels: 1
        )
    }

    static let usbMic = DeviceInfo(
        id: "USB-Mic-UID",
        name: "Blue Yeti",
        transportType: .usb,
        inputChannels: 1
    )
}
