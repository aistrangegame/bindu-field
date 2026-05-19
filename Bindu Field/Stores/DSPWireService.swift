import Foundation
import Observation

/// Bridges BinauralListener's analysis output to BinauralEngine's gain control,
/// and exposes audio-reactive state to the visualizer.
///
/// Polls `BinauralListener.readLatestFrame()` 10x/second while music plays,
/// inverts the RMS envelope, scales by user presence + global gain, and
/// pushes the result into `BinauralEngine.updateGain`.
///
/// Observes `.binduCarrierDerived` to lock the engine carrier to the
/// derived song carrier, and `.binduPlaybackComplete` to drone-down when
/// the music ends.
@MainActor
@Observable
final class DSPWireService {
    static let shared = DSPWireService()

    // Observable state — VisualizerView reads these
    private(set) var rms: Float = 0
    private(set) var hasOnset: Bool = false
    private(set) var carrierLocked: Bool = false
    private(set) var isMusicPlaying: Bool = false

    // User-controlled presence (0.0–1.0, default 0.7)
    var userPresence: Float = 0.7

    // Binaural on/off (user toggle)
    var binauralEnabled: Bool = true {
        didSet { binauralEnabled ? resumeBinaural() : suspendBinaural() }
    }

    private var pollingTimer: Timer?
    private var lastGain: Float = 0
    private let gainChangeThreshold: Float = 0.02

    // Retained observer tokens — addObserver(forName:queue:using:) returns
    // an opaque protocol object that must be retained for the registration
    // to remain active.
    private var carrierObserver: NSObjectProtocol?
    private var completeObserver: NSObjectProtocol?

    private init() { registerNotifications() }

    // MARK: - Polling lifecycle

    func startPolling() {
        isMusicPlaying = true
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            // Timer fires on the main run loop; hop into MainActor isolation
            // so we can touch DSPWireService state without a Task.
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isMusicPlaying = false
        rms = 0
        hasOnset = false
        lastGain = 0
    }

    /// Clear the carrier-lock visual flag. Called by TrackPlaybackService
    /// at the start of a new track so the next derivation pulse fires cleanly.
    func resetCarrierLock() {
        carrierLocked = false
    }

    // MARK: - Tick — 10 Hz

    private func tick() {
        guard binauralEnabled,
              let frame = BinauralListener.shared.readLatestFrame() else { return }

        // BinduDSPBridge marshals BinduFrame -> NSDictionary.
        // Keys: "rms" (Float), "onsetFlag" (Bool), "centroid" (Float),
        //       "flux" (Float), "onsetStrength" (Float), "timestamp" (Double).
        let newRMS = frame["rms"] as? Float ?? 0
        let onset = frame["onsetFlag"] as? Bool ?? false

        rms = newRMS
        hasOnset = onset

        let targetGain = computeGain(rms: newRMS)
        if abs(targetGain - lastGain) > gainChangeThreshold {
            BinauralEngine.shared.updateGain(targetGain * SettingsStore.shared.gain)
            lastGain = targetGain
        }
    }

    // MARK: - Inverse RMS gain curve

    private func computeGain(rms: Float) -> Float {
        // Loud music → quiet binaural. sqrt curve feels more musical than linear.
        // Floor at 0.1 so the binaural never fully disappears.
        let inverted = 1.0 - min(rms, 1.0)
        let curved = sqrtf(inverted) * 0.9 + 0.1
        return curved * userPresence
    }

    // MARK: - Notifications

    private func registerNotifications() {
        carrierObserver = NotificationCenter.default.addObserver(
            forName: .binduCarrierDerived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // BinauralListener posts carrierHz as Float.
            guard let hz = notification.userInfo?["carrierHz"] as? Float else { return }
            MainActor.assumeIsolated {
                BinauralEngine.shared.setCarrier(hz)
                self?.carrierLocked = true
            }
            // Reset the visual flag after a 500ms acknowledgment window.
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 500_000_000)
                self?.carrierLocked = false
            }
        }

        completeObserver = NotificationCenter.default.addObserver(
            forName: .binduPlaybackComplete,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMusicEnded()
            }
        }
    }

    // MARK: - Drone ending

    private func handleMusicEnded() {
        // Music has ended. Stop polling but leave the binaural engine
        // running at a reduced gain. The field dissipates, it doesn't die.
        stopPolling()
        let droneGain = userPresence * 0.2 * SettingsStore.shared.gain
        BinauralEngine.shared.updateGain(droneGain)
    }

    // MARK: - Binaural on/off

    private func suspendBinaural() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        BinauralEngine.shared.updateGain(0)
    }

    private func resumeBinaural() {
        if isMusicPlaying { startPolling() }
    }
}
