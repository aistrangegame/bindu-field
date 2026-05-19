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
    private var carrierDerivationTimer: Timer?
    private var derivedCarrier: CarrierProfileSwift?

    // MARK: Downmix buffer (allocated once, reused per tap callback)
    private var monoBuffer: UnsafeMutablePointer<Float>?
    private var monoBufferCapacity: Int = 0
    private let monoBufferLock = NSLock()  // only for capacity changes (rare)

    // MARK: - Public API

    /// Configure the audio engine. Call once at app startup, before any playback.
    /// Idempotent — safe to call multiple times.
    @objc public func configure() {
        if isConfigured { return }

        do {
            try configureAudioSession()
        } catch {
            NSLog("[BinauralListener] Failed to configure audio session: \(error)")
            return
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

        // Allocate downmix buffer (8192 frames covers any reasonable tap buffer size)
        allocateMonoBuffer(capacity: 8192)

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

        // Schedule the file for playback
        playerNode.scheduleFile(file, at: nil, completionCallbackType: .dataPlayedBack) {
            [weak self] _ in
            // Playback complete — fire JS event if needed
            DispatchQueue.main.async {
                self?.handlePlaybackComplete()
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

        playerNode.stop()
        carrierDerivationTimer?.invalidate()
        carrierDerivationTimer = nil
        isSessionActive = false
        currentFile = nil
        currentTrackURL = nil

        NSLog("[BinauralListener] Session stopped")
    }

    /// Read the most recent BinduFrame from the DSP ring buffer.
    /// Called by JS bridge at ~100ms intervals.
    /// Returns nil if no frame is available yet.
    @objc public func readLatestFrame() -> [String: Any]? {
        return dsp.readLatestFrame()
    }

    /// Get the derived CarrierProfile. Returns nil if derivation hasn't completed yet.
    @objc public func getCarrierProfile() -> [String: Any]? {
        guard let carrier = derivedCarrier else { return nil }
        return [
            "carrierHz": carrier.carrierHz,
            "salienceScore": carrier.salienceScore,
            "derivedFromAudio": carrier.derivedFromAudio
        ]
    }

    /// Check whether a session is currently active.
    @objc public func isActive() -> Bool {
        return isSessionActive
    }

    /// Get diagnostic info — frames produced by DSP so far this session.
    @objc public func diagnostics() -> [String: Any] {
        return [
            "framesProduced": dsp.framesProduced(),
            "sessionAge": isSessionActive ? (Date().timeIntervalSince1970 - sessionStartTime) : 0,
            "carrierDerived": derivedCarrier != nil,
            "engineRunning": engine.isRunning
        ]
    }

    // MARK: - Private: Audio session

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playback,
            mode: .default
        )
        try session.setActive(true)
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

        let frameCount = Int(buffer.frameLength)
        if frameCount <= 0 { return }

        // Compute host time in seconds.
        // mach_absolute_time() → host ticks → seconds via mach_timebase_info.
        let hostTime = hostTimeToSeconds(time.hostTime)

        let channelCount = Int(buffer.format.channelCount)

        // Ensure mono buffer is large enough
        if frameCount > monoBufferCapacity {
            allocateMonoBuffer(capacity: max(frameCount, monoBufferCapacity * 2))
        }

        guard let mono = monoBuffer else { return }

        if channelCount == 1 {
            // Already mono — direct copy
            mono.update(from: channelData[0], count: frameCount)
        } else {
            // Stereo or multi-channel — downmix L+R to mono via vDSP
            let leftPtr = channelData[0]
            let rightPtr = channelData[1]

            // mono = (L + R) * 0.5
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

    private func allocateMonoBuffer(capacity: Int) {
        monoBufferLock.lock()
        defer { monoBufferLock.unlock() }

        if let existing = monoBuffer {
            existing.deallocate()
        }
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
