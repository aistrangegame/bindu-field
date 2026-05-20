import SwiftUI

/// The interference pattern made visible.
///
/// Three layered sine paths:
/// - L channel: carrier alone, muted off-white at 0.14
/// - R channel: carrier + beat, element-colored at 0.38
/// - Beat envelope: |L + R| modulated by a cosine at half the beat rate,
///   drawn thick + double-stroked for a glow look. This is the *visible
///   interference* — the third wave the brain hears when L and R are different.
///
/// When `isActive == false` the canvas freezes into a ghost waveform — a
/// breathing standing wave at low opacity so the panel never feels dead.
///
/// Carrier is visually slowed by ×0.04 so that even 432 Hz reads as a wave
/// (~17 cycles/sec at 432) instead of a blur. The envelope rides at b·0.5 Hz.
struct BinauralWaveformView: View {
    let carrierHz: Float
    let beatHz: Float
    let isActive: Bool
    /// HSL hue (0–360) of the current brainwave state. Drives R-channel
    /// + envelope color so the wave shifts as the user moves through bands.
    let stateHue: Double

    var body: some View {
        TimelineView(.animation(paused: !isActive)) { context in
            Canvas { gc, size in
                let t = context.date.timeIntervalSinceReferenceDate
                draw(gc: gc, size: size, t: t)
            }
        }
    }

    private func draw(gc: GraphicsContext, size: CGSize, t: Double) {
        let W = size.width
        let H = size.height
        guard W > 0, H > 0 else { return }
        let Cy = H / 2
        let AMP = H * 0.28
        let hue = stateHue / 360

        // Background atmosphere — soft radial wash in state hue.
        let bgRect = Path(CGRect(origin: .zero, size: size))
        gc.fill(
            bgRect,
            with: .radialGradient(
                Gradient(colors: [
                    Color(hue: hue, saturation: 0.40, brightness: 0.14).opacity(0.22),
                    Color.clear
                ]),
                center: CGPoint(x: W / 2, y: H / 2),
                startRadius: 0,
                endRadius: W * 0.6
            )
        )

        if !isActive {
            drawGhost(gc: gc, W: W, Cy: Cy, AMP: AMP, hue: hue)
            return
        }

        let c = Double(carrierHz)
        let b = max(Double(beatHz), 0.1)

        // Dashed center reference
        var center = Path()
        center.move(to: CGPoint(x: 0, y: Cy))
        center.addLine(to: CGPoint(x: W, y: Cy))
        gc.stroke(
            center,
            with: .color(Color(red: 0.961, green: 0.886, blue: 0.839).opacity(0.05)),
            style: StrokeStyle(lineWidth: 0.5, dash: [3, 8])
        )

        // L channel — soft cream, slim
        var pathL = Path()
        var first = true
        for xi in stride(from: 0, through: Int(W), by: 2) {
            let x = Double(xi)
            let tS = (x / W) * 3 / b + t
            let y = Cy + AMP * sin(2 * .pi * c * tS * 0.04)
            if first { pathL.move(to: CGPoint(x: x, y: y)); first = false }
            else { pathL.addLine(to: CGPoint(x: x, y: y)) }
        }
        gc.stroke(
            pathL,
            with: .color(Color(red: 0.961, green: 0.886, blue: 0.839).opacity(0.14)),
            lineWidth: 1
        )

        // R channel — element-colored
        var pathR = Path()
        first = true
        for xi in stride(from: 0, through: Int(W), by: 2) {
            let x = Double(xi)
            let tS = (x / W) * 3 / b + t
            let y = Cy + AMP * sin(2 * .pi * (c + b) * tS * 0.04)
            if first { pathR.move(to: CGPoint(x: x, y: y)); first = false }
            else { pathR.addLine(to: CGPoint(x: x, y: y)) }
        }
        gc.stroke(
            pathR,
            with: .color(Color(hue: hue, saturation: 0.55, brightness: 0.65).opacity(0.38)),
            lineWidth: 1
        )

        // Beat envelope — the visible interference. Drawn twice for glow.
        var pathEnv = Path()
        first = true
        for xi in stride(from: 0, through: Int(W), by: 2) {
            let x = Double(xi)
            let tS = (x / W) * 3 / b + t
            let env = 0.5 + 0.5 * cos(2 * .pi * b * tS * 0.5)
            let y = Cy + AMP * env * sin(2 * .pi * c * tS * 0.04)
            if first { pathEnv.move(to: CGPoint(x: x, y: y)); first = false }
            else { pathEnv.addLine(to: CGPoint(x: x, y: y)) }
        }
        gc.stroke(
            pathEnv,
            with: .color(Color(hue: hue, saturation: 0.65, brightness: 0.68).opacity(0.32)),
            lineWidth: 5
        )
        gc.stroke(
            pathEnv,
            with: .color(Color(hue: hue, saturation: 0.65, brightness: 0.72)),
            lineWidth: 1.8
        )

        // L / R hairline labels in the corners
        let labelColor = Color(red: 0.961, green: 0.886, blue: 0.839).opacity(0.18)
        gc.draw(
            Text("L").font(.system(size: 9, design: .monospaced)).foregroundColor(labelColor),
            at: CGPoint(x: 12, y: 12),
            anchor: .topLeading
        )
        gc.draw(
            Text("R").font(.system(size: 9, design: .monospaced)).foregroundColor(labelColor),
            at: CGPoint(x: 12, y: H - 6),
            anchor: .bottomLeading
        )
    }

    private func drawGhost(gc: GraphicsContext, W: CGFloat, Cy: CGFloat, AMP: CGFloat, hue: Double) {
        var path = Path()
        var first = true
        for xi in stride(from: 0, through: Int(W), by: 2) {
            let x = Double(xi)
            let phase = (x / W) * .pi * 8
            let env = cos(phase / 8) * 0.5 + 0.5
            let y = Cy + AMP * env * sin(phase)
            if first { path.move(to: CGPoint(x: x, y: y)); first = false }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        gc.stroke(
            path,
            with: .color(Color(hue: hue, saturation: 0.50, brightness: 0.60).opacity(0.22)),
            lineWidth: 0.8
        )
        var center = Path()
        center.move(to: CGPoint(x: 0, y: Cy))
        center.addLine(to: CGPoint(x: W, y: Cy))
        gc.stroke(
            center,
            with: .color(Color(red: 0.961, green: 0.886, blue: 0.839).opacity(0.06)),
            lineWidth: 0.5
        )
    }
}
