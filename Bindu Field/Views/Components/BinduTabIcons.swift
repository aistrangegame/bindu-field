import SwiftUI

/// Custom tab-bar glyphs ported from
/// `design_handoff_lalita_pass/Bindu Tab Icons.html`.
///
/// Each icon is a 28×28 Canvas drawing. The cream color travels through
/// `BinduTabIcon.color` (active = 1.0 cream, inactive = 0.40 cream). The
/// design language is concentric geometry, sparse strokes, no fills
/// beyond the central dot — presence over object.
///
/// `BinduTabIcon.Tab` covers the HTML's seven icons (map / field / oracle
/// / space / lab / archive / letter) plus `.ritual`, since the live
/// app keeps the Ritual tab during Session A. Session B will revisit
/// the tab structure when the real MapView arrives.
struct BinduTabIcon: View {
    enum Tab { case map, field, oracle, space, lab, archive, letter, ritual }
    let tab: Tab
    let active: Bool

    private var color: Color {
        Color(red: 0xF5/255, green: 0xE2/255, blue: 0xD6/255)
    }
    private var activeOpacity: Double { active ? 1.0 : 0.40 }

    var body: some View {
        Canvas { ctx, _ in
            switch tab {
            case .map:     drawMap(in: ctx)
            case .field:   drawField(in: ctx)
            case .oracle:  drawOracle(in: ctx)
            case .space:   drawSpace(in: ctx)
            case .lab:     drawLab(in: ctx)
            case .archive: drawArchive(in: ctx)
            case .letter:  drawLetter(in: ctx)
            case .ritual:  drawRitual(in: ctx)
            }
        }
        .frame(width: 28, height: 28)
        .foregroundStyle(color.opacity(activeOpacity))
    }

    // MARK: - Helpers

    private func ring(_ ctx: GraphicsContext, cx: CGFloat, cy: CGFloat,
                      r: CGFloat, opacity: Double, lineWidth: CGFloat) {
        ctx.stroke(
            Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                   width: r * 2, height: r * 2)),
            with: .color(color.opacity(opacity * activeOpacity)),
            lineWidth: lineWidth
        )
    }

    private func dot(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat,
                     r: CGFloat, opacity: Double) {
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - r, y: y - r,
                                   width: r * 2, height: r * 2)),
            with: .color(color.opacity(opacity * activeOpacity))
        )
    }

    private func line(_ ctx: GraphicsContext,
                      from a: CGPoint, to b: CGPoint,
                      opacity: Double, lineWidth: CGFloat) {
        var p = Path()
        p.move(to: a)
        p.addLine(to: b)
        ctx.stroke(p,
                   with: .color(color.opacity(opacity * activeOpacity)),
                   lineWidth: lineWidth)
    }

    // MARK: - Icons

    /// MAP — three concentric orbits + 4 cardinal ticks + center dot.
    /// The 33 chakras as a nested map of consciousness.
    private func drawMap(in ctx: GraphicsContext) {
        let cx: CGFloat = 14, cy: CGFloat = 14
        ring(ctx, cx: cx, cy: cy, r: 12.5,
             opacity: active ? 0.65 : 0.35, lineWidth: 0.9)
        ring(ctx, cx: cx, cy: cy, r: 7.5,
             opacity: active ? 0.50 : 0.28, lineWidth: 0.8)
        ring(ctx, cx: cx, cy: cy, r: 3.2,
             opacity: active ? 0.70 : 0.40, lineWidth: 0.9)
        dot(ctx, x: cx, y: cy, r: 1.5, opacity: active ? 1.0 : 0.6)
        for deg in [0.0, 90.0, 180.0, 270.0] {
            let rad = deg * .pi / 180
            let a = CGPoint(x: cx + 11.8 * CGFloat(cos(rad)),
                            y: cy + 11.8 * CGFloat(sin(rad)))
            let b = CGPoint(x: cx + 13.5 * CGFloat(cos(rad)),
                            y: cy + 13.5 * CGFloat(sin(rad)))
            line(ctx, from: a, to: b,
                 opacity: active ? 0.50 : 0.25, lineWidth: 0.8)
        }
    }

    /// FIELD — 7-star deterministic constellation + center node + 3 lines.
    private func drawField(in ctx: GraphicsContext) {
        let stars: [(CGFloat, CGFloat)] = [
            (5, 6), (22, 5), (8, 20), (21, 19),
            (13, 9), (6, 14), (20, 13)
        ]
        for (i, s) in stars.enumerated() {
            let r: CGFloat = (i == 4) ? 1.8 : 0.9
            let op: Double = (i == 4)
                ? (active ? 1.0 : 0.7)
                : (active ? 0.45 : 0.22)
            dot(ctx, x: s.0, y: s.1, r: r, opacity: op)
        }
        // Center node
        dot(ctx, x: 14, y: 14, r: 2.5,
            opacity: active ? 0.85 : 0.5)
        // Three connecting lines
        let targets: [(CGFloat, CGFloat, Double)] = [
            (13, 9, active ? 0.25 : 0.12),
            (22, 5, active ? 0.20 : 0.10),
            (8, 20, active ? 0.20 : 0.10),
        ]
        for tgt in targets {
            line(ctx,
                 from: CGPoint(x: 14, y: 14),
                 to: CGPoint(x: tgt.0, y: tgt.1),
                 opacity: tgt.2, lineWidth: 0.5)
        }
    }

    /// ORACLE — outer ring (open at top) + inner ring + listening center.
    private func drawOracle(in ctx: GraphicsContext) {
        let cx: CGFloat = 14, cy: CGFloat = 14
        // Outer ring with a ~40° gap at the top (340° → 20°)
        var outer = Path()
        outer.addArc(center: CGPoint(x: cx, y: cy), radius: 12,
                     startAngle: .degrees(20),
                     endAngle: .degrees(340),
                     clockwise: false)
        ctx.stroke(outer,
                   with: .color(color.opacity((active ? 0.60 : 0.30) * activeOpacity)),
                   lineWidth: 1)
        // Inner ring
        ring(ctx, cx: cx, cy: cy, r: 6.5,
             opacity: active ? 0.45 : 0.22, lineWidth: 0.75)
        // Listening center
        dot(ctx, x: cx, y: cy, r: 2,
            opacity: active ? 1.0 : 0.6)
    }

    /// SPACE — full breath ring + inner ring + 3 timing dots + center.
    private func drawSpace(in ctx: GraphicsContext) {
        let cx: CGFloat = 14, cy: CGFloat = 14
        ring(ctx, cx: cx, cy: cy, r: 11.5,
             opacity: active ? 0.65 : 0.32, lineWidth: 1)
        ring(ctx, cx: cx, cy: cy, r: 6,
             opacity: active ? 0.40 : 0.20, lineWidth: 0.75)
        for deg in [60.0, 180.0, 300.0] {
            let rad = deg * .pi / 180
            dot(ctx,
                x: cx + 10.8 * CGFloat(cos(rad)),
                y: cy + 10.8 * CGFloat(sin(rad)),
                r: 0.9,
                opacity: active ? 0.50 : 0.25)
        }
        dot(ctx, x: cx, y: cy, r: 1.5,
            opacity: active ? 0.80 : 0.45)
    }

    /// LAB — sine wave + center node "cut" out of the wave + two vertical ticks.
    private func drawLab(in ctx: GraphicsContext) {
        // Carrier wave — sine path
        var wave = Path()
        wave.move(to: CGPoint(x: 2, y: 14))
        wave.addQuadCurve(to: CGPoint(x: 8, y: 14),
                          control: CGPoint(x: 5, y: 8))
        wave.addQuadCurve(to: CGPoint(x: 14, y: 14),
                          control: CGPoint(x: 11, y: 20))
        wave.addQuadCurve(to: CGPoint(x: 20, y: 14),
                          control: CGPoint(x: 17, y: 8))
        wave.addQuadCurve(to: CGPoint(x: 26, y: 14),
                          control: CGPoint(x: 23, y: 20))
        ctx.stroke(wave,
                   with: .color(color.opacity((active ? 0.75 : 0.40) * activeOpacity)),
                   lineWidth: 1.1)
        // Center node — small fill in bg color simulates "cut" of wave,
        // then the stroked outline + inner dot.
        let bgFill = Color(red: 2/255, green: 2/255, blue: 8/255)
        ctx.fill(
            Path(ellipseIn: CGRect(x: 14 - 2.5, y: 14 - 2.5,
                                   width: 5, height: 5)),
            with: .color(bgFill)
        )
        ring(ctx, cx: 14, cy: 14, r: 2.5,
             opacity: active ? 0.90 : 0.50, lineWidth: 1)
        dot(ctx, x: 14, y: 14, r: 1,
            opacity: active ? 1.0 : 0.7)
        // Frequency ticks above + below
        line(ctx,
             from: CGPoint(x: 14, y: 2), to: CGPoint(x: 14, y: 5),
             opacity: active ? 0.40 : 0.20, lineWidth: 0.8)
        line(ctx,
             from: CGPoint(x: 14, y: 23), to: CGPoint(x: 14, y: 26),
             opacity: active ? 0.40 : 0.20, lineWidth: 0.8)
    }

    /// ARCHIVE — memory sphere ellipse + equator + axis + 5 memory stars.
    private func drawArchive(in ctx: GraphicsContext) {
        let cx: CGFloat = 14, cy: CGFloat = 14
        // Memory-sphere ellipse
        ctx.stroke(
            Path(ellipseIn: CGRect(x: cx - 12, y: cy - 9,
                                   width: 24, height: 18)),
            with: .color(color.opacity((active ? 0.55 : 0.28) * activeOpacity)),
            lineWidth: 0.9
        )
        // Equator ring (flattened ellipse)
        ctx.stroke(
            Path(ellipseIn: CGRect(x: cx - 12, y: cy - 3.5,
                                   width: 24, height: 7)),
            with: .color(color.opacity((active ? 0.35 : 0.18) * activeOpacity)),
            lineWidth: 0.7
        )
        // Vertical axis
        line(ctx,
             from: CGPoint(x: cx, y: 5),
             to: CGPoint(x: cx, y: 23),
             opacity: active ? 0.30 : 0.15, lineWidth: 0.7)
        // Memory stars
        let stars: [(CGFloat, CGFloat)] = [(9, 10), (18, 11), (12, 17),
                                           (19, 17), (7, 15)]
        for (i, s) in stars.enumerated() {
            let r: CGFloat = (i == 0) ? 1.4 : 0.85
            let op: Double = (i == 0)
                ? (active ? 0.9 : 0.5)
                : (active ? 0.5 : 0.22)
            dot(ctx, x: s.0, y: s.1, r: r, opacity: op)
        }
    }

    /// LETTER — three outward arcs from a source dot + a receiving line.
    private func drawLetter(in ctx: GraphicsContext) {
        let cx: CGFloat = 14, cy: CGFloat = 14
        // Inner arc
        var a1 = Path()
        a1.move(to: CGPoint(x: 8, y: cy))
        a1.addQuadCurve(to: CGPoint(x: 20, y: cy),
                        control: CGPoint(x: cx, y: 6))
        ctx.stroke(a1,
                   with: .color(color.opacity((active ? 0.70 : 0.35) * activeOpacity)),
                   lineWidth: 1)
        // Mid arc
        var a2 = Path()
        a2.move(to: CGPoint(x: 5, y: cy))
        a2.addQuadCurve(to: CGPoint(x: 23, y: cy),
                        control: CGPoint(x: cx, y: 3))
        ctx.stroke(a2,
                   with: .color(color.opacity((active ? 0.45 : 0.22) * activeOpacity)),
                   lineWidth: 0.75)
        // Outer arc
        var a3 = Path()
        a3.move(to: CGPoint(x: 3, y: cy))
        a3.addQuadCurve(to: CGPoint(x: 25, y: cy),
                        control: CGPoint(x: cx, y: 0.5))
        ctx.stroke(a3,
                   with: .color(color.opacity((active ? 0.28 : 0.13) * activeOpacity)),
                   lineWidth: 0.6)
        // Source point
        dot(ctx, x: cx, y: cy, r: 2.2,
            opacity: active ? 0.9 : 0.5)
        // Receiving line + ground dot
        line(ctx,
             from: CGPoint(x: cx, y: 17),
             to: CGPoint(x: cx, y: 25),
             opacity: active ? 0.35 : 0.18, lineWidth: 0.8)
        dot(ctx, x: cx, y: 25.5, r: 0.9,
            opacity: active ? 0.40 : 0.20)
    }

    // MARK: - Static rasterization cache
    //
    // SwiftUI's `.tabItem` slot does not render a Canvas-based icon — the
    // tab bar item only displays Image / Text descendants and Canvas
    // resolves to an empty rect inside it. Workaround: rasterize each
    // (tab, active) variant once via ImageRenderer and surface the result
    // through `BinduTabIconImage` below, which is what `RootView` plugs
    // into the `.tabItem` Label.
    //
    // The cache uses CGImage (Core Graphics) instead of UIImage so this
    // file stays platform-neutral — the project's supported platforms
    // include macOS + visionOS in addition to iOS, and UIImage doesn't
    // exist on macOS.
    //
    // The cache is keyed by "tab-active-scale" and indexed by displayScale
    // so 2x and 3x devices each get a crisply-rendered copy.
    @MainActor fileprivate static var rasterCache: [String: CGImage] = [:]

    /// Render the icon at the given display scale and cache the result.
    /// Subsequent calls with the same key return the cached image.
    @MainActor fileprivate static func rasterImage(
        tab: Tab,
        active: Bool,
        scale: CGFloat
    ) -> CGImage? {
        let key = "\(tab)-\(active)-\(Int(scale * 100))"
        if let cached = rasterCache[key] { return cached }
        let renderer = ImageRenderer(content:
            BinduTabIcon(tab: tab, active: active)
                .frame(width: 28, height: 28)
        )
        renderer.scale = scale
        guard let cg = renderer.cgImage else { return nil }
        rasterCache[key] = cg
        return cg
    }

    /// RITUAL — three linked arcs around a center, like beads on a thread.
    /// The HTML icon set does not include a Ritual glyph; this matches
    /// the design vocabulary (concentric, sparse, verb-as-presence) and
    /// reads as "weave a sequence."
    private func drawRitual(in ctx: GraphicsContext) {
        let cx: CGFloat = 14, cy: CGFloat = 14
        // Outer ring
        ring(ctx, cx: cx, cy: cy, r: 11,
             opacity: active ? 0.30 : 0.15, lineWidth: 0.5)
        // Three orbital beads at 90°, 210°, 330° — each a small ring + dot
        let angles: [Double] = [90, 210, 330]
        for (i, deg) in angles.enumerated() {
            let rad = deg * .pi / 180
            let bx = cx + 8.5 * CGFloat(cos(rad))
            let by = cy + 8.5 * CGFloat(sin(rad))
            ring(ctx, cx: bx, cy: by, r: 2.4,
                 opacity: active ? 0.55 : 0.28, lineWidth: 0.8)
            dot(ctx, x: bx, y: by, r: 1.0,
                opacity: active ? 0.85 : 0.45)
            // Thread between consecutive beads — arcs along the outer ring.
            let next = angles[(i + 1) % angles.count]
            var thread = Path()
            thread.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: 8.5,
                startAngle: .degrees(deg + 12),
                endAngle: .degrees(next - 12),
                clockwise: false
            )
            ctx.stroke(thread,
                       with: .color(color.opacity((active ? 0.25 : 0.12) * activeOpacity)),
                       lineWidth: 0.6)
        }
        // Center dot
        dot(ctx, x: cx, y: cy, r: 1.4,
            opacity: active ? 0.85 : 0.45)
    }
}

/// Tab-bar-safe wrapper around `BinduTabIcon`. Resolves to a rasterized
/// `Image(decorative:scale:)` because `Canvas` does not render inside
/// `.tabItem`. Reads `\.displayScale` so the raster matches the device's
/// pixel density. `.renderingMode(.original)` preserves the icon's
/// encoded active/inactive opacity instead of letting iOS retint it.
struct BinduTabIconImage: View {
    let tab: BinduTabIcon.Tab
    let active: Bool

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let scale = max(displayScale, 2.0)
        if let cg = BinduTabIcon.rasterImage(tab: tab, active: active, scale: scale) {
            Image(decorative: cg, scale: scale)
                .renderingMode(.original)
        } else {
            // Fallback: empty 28×28 placeholder if the ImageRenderer
            // bailed (rare — typically a zero-size frame in preview).
            Color.clear.frame(width: 28, height: 28)
        }
    }
}
