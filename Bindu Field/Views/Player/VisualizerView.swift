import SwiftUI

/// The Cathedral — the sonic architecture of the Cross dance made visible.
///
/// Tier 1 (continuous, always running): cathedral floor, Sid columns,
/// vault ceiling, atmospheric grain, Gaia ground. Bindu (the singular
/// Lissajous) is always on top of all tiers.
///
/// Tier 2 (ensemble, presence-driven) and Tier 3+4 (crescendo / climax)
/// arrive in later phases of the Lalita pass.
///
/// All tiers read from `Performer.shared` for time-aware state
/// (crescendoModulator, beatPulse, energy, archetypePresence) and from
/// `DSPWireService.shared` for low-level signal state (rms, carrierLocked,
/// userBeatHz, onsetCount).
struct VisualizerView: View {
    let color: Color
    /// HSB hue (0–360) of the element. Lets tier colors stay in the
    /// element family without re-extracting from the `Color` opaque type.
    let elementHueDeg: Double

    @State private var wire = DSPWireService.shared
    @State private var performer = Performer.shared

    @State private var trailPositions: [CGPoint] = []
    @State private var rings: [Ring] = []
    @State private var grain: [Grain] = []
    @State private var lastTrailSampleAt: Double = 0
    @State private var lastGrainStepAt: Double = 0
    @State private var lastBeatPulseTrigger: Double = 0
    @State private var carrierPulse: CGFloat = 1.0

    private struct Ring: Identifiable {
        let id = UUID()
        let center: CGPoint
        let bornAt: Double
        let color: Color
    }

    private struct Grain: Identifiable {
        let id = UUID()
        var pos: CGPoint
        var vy: CGFloat        // upward drift (negative)
        var bornAt: Double
        var lifetime: Double
        var size: CGFloat
    }

    // MARK: - Tunables
    private let trailLength: Int = 120
    private let trailSampleInterval: Double = 0.04   // ~25 Hz
    private let ringDurationSec: Double = 0.7
    private let ringMaxRadius: CGFloat = 110
    private let grainTarget: Int = 80
    private let grainStepInterval: Double = 1.0 / 30.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geo in
                let bindu = binduPosition(t: t, in: geo.size)

                Canvas { ctx, size in
                    let mod = performer.crescendoModulator
                    let beat = performer.beatPulse
                    let energy = performer.energy
                    let gaiaPresence = performer.archetypePresence[.gaia] ?? 0

                    // TIER 1 — continuous
                    drawCathedralFloor(ctx: ctx, size: size, t: t,
                                       mod: mod, beat: beat)
                    drawSidColumns(ctx: ctx, size: size, t: t, mod: mod)
                    drawVaultCeiling(ctx: ctx, size: size, t: t,
                                     energy: energy, mod: mod)
                    drawAtmosphericGrain(ctx: ctx, t: t)
                    drawGaiaGround(ctx: ctx, size: size, t: t,
                                   gaia: gaiaPresence)

                    // TIER 2 — ensemble (presence-gated)
                    let archPresence = performer.archetypePresence[.arch] ?? 0
                    if archPresence > 0.1 {
                        drawArchChant(ctx: ctx, size: size, t: t,
                                      presence: archPresence)
                    }
                    let sakshiPresence = performer.archetypePresence[.sakshi] ?? 0
                    if sakshiPresence > 0.1 {
                        drawSakshiGesture(ctx: ctx, size: size, t: t,
                                          presence: sakshiPresence)
                    }

                    // BINDU — singular Lissajous on top
                    drawBindu(ctx: ctx, size: size, t: t,
                              energy: energy, beat: beat, mod: mod,
                              bindu: bindu)
                }
                .onChange(of: t) { _, newT in
                    if newT - lastTrailSampleAt >= trailSampleInterval {
                        lastTrailSampleAt = newT
                        appendTrail(bindu)
                    }
                    if newT - lastGrainStepAt >= grainStepInterval {
                        let dt = newT - lastGrainStepAt
                        lastGrainStepAt = newT
                        stepGrain(dt: dt, t: newT, in: geo.size)
                    }
                    triggerBeatRingIfNeeded(t: newT)
                }
            }
        }
        .onChange(of: wire.carrierLocked) { _, locked in
            withAnimation(.easeOut(duration: 0.18)) {
                carrierPulse = locked ? 1.5 : 1.0
            }
        }
    }

    // MARK: - TIER 1 · Cathedral floor
    //
    // Vanishing point at (W/2, H*0.52). 7 radial lines fanning from the
    // VP to evenly-spaced bottom points; 10 horizontal lines spaced by a
    // perspective-quadratic curve (closer-together near the horizon).
    // Beat pulse adds a bright horizontal across the horizon.

    private func drawCathedralFloor(ctx: GraphicsContext, size: CGSize,
                                    t: Double, mod: Double, beat: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0 else { return }
        let vp = CGPoint(x: W / 2, y: H * 0.52)
        let opacity = 0.03 + mod * 0.08 + beat * 0.025
        let col = Color(hue: elementHueDeg / 360, saturation: 0.35, brightness: 0.5)
            .opacity(opacity)

        var path = Path()
        // 7 radial lines from VP to bottom
        for i in 0..<7 {
            let x = W * (Double(i) / 6.0)
            path.move(to: vp)
            path.addLine(to: CGPoint(x: x, y: H))
        }
        // 10 horizontal lines, perspective-spaced (closer near horizon)
        for i in 0..<10 {
            let progress = pow(Double(i) / 9.0, 2.5)
            let y = vp.y + (H - vp.y) * progress
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: W, y: y))
        }
        ctx.stroke(path, with: .color(col), lineWidth: 0.5)

        // Beat pulse — bright horizontal at the horizon line
        if beat > 0.3 {
            var horizon = Path()
            horizon.move(to: CGPoint(x: 0, y: vp.y))
            horizon.addLine(to: CGPoint(x: W, y: vp.y))
            let beatCol = Color(hue: elementHueDeg / 360,
                                saturation: 0.55, brightness: 0.7)
                .opacity(beat * 0.4)
            ctx.stroke(horizon, with: .color(beatCol), lineWidth: 1)
        }
    }

    // MARK: - TIER 1 · Sid columns
    //
    // Two verticals at x = W*0.18 and W*0.82. Brightness pulses on a 5.5s
    // drone cycle and rises with the crescendo modulator. Capital + base
    // ticks (4 horizontal hairlines per column).

    private func drawSidColumns(ctx: GraphicsContext, size: CGSize,
                                t: Double, mod: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0 else { return }
        let positions: [Double] = [0.18, 0.82]
        let cycle = (t.truncatingRemainder(dividingBy: 5.5)) / 5.5
        let dronePulse = (cos(cycle * .pi * 2) + 1) / 2
        let brightness = 0.20 + dronePulse * 0.30 + mod * 0.40
        let col = Color(hue: elementHueDeg / 360,
                        saturation: 0.20, brightness: brightness)

        for xFrac in positions {
            let x = W * xFrac
            let top = H * 0.06
            let bottom = H * 0.58

            var column = Path()
            column.move(to: CGPoint(x: x, y: top))
            column.addLine(to: CGPoint(x: x, y: bottom))
            ctx.stroke(column, with: .color(col), lineWidth: 1.5)

            // Capital + base ticks
            for tickY in [top, top + 8, bottom - 8, bottom] {
                var tick = Path()
                tick.move(to: CGPoint(x: x - 5, y: tickY))
                tick.addLine(to: CGPoint(x: x + 5, y: tickY))
                ctx.stroke(tick, with: .color(col.opacity(0.6)), lineWidth: 0.5)
            }
        }
    }

    // MARK: - TIER 1 · Vault ceiling
    //
    // Three layered Bezier arches from left anchor through an apex
    // overhead to right anchor, with 4 rib vaults from each Sid column
    // to the apex. Opacity rises with energy + modulator.

    private func drawVaultCeiling(ctx: GraphicsContext, size: CGSize,
                                  t: Double, energy: Double, mod: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0 else { return }
        let left = CGPoint(x: W * 0.04, y: H * 0.28)
        let apex = CGPoint(x: W / 2,     y: H * 0.04)
        let right = CGPoint(x: W * 0.96, y: H * 0.28)
        let ctrlL = CGPoint(x: W * 0.04, y: H * 0.07)
        let ctrlR = CGPoint(x: W * 0.96, y: H * 0.07)

        let baseOp = min(0.38, energy * 0.22 + mod * 0.4)
        let col = Color(hue: elementHueDeg / 360,
                        saturation: 0.45, brightness: 0.65)

        // 3 layered arches with slight vertical offset for depth
        for layer in 0..<3 {
            let yOffset = CGFloat(layer) * 1.5
            var arch = Path()
            arch.move(to: CGPoint(x: left.x, y: left.y + yOffset))
            arch.addQuadCurve(
                to: CGPoint(x: apex.x, y: apex.y + yOffset),
                control: CGPoint(x: ctrlL.x, y: ctrlL.y + yOffset)
            )
            arch.addQuadCurve(
                to: CGPoint(x: right.x, y: right.y + yOffset),
                control: CGPoint(x: ctrlR.x, y: ctrlR.y + yOffset)
            )
            ctx.stroke(arch,
                       with: .color(col.opacity(baseOp * (1.0 - Double(layer) * 0.3))),
                       lineWidth: 1)
        }

        // 4 rib vaults from each column to the apex
        let columnXs: [Double] = [0.18, 0.82]
        for xFrac in columnXs {
            let base = CGPoint(x: W * xFrac, y: H * 0.28)
            for r in 0..<4 {
                let frac = Double(r + 1) / 5.0
                let endX = base.x + (apex.x - base.x) * frac
                let endY = base.y + (apex.y - base.y) * frac * 0.9
                var rib = Path()
                rib.move(to: base)
                rib.addLine(to: CGPoint(x: endX, y: endY))
                ctx.stroke(rib,
                           with: .color(col.opacity(baseOp * 0.55)),
                           lineWidth: 0.5)
            }
        }
    }

    // MARK: - TIER 1 · Atmospheric grain
    //
    // 80 slow-rising motes. Density (per-particle alpha scale) drops to
    // 0.05 inside score silence windows, rises with energy + modulator
    // elsewhere. Alpha peaks at mid-life.

    private func drawAtmosphericGrain(ctx: GraphicsContext, t: Double) {
        let mod = performer.crescendoModulator
        let energy = performer.energy
        let density = performer.inSilence
            ? 0.05
            : 0.18 + energy * 0.45 + mod * 0.35
        let col = Color(hue: elementHueDeg / 360,
                        saturation: 0.30, brightness: 0.75)

        for p in grain {
            let age = t - p.bornAt
            guard age >= 0, age < p.lifetime else { continue }
            let lifeFrac = age / p.lifetime
            let envelope = sin(lifeFrac * .pi)   // 0 → 1 → 0
            let alpha = envelope * density
            let rect = CGRect(x: p.pos.x - p.size / 2,
                              y: p.pos.y - p.size / 2,
                              width: p.size, height: p.size)
            ctx.fill(
                Path(ellipseIn: rect),
                with: .color(col.opacity(alpha))
            )
        }
    }

    private func stepGrain(dt: Double, t: Double, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        // Advance positions, drop expired
        var living: [Grain] = []
        living.reserveCapacity(grain.count)
        for var p in grain {
            let age = t - p.bornAt
            if age > p.lifetime { continue }
            p.pos.y += p.vy * CGFloat(dt)
            // Slight horizontal sway with a per-particle phase
            let sway = sin(t * 0.3 + Double(p.id.hashValue % 1000) * 0.07) * 0.2
            p.pos.x += CGFloat(sway)
            living.append(p)
        }

        // Spawn to maintain target density
        let toSpawn = max(0, grainTarget - living.count)
        for _ in 0..<toSpawn {
            let p = spawnGrain(in: size, t: t)
            living.append(p)
        }
        grain = living
    }

    private func spawnGrain(in size: CGSize, t: Double) -> Grain {
        let x = CGFloat.random(in: 0...size.width)
        // Spawn anywhere in the lower 2/3 so the rise is visible
        let y = CGFloat.random(in: size.height * 0.35...size.height)
        let lifetime = Double.random(in: 6...12)
        // Rise velocity: -2 to -6 pt/sec (negative = up)
        let vy = CGFloat.random(in: -6 ... -1.5)
        let sz = CGFloat.random(in: 0.4...1.4)
        return Grain(pos: CGPoint(x: x, y: y),
                     vy: vy, bornAt: t, lifetime: lifetime, size: sz)
    }

    // MARK: - TIER 1 · Gaia ground
    //
    // Soft radial glow at y = H*0.85, breathing on a slow 52s cycle,
    // scaled by Gaia's archetype presence (which ramps from 0 over the
    // first ~6s of a session).

    private func drawGaiaGround(ctx: GraphicsContext, size: CGSize,
                                t: Double, gaia: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0, gaia > 0.02 else { return }
        let center = CGPoint(x: W / 2, y: H * 0.85)
        let breath = sin(t * 0.12) * 0.5 + 0.5
        let radius = W * 0.55 * (0.85 + breath * 0.30)
        // Hue shifted 15° down to ground the color (terracotta direction).
        let h = (elementHueDeg - 15 + 360).truncatingRemainder(dividingBy: 360) / 360
        let col = Color(hue: h, saturation: 0.45, brightness: 0.40)
        let alpha = (0.04 + breath * 0.08) * gaia
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - radius,
                                   y: center.y - radius,
                                   width: radius * 2,
                                   height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [col.opacity(alpha), col.opacity(0)]),
                center: center,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    // MARK: - TIER 2 · Arch chant
    //
    // A single Bezier arc above center, breathing with sin(t*0.35)*8 in
    // Y. Five ghost echoes behind, each at an older `t` value (50ms
    // increments) so the chant feels like a phrase that has just been
    // said and is still ringing. Three phrase-lights — small warm-yellow
    // dots — traverse the arc with phase offsets, like syllables landing.

    private func drawArchChant(ctx: GraphicsContext, size: CGSize,
                               t: Double, presence: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0 else { return }

        let archColor = Color(hue: elementHueDeg / 360,
                              saturation: 0.50, brightness: 0.78)

        // Five ghost echoes behind the primary, oldest first so the
        // primary is drawn last on top.
        for i in (1...5).reversed() {
            let lag = 0.05 * Double(i)
            let yShift = sin((t - lag) * 0.35) * 8
            let ghostAlpha = (0.05 - Double(i - 1) * 0.008) * presence
            let path = archPath(W: W, H: H, yShift: yShift)
            ctx.stroke(path,
                       with: .color(archColor.opacity(ghostAlpha)),
                       lineWidth: 0.5)
        }

        // Primary arc
        let primaryShift = sin(t * 0.35) * 8
        let primaryPath = archPath(W: W, H: H, yShift: primaryShift)
        ctx.stroke(primaryPath,
                   with: .color(archColor.opacity(0.22 * presence)),
                   lineWidth: 1)

        // Three phrase-lights — small dots traversing the arc with phase
        // offsets. Light color is warm yellow per the design spec
        // (hsl(50, 60%, 72%)) — phrase-lights aren't element-keyed.
        let phraseColor = Color(hue: 50 / 360, saturation: 0.60, brightness: 0.72)
        let arcA = CGPoint(x: W * 0.25, y: H * 0.30 + primaryShift)
        let arcC = CGPoint(x: W * 0.50, y: H * 0.17 + primaryShift)
        let arcB = CGPoint(x: W * 0.75, y: H * 0.30 + primaryShift)
        for i in 0..<3 {
            let phase = (t * 0.6 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1.0)
            let p = quadraticPoint(a: arcA, c: arcC, b: arcB, at: phase)
            let r: CGFloat = 2.5
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r,
                                       width: r * 2, height: r * 2)),
                with: .color(phraseColor.opacity(0.6 * presence))
            )
            // Soft halo around each phrase-light
            let haloR: CGFloat = 6
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - haloR, y: p.y - haloR,
                                       width: haloR * 2, height: haloR * 2)),
                with: .radialGradient(
                    Gradient(colors: [
                        phraseColor.opacity(0.30 * presence),
                        phraseColor.opacity(0)
                    ]),
                    center: p,
                    startRadius: 0,
                    endRadius: haloR
                )
            )
        }
    }

    /// The base Bezier arc — moveTo(W*0.25, H*0.30) → quadCurve through
    /// (W*0.5, H*0.17) → (W*0.75, H*0.30). `yShift` is applied uniformly
    /// to all three points so the whole arc breathes.
    private func archPath(W: CGFloat, H: CGFloat, yShift: Double) -> Path {
        var p = Path()
        let dy = CGFloat(yShift)
        p.move(to: CGPoint(x: W * 0.25, y: H * 0.30 + dy))
        p.addQuadCurve(
            to: CGPoint(x: W * 0.75, y: H * 0.30 + dy),
            control: CGPoint(x: W * 0.50, y: H * 0.17 + dy)
        )
        return p
    }

    /// Point on a quadratic Bezier at parameter `at` in [0,1].
    private func quadraticPoint(a: CGPoint, c: CGPoint, b: CGPoint,
                                at u: Double) -> CGPoint {
        let oneMinusU = 1.0 - u
        let x = oneMinusU * oneMinusU * a.x
            + 2 * oneMinusU * u * c.x
            + u * u * b.x
        let y = oneMinusU * oneMinusU * a.y
            + 2 * oneMinusU * u * c.y
            + u * u * b.y
        return CGPoint(x: x, y: y)
    }

    // MARK: - TIER 2 · Sakshi (the unmade gesture)
    //
    // A 72%-of-circle arc at the right periphery (W*0.88, H*0.42), radius
    // W*0.05. The whole arc rotates slowly — the witness gesture starts,
    // traces 72%, releases, starts again. Three ghost trails at older
    // phases sit at opacity 0.08 behind it.

    private func drawSakshiGesture(ctx: GraphicsContext, size: CGSize,
                                   t: Double, presence: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0 else { return }

        let center = CGPoint(x: W * 0.88, y: H * 0.42)
        let radius = W * 0.05
        // Phase advances at ~0.15 cycles/sec → ~6.7s per full rotation
        let rotationSpeed = 0.15
        let arcFraction = 0.72   // of a full circle
        let arcSpan = arcFraction * 2 * .pi
        let col = Color(hue: elementHueDeg / 360,
                        saturation: 0.40, brightness: 0.78)

        // Three ghost trails, oldest first so the primary draws last
        for i in (1...3).reversed() {
            let lag = 0.18 * Double(i)
            let oldPhase = ((t - lag) * rotationSpeed)
                .truncatingRemainder(dividingBy: 1.0)
            let s = oldPhase * 2 * .pi
            var ghost = Path()
            ghost.addArc(center: center, radius: radius,
                         startAngle: .radians(s),
                         endAngle: .radians(s + arcSpan),
                         clockwise: false)
            ctx.stroke(ghost,
                       with: .color(col.opacity(0.08 * presence)),
                       lineWidth: 0.5)
        }

        // Primary arc
        let phase = (t * rotationSpeed).truncatingRemainder(dividingBy: 1.0)
        let startAngle = phase * 2 * .pi
        var arc = Path()
        arc.addArc(center: center, radius: radius,
                   startAngle: .radians(startAngle),
                   endAngle: .radians(startAngle + arcSpan),
                   clockwise: false)
        ctx.stroke(arc,
                   with: .color(col.opacity(0.35 * presence)),
                   lineWidth: 1)

        // Subtle leading-edge dot at the end of the arc — the active tip
        // of the gesture. Helps the eye find where the witness is now.
        let tipAngle = startAngle + arcSpan
        let tip = CGPoint(
            x: center.x + radius * cos(tipAngle),
            y: center.y + radius * sin(tipAngle)
        )
        let tipR: CGFloat = 2
        ctx.fill(
            Path(ellipseIn: CGRect(x: tip.x - tipR, y: tip.y - tipR,
                                   width: tipR * 2, height: tipR * 2)),
            with: .color(col.opacity(0.6 * presence))
        )
    }

    // MARK: - Bindu (singular Lissajous)
    //
    // Multi-harmonic Lissajous driven by the running BEAT Hz. Trail of
    // 120 samples renders as a comet behind the head; an RMS-driven
    // bloom halos the head; beat rings spawn on each performer.beatPulse
    // edge above 0.9; the carrier-lock flag pulses the core to 1.5×
    // size for ~180ms.

    private func drawBindu(ctx: GraphicsContext, size: CGSize, t: Double,
                           energy: Double, beat: Double, mod: Double,
                           bindu: CGPoint) {
        let baseOpacity: Double = wire.binauralEnabled ? 1.0 : 0.4

        // RMS-driven halo
        let haloR: CGFloat = 28 + CGFloat(mod) * 20 + CGFloat(energy) * 20
        let haloRect = CGRect(x: bindu.x - haloR, y: bindu.y - haloR,
                              width: haloR * 2, height: haloR * 2)
        let haloAlpha = (0.18 + energy * 0.45) * baseOpacity
        ctx.fill(
            Path(ellipseIn: haloRect),
            with: .radialGradient(
                Gradient(colors: [
                    color.opacity(haloAlpha),
                    color.opacity(0)
                ]),
                center: bindu,
                startRadius: 0,
                endRadius: haloR
            )
        )

        // Beat rings (onset-spawned, age-fading)
        for ring in rings {
            let age = t - ring.bornAt
            if age < 0 || age > ringDurationSec { continue }
            let progress = age / ringDurationSec
            let r = CGFloat(progress) * (ringMaxRadius + CGFloat(energy) * 60)
            let alpha = (0.6 * (1 - progress)) * baseOpacity
            ctx.stroke(
                Path(ellipseIn: CGRect(x: ring.center.x - r,
                                       y: ring.center.y - r,
                                       width: r * 2, height: r * 2)),
                with: .color(ring.color.opacity(alpha)),
                lineWidth: 1.4
            )
        }

        // Comet trail (120-sample buffer; newest at end of array)
        let trail = trailPositions
        let n = trail.count
        if n > 0 {
            for (i, p) in trail.enumerated() {
                let frac = Double(i + 1) / Double(n)
                let dotR: CGFloat = 1.0 + CGFloat(frac) * 3.0
                let alpha = pow(frac, 2.2) * 0.7 * baseOpacity
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR,
                                           width: dotR * 2, height: dotR * 2)),
                    with: .color(color.opacity(alpha))
                )
            }
        }

        // Bindu core (carrier-pulse-scaled)
        let coreR = 10 * carrierPulse
        let coreRect = CGRect(x: bindu.x - coreR, y: bindu.y - coreR,
                              width: coreR * 2, height: coreR * 2)
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

        // White center dot
        let dotR = coreR * 0.32
        ctx.fill(
            Path(ellipseIn: CGRect(x: bindu.x - dotR, y: bindu.y - dotR,
                                   width: dotR * 2, height: dotR * 2)),
            with: .color(.white.opacity(0.85 * baseOpacity))
        )
    }

    // MARK: - Bindu position (multi-harmonic Lissajous)

    private func binduPosition(t: Double, in size: CGSize) -> CGPoint {
        let cx = size.width / 2
        let cy = size.height * 0.38   // upper center (above the cathedral floor's VP)
        let minDim = min(size.width, size.height)
        // Grows with the crescendo modulator — the Bindu opens up at climax.
        let maxR = minDim * 0.12 + CGFloat(performer.crescendoModulator) * minDim * 0.10
        // Frequency tracks the current binaural beat Hz so visual motion
        // is rhythmically tied to the audible beat. 0.88 scale keeps it
        // legible at the upper beat range.
        let freq = max(Double(wire.userBeatHz), 0.5) * 0.88

        let bx = cx + (sin(2 * t * freq + .pi / 2) * 0.88 + sin(3 * t * freq + 0.5) * 0.12) * maxR
        let by = cy + sin(t * freq) * 0.84 * maxR * 0.70
        return CGPoint(x: bx, y: by)
    }

    // MARK: - Trail + ring management

    private func appendTrail(_ p: CGPoint) {
        trailPositions.append(p)
        if trailPositions.count > trailLength {
            trailPositions.removeFirst(trailPositions.count - trailLength)
        }
    }

    /// Beat-pulse-edge ring trigger. Spawns a ring at the head of the
    /// comet when Performer's beatPulse crosses above 0.9, with a 80ms
    /// debounce so two adjacent frames don't double-spawn.
    private func triggerBeatRingIfNeeded(t: Double) {
        let bp = performer.beatPulse
        guard bp > 0.9 else { return }
        guard t - lastBeatPulseTrigger > 0.08 else { return }
        lastBeatPulseTrigger = t
        let center = trailPositions.last ?? .zero
        if center == .zero { return }
        rings.append(Ring(center: center, bornAt: t, color: color))
        if rings.count > 24 {
            rings.removeFirst(rings.count - 24)
        }
    }
}
