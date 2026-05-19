import Foundation
import AVFoundation
import MediaPlayer

@MainActor
final class NowPlayingService {
    static let shared = NowPlayingService()

    private var didRegisterRemoteCommands = false
    private var elapsedTimer: Timer?
    private var elapsedSource: (() -> TimeInterval)?

    private init() {}

    /// One-time launch hook. Routes through `AudioSessionCoordinator` so
    /// no two stores fight over the audio session category.
    func configureAudioSession() {
        AudioSessionCoordinator.shared.configureForLaunch()
    }

    /// Register lock-screen / control-center remote command handlers.
    /// Idempotent — repeated calls are a no-op so handler stacking can't happen.
    ///
    /// Command mapping:
    ///   - stop:            full tear-down via the provided `stopHandler`
    ///   - pause / toggle:  TrackPlaybackService.pause / togglePlayPause
    ///                      (player node pauses, both engines hold, DSP wire stops)
    ///   - play:            TrackPlaybackService.resume
    func registerRemoteCommands(stopHandler: @escaping @Sendable () -> Void) {
        guard !didRegisterRemoteCommands else { return }
        didRegisterRemoteCommands = true

        let center = MPRemoteCommandCenter.shared()
        center.stopCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.playCommand.isEnabled = true

        center.stopCommand.addTarget { _ in
            stopHandler()
            return .success
        }
        center.pauseCommand.addTarget { _ in
            TrackPlaybackService.shared.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { _ in
            TrackPlaybackService.shared.togglePlayPause()
            return .success
        }
        center.playCommand.addTarget { _ in
            TrackPlaybackService.shared.resume()
            return .success
        }
    }

    /// Update the lock-screen playback rate so iOS renders the correct
    /// play/pause glyph on the now-playing card. Called by
    /// TrackPlaybackService at pause/resume.
    func setPaused(_ paused: Bool) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = paused ? 0.0 : 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Set now-playing metadata for a Field track.
    ///
    /// Pass an `elapsedProvider` so the lock-screen progress bar advances —
    /// the service polls it once per second via `updateElapsed`. Pass `nil`
    /// to leave elapsed pinned at 0.
    func updateForTrack(
        verb: String,
        song: String,
        artist: String,
        duration: TimeInterval,
        elapsedProvider: (() -> TimeInterval)? = nil
    ) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = "\(verb) · \(song)"
        info[MPMediaItemPropertyArtist] = artist
        info[MPMediaItemPropertyAlbumTitle] = "Bindu Field"
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        startElapsedTicker(elapsedProvider)
    }

    /// Set now-playing metadata for an Empty Space chakra session.
    func updateForChakra(
        sanskrit: String,
        english: String,
        duration: TimeInterval,
        elapsedProvider: (() -> TimeInterval)? = nil
    ) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = sanskrit
        info[MPMediaItemPropertyArtist] = english
        info[MPMediaItemPropertyAlbumTitle] = "Empty Space"
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        startElapsedTicker(elapsedProvider)
    }

    /// Set now-playing metadata for a Lab session.
    ///
    /// Lab is open-ended. Pass a `duration` if the user picked one (the
    /// default session duration); otherwise omit and we'll show the
    /// session as ongoing with no progress bar.
    func updateForLab(
        stateLabel: String,
        carrier: Float,
        beat: Float,
        duration: TimeInterval? = nil
    ) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = "Lab · \(stateLabel)"
        info[MPMediaItemPropertyArtist] = "\(Int(carrier)) Hz · \(String(format: "%.1f", beat)) Hz"
        info[MPMediaItemPropertyAlbumTitle] = "Bindu Field"
        if let duration { info[MPMediaItemPropertyPlaybackDuration] = duration }
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        stopElapsedTicker()
    }

    /// Update elapsed time on the current now-playing item.
    func updateElapsed(_ seconds: TimeInterval) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Clear all now-playing metadata. Call when audio stops.
    func clear() {
        stopElapsedTicker()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Elapsed ticker

    /// Drives the lock-screen progress bar by polling `elapsedProvider`
    /// once per second and writing the result into `MPNowPlayingInfo`.
    private func startElapsedTicker(_ provider: (() -> TimeInterval)?) {
        stopElapsedTicker()
        guard let provider else { return }
        elapsedSource = provider
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let src = self.elapsedSource else { return }
                self.updateElapsed(src())
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        elapsedTimer = timer
    }

    private func stopElapsedTicker() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        elapsedSource = nil
    }
}
