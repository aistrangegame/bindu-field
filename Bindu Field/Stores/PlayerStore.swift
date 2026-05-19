import Foundation
import Observation

@MainActor
@Observable
final class PlayerStore {
    static let shared = PlayerStore()

    var currentTrack: Track?
    var isPlaying: Bool = false
    var progress: Double = 0
    var isToneOn: Bool = true
    var currentCarrier: Float = 136.0
    var currentBeat: Float = 7.5
    var isPresentingPlayer: Bool = false
    var isLoadingTrack: Bool = false

    private var currentSessionStart: Date? = nil
    private var currentSessionTrack: Track? = nil

    private init() {}

    func configureEngine() {
        BinauralEngine.shared.configure()
    }

    /// Play a track: stream/cache the audio file, layer the binaural tone on top,
    /// present the Player modal. Falls back to binaural-only if the download fails.
    func play(_ track: Track) {
        // Save any in-flight session before swapping tracks
        finalizeCurrentSession(completed: false)

        let carrier = Float(track.carrierHz)
        let beat = Float(track.beatHz)

        currentTrack = track
        currentCarrier = carrier
        currentBeat = beat
        isPresentingPlayer = true
        isLoadingTrack = true

        // Stop any prior audio (both engines)
        BinauralEngine.shared.stop()
        TrackPlaybackService.shared.stop()

        let myTrack = track
        Task { @MainActor in
            do {
                let localURL = try await AudioCache.shared.fetch(trackID: myTrack.id)
                // Guard against late completion after the user moved on / closed the player.
                guard currentTrack?.id == myTrack.id else { return }
                try TrackPlaybackService.shared.play(
                    fileURL: localURL,
                    carrier: carrier,
                    beat: beat,
                    gain: SettingsStore.shared.gain
                )
                isLoadingTrack = false
                isPlaying = true

                let dur = TrackPlaybackService.shared.duration
                NowPlayingService.shared.updateForTrack(
                    verb: myTrack.verb,
                    song: myTrack.song,
                    artist: myTrack.artist,
                    duration: dur > 0 ? dur : 600
                )
            } catch {
                // Graceful fallback: binaural-only via BinauralEngine.
                guard currentTrack?.id == myTrack.id else { return }
                isLoadingTrack = false
                BinauralEngine.shared.start(carrierHz: carrier)
                BinauralEngine.shared.updateBeat(beat)
                BinauralEngine.shared.updateGain(SettingsStore.shared.gain)
                isPlaying = true
                NowPlayingService.shared.updateForTrack(
                    verb: myTrack.verb,
                    song: myTrack.song,
                    artist: myTrack.artist,
                    duration: 600
                )
            }
        }

        currentSessionStart = Date()
        currentSessionTrack = track
    }

    func stop() {
        TrackPlaybackService.shared.stop()
        finalizeCurrentSession(completed: false)
        BinauralEngine.shared.stop()
        isPlaying = false
        isLoadingTrack = false
        currentTrack = nil
        isPresentingPlayer = false
        NowPlayingService.shared.clear()
    }

    private func finalizeCurrentSession(completed: Bool) {
        guard let start = currentSessionStart, let track = currentSessionTrack else { return }
        let duration = Date().timeIntervalSince(start)
        currentSessionStart = nil
        currentSessionTrack = nil

        if duration < 5 { return }  // ignore very short taps

        let session = Session(
            id: UUID(),
            timestamp: start,
            type: .track,
            sourceID: String(track.id),
            displayName: track.verb,
            secondaryLabel: "\(track.song) — \(track.artist)",
            duration: duration,
            carrier: currentCarrier,
            beat: currentBeat,
            completed: completed
        )
        SessionStore.shared.save(session)
    }

    /// Close the player and stop audio.
    func closePlayer() {
        stop()
    }

    /// Minimize the player (keeps audio playing, just dismisses the modal).
    func minimizePlayer() {
        isPresentingPlayer = false
    }

    func startBinaural(carrier: Float, beat: Float) {
        TrackPlaybackService.shared.stop()
        BinauralEngine.shared.start(carrierHz: carrier)
        BinauralEngine.shared.updateBeat(beat)
        BinauralEngine.shared.updateGain(SettingsStore.shared.gain)
        currentCarrier = carrier
        currentBeat = beat
        isPlaying = true
    }

    func stopBinaural() {
        BinauralEngine.shared.stop()
        isPlaying = false
        currentTrack = nil
    }

    func setGain(_ gain: Float) {
        BinauralEngine.shared.updateGain(gain)
    }

    /// Update beat frequency on a currently running binaural tone (no restart).
    /// Used for breath-modulated binaural in Empty Space.
    func setBeat(_ beat: Float) {
        BinauralEngine.shared.updateBeat(beat)
        currentBeat = beat
    }
}
