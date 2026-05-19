import Foundation
import AVFoundation
import os

/// Single owner of `AVAudioSession` category transitions.
///
/// Engines (`BinauralEngine`, `BinauralListener`) and the recorder
/// (`RecorderService`) request the mode they need via this coordinator
/// instead of calling `AVAudioSession.setCategory` directly. The
/// coordinator serializes transitions and tracks who currently needs
/// which mode via a small reference count so flipping between
/// `.playback` and `.playAndRecord` doesn't fight itself.
///
/// Threading: every public entry point is `@MainActor`. The underlying
/// `AVAudioSession` is documented safe to call from any thread; main-actor
/// confinement here is purely to serialize requesters.
@MainActor
final class AudioSessionCoordinator {
    static let shared = AudioSessionCoordinator()

    enum Mode: String {
        case playback        // tone + music output only
        case playAndRecord   // microphone capture (Letters)
    }

    private(set) var currentMode: Mode = .playback
    private(set) var lastError: Error?

    /// Reference counts per mode. The active mode is the highest-priority
    /// non-zero entry (recording wins over playback). When the recording
    /// count drops to zero, we fall back to playback.
    private var refCounts: [Mode: Int] = [.playback: 0, .playAndRecord: 0]

    private let log = Logger(subsystem: "com.bindufield", category: "audio.session")

    private init() {}

    /// One-time launch hook. Configures the audio session for playback so
    /// any subsequent engine starts see a session that's already active.
    /// Idempotent.
    func configureForLaunch() {
        applyCategory(.playback)
    }

    /// Request a mode for the given identifier. Identifier should be stable
    /// (e.g. "BinauralEngine", "BinauralListener", "RecorderService"). The
    /// coordinator increments the requester's count; the session adopts the
    /// highest-priority mode that has at least one requester.
    func requestPlayback(_ identifier: String) {
        increment(.playback, for: identifier)
        recompute()
    }

    func requestRecording(_ identifier: String) {
        increment(.playAndRecord, for: identifier)
        recompute()
    }

    /// Release one prior request from this identifier.
    func release(_ identifier: String, mode: Mode) {
        decrement(mode, for: identifier)
        recompute()
    }

    // MARK: - Private

    /// Tracks which identifier holds which mode count, so we can
    /// authoritatively release without overshoot.
    private var holders: [String: [Mode: Int]] = [:]

    private func increment(_ mode: Mode, for id: String) {
        refCounts[mode, default: 0] += 1
        holders[id, default: [:]][mode, default: 0] += 1
    }

    private func decrement(_ mode: Mode, for id: String) {
        let held = holders[id]?[mode] ?? 0
        guard held > 0 else { return }
        holders[id]?[mode] = held - 1
        if holders[id]?[mode] == 0 { holders[id]?[mode] = nil }
        if holders[id]?.isEmpty == true { holders[id] = nil }
        refCounts[mode] = max(0, (refCounts[mode] ?? 0) - 1)
    }

    private func recompute() {
        // Recording wins if anyone needs the mic.
        let desired: Mode = (refCounts[.playAndRecord] ?? 0) > 0
            ? .playAndRecord
            : .playback
        if desired != currentMode {
            applyCategory(desired)
        }
    }

    private func applyCategory(_ mode: Mode) {
        let session = AVAudioSession.sharedInstance()
        do {
            switch mode {
            case .playback:
                try session.setCategory(.playback, mode: .default)
            case .playAndRecord:
                try session.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.defaultToSpeaker, .allowBluetoothHFP]
                )
            }
            try session.setActive(true)
            currentMode = mode
            lastError = nil
            log.info("AudioSession → \(mode.rawValue, privacy: .public)")
        } catch {
            lastError = error
            log.error("AudioSession setCategory(\(mode.rawValue, privacy: .public)) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
