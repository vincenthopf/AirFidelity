import Foundation

/// Pure cooldown state machine for microphone usage detection.
///
/// AudioDeviceManager drives this by calling `reportMicActivity(isActive:)`
/// whenever it detects a change in the BT device's running state.
/// This class handles the cooldown logic: waits for the configured duration
/// of inactivity before declaring a call ended.
final class MicrophoneUsageMonitor: ObservableObject {
    @Published private(set) var isCallActive: Bool = false

    private var cooldownTask: Task<Void, Never>?
    private let cooldownDuration: TimeInterval

    /// Called when a call is detected as ended after cooldown.
    var onCallEnded: (() -> Void)?
    /// Called when a call is detected as starting.
    var onCallStarted: (() -> Void)?

    init(cooldownDuration: TimeInterval = 5.0) {
        self.cooldownDuration = cooldownDuration
    }

    /// Report whether the microphone is currently active.
    /// Call this whenever the BT device's running state changes or on poll.
    func reportMicActivity(isActive: Bool) {
        if isActive && !isCallActive {
            cooldownTask?.cancel()
            cooldownTask = nil
            isCallActive = true
            onCallStarted?()
        } else if isActive && isCallActive {
            // Mic resumed during cooldown — cancel the pending call-ended
            cooldownTask?.cancel()
            cooldownTask = nil
        } else if !isActive && isCallActive {
            startCooldown()
        }
    }

    /// Reset to idle state. Call when BT device disconnects.
    func reset() {
        cooldownTask?.cancel()
        cooldownTask = nil
        isCallActive = false
    }

    private func startCooldown() {
        cooldownTask?.cancel()
        cooldownTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .seconds(self.cooldownDuration))
                guard !Task.isCancelled else { return }
                self.isCallActive = false
                self.onCallEnded?()
            } catch {
                // Task was cancelled — call resumed before cooldown finished
            }
        }
    }

    deinit {
        cooldownTask?.cancel()
    }
}
