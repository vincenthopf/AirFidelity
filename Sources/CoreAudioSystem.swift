import Foundation
import SimplyCoreAudio

/// Production implementation of AudioSystemProviding backed by SimplyCoreAudio.
final class CoreAudioSystem: AudioSystemProviding {
    private let simplyCA = SimplyCoreAudio()
    private var observers: [NSObjectProtocol] = []

    // MARK: - Event callbacks

    var onDevicesAdded: (([DeviceInfo]) -> Void)?
    var onDefaultInputChanged: (() -> Void)?
    var onDefaultOutputChanged: (() -> Void)?
    var onDeviceRunningStateChanged: (() -> Void)?

    init() {
        setupNotificationObservers()
    }

    // MARK: - AudioSystemProviding

    var allInputDevices: [DeviceInfo] {
        simplyCA.allInputDevices.map { $0.toDeviceInfo() }
    }

    var defaultInputDevice: DeviceInfo? {
        simplyCA.defaultInputDevice?.toDeviceInfo()
    }

    var defaultOutputDevice: DeviceInfo? {
        simplyCA.defaultOutputDevice?.toDeviceInfo()
    }

    func setDefaultInput(deviceID: String) {
        guard let device = simplyCA.allInputDevices.first(where: { $0.uid == deviceID }) else {
            return
        }
        device.isDefaultInputDevice = true
    }

    // MARK: - Notification bridging

    private func setupNotificationObservers() {
        let deviceListObserver = NotificationCenter.default.addObserver(
            forName: .deviceListChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let added = (notification.userInfo?["addedDevices"] as? [AudioDevice]) ?? []
            self?.onDevicesAdded?(added.map { $0.toDeviceInfo() })
        }
        observers.append(deviceListObserver)

        let inputObserver = NotificationCenter.default.addObserver(
            forName: .defaultInputDeviceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onDefaultInputChanged?()
        }
        observers.append(inputObserver)

        let outputObserver = NotificationCenter.default.addObserver(
            forName: .defaultOutputDeviceChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onDefaultOutputChanged?()
        }
        observers.append(outputObserver)

        // Observe running state changes on all devices
        let runningObserver = NotificationCenter.default.addObserver(
            forName: .deviceIsRunningDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onDeviceRunningStateChanged?()
        }
        observers.append(runningObserver)
    }
}

// MARK: - AudioDevice → DeviceInfo conversion

extension AudioDevice {
    func toDeviceInfo() -> DeviceInfo {
        DeviceInfo(
            id: uid ?? "\(id)",
            name: name,
            transportType: (transportType ?? .builtIn).toAudioTransportType(),
            isRunningSomewhere: isRunningSomewhere,
            nominalSampleRate: nominalSampleRate,
            outputChannels: channels(scope: .output),
            inputChannels: channels(scope: .input)
        )
    }
}

extension TransportType {
    func toAudioTransportType() -> AudioTransportType {
        switch self {
        case .builtIn: .builtIn
        case .bluetooth: .bluetooth
        case .bluetoothLE: .bluetoothLE
        case .usb: .usb
        case .aggregate: .aggregate
        case .virtual: .virtual
        default: .other
        }
    }
}
