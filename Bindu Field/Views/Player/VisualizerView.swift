import SwiftUI

struct VisualizerView: View {
    let beat: Float       // Hz
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let beatPhase = (t * Double(beat)).truncatingRemainder(dividingBy: 1.0)
            // Soft pulse: 0..1..0
            let pulse = sin(beatPhase * .pi)  // 0 → 1 → 0

            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseRadius: CGFloat = min(size.width, size.height) * 0.18

                // Outer pulsing rings (3 rings, expanding)
                for ringIdx in 0..<5 {
                    let phase = (t * Double(beat) - Double(ringIdx) * 0.18).truncatingRemainder(dividingBy: 1.0)
                    if phase < 0 { continue }
                    let normalized = phase
                    let r = baseRadius + CGFloat(normalized) * baseRadius * 4
                    let alpha = (1 - normalized) * 0.5
                    let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                    ctx.stroke(
                        Path(ellipseIn: rect),
                        with: .color(color.opacity(alpha)),
                        lineWidth: 1.2
                    )
                }

                // Core orb
                let coreR = baseRadius * (0.9 + CGFloat(pulse) * 0.25)
                let coreRect = CGRect(x: center.x - coreR, y: center.y - coreR, width: coreR * 2, height: coreR * 2)
                ctx.fill(
                    Path(ellipseIn: coreRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            color.opacity(0.8),
                            color.opacity(0.4),
                            color.opacity(0.0)
                        ]),
                        center: center,
                        startRadius: 0,
                        endRadius: coreR
                    )
                )

                // Inner bright dot
                let dotR = baseRadius * 0.25 * (1 + CGFloat(pulse) * 0.5)
                let dotRect = CGRect(x: center.x - dotR, y: center.y - dotR, width: dotR * 2, height: dotR * 2)
                ctx.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(.white.opacity(0.85 * (0.5 + Double(pulse) * 0.5)))
                )
            }
        }
    }
}
