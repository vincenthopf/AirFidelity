import Foundation

/// Transport type abstraction to decouple from SimplyCoreAudio's enum.
enum AudioTransportType: Equatable, CustomStringConvertible {
    case builtIn
    case bluetooth
    case bluetoothLE
    case usb
    case aggregate
    case virtual
    case other

    var isBluetooth: Bool {
        self == .bluetooth || self == .bluetoothLE
    }

    var description: String {
        switch self {
        case .builtIn: "Built-In"
        case .bluetooth: "Bluetooth"
        case .bluetoothLE: "Bluetooth LE"
        case .usb: "USB"
        case .aggregate: "Aggregate"
        case .virtual: "Virtual"
        case .other: "Other"
        }
    }
}

/// Value type representing an audio device's observable properties.
struct DeviceInfo: Equatable, Identifiable {
    let id: String
    let name: String
    let transportType: AudioTransportType
    var isRunningSomewhere: Bool = false
    var nominalSampleRate: Float64? = nil
    var outputChannels: UInt32 = 0
    var inputChannels: UInt32 = 0
}

/// Abstraction over the system audio device layer.
///
/// Production: implemented by CoreAudioSystem (wraps SimplyCoreAudio).
/// Tests: implemented by MockAudioSystem (fully controllable).
protocol AudioSystemProviding: AnyObject {
    var allInputDevices: [DeviceInfo] { get }
    var defaultInputDevice: DeviceInfo? { get }
    var defaultOutputDevice: DeviceInfo? { get }

    /// Set the system default input device by its ID.
    func setDefaultInput(deviceID: String)

    // MARK: - Event callbacks (set by the consumer)

    /// Fired when the device list changes. Passes newly added devices.
    var onDevicesAdded: (([DeviceInfo]) -> Void)? { get set }
    /// Fired when the default input device changes.
    var onDefaultInputChanged: (() -> Void)? { get set }
    /// Fired when the default output device changes.
    var onDefaultOutputChanged: (() -> Void)? { get set }
    /// Fired when any monitored device's running state changes.
    var onDeviceRunningStateChanged: (() -> Void)? { get set }
}
