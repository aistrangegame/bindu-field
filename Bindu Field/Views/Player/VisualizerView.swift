import SwiftUI

/// Audio-reactive Bindu visualization.
///
/// Reads observable state from `DSPWireService.shared`:
///   - `rms` drives the bloom brightness around Bindu
///   - `hasOnset` emits an expanding ring at Bindu's current position
///   - `carrierLocked` triggers a brief 1.5x size pulse on Bindu
///   - `binauralEnabled` softens everything to 40% opacity when off
///
/// Bindu moves along a multi-harmonic Lissajous path. A rolling buffer
/// of the last 20 positions renders as a comet trail.
struct VisualizerView: View {
    let beat: Float       // Hz — preserved as legacy parameter (unused for motion)
    let color: Color

    @State private var wire = DSPWireService.shared

    @State private var trailPositions: [CGPoint] = []
    @State private var rings: [Ring] = []
    @State private var lastOnsetEmittedAt: Double = 0
    @State private var lastTrailSampleAt: Double = 0
    @State private var carrierPulse: CGFloat = 1.0

    private struct Ring: Identifiable {
        let id = UUID()
        let center: CGPoint
        let bornAt: Double
        let color: Color
    }

    // MARK: - Tunables
    private let trailLength: Int = 20
    private let trailSampleInterval: Double = 0.04   // ~25 Hz
    private let ringDurationSec: Double = 0.6
    private let ringMaxRadius: CGFloat = 80

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geo in
                let bindu = binduPosition(t: t, in: geo.size)

                Canvas { ctx, size in
                    let baseOpacity: Double = wire.binauralEnabled ? 1.0 : 0.4

                    // === Bloom around Bindu (RMS-driven) ===
                    let bloomR: CGFloat = 40 + CGFloat(wire.rms) * 60
                    let bloomRect = CGRect(
                        x: bindu.x - bloomR,
                        y: bindu.y - bloomR,
                        width: bloomR * 2,
                        height: bloomR * 2
                    )
                    let bloomOpacity = (0.18 + Double(wire.rms) * 0.45) * baseOpacity
                    ctx.fill(
                        Path(ellipseIn: bloomRect),
                        with: .radialGradient(
                            Gradient(colors: [
                                color.opacity(bloomOpacity),
                                color.opacity(0)
                            ]),
                            center: bindu,
                            startRadius: 0,
                            endRadius: bloomR
                        )
                    )

                    // === Beat rings (onset-spawned, age-fading) ===
                    for ring in rings {
                        let age = t - ring.bornAt
                        if age < 0 || age > ringDurationSec { continue }
                        let progress = age / ringDurationSec
                        let r = CGFloat(progress) * ringMaxRadius
                        let alpha = (0.6 * (1 - progress)) * baseOpacity
                        let rect = CGRect(
                            x: ring.center.x - r,
                            y: ring.center.y - r,
                            width: r * 2,
                            height: r * 2
                        )
                        ctx.stroke(
                            Path(ellipseIn: rect),
                            with: .color(ring.color.opacity(alpha)),
                            lineWidth: 1.4
                        )
                    }

                    // === Comet trail (oldest to newest, opacity ramp) ===
                    let trail = trailPositions
                    let n = trail.count
                    if n > 0 {
                        for (i, p) in trail.enumerated() {
                            // Newest at end of array. opacity climbs with i.
                            let frac = Double(i + 1) / Double(n)
                            let dotR: CGFloat = 1.5 + CGFloat(frac) * 3.5
                            let alpha = frac * frac * 0.7 * baseOpacity
                            let rect = CGRect(
                                x: p.x - dotR,
                                y: p.y - dotR,
                                width: dotR * 2,
                                height: dotR * 2
                            )
                            ctx.fill(
                                Path(ellipseIn: rect),
                                with: .color(color.opacity(alpha))
                            )
                        }
                    }

                    // === Bindu core ===
                    let coreR = 10 * carrierPulse
                    let coreRect = CGRect(
                        x: bindu.x - coreR,
                        y: bindu.y - coreR,
                        width: coreR * 2,
                        height: coreR * 2
                    )
                    ctx.fill(
                        Path(ellipseIn: coreRect),
                        with: .radialGradient(
                            Gradient(colors: [
                                color.opacity(0.95 * baseOpacity),
                                color.opacity(0.55 * baseOpacity),
                                color.opacity(0)
                            ]),
                            center: bindu,
                            startRadius: 0,
                            endRadius: coreR
                        )
                    )

                    let dotR = coreR * 0.32
                    let dotRect = CGRect(
                        x: bindu.x - dotR,
                        y: bindu.y - dotR,
                        width: dotR * 2,
                        height: dotR * 2
                    )
                    ctx.fill(
                        Path(ellipseIn: dotRect),
                        with: .color(.white.opacity(0.85 * baseOpacity))
                    )
                }
                // Sample Bindu position into the trail every ~40 ms.
                .onChange(of: t) { _, newT in
                    if newT - lastTrailSampleAt >= trailSampleInterval {
                        lastTrailSampleAt = newT
                        appendTrail(bindu, t: newT)
                    }
                }
            }
        }
        // Spawn a beat ring whenever the wire reports a fresh onset.
        .onChange(of: wire.hasOnset) { _, isOnset in
            guard isOnset else { return }
            let now = Date().timeIntervalSinceReferenceDate
            // Coalesce rapid retriggers — DSP onset flag can sit "true" across a poll.
            if now - lastOnsetEmittedAt < 0.08 { return }
            lastOnsetEmittedAt = now
            let center = trailPositions.last ?? .zero
            if center != .zero {
                rings.append(Ring(center: center, bornAt: now, color: color))
                // Cap ring history so we don't grow without bound.
                if rings.count > 24 {
                    rings.removeFirst(rings.count - 24)
                }
            }
        }
        // Carrier lock → 1.5x size pulse for the 500ms ack window.
        .onChange(of: wire.carrierLocked) { _, locked in
            withAnimation(.easeOut(duration: 0.18)) {
                carrierPulse = locked ? 1.5 : 1.0
            }
        }
    }

    // MARK: - Lissajous path

    private func binduPosition(t: Double, in size: CGSize) -> CGPoint {
        let cx = size.width / 2
        let cy = size.height / 2
        let r = min(size.width, size.height) * 0.22

        // Primary orbit
        let x1 = r * sin(2 * t + 0.5)
        let y1 = r * sin(3 * t)

        // Secondary harmonic (smaller, faster)
        let x2 = r * 0.3 * sin(5 * t + 1.2)
        let y2 = r * 0.3 * sin(4 * t + 0.8)

        return CGPoint(x: cx + x1 + x2, y: cy + y1 + y2)
    }

    private func appendTrail(_ p: CGPoint, t: Double) {
        trailPositions.append(p)
        if trailPositions.count > trailLength {
            trailPositions.removeFirst(trailPositions.count - trailLength)
        }
    }
}
