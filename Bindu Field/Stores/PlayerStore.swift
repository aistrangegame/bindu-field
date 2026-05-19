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

    /// Optional note captured by the Integration Chamber. Read once and
    /// cleared by `finalizeCurrentSession`.
    var pendingNote: String? = nil

    /// Most recent track-fetch error message (O21). Surfaced as a banner
    /// in `PlayerView` so the user knows why music is silent / replaced
    /// with binaural-only. Cleared on the next successful start.
    var lastFetchError: String? = nil

    private init() {}

    func configureEngine() {
        BinauralEngine.shared.configure()
    }

    /// Play a track: stream/cache the audio file, layer the binaural tone on top,
    /// present the Player modal. Falls back to binaural-only if the download fails.
    func play(_ track: Track) {
        // O17: ignore a rapid retap of the same track while the first is
        // still being fetched / starting up. Without this, two parallel
        // continuations both call TrackPlaybackService.play and the
        // second tears down the first's audio audibly.
        if isLoadingTrack, currentTrack?.id == track.id { return }

        // Save any in-flight session before swapping tracks
        finalizeCurrentSession(completed: false)

        let carrier = Float(track.carrierHz)
        let beat = Float(track.beatHz)

        currentTrack = track
        currentCarrier = carrier
        currentBeat = beat
        isPresentingPlayer = true
        isLoadingTrack = true

        // Stop any prior audio. TrackPlaybackService.stop() handles both
        // the music engine (BinauralListener) and the tone engine
        // (BinauralEngine); calling BinauralEngine.stop() too would be
        // a redundant fade-out trigger (B5).
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
                    duration: dur > 0 ? dur : 600,
                    elapsedProvider: { [weak svc = TrackPlaybackService.shared] in
                        svc?.elapsed ?? 0
                    }
                )
            } catch {
                // O21: surface the failure so the user knows why the track
                // didn't appear, then gracefully fall back to binaural-only.
                guard currentTrack?.id == myTrack.id else { return }
                isLoadingTrack = false
                lastFetchError = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
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

    /// Tear down audio and finalize the in-flight session.
    /// `completed: true` only when the track ran to its natural end
    /// (the Integration Chamber close path). User-initiated stops
    /// (lock-screen, stop button, X button) leave the default `false`.
    func stop(completed: Bool = false) {
        TrackPlaybackService.shared.stop()  // stops both engines
        finalizeCurrentSession(completed: completed)
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

        let trimmed = pendingNote?.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = (trimmed?.isEmpty == false) ? trimmed : nil
        pendingNote = nil

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
            completed: completed,
            note: note
        )
        SessionStore.shared.save(session)
    }

    /// Close the player and stop audio. Pass `completed: true` only from
    /// the natural-end path (Integration Chamber); user-initiated closes
    /// keep the default `false` so the Archive reflects an early stop.
    func closePlayer(completed: Bool = false) {
        stop(completed: completed)
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

    /// Update carrier frequency on a currently running binaural tone
    /// (B7). The engine glides to the new value over ~10 s.
    func setCarrier(_ carrier: Float) {
        BinauralEngine.shared.setCarrier(carrier)
        currentCarrier = carrier
    }
}
