import Foundation
import AVFoundation
import Observation
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
@Observable
final class AudioSessionCoordinator {
    static let shared = AudioSessionCoordinator()

    enum Mode: String {
        case playback        // tone + music output only
        case playAndRecord   // microphone capture (Letters)
    }

    private(set) var currentMode: Mode = .playback

    /// O20: observable so a `RootView` banner can surface session failures
    /// instead of swallowing them in logs. `nil` once a subsequent call
    /// succeeds — the banner is fresh-error-only.
    private(set) var lastError: Error?

    /// Reference counts per mode. The active mode is the highest-priority
    /// non-zero entry (recording wins over playback). When the recording
    /// count drops to zero, we fall back to playback.
    private var refCounts: [Mode: Int] = [.playback: 0, .playAndRecord: 0]

    private let log = Logger(subsystem: "com.bindufield", category: "audio.session")

    /// Retained observer tokens. `addObserver(forName:queue:using:)` returns
    /// an opaque object the registration is bound to — let it deallocate and
    /// the notification stops firing.
    private var interruptionObserver: NSObjectProtocol?
    private var mediaResetObserver: NSObjectProtocol?

    private init() {
        registerSystemObservers()
    }

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

    /// Dismiss the surfaced error banner. Lets the RootView banner be
    /// user-dismissable instead of waiting for the next successful
    /// session transition to self-clear.
    func clearError() {
        lastError = nil
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

    // MARK: - System notifications
    //
    // Even with `audio` in UIBackgroundModes, the audio session can be
    // interrupted (phone call, Siri, alarm) or torn down (mediaServices
    // reset). Without an observer, the engines stay paused after the
    // interruption ends. Re-activate the session and tell engines to
    // restart themselves via `.binduAudioSessionShouldRestart`.

    private func registerSystemObservers() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleInterruption(notification)
            }
        }

        mediaResetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMediaServicesReset()
            }
        }
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else { return }

        switch type {
        case .began:
            // System paused our audio; engines' .isRunning is now false.
            // Our Swift-side state (BinauralEngine.isRunning, etc.) is
            // intact, so we know what to restart when the interruption ends.
            log.info("Interruption began")
        case .ended:
            let optsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let opts = AVAudioSession.InterruptionOptions(rawValue: optsRaw)
            log.info("Interruption ended (shouldResume=\(opts.contains(.shouldResume), privacy: .public))")
            if opts.contains(.shouldResume) {
                reactivateAndSignalRestart()
            }
        @unknown default:
            break
        }
    }

    private func handleMediaServicesReset() {
        log.error("Media services reset — rebuilding audio session")
        applyCategory(currentMode)
        NotificationCenter.default.post(name: .binduAudioSessionShouldRestart, object: nil)
    }

    private func reactivateAndSignalRestart() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            log.info("AudioSession reactivated after interruption")
            lastError = nil
        } catch {
            lastError = error
            log.error("AudioSession reactivation failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        NotificationCenter.default.post(name: .binduAudioSessionShouldRestart, object: nil)
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

extension Notification.Name {
    /// Posted by `AudioSessionCoordinator` after the audio session has been
    /// reactivated following an interruption (`.shouldResume`) or media
    /// services reset. Engines observe this and restart themselves if
    /// their Swift-side `isRunning` flag indicates they should be playing.
    static let binduAudioSessionShouldRestart = Notification.Name("BinduAudioSessionShouldRestart")
}
