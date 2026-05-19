import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class TrackPlaybackService {
    static let shared = TrackPlaybackService()

    private(set) var isPlaying: Bool = false
    /// True while a session is active but audio has been paused. Mirrors
    /// `BinauralListener.shared.isPaused`; kept here as the @Observable
    /// source of truth for SwiftUI views and the scene-phase reconciler.
    private(set) var isPaused: Bool = false
    private(set) var duration: TimeInterval = 0
    private var startTime: Date?
    private var startSampleTime: AVAudioFramePosition = 0

    /// Elapsed time. Prefers the audio clock (sample-accurate, immune to
    /// background-suspension drift); falls back to wall-clock only before
    /// the player node has produced its first sample.
    var elapsed: TimeInterval {
        guard isPlaying else { return 0 }
        if let audioClock = audioClockElapsed() {
            return min(audioClock, duration)
        }
        if let start = startTime {
            return min(Date().timeIntervalSince(start), duration)
        }
        return 0
    }

    var hasCompleted: Bool {
        isPlaying && duration > 0 && elapsed >= duration
    }

    private func audioClockElapsed() -> TimeInterval? {
        // BinauralListener owns the AVAudioPlayerNode; we read its
        // lastRenderTime / playerTime through a small accessor.
        guard let info = BinauralListener.shared.playerTime() else { return nil }
        let frames = info.sampleTime - startSampleTime
        guard info.sampleRate > 0 else { return nil }
        return max(0, Double(frames) / info.sampleRate)
    }

    private init() {}

    enum PlaybackError: LocalizedError {
        case listenerStartFailed

        var errorDescription: String? {
            switch self {
            case .listenerStartFailed: return "Failed to start audio playback."
            }
        }
    }

    /// Begin playback of a local audio file mixed with the binaural carrier/beat.
    /// Routes the music through `BinauralListener` (its `startSession(trackURL:)` API)
    /// and the binaural tone through `BinauralEngine` so both mix at the device output.
    func play(fileURL: URL, carrier: Float, beat: Float, gain: Float) throws {
        stop()

        // Read duration via AVAudioFile (frames / sampleRate)
        if let audioFile = try? AVAudioFile(forReading: fileURL) {
            let frames = audioFile.length
            let sampleRate = audioFile.fileFormat.sampleRate
            if sampleRate > 0 {
                duration = Double(frames) / sampleRate
            }
        }

        // === BinauralListener (music file)
        // Actual API: configure() + startSession(trackURL:) -> Bool + stopSession()
        BinauralListener.shared.configure()
        let started = BinauralListener.shared.startSession(trackURL: fileURL)
        guard started else {
            duration = 0
            throw PlaybackError.listenerStartFailed
        }

        // === BinauralEngine (binaural tone layered on top)
        // Actual API: start(carrierHz:) + updateBeat(_:) + updateGain(_:)
        BinauralEngine.shared.start(carrierHz: carrier)
        BinauralEngine.shared.updateBeat(beat)
        BinauralEngine.shared.updateGain(gain)

        // === DSPWireService: poll analysis frames and drive engine gain
        DSPWireService.shared.resetCarrierLock()
        DSPWireService.shared.startPolling()

        isPlaying = true
        isPaused = false
        startTime = Date()
        startSampleTime = BinauralListener.shared.playerTime()?.sampleTime ?? 0
    }

    func stop() {
        guard isPlaying else { return }
        DSPWireService.shared.stopPolling()
        BinauralListener.shared.stopSession()
        BinauralEngine.shared.stop()
        isPlaying = false
        isPaused = false
        duration = 0
        startTime = nil
    }

    /// Pause both engines and the DSP wire. The session stays "active"
    /// (isPlaying remains true) — only audio rendering halts. The player
    /// node's sample clock freezes, so `elapsed` naturally pauses too.
    func pause() {
        guard isPlaying, !isPaused else { return }
        DSPWireService.shared.stopPolling()
        BinauralListener.shared.pause()
        BinauralEngine.shared.pause()
        isPaused = true
        NowPlayingService.shared.setPaused(true)
    }

    /// Resume from a paused state. Restores engine gain, un-pauses the
    /// player node (resumes from the exact sample where it was paused),
    /// and kicks DSP polling back up.
    func resume() {
        guard isPlaying, isPaused else { return }
        BinauralEngine.shared.resume()
        BinauralListener.shared.resume()
        DSPWireService.shared.startPolling()
        isPaused = false
        NowPlayingService.shared.setPaused(false)
    }

    func togglePlayPause() {
        if isPaused { resume() } else { pause() }
    }
}
