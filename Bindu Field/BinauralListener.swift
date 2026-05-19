//
//  BinauralListener.swift
//  ASG / Bindu Field
//
//  Swift wrapper around the C++ BinduDSP kernel.
//  Owns an AVAudioEngine, installs an analysis tap on the player node,
//  forwards mono PCM to the kernel, and exposes a NativeModules interface.
//
//  Architecture (Path B — AVAudioEngine player ownership):
//
//      AVAudioFile (track in app library)
//             │
//             ▼
//      AVAudioPlayerNode  ──── analysis tap ────► BinduDSP.processBlock()
//             │
//             ▼
//      AVAudioMixerNode
//             │
//             ▼
//      AVAudioEngine.mainMixerNode
//             │
//             ▼
//      Hardware output
//
//  The audio engine drives playback directly via AVAudioPlayerNode.
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - BinauralListener

@objc(BinauralListener)
public final class BinauralListener: NSObject {

    // MARK: Singleton
    @objc public static let shared = BinauralListener()

    // MARK: Audio graph
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let mixerNode = AVAudioMixerNode()

    // MARK: DSP kernel (ObjC++ bridge)
    private let dsp = BinduDSPBridge()

    // MARK: State
    private var isConfigured = false
    private var isSessionActive = false
    private var sessionStartTime: TimeInterval = 0
    private var currentTrackURL: URL?
    private var currentFile: AVAudioFile?
    private var derivedCarrier: CarrierProfileSwift?

    /// Set to `true` by `stopSession()` so the completion callback on
    /// AVAudioPlayerNode (which can fire shortly after a manual stop as
    /// the buffer drains) doesn't post `.binduPlaybackComplete` for what
    /// was actually a user-initiated stop.
    private var userStopped: Bool = false

    private let audioSessionID = "BinauralListener"

    // MARK: Downmix buffer
    //
    // Pre-allocated once at configure() to a worst-case ceiling. The audio
    // tap thread reads `monoBuffer` without a lock; reallocation would
    // race with that read. We size for far more than iOS ever returns
    // (typical tap buffer is 4800–9600 frames at 48 kHz) and never
    // re-allocate; if a buffer ever overruns this ceiling we clamp.
    private static let monoBufferCeiling: Int = 32768
    private var monoBuffer: UnsafeMutablePointer<Float>?
    private var monoBufferCapacity: Int = 0

    // MARK: - Public API

    /// Configure the audio engine. Call once at app startup, before any playback.
    /// Idempotent — safe to call multiple times.
    @objc public func configure() {
        if isConfigured { return }

        // Audio session category is owned by AudioSessionCoordinator.
        DispatchQueue.main.async {
            AudioSessionCoordinator.shared.requestPlayback(self.audioSessionID)
        }

        // Attach nodes
        engine.attach(playerNode)
        engine.attach(mixerNode)

        // Determine canonical format from output hardware
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 48000.0

        // Connect: player -> mixer -> mainMixer -> output
        // Player and mixer use the hardware format for clean routing.
        let processingFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )

        engine.connect(playerNode, to: mixerNode, format: processingFormat)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: processingFormat)

        // Install analysis tap on the player node's output bus.
        // Tap fires whenever the player node produces output, regardless of
        // downstream routing. Buffer size is advisory.
        installAnalysisTap(format: processingFormat)

        // Initialize DSP kernel
        dsp.initialize(withSampleRate: Float(sampleRate))

        // One-time allocation, never resized — see monoBufferCeiling rationale.
        allocateMonoBuffer(capacity: BinauralListener.monoBufferCeiling)

        // Start the engine
        do {
            try engine.start()
            isConfigured = true
            NSLog("[BinauralListener] Configured at \(sampleRate) Hz")
        } catch {
            NSLog("[BinauralListener] Failed to start engine: \(error)")
        }
    }

    /// Begin a new listening session for a track. Resets DSP state, schedules
    /// carrier derivation after 10 seconds of playback.
    /// - Parameter trackURL: file URL of the audio track to play
    @objc public func startSession(trackURL: URL) -> Bool {
        guard isConfigured else {
            NSLog("[BinauralListener] startSession called before configure()")
            return false
        }

        // Stop any previous session cleanly
        if isSessionActive {
            stopSession()
        }

        // Load the audio file
        do {
            currentFile = try AVAudioFile(forReading: trackURL)
            currentTrackURL = trackURL
        } catch {
            NSLog("[BinauralListener] Failed to load track \(trackURL): \(error)")
            return false
        }

        guard let file = currentFile else { return false }

        // Reset DSP state for clean carrier derivation
        dsp.reset()
        derivedCarrier = nil
        sessionStartTime = Date().timeIntervalSince1970
        userStopped = false

        // Schedule the file for playback
        playerNode.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) {
            [weak self] _ in
            // Playback complete — fire only if this wasn't a user-initiated stop.
            DispatchQueue.main.async {
                guard let self, !self.userStopped else { return }
                self.handlePlaybackComplete()
            }
        }

        // Begin playback
        playerNode.play()
        isSessionActive = true

        // Schedule carrier derivation in 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.performCarrierDerivation()
        }

        NSLog("[BinauralListener] Session started for \(trackURL.lastPathComponent)")
        return true
    }

    /// Stop the current session. Safe to call when no session is active.
    @objc public func stopSession() {
        if !isSessionActive { return }

        // Mark the stop as user-initiated so the scheduleFile completion
        // callback (which can still fire as the buffer drains) doesn't
        // raise the Integration Chamber via .binduPlaybackComplete.
        userStopped = true
        playerNode.stop()
        isSessionActive = false
        currentFile = nil
        currentTrackURL = nil

        NSLog("[BinauralListener] Session stopped")
    }

    /// Read the most recent BinduFrame from the DSP ring buffer.
    /// Polled by DSPWireService at ~10 Hz.
    @objc public func readLatestFrame() -> [String: Any]? {
        return dsp.readLatestFrame()
    }

    /// Check whether a session is currently active.
    @objc public func isActive() -> Bool {
        return isSessionActive
    }

    /// Sample-accurate player-node clock. Returns `nil` before the node
    /// has produced its first sample. Used by `TrackPlaybackService` to
    /// derive elapsed time from the audio clock instead of wall clock.
    public func playerTime() -> (sampleTime: AVAudioFramePosition, sampleRate: Double)? {
        guard let last = playerNode.lastRenderTime,
              let player = playerNode.playerTime(forNodeTime: last)
        else { return nil }
        return (player.sampleTime, player.sampleRate)
    }

    // MARK: - Private: Tap installation

    private func installAnalysisTap(format: AVAudioFormat?) {
        // Buffer size is advisory; iOS typically returns 4800–9600 frames at 48 kHz.
        let advisoryBufferSize: AVAudioFrameCount = 1024

        playerNode.installTap(
            onBus: 0,
            bufferSize: advisoryBufferSize,
            format: format
        ) { [weak self] buffer, time in
            self?.handleAnalysisTap(buffer: buffer, time: time)
        }
    }

    private func handleAnalysisTap(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData else { return }

        var frameCount = Int(buffer.frameLength)
        if frameCount <= 0 { return }

        // Clamp to the pre-allocated ceiling. iOS never returns tap blocks
        // anywhere near 32k frames, but if it ever does we discard the
        // tail rather than reallocate from under the audio thread.
        if frameCount > monoBufferCapacity {
            frameCount = monoBufferCapacity
        }

        // Compute host time in seconds.
        let hostTime = hostTimeToSeconds(time.hostTime)

        let channelCount = Int(buffer.format.channelCount)
        guard let mono = monoBuffer else { return }

        if channelCount == 1 {
            // Already mono — direct copy
            mono.update(from: channelData[0], count: frameCount)
        } else {
            // Stereo or multi-channel — downmix L+R to mono via vDSP
            let leftPtr = channelData[0]
            let rightPtr = channelData[1]

            vDSP_vadd(leftPtr, 1, rightPtr, 1, mono, 1, vDSP_Length(frameCount))
            var scale: Float = 0.5
            vDSP_vsmul(mono, 1, &scale, mono, 1, vDSP_Length(frameCount))
        }

        // Forward to DSP kernel
        dsp.processBlock(
            withSamples: UnsafePointer(mono),
            count: Int32(frameCount),
            hostTime: hostTime
        )
    }

    // MARK: - Private: Mono buffer management
    //
    // Called exactly once from `configure()`. Never resized while the
    // audio thread is reading — that would race the tap callback.

    private func allocateMonoBuffer(capacity: Int) {
        guard monoBuffer == nil else { return }
        monoBuffer = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
        monoBuffer?.initialize(repeating: 0, count: capacity)
        monoBufferCapacity = capacity
    }

    // MARK: - Private: Host time conversion

    private static var timebaseInfo: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private func hostTimeToSeconds(_ hostTime: UInt64) -> Double {
        let info = BinauralListener.timebaseInfo
        let nanos = Double(hostTime) * Double(info.numer) / Double(info.denom)
        return nanos / 1_000_000_000.0
    }

    // MARK: - Private: Carrier derivation

    private func performCarrierDerivation() {
        guard isSessionActive else { return }

        let profileDict = dsp.deriveCarrier()

        // Parse the dictionary returned by the bridge
        guard let carrierHz = profileDict["carrierHz"] as? Float,
              let salience = profileDict["salienceScore"] as? Float,
              let derived = profileDict["derivedFromAudio"] as? Bool else {
            NSLog("[BinauralListener] Carrier derivation returned invalid data")
            return
        }

        derivedCarrier = CarrierProfileSwift(
            carrierHz: carrierHz,
            salienceScore: salience,
            derivedFromAudio: derived
        )

        NSLog("[BinauralListener] Carrier derived: \(carrierHz) Hz, salience \(salience), fromAudio \(derived)")

        // Notify JS layer via event emitter (handled in bridge .m file)
        NotificationCenter.default.post(
            name: .binduCarrierDerived,
            object: nil,
            userInfo: [
                "carrierHz": carrierHz,
                "salienceScore": salience,
                "derivedFromAudio": derived
            ]
        )
    }

    // MARK: - Private: Playback completion

    private func handlePlaybackComplete() {
        NotificationCenter.default.post(name: .binduPlaybackComplete, object: nil)
    }
}

// MARK: - Supporting Types

private struct CarrierProfileSwift {
    let carrierHz: Float
    let salienceScore: Float
    let derivedFromAudio: Bool
}

// MARK: - Notifications

extension Notification.Name {
    static let binduCarrierDerived = Notification.Name("BinduCarrierDerived")
    static let binduPlaybackComplete = Notification.Name("BinduPlaybackComplete")
}
