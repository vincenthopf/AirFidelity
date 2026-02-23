import Foundation

/// Human-readable codec information derived from a Bluetooth audio device's properties.
///
/// Infers the active Bluetooth profile and codec from sample rate and channel count:
/// - A2DP (high quality): 2 channels at 44.1 or 48 kHz -> AAC codec
/// - HFP/SCO (call mode): 1 channel at 8 or 16 kHz -> SCO codec
struct CodecInfo: Equatable {
    let codecName: String
    let profileName: String
    let sampleRateDisplay: String
    let channelDisplay: String
    let isHighQuality: Bool
    let summary: String

    /// Returns nil for non-Bluetooth devices.
    init?(from device: DeviceInfo) {
        guard device.transportType.isBluetooth else { return nil }

        let sampleRate = device.nominalSampleRate
        let channels = device.outputChannels

        if let rate = sampleRate {
            let rateKHz = rate / 1000.0
            // Format: show one decimal place, but drop ".0" for whole numbers
            if rateKHz.truncatingRemainder(dividingBy: 1) == 0 {
                self.sampleRateDisplay = "\(String(format: "%.1f", rateKHz)) kHz"
            } else {
                self.sampleRateDisplay = "\(String(format: "%.1f", rateKHz)) kHz"
            }
        } else {
            self.sampleRateDisplay = "— kHz"
        }

        self.channelDisplay = channels >= 2 ? "Stereo" : "Mono"

        let rate = sampleRate ?? 0
        if channels <= 1 || rate <= 16000 {
            self.codecName = rate > 0 ? "SCO" : "Unknown"
            self.profileName = "HFP"
            self.isHighQuality = false
        } else {
            self.codecName = rate > 0 ? "AAC" : "Unknown"
            self.profileName = "A2DP"
            self.isHighQuality = true
        }

        self.summary = "\(codecName) · \(sampleRateDisplay) · \(channelDisplay)"
    }
}
