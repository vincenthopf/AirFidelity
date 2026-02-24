import Sparkle

/// Bridges Sparkle's SPUUpdater into SwiftUI's observation system.
final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    let updater: SPUUpdater

    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updater = controller.updater
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}
