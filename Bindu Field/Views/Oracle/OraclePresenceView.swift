import SwiftUI

/// State shared with `OracleView` so the presence renderer can react to
/// state changes (response arrival picks up the element hue, intensifies
/// the fog) without owning the four-state machine itself.
@MainActor
@Observable
final class OraclePresenceModel {
    var isActive: Bool = false
    /// nil = idle warm neutral; non-nil = response element hue in degrees.
    var responseHue: Double? = nil
}

/// The Oracle's consciousness made visible — a single drifting radial fog
/// that breathes at 14s. Sits behind every state of `OracleView` so the
/// void is never empty, just barely lit. Hit-testing is off; the view
/// underneath owns all gestures.
struct OraclePresenceView: View {
    let model: OraclePresenceModel

    var body: some View {
        TimelineView(.animation(paused: !model.isActive)) { context in
            Canvas { gc, size in
                let t = context.date.timeIntervalSinceReferenceDate * 0.014 * 60
                let W = size.width, H = size.height

                // Drift center — barely perceptible parametric motion.
                let dx = 38 * sin(t * 0.11) * sin(t * 0.073)
                let dy = 24 * cos(t * 0.088) * cos(t * 0.051)
                let cx = W / 2 + dx
                let cy = H * 0.44 + dy

                // 14s breath cycle.
                let breathe = 0.5 + 0.5 * sin(t * (.pi * 2 / 14) * 0.5)

                let hue = model.responseHue ?? 30.0
                let hasResponse = model.responseHue != nil
                let fogAlpha = hasResponse
                    ? (0.06 + 0.04 * breathe)
                    : (0.032 + 0.018 * breathe)
                let fogR = W * (hasResponse ? 0.55 : 0.45)
                let fogSat: Double = hasResponse ? 30 : 15
                let fogBright: Double = hasResponse ? 60 : 72

                let gradient = Gradient(stops: [
                    .init(
                        color: Color(
                            hue: hue / 360,
                            saturation: fogSat / 100,
                            brightness: fogBright / 100
                        ).opacity(fogAlpha),
                        location: 0
                    ),
                    .init(
                        color: Color(
                            hue: hue / 360,
                            saturation: (fogSat * 0.83) / 100,
                            brightness: (fogBright * 0.83) / 100
                        ).opacity(fogAlpha * 0.3),
                        location: 0.55
                    ),
                    .init(color: .clear, location: 1.0),
                ])

                gc.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        gradient,
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0,
                        endRadius: fogR
                    )
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
