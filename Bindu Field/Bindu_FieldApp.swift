import SwiftUI

@main
struct Bindu_FieldApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
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
    }
}
