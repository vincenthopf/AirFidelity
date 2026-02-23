import Foundation
import Combine

/// Codec quality state for the connected Bluetooth headphones.
enum AudioQualityState: String {
    case highQuality = "High Quality Audio"
    case callMode = "Call Mode"
    case disconnected = "No Bluetooth Audio"
    case unknown = "Unknown"
}

/// Central manager for audio device monitoring and input switching.
///
/// Uses AudioSystemProviding for all hardware interaction, making the
/// full state machine testable with a mock audio system.
final class AudioDeviceManager: ObservableObject {
    // MARK: - Published State

    @Published private(set) var currentOutputDeviceName: String = "None"
    @Published private(set) var currentInputDeviceName: String = "None"
    @Published private(set) var qualityState: AudioQualityState = .disconnected
    @Published private(set) var isBluetoothOutputConnected: Bool = false
    @Published private(set) var currentCodecInfo: CodecInfo?

    // MARK: - Dependencies

    let audioSystem: AudioSystemProviding
    let preferences: PreferencesManager
    let micMonitor: MicrophoneUsageMonitor
    let notificationManager: QualityNotificationManager

    /// Debounce tracking to avoid reacting to duplicate CoreAudio events.
    private var lastSwitchTime: Date = .distantPast
    private let debounceInterval: TimeInterval

    /// Delay after BT connection before auto-switching input.
    private let connectionDelay: TimeInterval

    /// Polling timer for fallback mic activity detection.
    private var pollingTimer: Timer?
    private let pollingInterval: TimeInterval

    /// Device ID of the BT device we're monitoring for mic activity.
    private var monitoredBTDeviceID: String?

    init(
        audioSystem: AudioSystemProviding = CoreAudioSystem(),
        preferences: PreferencesManager = .shared,
        connectionDelay: TimeInterval = 2.5,
        pollingInterval: TimeInterval = 3.0,
        cooldownDuration: TimeInterval = 5.0,
        debounceInterval: TimeInterval = 1.0
    ) {
        self.audioSystem = audioSystem
        self.preferences = preferences
        self.connectionDelay = connectionDelay
        self.pollingInterval = pollingInterval
        self.debounceInterval = debounceInterval
        self.micMonitor = MicrophoneUsageMonitor(cooldownDuration: cooldownDuration)
        self.notificationManager = QualityNotificationManager(preferences: preferences)

        setupCallbackHandlers()
        setupAudioSystemCallbacks()
        refreshState()
    }

    // MARK: - Public Actions

    /// Force-switch input to the preferred/built-in mic immediately.
    func fixNow() {
        guard let targetDevice = findPreferredInputDevice() else { return }
        setDefaultInput(to: targetDevice)
    }

    /// Returns all available input devices for the manual selector.
    func availableInputDevices() -> [(name: String, uid: String)] {
        audioSystem.allInputDevices.map { (name: $0.name, uid: $0.id) }
    }

    /// Manually select a preferred input device by ID.
    func selectPreferredInput(uid: String) {
        preferences.preferredInputDeviceUID = uid
        setDefaultInput(toID: uid)
    }

    // MARK: - Audio System Callbacks

    private func setupAudioSystemCallbacks() {
        audioSystem.onDevicesAdded = { [weak self] addedDevices in
            self?.handleDevicesAdded(addedDevices)
        }
        audioSystem.onDefaultInputChanged = { [weak self] in
            self?.handleInputDeviceChange()
        }
        audioSystem.onDefaultOutputChanged = { [weak self] in
            self?.refreshState()
        }
        audioSystem.onDeviceRunningStateChanged = { [weak self] in
            self?.handleRunningStateChange()
        }
    }

    private func setupCallbackHandlers() {
        micMonitor.onCallStarted = { [weak self] in
            guard let self else { return }
            let old = self.qualityState
            self.qualityState = .callMode
            self.notificationManager.qualityDidChange(
                from: old,
                to: .callMode,
                deviceName: self.currentOutputDeviceName
            )
        }
        micMonitor.onCallEnded = { [weak self] in
            self?.handleCallEnded()
        }
    }

    // MARK: - Event Handlers

    func handleDevicesAdded(_ addedDevices: [DeviceInfo]) {
        let newBTOutputDevices = addedDevices.filter { device in
            device.transportType.isBluetooth && device.outputChannels > 0
        }

        if !newBTOutputDevices.isEmpty {
            if connectionDelay > 0 {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(self?.connectionDelay ?? 0))
                    self?.onBluetoothHeadphonesConnected()
                }
            } else {
                onBluetoothHeadphonesConnected()
            }
        }

        refreshState()
    }

    func handleInputDeviceChange() {
        guard preferences.autoSwitchingEnabled else {
            refreshState()
            return
        }
        guard isBluetoothOutputConnected else {
            refreshState()
            return
        }
        guard !micMonitor.isCallActive else {
            refreshState()
            return
        }

        // If the input just switched to a BT device unexpectedly, switch it back
        if let currentInput = audioSystem.defaultInputDevice,
           currentInput.transportType.isBluetooth,
           !shouldDebounce() {
            fixNow()
        }

        refreshState()
    }

    private func onBluetoothHeadphonesConnected() {
        guard preferences.autoSwitchingEnabled else { return }
        fixNow()
        refreshState()

        // Start monitoring the BT output device for mic activity
        if let btOutput = audioSystem.defaultOutputDevice,
           btOutput.transportType.isBluetooth {
            startMonitoringDevice(btOutput)
        }
    }

    private func handleRunningStateChange() {
        guard let deviceID = monitoredBTDeviceID else { return }

        // Check if the monitored BT device's mic is still active
        // Look in all input devices (BT devices appear in both input and output lists)
        let btDevice = audioSystem.allInputDevices.first { $0.id == deviceID }
            ?? audioSystem.defaultOutputDevice.flatMap { $0.id == deviceID ? $0 : nil }

        if let device = btDevice {
            micMonitor.reportMicActivity(isActive: device.isRunningSomewhere)
        }
    }

    private func handleCallEnded() {
        guard preferences.autoSwitchingEnabled else { return }
        fixNow()
        refreshState()
    }

    // MARK: - Monitoring

    private func startMonitoringDevice(_ device: DeviceInfo) {
        monitoredBTDeviceID = device.id
        stopPolling()

        // Start fallback polling timer
        if pollingInterval > 0 {
            pollingTimer = Timer.scheduledTimer(
                withTimeInterval: pollingInterval,
                repeats: true
            ) { [weak self] _ in
                self?.handleRunningStateChange()
            }
        }
    }

    private func stopMonitoring() {
        monitoredBTDeviceID = nil
        stopPolling()
        micMonitor.reset()
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Device Utilities

    func findPreferredInputDevice() -> DeviceInfo? {
        let inputDevices = audioSystem.allInputDevices

        // If user has a preferred device, try that first
        if !preferences.preferredInputDeviceUID.isEmpty {
            if let preferred = inputDevices.first(where: {
                $0.id == preferences.preferredInputDeviceUID
            }) {
                return preferred
            }
        }

        // Fall back to built-in mic
        return inputDevices.first { $0.transportType == .builtIn }
    }

    private func setDefaultInput(to device: DeviceInfo) {
        setDefaultInput(toID: device.id)
    }

    private func setDefaultInput(toID deviceID: String) {
        audioSystem.setDefaultInput(deviceID: deviceID)
        lastSwitchTime = Date()
        refreshState()
    }

    private func shouldDebounce() -> Bool {
        Date().timeIntervalSince(lastSwitchTime) < debounceInterval
    }

    // MARK: - State

    func refreshState() {
        currentOutputDeviceName = audioSystem.defaultOutputDevice?.name ?? "None"
        currentInputDeviceName = audioSystem.defaultInputDevice?.name ?? "None"

        let hasBluetoothOutput: Bool = {
            guard let output = audioSystem.defaultOutputDevice else { return false }
            return output.transportType.isBluetooth
        }()

        isBluetoothOutputConnected = hasBluetoothOutput

        let oldQualityState = qualityState

        if !hasBluetoothOutput {
            qualityState = .disconnected
            stopMonitoring()
        } else if micMonitor.isCallActive {
            qualityState = .callMode
        } else {
            qualityState = detectCodecQuality()
        }

        if oldQualityState != qualityState {
            notificationManager.qualityDidChange(
                from: oldQualityState,
                to: qualityState,
                deviceName: currentOutputDeviceName
            )
        }

        if let output = audioSystem.defaultOutputDevice {
            currentCodecInfo = CodecInfo(from: output)
        } else {
            currentCodecInfo = nil
        }
    }

    /// Detect A2DP vs HFP by checking sample rate and channel count.
    private func detectCodecQuality() -> AudioQualityState {
        guard let output = audioSystem.defaultOutputDevice,
              output.transportType.isBluetooth else {
            return .disconnected
        }

        let sampleRate = output.nominalSampleRate ?? 0
        let channels = output.outputChannels

        // HFP/SCO: 1 channel at 8kHz or 16kHz
        // A2DP: 2 channels at 44.1kHz or 48kHz
        if channels <= 1 || sampleRate <= 16000 {
            return .callMode
        } else {
            return .highQuality
        }
    }
}
