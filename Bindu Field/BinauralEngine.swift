//
//  BinauralEngine.swift
//  Bindu Field
//
//  Real-time binaural beat generator with hybrid AM modulation.
//
//  Architecture:
//    - AVAudioEngine + AVAudioSourceNode render callback
//    - Left ear:  sin(2π · carrierHz · t)
//    - Right ear: sin(2π · (carrierHz + beatHz) · t)
//    - Both channels modulated by (1 + amDepth · sin(2π · beatHz · t)) / (1 + amDepth)
//    - Exponential smoothing for all parameter changes (no audible clicks)
//
//  The hybrid binaural + AM approach combines:
//    - Phantom binaural beat (generated in brainstem olivary nucleus)
//    - Physical monaural beat (audible amplitude oscillation at same frequency)
//  Both reinforce each other at the target brainwave frequency.
//
//  Threading:
//    - Render callback runs on a real-time audio thread
//    - Parameter setters write to instance properties; render callback reads them
//    - Single-word float writes are naturally atomic on ARM
//    - Smoothing in render callback prevents audible parameter jumps
//

import Foundation
import AVFoundation

@objc(BinauralEngine)
public final class BinauralEngine: NSObject {

    // MARK: - Singleton

    @objc public static let shared = BinauralEngine()

    // MARK: - Audio graph

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let mixerNode = AVAudioMixerNode()

    // MARK: - Configuration

    private var sampleRate: Double = 48000.0
    private var isRunning = false

    // MARK: - Render parameters (read by render callback, written by setters)
    //
    // All marked private(set) where externally read; render callback accesses
    // these via the captured self reference. Float writes are atomic on ARM
    // for naturally-aligned word stores.

    // Carrier frequency
    private var carrierTarget: Float = 136.1
    private var carrierCurrent: Float = 136.1
    private let carrierGlideAlpha: Float = 0.0002    // ~10s time constant @ 48kHz

    // Binaural beat frequency
    private var beatTarget: Float = 7.5
    private var beatCurrent: Float = 7.5
    private let beatGlideAlpha: Float = 0.0008      // ~2.5s time constant

    // Output gain
    private var gainTarget: Float = 0.0
    private var gainCurrent: Float = 0.0
    private let gainGlideAlpha: Float = 0.0010      // ~2s time constant

    // AM modulation depth (0 = pure binaural, 0.30 = strong tremolo)
    private var amDepthTarget: Float = 0.15
    private var amDepthCurrent: Float = 0.0         // starts at 0, glides up
    private let amDepthGlideAlpha: Float = 0.0005   // ~4s time constant

    // MARK: - Render state (oscillator phases)
    //
    // Phases must persist across render callback invocations to maintain
    // continuous waveforms. They wrap to [0, 2π] each sample for numerical
    // stability.

    private var leftPhase: Float = 0.0
    private var rightPhase: Float = 0.0
    private var amPhase: Float = 0.0

    // Two-pi constant (avoid repeated computation in hot loop)
    private let TWO_PI = Float.pi * 2.0

    // MARK: - Configuration

    /// Set up the audio engine. Call once before start().
    /// Idempotent — safe to call multiple times.
    @objc public func configure() {
        if sourceNode != nil { return }

        do {
            try configureAudioSession()
        } catch {
            NSLog("[BinauralEngine] Audio session configuration failed: \(error)")
            return
        }

        // Determine sample rate from hardware
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 48000.0

        // Create stereo output format matching hardware sample rate
        guard let stereoFormat = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        ) else {
            NSLog("[BinauralEngine] Failed to create stereo format")
            return
        }

        // Create the source node — its render block produces our binaural audio
        let source = AVAudioSourceNode(format: stereoFormat) {
            [weak self] (_, _, frameCount, audioBufferList) -> OSStatus in
            return self?.renderCallback(
                frameCount: frameCount,
                audioBufferList: audioBufferList
            ) ?? noErr
        }
        self.sourceNode = source

        // Build graph: source → mixer → mainMixer → output
        engine.attach(source)
        engine.attach(mixerNode)
        engine.connect(source, to: mixerNode, format: stereoFormat)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: stereoFormat)

        NSLog("[BinauralEngine] Configured at \(sampleRate) Hz")
    }

    // MARK: - Lifecycle

    /// Start the binaural engine with the given initial carrier frequency.
    /// Carrier can be updated later via setCarrier().
    @objc public func start(carrierHz: Float) {
        if isRunning { return }

        configure()
        carrierTarget = clampCarrier(carrierHz)
        carrierCurrent = carrierTarget  // start at target, no glide on first start

        do {
            try engine.start()
            isRunning = true
            NSLog("[BinauralEngine] Started at carrier \(carrierTarget) Hz")
        } catch {
            NSLog("[BinauralEngine] Failed to start engine: \(error)")
        }
    }

    /// Stop the engine and fade out gracefully.
    @objc public func stop() {
        if !isRunning { return }

        // Fade gain to zero — the render callback will glide it down over ~2s
        gainTarget = 0.0

        // Stop after fade completes
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.5) {
            [weak self] in
            guard let self = self, self.isRunning else { return }
            self.engine.stop()
            self.isRunning = false
            NSLog("[BinauralEngine] Stopped")
        }
    }

    // MARK: - Parameter setters
    //
    // All setters perform clamping + single float write.
    // The render callback reads these values each block and glides toward them.

    /// Set the carrier frequency. Render callback glides smoothly over ~10s.
    @objc public func setCarrier(_ hz: Float) {
        carrierTarget = clampCarrier(hz)
    }

    /// Set the binaural beat frequency.
    @objc public func updateBeat(_ hz: Float) {
        beatTarget = max(0.5, min(40.0, hz))
    }

    /// Set the output gain. Typical range: 0.005 (subthreshold) to 0.050 (deep presence).
    /// Hard ceiling at 0.10 for safety.
    @objc public func updateGain(_ gain: Float) {
        gainTarget = max(0.0, min(0.10, gain))
    }

    /// Set the AM modulation depth.
    /// 0.0 = pure binaural. 0.15 = subtle tremolo reinforcement. 0.30 = maximum.
    @objc public func updateAMDepth(_ depth: Float) {
        amDepthTarget = max(0.0, min(0.30, depth))
    }

    // MARK: - Diagnostics

    @objc public func diagnostics() -> [String: Any] {
        return [
            "isRunning": isRunning,
            "sampleRate": sampleRate,
            "carrierTarget": carrierTarget,
            "carrierCurrent": carrierCurrent,
            "beatTarget": beatTarget,
            "beatCurrent": beatCurrent,
            "gainTarget": gainTarget,
            "gainCurrent": gainCurrent,
            "amDepthTarget": amDepthTarget,
            "amDepthCurrent": amDepthCurrent
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

    // MARK: - Private: Clamping

    private func clampCarrier(_ hz: Float) -> Float {
        return max(60.0, min(500.0, hz))
    }

    // MARK: - Render callback (REAL-TIME HOT PATH)
    //
    // Called by the audio system at the buffer rate. Must complete within the
    // available time budget (typically <2ms for 256-sample blocks at 48kHz).
    //
    // Constraints:
    //   - No allocation
    //   - No locks
    //   - No Objective-C / Swift dispatch except trivial captures
    //   - No system calls
    //   - All math must be deterministic-time

    private func renderCallback(
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafePointer<AudioBufferList>
    ) -> OSStatus {

        let ablPointer = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: audioBufferList)
        )

        // Stereo output — two non-interleaved float buffers
        guard ablPointer.count >= 2 else { return noErr }

        let leftBuffer = ablPointer[0].mData?.assumingMemoryBound(to: Float.self)
        let rightBuffer = ablPointer[1].mData?.assumingMemoryBound(to: Float.self)

        guard let leftPtr = leftBuffer, let rightPtr = rightBuffer else {
            return noErr
        }

        // Sample rate as float for the inner loop
        let sr = Float(sampleRate)
        let invSR = 1.0 / sr

        // Snapshot glide targets for this block.
        // (Reading the targets each sample is fine, but block-coherent
        // snapshots match how AVAudioEngine schedules parameter updates.)
        let cTarget = carrierTarget
        let bTarget = beatTarget
        let gTarget = gainTarget
        let amTarget = amDepthTarget

        // Local copies of current values — write back at end of block.
        // This avoids re-reading the volatile instance properties N times per block.
        var c = carrierCurrent
        var b = beatCurrent
        var g = gainCurrent
        var am = amDepthCurrent

        var lp = leftPhase
        var rp = rightPhase
        var ap = amPhase

        // Pre-compute glide alphas as local floats
        let cAlpha = carrierGlideAlpha
        let bAlpha = beatGlideAlpha
        let gAlpha = gainGlideAlpha
        let amAlpha = amDepthGlideAlpha

        let frames = Int(frameCount)

        for i in 0..<frames {

            // === Glide parameters toward their targets ===
            c += (cTarget - c) * cAlpha
            b += (bTarget - b) * bAlpha
            g += (gTarget - g) * gAlpha
            am += (amTarget - am) * amAlpha

            // === Advance oscillator phases ===
            let leftFreq = c
            let rightFreq = c + b
            let amFreq = b

            lp += TWO_PI * leftFreq * invSR
            rp += TWO_PI * rightFreq * invSR
            ap += TWO_PI * amFreq * invSR

            // Wrap phases to [0, 2π] for numerical stability
            if lp > TWO_PI { lp -= TWO_PI }
            if rp > TWO_PI { rp -= TWO_PI }
            if ap > TWO_PI { ap -= TWO_PI }

            // === Compute sine outputs ===
            var leftSample = sinf(lp)
            var rightSample = sinf(rp)

            // === Apply AM modulation at beat frequency ===
            //
            // amMod = (1 + d · sin(amPhase)) / (1 + d)
            //
            // Normalized so peak amplitude stays at 1.0 regardless of depth.
            // When d = 0: amMod = 1 (no modulation)
            // When d = 0.15: amMod oscillates between 0.74 and 1.0
            // When d = 0.30: amMod oscillates between 0.54 and 1.0
            let amSin = sinf(ap)
            let amMod = (1.0 + am * amSin) / (1.0 + am)

            leftSample *= amMod
            rightSample *= amMod

            // === Apply output gain ===
            leftSample *= g
            rightSample *= g

            // === Write to output buffers ===
            leftPtr[i] = leftSample
            rightPtr[i] = rightSample
        }

        // Write back current values for next block
        carrierCurrent = c
        beatCurrent = b
        gainCurrent = g
        amDepthCurrent = am
        leftPhase = lp
        rightPhase = rp
        amPhase = ap

        return noErr
    }
}
