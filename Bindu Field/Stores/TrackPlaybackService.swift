import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class TrackPlaybackService {
    static let shared = TrackPlaybackService()

    private(set) var isPlaying: Bool = false
    private(set) var duration: TimeInterval = 0
    private var startTime: Date?

    var elapsed: TimeInterval {
        guard isPlaying, let start = startTime else { return 0 }
        return min(Date().timeIntervalSince(start), duration)
    }

    var hasCompleted: Bool {
        isPlaying && duration > 0 && elapsed >= duration
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
        startTime = Date()
    }

    func stop() {
        guard isPlaying else { return }
        DSPWireService.shared.stopPolling()
        BinauralListener.shared.stopSession()
        BinauralEngine.shared.stop()
        isPlaying = false
        duration = 0
        startTime = nil
    }
}
