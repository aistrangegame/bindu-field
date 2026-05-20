import SwiftUI

/// One vocabulary per element. The Cathedral (Air) is one of nine; the
/// other eight are drawn here. Each vocabulary is a `GraphicsContext`
/// draw function with the same signature, called from `VisualizerView`
/// inside its `Canvas` after intensity has been computed from Performer
/// state.
///
/// Ported from `design_handoff_lalita_pass/Bindu Vocabularies.html`.
/// JavaScript canvas idioms map to SwiftUI Canvas as follows:
///
///   ctx.fillRect(0,0,W,H)            → gc.fill(Path(rect), with: .color(...))
///   ctx.arc + fill                   → gc.fill(Path(ellipseIn: rect), with: ...)
///   ctx.createRadialGradient(...)    → .radialGradient(Gradient(...), center:..., startRadius:..., endRadius:...)
///   ctx.createLinearGradient(...)    → .linearGradient(Gradient(...), startPoint:..., endPoint:...)
///   ctx.globalCompositeOperation='screen' → ctx.blendMode = .screen
///
/// The Bindu dot is drawn at the bottom of every vocabulary at the
/// vocabulary's natural center; `VisualizerView` overlays its own
/// audio-reactive Bindu Lissajous on top.
enum ElementVocabulary: String {
    case earth, water, fire, air, ether
    case constellation, crown, soul, dissolution
    case meditate, family

    /// Map an Airtable element string to a vocabulary id.
    static func from(element: String) -> ElementVocabulary {
        switch element.lowercased() {
        case "earth":       return .earth
        case "water":       return .water
        case "fire":        return .fire
        case "air":         return .air
        case "light":       return .constellation   // Ajna · Light
        case "crown":       return .crown
        case "soul":        return .soul
        case "dissolution": return .dissolution
        case "meditate":    return .meditate
        case "family":      return .family
        default:            return .meditate
        }
    }

    /// Track-level override. Track 27 (Sound of Silence) is labelled Air
    /// in Airtable but the vocabulary belongs to Vishuddha (Ether).
    static func forTrack(_ track: Track) -> ElementVocabulary {
        if track.id == 27 { return .ether }
        return from(element: track.element)
    }

    /// Background color for each vocabulary. The element sets the void's
    /// tint. PlayerView reads this so the background swaps when the
    /// track changes.
    var bg: Color {
        switch self {
        case .earth:         return Color(red: 0x08/255, green: 0x05/255, blue: 0x03/255)
        case .water:         return Color(red: 0x02/255, green: 0x05/255, blue: 0x08/255)
        case .fire:          return Color(red: 0x08/255, green: 0x03/255, blue: 0x00/255)
        case .air:           return Color(red: 0x02/255, green: 0x02/255, blue: 0x08/255)
        case .ether:         return Color(red: 0x03/255, green: 0x08/255, blue: 0x09/255)
        case .constellation: return Color(red: 0x02/255, green: 0x02/255, blue: 0x02/255)
        case .crown:         return Color(red: 0x06/255, green: 0x04/255, blue: 0x08/255)
        case .soul:          return Color(red: 0x03/255, green: 0x04/255, blue: 0x08/255)
        case .dissolution:   return Color(red: 0x04/255, green: 0x02/255, blue: 0x09/255)
        case .meditate:      return Color(red: 0x02/255, green: 0x02/255, blue: 0x08/255)
        case .family:        return Color(red: 0x02/255, green: 0x02/255, blue: 0x08/255)
        }
    }

    /// Central hue for the vocabulary's Bindu dot.
    var hue: Double {
        switch self {
        case .earth:         return 15
        case .water:         return 210
        case .fire:          return 25
        case .air:           return 195
        case .ether:         return 185
        case .constellation: return 50
        case .crown:         return 280
        case .soul:          return 265
        case .dissolution:   return 190
        case .meditate:      return 265
        case .family:        return 330
        }
    }
}

// MARK: - Deterministic noise (ported from the HTML's dn / dn2)

@inline(__always)
func dn(_ seed: Double) -> Double {
    let x = sin(seed * 127.1 + 311.7) * 43758.5
    return x - floor(x)
}

@inline(__always)
func dn2(_ seed: Double) -> Double {
    let x = sin(seed * 269.5 + 183.3) * 43758.5
    return x - floor(x)
}

// MARK: - Shared Bindu dot (vocabulary-level)
//
// The vocabulary-level Bindu lives in the center of each draw function.
// VisualizerView overlays its own audio-reactive Lissajous Bindu on top,
// so this one is a still anchor — the constant point through which all
// the vocabularies are seen.

func drawVocabBindu(
    in gc: GraphicsContext,
    at point: CGPoint,
    hue: Double,
    t: Double,
    scale: Double = 1
) {
    let b = 0.65 + 0.35 * sin(t * 1.15)
    let r = CGFloat(5.5 * scale)

    // Aura — radial gradient from saturated hue to transparent
    let auraR = CGFloat(32 * scale)
    let auraColor = Color(hue: hue / 360, saturation: 0.60, brightness: 0.72)
    gc.fill(
        Path(ellipseIn: CGRect(x: point.x - auraR, y: point.y - auraR,
                               width: auraR * 2, height: auraR * 2)),
        with: .radialGradient(
            Gradient(colors: [
                auraColor.opacity(0.32 * b),
                auraColor.opacity(0)
            ]),
            center: point, startRadius: 0, endRadius: auraR
        )
    )

    // Core — small radial from bright center to a less-saturated rim
    let coreInner = Color(hue: hue / 360, saturation: 0.70, brightness: 0.88)
    let coreOuter = Color(hue: hue / 360, saturation: 0.58, brightness: 0.65)
    gc.fill(
        Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r,
                               width: r * 2, height: r * 2)),
        with: .radialGradient(
            Gradient(colors: [coreInner, coreOuter]),
            center: CGPoint(x: point.x - r * 0.3, y: point.y - r * 0.3),
            startRadius: 0, endRadius: r
        )
    )

    // Small offset shine on the upper-left
    let shineR = r * 0.3
    let shineP = CGPoint(x: point.x - r * 0.28, y: point.y - r * 0.3)
    gc.fill(
        Path(ellipseIn: CGRect(x: shineP.x - shineR, y: shineP.y - shineR,
                               width: shineR * 2, height: shineR * 2)),
        with: .color(.white.opacity(0.35))
    )
}

// MARK: - Vocabulary draw functions

/// EARTH — Muladhara — seismic fractures, amber ground, dust
func drawEarth(
    in gc: GraphicsContext, size: CGSize, t: Double, intens: Double
) {
    let W = size.width, H = size.height
    guard W > 0, H > 0 else { return }
    let cx = W / 2, cy = H * 0.67
    let b = 0.7 + 0.3 * sin(t * 0.38)

    // Ground gradient — bottom half deepens to terracotta
    gc.fill(
        Path(CGRect(x: 0, y: 0, width: W, height: H)),
        with: .linearGradient(
            Gradient(stops: [
                .init(color: Color.clear, location: 0),
                .init(color: Color(red: 55/255, green: 22/255, blue: 5/255)
                    .opacity(0.5 * intens), location: 0.75),
                .init(color: Color(red: 80/255, green: 30/255, blue: 6/255)
                    .opacity(0.75 * intens), location: 1.0),
            ]),
            startPoint: CGPoint(x: W / 2, y: H * 0.5),
            endPoint: CGPoint(x: W / 2, y: H)
        )
    )

    // Seismic cracks
    struct Crack { let a: Double; let l: Double; let n: Int; let spread: Double }
    let cracks: [Crack] = [
        Crack(a: -80, l: 0.40, n: 6, spread: 0.45),
        Crack(a: -55, l: 0.44, n: 7, spread: 0.52),
        Crack(a: -38, l: 0.36, n: 5, spread: 0.35),
        Crack(a: -105, l: 0.32, n: 5, spread: 0.38),
        Crack(a: -125, l: 0.34, n: 6, spread: 0.42),
        Crack(a: -150, l: 0.24, n: 4, spread: 0.28),
    ]
    let nCracks = max(2, min(cracks.count, 2 + Int(intens * Double(cracks.count - 2))))

    for i in 0..<nCracks {
        let c = cracks[i]
        var ctxTransformed = gc
        ctxTransformed.translateBy(x: cx, y: cy)
        ctxTransformed.rotate(by: .radians(c.a * .pi / 180))

        let maxL = c.l * H * b
        let pulse = 0.25 + 0.15 * sin(t * 0.5 + Double(i) * 0.7) * intens
        let crackColor = Color(hue: 18 / 360, saturation: 0.50, brightness: 0.45)

        var path = Path()
        path.move(to: .zero)
        var px: CGFloat = 0, py: CGFloat = 0
        for s in 1...c.n {
            let jx = (dn(Double(i * 31 + s * 17)) - 0.5) * c.spread * 28
            let jy = (maxL / Double(c.n))
            px += CGFloat(jx)
            py -= CGFloat(jy)
            path.addLine(to: CGPoint(x: px, y: py))
        }
        ctxTransformed.stroke(path,
                              with: .color(crackColor.opacity(pulse)),
                              lineWidth: 0.8 + intens * 0.5)

        if intens > 0.4 {
            let bx = px * 0.6, by = py * 0.6
            var branch = Path()
            branch.move(to: CGPoint(x: bx, y: by))
            branch.addLine(to: CGPoint(
                x: bx + CGFloat((dn(Double(i * 7 + 23)) - 0.5) * 30),
                y: by - 18
            ))
            ctxTransformed.stroke(branch,
                                  with: .color(crackColor.opacity(pulse * 0.5)),
                                  lineWidth: 0.4)
        }
    }

    // Amber center glow
    let gloR = W * 0.52 * CGFloat(intens)
    if gloR > 1 {
        let inner = Color(hue: 22 / 360, saturation: 0.65, brightness: 0.40)
        let mid = Color(hue: 18 / 360, saturation: 0.55, brightness: 0.32)
        gc.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: H)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: inner.opacity(0.28 * b * intens), location: 0),
                    .init(color: mid.opacity(0.12 * intens), location: 0.4),
                    .init(color: .clear, location: 1.0),
                ]),
                center: CGPoint(x: cx, y: cy),
                startRadius: 0,
                endRadius: gloR
            )
        )
    }

    // Dust particles
    let nP = Int(20 + 30 * intens)
    let dustColor = Color(hue: 22 / 360, saturation: 0.55, brightness: 0.68)
    for i in 0..<nP {
        let seed = Double(i) * 1337
        let ox = (dn(seed) - 0.5) * W * 0.7
        let speed = 8 + dn2(seed) * 14
        let raw = (t * speed + dn(seed * 3) * H * 0.55)
            .truncatingRemainder(dividingBy: H * 0.58)
        let px = cx + CGFloat(ox)
        let py = cy - CGFloat(raw)
        let alpha = (0.08 + 0.08 * dn2(seed * 2))
            * (1 - Double(py / cy) * 0.4) * intens
        let sz = CGFloat(0.5 + dn(seed + 7))
        gc.fill(
            Path(ellipseIn: CGRect(x: px - sz, y: py - sz,
                                   width: sz * 2, height: sz * 2)),
            with: .color(dustColor.opacity(alpha))
        )
    }

    drawVocabBindu(in: gc, at: CGPoint(x: cx, y: cy - 8),
                   hue: 15, t: t)
}

/// WATER — Svadhisthana — interference ripples, flow lines
func drawWater(
    in gc: GraphicsContext, size: CGSize, t: Double, intens: Double
) {
    let W = size.width, H = size.height
    guard W > 0, H > 0 else { return }
    let cx = W / 2, cy = H / 2

    // Interference ripple systems — 3 origin points
    struct Origin { let x: CGFloat; let y: CGFloat; let per: Double }
    let origins: [Origin] = [
        Origin(x: cx, y: cy, per: 3.2),
        Origin(x: cx - 55, y: cy - 30, per: 4.1),
        Origin(x: cx + 42, y: cy + 38, per: 2.8),
    ]
    let nO = min(origins.count, 1 + Int(intens * 2))
    let rippleColor = Color(hue: 210 / 360, saturation: 0.60, brightness: 0.68)
    for oi in 0..<nO {
        let o = origins[oi]
        let phase = (t / o.per).truncatingRemainder(dividingBy: 1)
        for ring in 0..<7 {
            let rPhase = (phase + Double(ring) / 7).truncatingRemainder(dividingBy: 1)
            let r = CGFloat(rPhase) * min(W, H) * 0.62
            let alpha = (1 - rPhase) * (0.18 + 0.12 * intens) * (oi == 0 ? 1 : 0.65)
            gc.stroke(
                Path(ellipseIn: CGRect(x: o.x - r, y: o.y - r,
                                       width: r * 2, height: r * 2)),
                with: .color(rippleColor.opacity(alpha)),
                lineWidth: 0.7
            )
        }
    }

    // Flow lines — horizontal sine paths
    let nLines = 4 + Int(intens * 3)
    let flowColor = Color(hue: 210 / 360, saturation: 0.55, brightness: 0.72)
    for li in 0..<nLines {
        let yBase = H * 0.2 + CGFloat(li) * (H * 0.65 / CGFloat(nLines))
        let amp = CGFloat(12 + dn(Double(li * 11)) * 18)
        let freq = 0.012 + dn2(Double(li * 7)) * 0.008
        let spd = t * (0.4 + dn(Double(li * 3)) * 0.3) * (li % 2 == 0 ? 1 : -1)
        var path = Path()
        var first = true
        var px: CGFloat = 0
        while px <= W {
            let py = yBase + amp * CGFloat(sin(Double(px) * freq + spd))
            if first { path.move(to: CGPoint(x: px, y: py)); first = false }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
            px += 3
        }
        let alpha = (0.06 + 0.06 * dn(Double(li * 13))) * intens
        gc.stroke(path,
                  with: .color(flowColor.opacity(alpha)),
                  lineWidth: 0.6)
    }

    // Deep glow
    let gloR = W * 0.5
    let gloColor = Color(hue: 210 / 360, saturation: 0.55, brightness: 0.40)
    gc.fill(
        Path(CGRect(x: 0, y: 0, width: W, height: H)),
        with: .radialGradient(
            Gradient(colors: [
                gloColor.opacity(0.15 * intens),
                gloColor.opacity(0)
            ]),
            center: CGPoint(x: cx, y: cy),
            startRadius: 0, endRadius: gloR
        )
    )

    drawVocabBindu(in: gc, at: CGPoint(x: cx, y: cy), hue: 210, t: t)
}

/// FIRE — Manipura — ember particles, solar rings, radial expansion
func drawFire(
    in gc: GraphicsContext, size: CGSize, t: Double, intens: Double
) {
    let W = size.width, H = size.height
    guard W > 0, H > 0 else { return }
    let cx = W / 2, cy = H * 0.58

    // Inner sun glow
    let sunR = W * 0.44 * CGFloat(intens)
    if sunR > 1 {
        gc.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: H)),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: Color(hue: 38/360, saturation: 0.80, brightness: 0.65)
                        .opacity(0.35 * intens), location: 0),
                    .init(color: Color(hue: 25/360, saturation: 0.70, brightness: 0.45)
                        .opacity(0.22 * intens), location: 0.3),
                    .init(color: Color(hue: 15/360, saturation: 0.60, brightness: 0.25)
                        .opacity(0.08 * intens), location: 0.7),
                    .init(color: .clear, location: 1.0),
                ]),
                center: CGPoint(x: cx, y: cy),
                startRadius: 0, endRadius: sunR
            )
        )
    }

    // Solar ring pulses — every 2.5s
    let ringPeriod = 2.5
    let ringColor = Color(hue: 28 / 360, saturation: 0.70, brightness: 0.60)
    for ri in 0..<3 {
        let rPhase = ((t / ringPeriod) + Double(ri) / 3)
            .truncatingRemainder(dividingBy: 1)
        let r = CGFloat(rPhase) * W * 0.55
        let alpha = (1 - rPhase) * (0.25 * intens)
        gc.stroke(
            Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                   width: r * 2, height: r * 2)),
            with: .color(ringColor.opacity(alpha)),
            lineWidth: CGFloat(1.2 - rPhase)
        )
    }

    // Upward triangle (faint)
    if intens > 0.3 {
        let th = H * 0.38 * CGFloat(intens)
        let tw = th * 0.9
        var tri = Path()
        tri.move(to: CGPoint(x: cx, y: cy - th))
        tri.addLine(to: CGPoint(x: cx - tw / 2, y: cy + th * 0.12))
        tri.addLine(to: CGPoint(x: cx + tw / 2, y: cy + th * 0.12))
        tri.closeSubpath()
        gc.stroke(tri,
                  with: .color(Color(hue: 35/360, saturation: 0.65, brightness: 0.55)
                    .opacity(0.08 * intens)),
                  lineWidth: 0.8)
    }

    // Ember particles
    let nP = Int(30 + 50 * intens)
    let lifespan = H * 0.7
    for i in 0..<nP {
        let seed = Double(i) * 937
        let ox = (dn(seed) - 0.5) * W * 0.48
        let speed = 22 + dn2(seed) * 38
        let age = (t * speed + dn(seed * 3) * lifespan)
            .truncatingRemainder(dividingBy: lifespan)
        let px = cx + CGFloat(ox) + CGFloat(sin(t * 0.8 + dn(seed) * 6.28) * 8)
        let py = cy - CGFloat(age)
        let pct = age / lifespan
        let env = pct < 0.3 ? pct / 0.3 : 1 - pct
        let alpha = env * (0.55 + 0.25 * dn(seed + 2)) * intens
        let sz = (1.4 + dn(seed + 5) * 2) * (1 - pct * 0.7)
        let hue = 15 + dn2(seed + 1) * 25
        let col = Color(hue: hue / 360, saturation: 0.80,
                        brightness: 0.55 + pct * 0.25)
        gc.fill(
            Path(ellipseIn: CGRect(x: px - CGFloat(sz), y: py - CGFloat(sz),
                                   width: CGFloat(sz) * 2, height: CGFloat(sz) * 2)),
            with: .color(col.opacity(alpha))
        )
    }

    drawVocabBindu(in: gc, at: CGPoint(x: cx, y: cy), hue: 25, t: t)
}

/// AIR — Anahata. Vocabulary-level Air drawn here as a fallback for
/// Air-element tracks other than Track 27. The full Cathedral renderer
/// in `VisualizerView` handles the real Air case — this is the simpler
/// glyph from the design HTML so any Air track that isn't routed to
/// the Cathedral still gets a coherent atmosphere.
func drawAirGlyph(
    in gc: GraphicsContext, size: CGSize, t: Double, intens: Double
) {
    let W = size.width, H = size.height
    guard W > 0, H > 0 else { return }
    let cx = W / 2, cy = H * 0.48
    let b = 0.6 + 0.4 * sin(t * 0.45)

    // Cathedral floor gradient (bottom)
    gc.fill(
        Path(CGRect(x: 0, y: 0, width: W, height: H)),
        with: .linearGradient(
            Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: Color(red: 12/255, green: 18/255, blue: 30/255)
                    .opacity(0.5 * intens), location: 1.0),
            ]),
            startPoint: CGPoint(x: cx, y: H * 0.7),
            endPoint: CGPoint(x: cx, y: H)
        )
    )

    // Gothic arches
    if intens > 0.2 {
        let ky = H * 0.22, lx = W * 0.08, rx = W * 0.92, by = H * 0.85
        var outer = Path()
        outer.move(to: CGPoint(x: lx, y: by))
        outer.addCurve(to: CGPoint(x: cx, y: ky),
                       control1: CGPoint(x: lx, y: ky + 40),
                       control2: CGPoint(x: cx - 20, y: ky))
        outer.addCurve(to: CGPoint(x: rx, y: by),
                       control1: CGPoint(x: cx + 20, y: ky),
                       control2: CGPoint(x: rx, y: ky + 40))
        gc.stroke(outer,
                  with: .color(Color(hue: 195/360, saturation: 0.40, brightness: 0.45)
                    .opacity(0.08 + 0.06 * intens)),
                  lineWidth: 0.8)

        var inner = Path()
        inner.move(to: CGPoint(x: W * 0.2, y: by))
        inner.addCurve(to: CGPoint(x: cx, y: ky + 28),
                       control1: CGPoint(x: W * 0.2, y: ky + 70),
                       control2: CGPoint(x: cx - 12, y: ky + 28))
        inner.addCurve(to: CGPoint(x: W * 0.8, y: by),
                       control1: CGPoint(x: cx + 12, y: ky + 28),
                       control2: CGPoint(x: W * 0.8, y: ky + 70))
        gc.stroke(inner,
                  with: .color(Color(hue: 195/360, saturation: 0.40, brightness: 0.50)
                    .opacity(0.06 * intens)),
                  lineWidth: 0.6)
    }

    // Vertical luminous column (screen blend in the original; SwiftUI Canvas
    // lacks per-shape composite — we approximate by mutating a local
    // GraphicsContext copy that has its blendMode set to .screen.)
    let column = ctxScreen(gc: gc)
    column.fill(
        Path(CGRect(x: cx - 8, y: 0, width: 16, height: H)),
        with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(hue: 195/360, saturation: 0.50, brightness: 0.70)
                    .opacity(0), location: 0),
                .init(color: Color(hue: 195/360, saturation: 0.50, brightness: 0.68)
                    .opacity(0.12 * b * intens), location: 0.3),
                .init(color: Color(hue: 195/360, saturation: 0.55, brightness: 0.72)
                    .opacity(0.18 * b * intens), location: 0.5),
                .init(color: Color(hue: 195/360, saturation: 0.50, brightness: 0.65)
                    .opacity(0.10 * intens), location: 0.7),
                .init(color: .clear, location: 1.0),
            ]),
            startPoint: CGPoint(x: cx, y: 0),
            endPoint: CGPoint(x: cx, y: H)
        )
    )

    // Breath rings
    let breathColor = Color(hue: 195/360, saturation: 0.55, brightness: 0.70)
    for ri in 0..<4 {
        let rPhase = ((t / 4.8) + Double(ri) / 4)
            .truncatingRemainder(dividingBy: 1)
        let r = CGFloat(rPhase) * W * 0.48
        let alpha = (1 - rPhase) * (0.18 + 0.1 * intens) * b
        gc.stroke(
            Path(ellipseIn: CGRect(x: cx - r, y: cy - r,
                                   width: r * 2, height: r * 2)),
            with: .color(breathColor.opacity(alpha)),
            lineWidth: 0.8
        )
    }

    // Keystone glow
    let keyR = W * 0.38
    gc.fill(
        Path(CGRect(x: 0, y: 0, width: W, height: H)),
        with: .radialGradient(
            Gradient(colors: [
                Color(hue: 200/360, saturation: 0.55, brightness: 0.65)
                    .opacity(0.2 * b * intens),
                Color.clear,
            ]),
            center: CGPoint(x: cx, y: cy),
            startRadius: 0, endRadius: keyR
        )
    )

    drawVocabBindu(in: gc, at: CGPoint(x: cx, y: cy), hue: 195, t: t)
}

/// Helper: returns a GraphicsContext copy with screen blend mode applied.
/// SwiftUI doesn't expose composite-per-shape, so mutating a local copy
/// before drawing is the right pattern.
@inline(__always)
private func ctxScreen(gc: GraphicsContext) -> GraphicsContext {
    var copy = gc
    copy.blendMode = .screen
    return copy
}

/// ETHER — Vishuddha — standing sine bands, mirror vocal pair
func drawEther(
    in gc: GraphicsContext, size: CGSize, t: Double, intens: Double
) {
    let W = size.width, H = size.height
    guard W > 0, H > 0 else { return }
    let cx = W / 2, cy = H / 2

    let bandColor = Color(hue: 185/360, saturation: 0.60, brightness: 0.72)
    let bands = 7
    for li in 0..<bands {
        let yBase = H * 0.18 + CGFloat(li) * (H * 0.66 / CGFloat(bands))
        let freq = 0.014 + Double(li) * 0.001
        let amp = CGFloat(6 + Double(li) * 3 + intens * 12)
        let spd = t * (0.35 + Double(li) * 0.04)
        let direc: Double = li % 2 == 0 ? 1 : -1
        var path = Path()
        var first = true
        var px: CGFloat = 0
        while px <= W {
            let py = yBase + amp * CGFloat(sin(Double(px) * freq + spd * direc))
            if first { path.move(to: CGPoint(x: px, y: py)); first = false }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
            px += 2
        }
        let alpha = (0.04 + 0.05 * (li == 3 ? intens : 0)) * (0.5 + intens * 0.5)
        gc.stroke(path,
                  with: .color(bandColor.opacity(alpha)),
                  lineWidth: 0.7)

        if intens > 0.3 {
            let nodeR: CGFloat = 5
            gc.fill(
                Path(ellipseIn: CGRect(x: cx - nodeR, y: yBase - nodeR,
                                       width: nodeR * 2, height: nodeR * 2)),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(hue: 185/360, saturation: 0.65, brightness: 0.80)
                            .opacity(0.25 * intens),
                        .clear
                    ]),
                    center: CGPoint(x: cx, y: yBase),
                    startRadius: 0, endRadius: nodeR
                )
            )
        }
    }

    // Mirror vocal pair — two mirrored sine paths
    let vocalColor = Color(hue: 185/360, saturation: 0.65, brightness: 0.78)
    for m in 0..<2 {
        let sign: CGFloat = m == 0 ? 1 : -1
        let vAmp = CGFloat(18 + intens * 22)
        let vFreq = 0.02
        let vSpd = t * 0.55
        var path = Path()
        var first = true
        var px: CGFloat = 0
        while px <= W {
            let py = cy + sign * vAmp * CGFloat(sin(Double(px) * vFreq + vSpd))
            if first { path.move(to: CGPoint(x: px, y: py)); first = false }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
            px += 2
        }
        gc.stroke(path,
                  with: .color(vocalColor.opacity(0.12 + 0.08 * intens)),
                  lineWidth: 1)
    }

    // Resonance glow at center
    let resR = W * 0.35 * CGFloat(intens)
    if resR > 1 {
        gc.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: H)),
            with: .radialGradient(
                Gradient(colors: [
                    Color(hue: 185/360, saturation: 0.55, brightness: 0.65)
                        .opacity(0.18 * intens),
                    .clear,
                ]),
                center: CGPoint(x: cx, y: cy),
                startRadius: 0, endRadius: resR
            )
        )
    }

    drawVocabBindu(in: gc, at: CGPoint(x: cx, y: cy), hue: 185, t: t)
}

/// CONSTELLATION — Ajna — star field, focal stars, connection lines
func drawConstellation(
    in gc: GraphicsContext, size: CGSize, t: Double, intens: Double
) {
    let W = size.width, H = size.height
    guard W > 0, H > 0 else { return }
    let cx = W / 2, cy = H / 2

    // Star field — 80 deterministic stars
    let nStars = 80
    for i in 0..<nStars {
        let sx = dn(Double(i * 13)) * W
        let sy = dn(Double(i * 17)) * H
        let brightness = dn2(Double(i * 11))
        let sz: CGFloat = brightness > 0.85 ? 2 : (brightness > 0.65 ? 1.2 : 0.7)
        let twinkle = 0.5 + 0.5 * sin(t * (1.2 + dn(Double(i * 7))) + Double(i))
        let alpha = (0.15 + 0.5 * brightness) * twinkle * (0.4 + 0.6 * intens)
        let col = Color(
            hue: 50 / 360,
            saturation: 0.30 + brightness * 0.30,
            brightness: 0.60 + brightness * 0.20
        )
        gc.fill(
            Path(ellipseIn: CGRect(x: sx - sz, y: sy - sz,
                                   width: sz * 2, height: sz * 2)),
            with: .color(col.opacity(alpha))
        )
    }

    // 5 focal stars with glow
    let focals: [CGPoint] = [
        CGPoint(x: cx - 80, y: cy - 110),
        CGPoint(x: cx + 95, y: cy - 85),
        CGPoint(x: cx - 110, y: cy + 60),
        CGPoint(x: cx + 70, y: cy + 100),
        CGPoint(x: cx - 30, y: cy - 155),
    ]
    let nFocal = min(focals.count, 2 + Int(intens * 3))
    for i in 0..<nFocal {
        let f = focals[i]
        let tw = 0.7 + 0.3 * sin(t * (1 + Double(i) * 0.3))
        let gloR: CGFloat = 16
        gc.fill(
            Path(ellipseIn: CGRect(x: f.x - gloR, y: f.y - gloR,
                                   width: gloR * 2, height: gloR * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    Color(hue: 50/360, saturation: 0.70, brightness: 0.80)
                        .opacity(0.45 * tw * intens),
                    .clear,
                ]),
                center: f, startRadius: 0, endRadius: gloR
            )
        )
        let coreR: CGFloat = 1.8
        gc.fill(
            Path(ellipseIn: CGRect(x: f.x - coreR, y: f.y - coreR,
                                   width: coreR * 2, height: coreR * 2)),
            with: .color(Color(hue: 50/360, saturation: 0.80, brightness: 0.92)
                .opacity(tw))
        )
    }

    // Connection lines (first 30 stars, neighbours under 110pt)
    if intens > 0.3 {
        let lineColor = Color(hue: 50/360, saturation: 0.40, brightness: 0.60)
        for a in 0..<30 {
            for b in (a + 1)..<30 {
                let ax = dn(Double(a * 13)) * W
                let ay = dn(Double(a * 17)) * H
                let bx = dn(Double(b * 13)) * W
                let by = dn(Double(b * 17)) * H
                let d = sqrt(pow(ax - bx, 2) + pow(ay - by, 2))
                if d < 110 {
                    var p = Path()
                    p.move(to: CGPoint(x: ax, y: ay))
                    p.addLine(to: CGPoint(x: bx, y: by))
                    gc.stroke(p,
                              with: .color(lineColor.opacity(
                                (0.03 + 0.03 * intens) * (1 - d / 110)
                              )),
                              lineWidth: 0.4)
                }
            }
        }
    }

    drawVocabBindu(in: gc, at: CGPoint(x: cx, y: cy), hue: 50, t: t)
}

/// CROWN — Sahasrara — 12-petal lotus, ascending light, violet
func drawCrown(
    in gc: GraphicsContext, size: CGSize, t: Double, intens: Double
) {
    let W = size.width, H = size.height
    guard W > 0, H > 0 else { return }
    let cx = W / 2, cy = H * 0.52
    let b = 0.7 + 0.3 * sin(t * 0.4)

    // Central violet glow
    let gloR = W * 0.55
    gc.fill(
        Path(CGRect(x: 0, y: 0, width: W, height: H)),
        with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(hue: 280/360, saturation: 0.55, brightness: 0.50)
                    .opacity(0.22 * b * intens), location: 0),
                .init(color: Color(hue: 280/360, saturation: 0.45, brightness: 0.35)
                    .opacity(0.10 * intens), location: 0.5),
                .init(color: .clear, location: 1.0),
            ]),
            center: CGPoint(x: cx, y: cy),
            startRadius: 0, endRadius: gloR
        )
    )

    // 12-petal lotus
    let nPetals = 12
    let outerR = W * 0.28 * (0.85 + 0.15 * CGFloat(b * intens))
    let petalFill = Color(hue: 280/360, saturation: 0.50, brightness: 0.65)
    let petalStroke = Color(hue: 280/360, saturation: 0.55, brightness: 0.72)
    for p in 0..<nPetals {
        let angle = Double(p) * (.pi * 2 / Double(nPetals)) - .pi / 2
        let px = cx + outerR * CGFloat(cos(angle))
        let py = cy + outerR * CGFloat(sin(angle))
        let cp1x = cx + (outerR * 0.65) * CGFloat(cos(angle - 0.22))
        let cp1y = cy + (outerR * 0.65) * CGFloat(sin(angle - 0.22))
        let cp2x = cx + (outerR * 0.65) * CGFloat(cos(angle + 0.22))
        let cp2y = cy + (outerR * 0.65) * CGFloat(sin(angle + 0.22))

        var petal = Path()
        petal.move(to: CGPoint(x: cx, y: cy))
        petal.addCurve(to: CGPoint(x: px, y: py),
                       control1: CGPoint(x: cp1x, y: cp1y),
                       control2: CGPoint(x: cp2x, y: cp2y))
        petal.addCurve(to: CGPoint(x: cx, y: cy),
                       control1: CGPoint(x: cp2x, y: cp2y),
                       control2: CGPoint(x: cp1x, y: cp1y))

        let pAlpha = 0.10 + 0.06 * intens + 0.04 * sin(t * 0.5 + Double(p) * 0.5)
        gc.fill(petal, with: .color(petalFill.opacity(pAlpha)))
        gc.stroke(petal,
                  with: .color(petalStroke.opacity(pAlpha * 0.8)),
                  lineWidth: 0.6)
    }

    // Ascending light particles
    let nP = Int(15 + 25 * intens)
    let span = H * 0.75
    for i in 0..<nP {
        let seed = Double(i) * 773
        let ox = (dn(seed) - 0.5) * W * 0.5
        let speed = 14 + dn2(seed) * 18
        let py = cy - CGFloat((t * speed + dn(seed * 3) * H * 0.7)
            .truncatingRemainder(dividingBy: span))
        let px = cx + CGFloat(ox)
        let pct = 1 - Double((py - (cy - span)) / span)
        let alpha = (0.2 + 0.2 * dn(seed + 2)) * (1 - pct * 0.6) * intens
        let r = CGFloat(1 + dn(seed + 1) * 0.8)
        let hue = 280 + dn(seed * 2) * 40
        let col = Color(hue: hue / 360, saturation: 0.60,
                        brightness: 0.70 + pct * 0.20)
        gc.fill(
            Path(ellipseIn: CGRect(x: px - r, y: py - r,
                                   width: r * 2, height: r * 2)),
            with: .color(col.opacity(alpha))
        )
    }

    drawVocabBindu(in: gc, at: CGPoint(x: cx, y: cy), hue: 280, t: t)
}

/// SOUL — Aatma — dual triangles, deep stillness, witness
func drawSoul(
    in gc: GraphicsContext, size: CGSize, t: Double, intens: Double
) {
    let W = size.width, H = size.height
    guard W > 0, H > 0 else { return }
    let cx = W / 2, cy = H * 0.5
    let b = 0.92 + 0.08 * sin(t * 0.28)  // barely breathing

    // Subtle field
    gc.fill(
        Path(CGRect(x: 0, y: 0, width: W, height: H)),
        with: .radialGradient(
            Gradient(colors: [
                Color(hue: 265/360, saturation: 0.40, brightness: 0.30)
                    .opacity(0.12 * intens),
                .clear,
            ]),
            center: CGPoint(x: cx, y: cy),
            startRadius: 0, endRadius: W * 0.5
        )
    )

    // Outer triangle (upward)
    let tr = W * 0.34 * CGFloat(b)
    let t1y = cy - tr * 0.92
    let t2x = cx - tr * 0.87
    let t2y = cy + tr * 0.46
    let t3x = cx + tr * 0.87
    let t3y = cy + tr * 0.46
    var outer = Path()
    outer.move(to: CGPoint(x: cx, y: t1y))
    outer.addLine(to: CGPoint(x: t2x, y: t2y))
    outer.addLine(to: CGPoint(x: t3x, y: t3y))
    outer.closeSubpath()
    gc.stroke(outer,
              with: .color(Color(hue: 265/360, saturation: 0.42, brightness: 0.52)
                .opacity(0.22 + 0.12 * intens)),
              lineWidth: 0.9)
    gc.fill(outer,
            with: .color(Color(hue: 265/360, saturation: 0.38, brightness: 0.28)
                .opacity(0.06 * intens)))

    // Inner triangle (downward, slow rotation ~60s)
    let ir = tr * 0.52
    let rot = t * 0.016 * (.pi * 2 / 60) + .pi
    var rotCtx = gc
    rotCtx.translateBy(x: cx, y: cy)
    rotCtx.rotate(by: .radians(rot))
    var inner = Path()
    inner.move(to: CGPoint(x: 0, y: -ir * 0.92))
    inner.addLine(to: CGPoint(x: -ir * 0.87, y: ir * 0.46))
    inner.addLine(to: CGPoint(x: ir * 0.87, y: ir * 0.46))
    inner.closeSubpath()
    rotCtx.stroke(inner,
                  with: .color(Color(hue: 265/360, saturation: 0.38, brightness: 0.48)
                    .opacity(0.15 + 0.08 * intens)),
                  lineWidth: 0.7)

    // Star of David center glow
    let sR: CGFloat = 18
    gc.fill(
        Path(ellipseIn: CGRect(x: cx - sR, y: cy - sR,
                               width: sR * 2, height: sR * 2)),
        with: .radialGradient(
            Gradient(colors: [
                Color(hue: 265/360, saturation: 0.50, brightness: 0.60)
                    .opacity(0.3 * intens),
                .clear,
            ]),
            center: CGPoint(x: cx, y: cy),
            startRadius: 0, endRadius: sR
        )
    )

    // Deep-field witness stars
    let witnessColor = Color(hue: 265/360, saturation: 0.30, brightness: 0.55)
    for i in 0..<12 {
        let sx = dn(Double(i * 41)) * W
        let sy = dn(Double(i * 53)) * H
        let sz = CGFloat(0.6 + dn2(Double(i * 7)) * 0.5)
        gc.fill(
            Path(ellipseIn: CGRect(x: sx - sz, y: sy - sz,
                                   width: sz * 2, height: sz * 2)),
            with: .color(witnessColor.opacity(0.08 * dn(Double(i * 19)) * intens))
        )
    }

    drawVocabBindu(in: gc, at: CGPoint(x: cx, y: cy), hue: 265, t: t)
}

/// DISSOLUTION — Maya — veil cycle, form ↔ void
func drawDissolution(
    in gc: GraphicsContext, size: CGSize, t: Double, intens: Double
) {
    let W = size.width, H = size.height
    guard W > 0, H > 0 else { return }
    let cx = W / 2, cy = H * 0.5
    let cycleLen = 9.0
    let cyclePhase = t.truncatingRemainder(dividingBy: cycleLen * 2)
    let dissolving = cyclePhase > cycleLen
    let cyclePct = dissolving
        ? (cyclePhase - cycleLen) / cycleLen
        : cyclePhase / cycleLen
    let formPct = dissolving ? (1 - cyclePct) : cyclePct  // 0 = void, 1 = full

    // Deep field glow
    gc.fill(
        Path(CGRect(x: 0, y: 0, width: W, height: H)),
        with: .radialGradient(
            Gradient(colors: [
                Color(hue: 195/360, saturation: 0.35, brightness: 0.30)
                    .opacity(0.12 * intens * (1 - formPct * 0.3)),
                .clear,
            ]),
            center: CGPoint(x: cx, y: cy),
            startRadius: 0, endRadius: W * 0.6
        )
    )

    // Veil particles — 64 in an 8×8 grid
    let grid = 8
    let spacing = W * 0.088
    let gx0 = cx - CGFloat(grid - 1) * spacing / 2
    let gy0 = cy - CGFloat(grid - 1) * spacing / 2
    let veilColor = Color(hue: 195/360, saturation: 0.45, brightness: 0.65)
    for r in 0..<grid {
        for c in 0..<grid {
            let idx = r * grid + c
            let gPx = gx0 + CGFloat(c) * spacing
            let gPy = gy0 + CGFloat(r) * spacing
            let driftAng = (dn(Double(idx * 37)) - 0.5) * .pi * 2
            let driftDist = dn2(Double(idx * 53)) * W * 0.38 * (1 - formPct)
            let px = gPx + CGFloat(cos(driftAng) * driftDist * (1 - formPct))
            let py = gPy + CGFloat(sin(driftAng) * driftDist * (1 - formPct))
            let alpha = formPct * (0.25 + 0.1 * dn(Double(idx * 17))) * intens
            let sz = CGFloat(0.8 + dn(Double(idx * 29)) * 0.8)
            gc.fill(
                Path(ellipseIn: CGRect(x: px - sz, y: py - sz,
                                       width: sz * 2, height: sz * 2)),
                with: .color(veilColor.opacity(alpha))
            )
        }
    }

    // Veil overlay — what's behind
    if formPct < 0.7 {
        gc.fill(
            Path(CGRect(x: 0, y: 0, width: W, height: H)),
            with: .radialGradient(
                Gradient(colors: [
                    Color(hue: 280/360, saturation: 0.40, brightness: 0.35)
                        .opacity((0.7 - formPct) * 0.2 * intens),
                    .clear,
                ]),
                center: CGPoint(x: cx, y: cy),
                startRadius: 0, endRadius: W * 0.45
            )
        )
    }

    drawVocabBindu(in: gc, at: CGPoint(x: cx, y: cy), hue: 190, t: t)
}

/// AMBIENT — meditate / family tracks. A breathing void + central Bindu.
/// No element-specific atmosphere. The Lissajous dot drawn by
/// `VisualizerView` carries the entire visual presence.
func drawAmbient(
    in gc: GraphicsContext, size: CGSize, t: Double, intens: Double, hue: Double
) {
    let W = size.width, H = size.height
    guard W > 0, H > 0 else { return }
    let cx = W / 2, cy = H / 2

    let breath = 0.5 + 0.5 * sin(t * 0.15)
    gc.fill(
        Path(CGRect(x: 0, y: 0, width: W, height: H)),
        with: .radialGradient(
            Gradient(colors: [
                Color(hue: hue/360, saturation: 0.20, brightness: 0.20)
                    .opacity(0.08 * breath * (0.5 + 0.5 * intens)),
                .clear,
            ]),
            center: CGPoint(x: cx, y: cy),
            startRadius: 0,
            endRadius: min(W, H) * 0.55
        )
    )

    drawVocabBindu(in: gc, at: CGPoint(x: cx, y: cy), hue: hue, t: t)
}
