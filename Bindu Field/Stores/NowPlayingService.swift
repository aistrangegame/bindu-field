import Foundation
import AVFoundation
import MediaPlayer

@MainActor
final class NowPlayingService {
    static let shared = NowPlayingService()

    private init() {}

    /// Configure AVAudioSession for playback that continues in background.
    /// MUST be called once on app launch BEFORE the audio engine starts.
    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("[AudioSession] config failed: \(error)")
        }
    }

    /// Register lock screen / control center remote command handlers.
    /// All commands (play, pause, stop, togglePlayPause) currently route to stopHandler
    /// since binaural has no paused state — stop is the only meaningful action.
    func registerRemoteCommands(stopHandler: @escaping @Sendable () -> Void) {
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
            stopHandler()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { _ in
            stopHandler()
            return .success
        }
        center.playCommand.addTarget { _ in
            // No "resume" concept for binaural — no-op
            return .success
        }
    }

    /// Set now-playing metadata for a Field track.
    func updateForTrack(verb: String, song: String, artist: String, duration: TimeInterval) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = "\(verb) · \(song)"
        info[MPMediaItemPropertyArtist] = artist
        info[MPMediaItemPropertyAlbumTitle] = "Bindu Field"
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Set now-playing metadata for an Empty Space chakra session.
    func updateForChakra(sanskrit: String, english: String, duration: TimeInterval) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = sanskrit
        info[MPMediaItemPropertyArtist] = english
        info[MPMediaItemPropertyAlbumTitle] = "Empty Space"
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0.0
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Set now-playing metadata for a Lab session.
    func updateForLab(stateLabel: String, carrier: Float, beat: Float) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = "Lab · \(stateLabel)"
        info[MPMediaItemPropertyArtist] = "\(Int(carrier)) Hz · \(String(format: "%.1f", beat)) Hz"
        info[MPMediaItemPropertyAlbumTitle] = "Bindu Field"
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Update elapsed time on the current now-playing item.
    func updateElapsed(_ seconds: TimeInterval) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = seconds
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Clear all now-playing metadata. Call when audio stops.
    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
