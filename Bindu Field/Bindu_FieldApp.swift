import SwiftUI

@main
struct Bindu_FieldApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var didLaunch = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear { runLaunchSetupIfNeeded() }
                .onChange(of: scenePhase) { _, phase in
                    // G16: on return to foreground, reconcile the DSP wire
                    // with the actual playback state — if audio is still
                    // playing, ensure polling is on; otherwise leave alone.
                    if phase == .active, didLaunch {
                        if TrackPlaybackService.shared.isPlaying,
                           !DSPWireService.shared.isMusicPlaying {
                            DSPWireService.shared.startPolling()
                        }
                    }
                }
        }
    }

    /// One-shot launch setup. Guarded by `didLaunch` so scene rebuilds
    /// (multi-window, extension lifecycle) don't re-register handlers or
    /// re-fetch the catalog (B15).
    private func runLaunchSetupIfNeeded() {
        guard !didLaunch else { return }
        didLaunch = true

        NowPlayingService.shared.configureAudioSession()
        PlayerStore.shared.configureEngine()
        NowPlayingService.shared.registerRemoteCommands {
            Task { @MainActor in
                PlayerStore.shared.stop()
                PlayerStore.shared.stopBinaural()
                NowPlayingService.shared.clear()
            }
        }
        Task { await CatalogStore.shared.refresh() }
    }
}
