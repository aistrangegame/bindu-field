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
    /// Track drives vocabulary routing. The Cathedral is one of nine
    /// vocabularies (Air); every other element renders a different
    /// visual world. See `ElementVocabulary.forTrack`.
    let track: Track

    @State private var wire = DSPWireService.shared
    @State private var performer = Performer.shared
    @State private var settings = SettingsStore.shared

    @State private var trailPositions: [CGPoint] = []
    @State private var rings: [Ring] = []
    @State private var grain: [Grain] = []
    @State private var ashreyTrail: [CGPoint] = []
    @State private var lastTrailSampleAt: Double = 0
    @State private var lastAshreyTrailSampleAt: Double = 0
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
    private let ashreyTrailLength: Int = 40
    private let ashreyTrailInterval: Double = 0.06   // ~17 Hz

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geo in
                let bindu = binduPosition(t: t, in: geo.size)

                Canvas { ctx, size in
                    let mod = performer.crescendoModulator
                    let beat = performer.beatPulse
                    let energy = performer.energy
                    let isSingular = settings.vizMode == "singular"
                    let vocab = ElementVocabulary.forTrack(track)
                    // Vocabulary intensity maps Performer state to a 0–1
                    // band. DSP energy is the floor; crescendo modulator
                    // is the ceiling — at climax the vocabulary peaks.
                    let intensity = min(1.0,
                        Double(energy) * 0.4 + Double(mod) * 0.6)

                    // Singular mode is the intimate mode — only the Bindu
                    // Lissajous dances. The Cathedral (Air), every other
                    // vocabulary (Earth · Water · Fire · Ether · …), and
                    // every ensemble archetype draw is skipped. Background
                    // remains the vocabulary's element-tinted bg (set by
                    // PlayerView at the layer below this view) so the
                    // element still breathes through, just calmly.
                    if !isSingular {
                        if vocab == .air {
                            drawAirCathedral(ctx: ctx, size: size, t: t,
                                             mod: mod, beat: beat,
                                             energy: energy)
                        } else {
                            drawVocabulary(vocab: vocab, ctx: ctx,
                                           size: size, t: t,
                                           intensity: intensity)
                        }
                    }

                    // BINDU — always drawn. Comet trail + RMS bloom + beat
                    // rings + carrier-lock 1.5× pulse. In singular mode,
                    // this is the entire visualizer.
                    drawBindu(ctx: ctx, size: size, t: t,
                              energy: energy, beat: beat, mod: mod,
                              bindu: bindu)
                }
                .onChange(of: t) { _, newT in
                    let isSingular = settings.vizMode == "singular"
                    if newT - lastTrailSampleAt >= trailSampleInterval {
                        lastTrailSampleAt = newT
                        appendTrail(bindu)
                    }
                    // Grain stepping is purely a cathedral concern — skip
                    // entirely in singular mode.
                    if !isSingular,
                       newT - lastGrainStepAt >= grainStepInterval {
                        let dt = newT - lastGrainStepAt
                        lastGrainStepAt = newT
                        stepGrain(dt: dt, t: newT, in: geo.size)
                    }
                    // Sample Ashrey's centroid only when Ashrey is actually
                    // present AND we're in ensemble mode (the centroid
                    // averages positions of archetypes that don't render
                    // in singular).
                    if !isSingular,
                       (performer.archetypePresence[.ashrey] ?? 0) > 0.05,
                       newT - lastAshreyTrailSampleAt >= ashreyTrailInterval {
                        lastAshreyTrailSampleAt = newT
                        let c = ashreyCentroid(t: newT, in: geo.size, bindu: bindu)
                        appendAshreyTrail(c)
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
        // Singular ↔ ensemble transitions can leave stale buffer data
        // for archetypes that the new mode doesn't draw (Ashrey trail,
        // grain particles). Clear them so a return to ensemble doesn't
        // briefly paint yesterday's centroid trail. Beat rings stay —
        // they're a Bindu effect, drawn in both modes.
        .onChange(of: settings.vizMode) { _, _ in
            ashreyTrail.removeAll(keepingCapacity: false)
            grain.removeAll(keepingCapacity: false)
        }
    }

    // MARK: - Cathedral entry point
    //
    // Wraps the existing Tier 1–4 + Ensemble draw calls so the body's
    // routing block stays small. The cathedral's composition is
    // unchanged — it's just hoisted into one method.

    private func drawAirCathedral(ctx: GraphicsContext, size: CGSize,
                                  t: Double, mod: Double, beat: Double,
                                  energy: Double) {
        let gaiaPresence = performer.archetypePresence[.gaia] ?? 0

        // TIER 1 — continuous
        drawCathedralFloor(ctx: ctx, size: size, t: t, mod: mod, beat: beat)
        drawSidColumns(ctx: ctx, size: size, t: t, mod: mod)
        drawVaultCeiling(ctx: ctx, size: size, t: t, energy: energy, mod: mod)
        drawAtmosphericGrain(ctx: ctx, t: t)
        drawGaiaGround(ctx: ctx, size: size, t: t, gaia: gaiaPresence)

        // ENSEMBLE · Karishma — silence sits deep, before the chant.
        let karishmaPresence = performer.archetypePresence[.karishma] ?? 0
        if karishmaPresence > 0.10 {
            drawKarishma(ctx: ctx, size: size, t: t, presence: karishmaPresence)
        }

        // TIER 2 — ensemble (presence-gated)
        let archPresence = performer.archetypePresence[.arch] ?? 0
        if archPresence > 0.1 {
            drawArchChant(ctx: ctx, size: size, t: t, presence: archPresence)
        }
        let sakshiPresence = performer.archetypePresence[.sakshi] ?? 0
        if sakshiPresence > 0.1 {
            drawSakshiGesture(ctx: ctx, size: size, t: t, presence: sakshiPresence)
        }

        // ENSEMBLE · Ashrey — synthesis. Above chant + witness; below crescendo.
        let ashreyPresence = performer.archetypePresence[.ashrey] ?? 0
        if ashreyPresence > 0.05 {
            drawAshrey(ctx: ctx, size: size, t: t, presence: ashreyPresence)
        }

        // TIER 3 — crescendo (modulator > 0)
        if mod > 0 {
            drawRisingArches(ctx: ctx, size: size,
                             elapsed: performer.elapsed, mod: mod)
            drawConvergenceLines(ctx: ctx, size: size, mod: mod)
        }

        // TIER 4 — climax (modulator > 0.25)
        if mod > 0.25 {
            drawKeystoneCascade(ctx: ctx, size: size, t: t, mod: mod, beat: beat)
            drawEarthRising(ctx: ctx, size: size, elapsed: performer.elapsed)
        }
        let shwetaPresence = performer.archetypePresence[.shweta] ?? 0
        if shwetaPresence > 0.01 {
            drawShwetaCrystallization(ctx: ctx, size: size, shweta: shwetaPresence)
        }

        // ENSEMBLE · Neev — bookends only.
        let neevPresence = performer.archetypePresence[.neev] ?? 0
        if neevPresence > 0.10 {
            drawNeev(ctx: ctx, size: size, t: t, presence: neevPresence)
        }
    }

    // MARK: - Vocabulary routing
    //
    // Each non-Air element gets its own draw function from
    // VocabularyRenderer.swift. Ambient and family route to the breathing
    // void with the element's hue.

    private func drawVocabulary(vocab: ElementVocabulary,
                                ctx: GraphicsContext,
                                size: CGSize, t: Double, intensity: Double) {
        switch vocab {
        case .earth:
            drawEarth(in: ctx, size: size, t: t, intens: intensity)
        case .water:
            drawWater(in: ctx, size: size, t: t, intens: intensity)
        case .fire:
            drawFire(in: ctx, size: size, t: t, intens: intensity)
        case .ether:
            drawEther(in: ctx, size: size, t: t, intens: intensity)
        case .constellation:
            drawConstellation(in: ctx, size: size, t: t, intens: intensity)
        case .crown:
            drawCrown(in: ctx, size: size, t: t, intens: intensity)
        case .soul:
            drawSoul(in: ctx, size: size, t: t, intens: intensity)
        case .dissolution:
            drawDissolution(in: ctx, size: size, t: t, intens: intensity)
        case .meditate, .family:
            drawAmbient(in: ctx, size: size, t: t,
                        intens: intensity, hue: vocab.hue)
        case .air:
            // Routed through drawAirCathedral above — should not reach here.
            break
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

    // MARK: - TIER 3 · Rising arches
    //
    // Seven arches reaching from floor-side anchors to the keystone at
    // (W/2, H*0.14). Alternating left/right. Triggered sequentially as
    // `(elapsed - 145) / 15` advances — arch N appears once the progress
    // exceeds N/7. Per-arch opacity, line width, and a faked glow all
    // scale with the crescendo modulator.

    private func drawRisingArches(ctx: GraphicsContext, size: CGSize,
                                  elapsed: Double, mod: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0 else { return }
        let totalProgress = max(0, min(1, (elapsed - 145.0) / 15.0)) * 7.0
        let keystone = CGPoint(x: W / 2, y: H * 0.14)
        let col = Color(hue: elementHueDeg / 360,
                        saturation: 0.55, brightness: 0.78)

        for i in 0..<7 {
            let archProgress = max(0, min(1, totalProgress - Double(i)))
            if archProgress <= 0.001 { continue }

            // Alternate left / right side anchors
            let sideX = (i % 2 == 0) ? W * 0.04 : W * 0.96
            let floorY = H * 0.85
            let start = CGPoint(x: sideX, y: floorY)
            // Control point pulls the curve high and inward — gives an
            // arching shape that springs off the floor toward the apex.
            let control = CGPoint(x: (sideX + keystone.x) / 2, y: H * 0.20)

            var arch = Path()
            arch.move(to: start)
            arch.addQuadCurve(to: keystone, control: control)

            let opacity = archProgress * (0.20 + mod * 0.45)
            let lineWidth = 0.8 + archProgress * mod
            // Faked glow — wider, fainter stroke under the main line. The
            // spec calls for shadowBlur 4 + mod*10 which SwiftUI Canvas
            // doesn't have natively; this two-pass stroke approximates it.
            let glowWidth = lineWidth + (4 + mod * 10) * 0.6
            ctx.stroke(arch, with: .color(col.opacity(opacity * 0.35)),
                       lineWidth: glowWidth)
            ctx.stroke(arch, with: .color(col.opacity(opacity)),
                       lineWidth: lineWidth)
        }
    }

    // MARK: - TIER 3 · Convergence lines
    //
    // Seven hairlines from screen-edge points all converging at the
    // keystone. Drawn with additive blending so they brighten the
    // keystone area at intersection without overwhelming the cathedral.

    private func drawConvergenceLines(ctx: GraphicsContext, size: CGSize,
                                      mod: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0 else { return }
        let keystone = CGPoint(x: W / 2, y: H * 0.14)
        let endpoints: [CGPoint] = [
            CGPoint(x: 0,       y: 0),         // TL
            CGPoint(x: W,       y: 0),         // TR
            CGPoint(x: 0,       y: H),         // BL
            CGPoint(x: W,       y: H),         // BR
            CGPoint(x: W / 2,   y: H),         // bottom center
            CGPoint(x: 0,       y: H / 2),     // mid-left
            CGPoint(x: W,       y: H / 2),     // mid-right
        ]
        let col = Color(hue: elementHueDeg / 360,
                        saturation: 0.55, brightness: 0.88)
        let alpha = mod * 0.04

        var convergence = ctx
        convergence.blendMode = .plusLighter

        for e in endpoints {
            var p = Path()
            p.move(to: e)
            p.addLine(to: keystone)
            convergence.stroke(p,
                               with: .color(col.opacity(alpha)),
                               lineWidth: 0.5)
        }
    }

    // MARK: - TIER 4 · Keystone cascade
    //
    // A bright radial glow at the keystone, sized by the crescendo
    // strength and the beat pulse. Four expanding rings cycle through a
    // 0.42s period, each starting at a different phase so a ring is
    // always somewhere in its expansion. Climax intensity `str` ramps 0
    // → 1 over modulator [0.25, 0.80].

    private func drawKeystoneCascade(ctx: GraphicsContext, size: CGSize,
                                     t: Double, mod: Double, beat: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0 else { return }
        let keystone = CGPoint(x: W / 2, y: H * 0.14)
        let str = min(1.0, max(0.0, (mod - 0.25) / 0.55))

        // Radial glow
        let glowR = W * 0.28 * (0.5 + beat * 0.3) * str
        if glowR > 1 {
            let inner = Color(hue: elementHueDeg / 360, saturation: 0.88, brightness: 0.90)
            let outer = Color(hue: elementHueDeg / 360, saturation: 0.70, brightness: 0.68)
            ctx.fill(
                Path(ellipseIn: CGRect(x: keystone.x - glowR,
                                       y: keystone.y - glowR,
                                       width: glowR * 2,
                                       height: glowR * 2)),
                with: .radialGradient(
                    Gradient(colors: [
                        inner.opacity(0.55 * str),
                        outer.opacity(0.20 * str),
                        outer.opacity(0)
                    ]),
                    center: keystone,
                    startRadius: 0,
                    endRadius: glowR
                )
            )
        }

        // Four expanding rings, cycling with period 0.42s, staggered
        let period = 0.42
        let ringColor = Color(hue: elementHueDeg / 360, saturation: 0.78, brightness: 0.88)
        let maxRingR = W * 0.45
        for i in 0..<4 {
            let phaseOffset = period * Double(i) / 4.0
            let progress = ((t + phaseOffset).truncatingRemainder(dividingBy: period)) / period
            let radius = CGFloat(progress) * maxRingR
            let alpha = (1.0 - progress) * str * 0.45
            if alpha < 0.005 { continue }
            ctx.stroke(
                Path(ellipseIn: CGRect(x: keystone.x - radius,
                                       y: keystone.y - radius,
                                       width: radius * 2,
                                       height: radius * 2)),
                with: .color(ringColor.opacity(alpha)),
                lineWidth: 1
            )
        }
    }

    // MARK: - TIER 4 · Earth rising
    //
    // 5-second Schumann window (elapsed 161–166). A linear gradient rises
    // from the bottom of the canvas in a grounding hue. Alpha forms a
    // bell over the window: easeIn-easeOut, peak alpha 0.25.

    private func drawEarthRising(ctx: GraphicsContext, size: CGSize,
                                 elapsed: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0 else { return }
        guard elapsed >= 161, elapsed <= 166 else { return }

        // Bell curve: 0 → 1 → 0 over [161, 166]
        let progress = (elapsed - 161) / 5.0
        let bell = sin(progress * .pi)
        let alpha = bell * 0.25

        // Hue shifted -15° to land in the terracotta / earth direction.
        let h = (elementHueDeg - 15 + 360).truncatingRemainder(dividingBy: 360) / 360
        let col = Color(hue: h, saturation: 0.60, brightness: 0.55)

        // Linear gradient covering the bottom half
        let topY = H * 0.5
        let rect = CGRect(x: 0, y: topY, width: W, height: H - topY)
        ctx.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [col.opacity(0), col.opacity(alpha)]),
                startPoint: CGPoint(x: W / 2, y: topY),
                endPoint: CGPoint(x: W / 2, y: H)
            )
        )
    }

    // MARK: - TIER 4 · Shweta crystallization
    //
    // The clarity moment. 22 shards radiating from the keystone, alternating
    // long (W*0.20) and short (W*0.12). Even-indexed shards are pure
    // white-ish, odd-indexed shards rotate through a prismatic hue spread.
    // 14 secondary diffraction dashes sit at fractional positions along
    // alternating shards. A bright glowing center caps it.

    private func drawShwetaCrystallization(ctx: GraphicsContext, size: CGSize,
                                           shweta: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0 else { return }
        let keystone = CGPoint(x: W / 2, y: H * 0.14)

        // 22 shards
        for i in 0..<22 {
            let angle = (Double(i) / 22.0) * 2 * .pi
            let longShard = (i % 2 == 0)
            let length = (longShard ? W * 0.20 : W * 0.12) * CGFloat(shweta)
            let end = CGPoint(
                x: keystone.x + CGFloat(cos(angle)) * length,
                y: keystone.y + CGFloat(sin(angle)) * length
            )
            let color: Color
            if longShard {
                color = Color(red: 1.0, green: 0.988, blue: 1.0)
            } else {
                let h = (elementHueDeg + Double(i) * 6).truncatingRemainder(dividingBy: 360) / 360
                color = Color(hue: h, saturation: 0.62, brightness: 0.85)
            }
            var shard = Path()
            shard.move(to: keystone)
            shard.addLine(to: end)
            ctx.stroke(shard,
                       with: .color(color.opacity(0.85 * shweta)),
                       lineWidth: longShard ? 1.2 : 0.8)
        }

        // 14 secondary diffraction dashes — small perpendicular dashes
        // at fractional positions along every-other shard. Adds the
        // "diffraction grating" feel without doubling the shard count.
        let diffractionColor = Color(red: 1.0, green: 0.995, blue: 1.0)
        for i in 0..<14 {
            let shardIndex = (i * 22 / 14) % 22
            let angle = (Double(shardIndex) / 22.0) * 2 * .pi
            let baseLen: CGFloat = (shardIndex % 2 == 0 ? W * 0.20 : W * 0.12) * CGFloat(shweta)
            // Inner and outer positions along the shard
            let positions: [CGFloat] = [0.45, 0.78]
            for posFrac in positions {
                let alongLen = baseLen * posFrac
                let along = CGPoint(
                    x: keystone.x + CGFloat(cos(angle)) * alongLen,
                    y: keystone.y + CGFloat(sin(angle)) * alongLen
                )
                // Perpendicular direction
                let perpAngle = angle + .pi / 2
                let dashLen: CGFloat = 4
                let dashA = CGPoint(
                    x: along.x + CGFloat(cos(perpAngle)) * dashLen,
                    y: along.y + CGFloat(sin(perpAngle)) * dashLen
                )
                let dashB = CGPoint(
                    x: along.x - CGFloat(cos(perpAngle)) * dashLen,
                    y: along.y - CGFloat(sin(perpAngle)) * dashLen
                )
                var dash = Path()
                dash.move(to: dashA)
                dash.addLine(to: dashB)
                ctx.stroke(dash,
                           with: .color(diffractionColor.opacity(0.55 * shweta)),
                           lineWidth: 0.5)
            }
        }

        // Glowing center — simulates the spec's shadowBlur 22 with a wide
        // radial gradient halo + a tight bright core.
        let haloR = CGFloat(28) * CGFloat(shweta)
        ctx.fill(
            Path(ellipseIn: CGRect(x: keystone.x - haloR,
                                   y: keystone.y - haloR,
                                   width: haloR * 2, height: haloR * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.white.opacity(0.85 * shweta),
                    Color.white.opacity(0)
                ]),
                center: keystone,
                startRadius: 0,
                endRadius: haloR
            )
        )
        let coreR = CGFloat(4) * CGFloat(shweta)
        ctx.fill(
            Path(ellipseIn: CGRect(x: keystone.x - coreR,
                                   y: keystone.y - coreR,
                                   width: coreR * 2, height: coreR * 2)),
            with: .color(Color(red: 1, green: 1, blue: 1).opacity(0.97 * shweta))
        )
    }

    // MARK: - ENSEMBLE · Karishma (the silence)
    //
    // Paradox radial — light surrounds darkness. A dark center "swallows"
    // the cathedral grain and grid around the upper-middle of the canvas
    // while a faint element-color rim marks the boundary. Three concentric
    // depth rings recede inward, drawing the eye into the void.
    //
    // Performer's `karishma` presence is highest inside score silence
    // windows (0.85) and elsewhere ramps with inverse energy ((1−rms)×0.5).
    // So the dark void deepens precisely when the music drops out.

    private func drawKarishma(ctx: GraphicsContext, size: CGSize,
                              t: Double, presence: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0 else { return }
        let center = CGPoint(x: W / 2, y: H * 0.45)
        // The void radius grows with presence — silence is visually heavier.
        let voidR = (W * 0.18 + W * 0.10 * CGFloat(presence))

        // Dark center — radial gradient from a near-black center fading to
        // transparent. The "subtractive" feel against the dim cathedral.
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - voidR, y: center.y - voidR,
                                   width: voidR * 2, height: voidR * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    Color.black.opacity(0.45 * presence),
                    Color.black.opacity(0.18 * presence),
                    Color.black.opacity(0)
                ]),
                center: center,
                startRadius: 0,
                endRadius: voidR
            )
        )

        // Paradox rim — a faint element-color ring at the void's edge.
        // Light marks where the darkness ends, which is the gesture.
        let rimColor = Color(hue: elementHueDeg / 360,
                             saturation: 0.50, brightness: 0.70)
        let rimR = voidR * 0.92
        ctx.stroke(
            Path(ellipseIn: CGRect(x: center.x - rimR, y: center.y - rimR,
                                   width: rimR * 2, height: rimR * 2)),
            with: .color(rimColor.opacity(0.16 * presence)),
            lineWidth: 0.8
        )

        // Depth rings — three concentric hairlines spiraling inward. Their
        // radii breathe slowly so the void doesn't feel static.
        let breath = sin(t * 0.18) * 0.5 + 0.5
        for i in 1...3 {
            let frac = CGFloat(i) / 4.0 + CGFloat(breath) * 0.04
            let r = voidR * frac
            ctx.stroke(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                       width: r * 2, height: r * 2)),
                with: .color(rimColor.opacity(0.07 * presence)),
                lineWidth: 0.5
            )
        }
    }

    // MARK: - ENSEMBLE · Ashrey (the synthesis)
    //
    // Lives at the *centroid* of the other positioned archetypes. As Bindu
    // moves along its Lissajous and the witness's tip rotates, Ashrey
    // wanders with them — synthesis follows the field. A multi-hue trail
    // behind the head cycles through the spectrum, marking the path
    // through all the other archetypes.

    /// Computes the running centroid of six positioned archetypes for the
    /// current frame. Bindu's current Lissajous head + both Sid columns'
    /// midpoints + Arch's breathing apex + Sakshi's leading-edge tip +
    /// Karishma's void center.
    private func ashreyCentroid(t: Double, in size: CGSize, bindu: CGPoint) -> CGPoint {
        let W = size.width, H = size.height
        let leftSid  = CGPoint(x: W * 0.18, y: H * 0.32)
        let rightSid = CGPoint(x: W * 0.82, y: H * 0.32)
        let archYShift = sin(t * 0.35) * 8
        let archApex = CGPoint(x: W * 0.50, y: H * 0.17 + CGFloat(archYShift))
        // Sakshi tip: rotation phase matches drawSakshiGesture exactly.
        let sakshiPhase = (t * 0.15).truncatingRemainder(dividingBy: 1.0)
        let sakshiTipAngle = sakshiPhase * 2 * .pi + 0.72 * 2 * .pi
        let sakshiCenter = CGPoint(x: W * 0.88, y: H * 0.42)
        let sakshiRadius = W * 0.05
        let sakshiTip = CGPoint(
            x: sakshiCenter.x + sakshiRadius * CGFloat(cos(sakshiTipAngle)),
            y: sakshiCenter.y + sakshiRadius * CGFloat(sin(sakshiTipAngle))
        )
        let karishmaCenter = CGPoint(x: W * 0.50, y: H * 0.45)

        let points: [CGPoint] = [bindu, leftSid, rightSid, archApex, sakshiTip, karishmaCenter]
        var sx: CGFloat = 0, sy: CGFloat = 0
        for p in points { sx += p.x; sy += p.y }
        let n = CGFloat(points.count)
        return CGPoint(x: sx / n, y: sy / n)
    }

    private func appendAshreyTrail(_ p: CGPoint) {
        ashreyTrail.append(p)
        if ashreyTrail.count > ashreyTrailLength {
            ashreyTrail.removeFirst(ashreyTrail.count - ashreyTrailLength)
        }
    }

    private func drawAshrey(ctx: GraphicsContext, size: CGSize,
                            t: Double, presence: Double) {
        guard !ashreyTrail.isEmpty else { return }

        // Multi-hue trail. Each dot's hue advances around the wheel by
        // its position in the buffer; oldest = far behind, newest = head.
        // Slow hue rotation with `t` so the spectrum rolls through over
        // time instead of being phase-locked to the buffer's content.
        let baseHueOffset = t * 18.0  // degrees per second
        let n = ashreyTrail.count
        for (i, p) in ashreyTrail.enumerated() {
            let frac = Double(i + 1) / Double(n)
            let hueDeg = (baseHueOffset + frac * 240).truncatingRemainder(dividingBy: 360)
            let alpha = pow(frac, 1.8) * 0.55 * presence
            let r: CGFloat = 1.2 + CGFloat(frac) * 2.4
            let color = Color(hue: hueDeg / 360, saturation: 0.55, brightness: 0.92)
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r,
                                       width: r * 2, height: r * 2)),
                with: .color(color.opacity(alpha))
            )
        }

        // Head — a small bright dot at the current centroid, with a soft
        // halo so the synthesis feels like a held point, not a streak.
        let head = ashreyTrail.last!
        let haloR: CGFloat = 8
        let haloHue = baseHueOffset.truncatingRemainder(dividingBy: 360) / 360
        let halo = Color(hue: haloHue, saturation: 0.50, brightness: 0.95)
        ctx.fill(
            Path(ellipseIn: CGRect(x: head.x - haloR, y: head.y - haloR,
                                   width: haloR * 2, height: haloR * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    halo.opacity(0.40 * presence),
                    halo.opacity(0)
                ]),
                center: head,
                startRadius: 0,
                endRadius: haloR
            )
        )
        let coreR: CGFloat = 2.5
        ctx.fill(
            Path(ellipseIn: CGRect(x: head.x - coreR, y: head.y - coreR,
                                   width: coreR * 2, height: coreR * 2)),
            with: .color(halo.opacity(0.85 * presence))
        )
    }

    // MARK: - ENSEMBLE · Neev (the foundation)
    //
    // Bookends only — Performer presence is 0.8 for the first 4s and the
    // last 2s of a scored session, and 0 otherwise. Five rings cycle
    // continuously through a contract-and-descend lifecycle: each ring
    // starts large near the upper cathedral and shrinks as it falls
    // toward the floor. Hue is shifted -10° from the element to land
    // in the grounding terracotta direction.

    private func drawNeev(ctx: GraphicsContext, size: CGSize,
                          t: Double, presence: Double) {
        let W = size.width, H = size.height
        guard W > 0, H > 0 else { return }
        // Ring lifecycle period in seconds. 2s per ring with 5 staggered
        // copies means a ring is always in transit.
        let period = 2.0
        let h = (elementHueDeg - 10 + 360).truncatingRemainder(dividingBy: 360) / 360
        let col = Color(hue: h, saturation: 0.45, brightness: 0.70)

        let yStart = H * 0.18
        let yEnd = H * 0.85
        let startR = CGFloat(min(W, H)) * 0.40
        let endR: CGFloat = 8

        for i in 0..<5 {
            let phaseOffset = period * Double(i) / 5.0
            let phase = ((t + phaseOffset).truncatingRemainder(dividingBy: period)) / period
            let centerY = yStart + (yEnd - yStart) * CGFloat(phase)
            // Quadratic contraction — slower at first, faster near floor.
            let contractCurve = pow(phase, 0.85)
            let radius = startR * (1.0 - CGFloat(contractCurve)) + endR * CGFloat(contractCurve)
            // Alpha fades as the ring lands.
            let alpha = (1.0 - phase) * 0.55 * presence
            if alpha < 0.005 { continue }

            ctx.stroke(
                Path(ellipseIn: CGRect(x: W / 2 - radius,
                                       y: centerY - radius,
                                       width: radius * 2,
                                       height: radius * 2)),
                with: .color(col.opacity(alpha)),
                lineWidth: 0.8
            )
        }
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
