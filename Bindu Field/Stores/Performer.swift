import Foundation
import Observation

// MARK: - Score types

/// Named phases of a Cross-dance score. A track without a `Score` runs in
/// ambient mode and leaves `currentPhase` at `.silence`.
enum ScorePhase: String, Hashable {
    case silence, intro, build, peak, descent, outro
}

/// The ten archetypes whose presence the renderer can read. Phase 5
/// (Cathedral) reads `bindu / sid / arch / sakshi / shweta / neev`. Phase 6
/// (Ensemble) adds `gaia / karishma / ashrey`. Phase 7 (Lalita engine)
/// will read `lalita`.
enum ArchetypeName: String, Hashable, CaseIterable {
    case bindu, gaia, sid, arch, karishma, sakshi, ashrey, shweta, neev, lalita
}

/// Pre-authored score for a specific track. Drives `Performer`'s phase
/// tracking, silence windows, and crescendo modulator. The score never
/// describes *what to render* — it describes *what is happening in the
/// music* so the renderer can respond.
struct Score {
    let trackID: Int
    let totalDuration: Double

    struct PhaseWindow {
        let phase: ScorePhase
        let start: Double
        let end: Double
    }

    struct SilenceWindow {
        let start: Double
        let end: Double
    }

    struct BeatEvent {
        let time: Double
    }

    let phases: [PhaseWindow]
    let silenceWindows: [SilenceWindow]
    /// Authored beat times. Empty for `.cross` — the Performer derives
    /// beats from `DSPWireService.onsetCount` instead.
    let beatSchedule: [BeatEvent]

    // The Zimmer move — modulator ramps in at `modulatorRampIn`, holds at
    // `modulatorBoost` between `modulatorHoldStart`..`modulatorHoldEnd`,
    // ramps out by `modulatorRampOut`. Outside that window, 0.
    let modulatorRampIn: Double
    let modulatorHoldStart: Double
    let modulatorHoldEnd: Double
    let modulatorRampOut: Double
    let modulatorBoost: Double

    // MARK: Hardcoded scores

    /// Track 27 — Sound of Silence (Disturbed) · Vishuddha. The first
    /// score to ship. Phase breakdown follows the handoff spec (silence /
    /// intro / build / peak / descent / outro); modulator timings match
    /// the bindu-performance-engine.js reference.
    static let cross: Score = Score(
        trackID: 27,
        totalDuration: 268,
        phases: [
            PhaseWindow(phase: .silence, start: 0,   end: 8),
            PhaseWindow(phase: .intro,   start: 8,   end: 68),
            PhaseWindow(phase: .build,   start: 68,  end: 145),
            PhaseWindow(phase: .peak,    start: 145, end: 200),
            PhaseWindow(phase: .descent, start: 200, end: 248),
            PhaseWindow(phase: .outro,   start: 248, end: 268),
        ],
        silenceWindows: [
            SilenceWindow(start: 0,  end: 8),
            SilenceWindow(start: 42, end: 50),
        ],
        beatSchedule: [],
        modulatorRampIn:   145,
        modulatorHoldStart: 160,
        modulatorHoldEnd:   180,
        modulatorRampOut:   195,
        modulatorBoost:     0.8
    )

    /// Lookup table. Add a `case` per scored track. Returns `nil` for
    /// tracks with no authored score — `Performer` runs ambient.
    static func forTrack(id: Int) -> Score? {
        switch id {
        case 27: return .cross
        default: return nil
        }
    }
}

// MARK: - Performer

/// Reads the song's time signature and exposes the consciousness
/// architecture underneath as @Observable state. Phase 5+ renderers read
/// from here; Phase 7's LalitaEngine will read from here too.
///
/// Lifecycle is driven by `PlayerStore.play` (start) and `PlayerStore.stop`
/// (stop). When a tracked song has no authored `Score`, the Performer ticks
/// in *ambient mode* — `currentPhase` stays `.silence`, the crescendo
/// modulator stays `0`, and archetype presence runs the ambient formulas.
@MainActor
@Observable
final class Performer {
    static let shared = Performer()
    private init() {}

    // MARK: Observable state

    private(set) var isActive: Bool = false
    private(set) var elapsed: Double = 0
    private(set) var currentPhase: ScorePhase = .silence
    private(set) var timeIntoPhase: Double = 0

    /// 0...modulatorBoost. The Zimmer move: ramps in at the build / peak
    /// boundary, holds for the awakening window, ramps out at descent.
    private(set) var crescendoModulator: Double = 0

    /// `true` while `elapsed` is inside one of the score's silence windows.
    private(set) var inSilence: Bool = false

    /// Mirrors `DSPWireService.rms` as a Double so the rest of Performer
    /// (and downstream renderers) can do arithmetic without re-casting.
    private(set) var energy: Double = 0

    /// Sharp attack, slow decay per audio onset. 1.0 at the moment of an
    /// onset edge, decaying at ~6/sec.
    private(set) var beatPulse: Double = 0

    private(set) var onsetCount: Int = 0

    /// Per-archetype presence values, each 0–1. Seeded with sane idle
    /// defaults so first-frame reads from a renderer aren't all-zero.
    private(set) var archetypePresence: [ArchetypeName: Double] = ambientDefaults

    private static let ambientDefaults: [ArchetypeName: Double] = [
        .bindu: 1.0,
        .gaia:    0.4,
        .sid:     0.5,
        .arch:    0,
        .karishma: 0,
        .sakshi:  0.6,
        .ashrey:  0,
        .shweta:  0,
        .neev:    0,
        .lalita:  0,
    ]

    // MARK: Private state

    private(set) var score: Score? = nil

    private var lastOnsetCount: Int = 0
    private var lastTickAt: TimeInterval = 0
    private var updateTimer: Timer?

    // MARK: Lifecycle

    /// Begin ticking. Pass a `Score` for scored tracks; pass `nil` for
    /// ambient mode (Player open on a track without an authored score).
    func start(score: Score?) {
        self.score = score
        elapsed = 0
        currentPhase = .silence
        timeIntoPhase = 0
        crescendoModulator = 0
        inSilence = false
        beatPulse = 0
        lastOnsetCount = DSPWireService.shared.onsetCount
        archetypePresence = Self.ambientDefaults
        isActive = true
        lastTickAt = Date().timeIntervalSinceReferenceDate
        startUpdateLoop()
    }

    /// Stop ticking, clear score, drop active flag. Idempotent — calling
    /// twice in a row is safe.
    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil
        score = nil
        isActive = false
        elapsed = 0
        currentPhase = .silence
        timeIntoPhase = 0
        crescendoModulator = 0
        inSilence = false
        beatPulse = 0
        // Reset archetype presence so a fresh start renders the same way
        // as the very first start did.
        archetypePresence = Self.ambientDefaults
    }

    private func startUpdateLoop() {
        updateTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        // .common keeps the score advancing during scroll tracking, same
        // run-loop-mode trick DSPWireService uses (B11).
        RunLoop.main.add(timer, forMode: .common)
        updateTimer = timer
    }

    private func tick() {
        let now = Date().timeIntervalSinceReferenceDate
        let dt = max(0.001, now - lastTickAt)
        lastTickAt = now
        update(elapsed: TrackPlaybackService.shared.elapsed,
               dsw: DSPWireService.shared,
               dt: dt)
    }

    // MARK: Main update

    /// Drive all observable state from current audio + score time. Public
    /// so an external driver (test harness, alternative renderer) can run
    /// the Performer without the built-in 60Hz Timer.
    func update(elapsed: Double, dsw: DSPWireService, dt: Double = 1.0 / 60.0) {
        self.elapsed = elapsed
        self.energy = Double(dsw.rms)
        self.onsetCount = dsw.onsetCount

        // Beat pulse — spike on a new onset edge, decay at ~6/sec
        if dsw.onsetCount != lastOnsetCount {
            beatPulse = 1.0
            lastOnsetCount = dsw.onsetCount
        } else {
            beatPulse = max(0, beatPulse - dt * 6.0)
        }

        guard let score else {
            // Ambient mode — no phase tracking, no modulator, no silence
            crescendoModulator = 0
            inSilence = false
            currentPhase = .silence
            timeIntoPhase = 0
            updateAmbientArchetypePresence()
            return
        }

        // Phase tracking
        if let p = score.phases.first(where: { elapsed >= $0.start && elapsed < $0.end }) {
            currentPhase = p.phase
            timeIntoPhase = elapsed - p.start
        } else if elapsed >= score.totalDuration {
            // Past the final phase end — clamp to outro
            if let outro = score.phases.first(where: { $0.phase == .outro }) {
                currentPhase = outro.phase
                timeIntoPhase = elapsed - outro.start
            }
        }

        // Silence windows
        inSilence = score.silenceWindows.contains {
            elapsed >= $0.start && elapsed < $0.end
        }

        // Crescendo modulator (the Zimmer move)
        crescendoModulator = computeModulator(at: elapsed, in: score)

        // Awakening-peak binaural depth — beat Hz deepens with the
        // modulator's crescendo. Only applies when the user hasn't
        // manually overridden BEAT this session.
        updateBinauralDepth()

        // Archetype presence
        updateScoredArchetypePresence(elapsed: elapsed, score: score)
    }

    // MARK: Crescendo modulator

    private func computeModulator(at t: Double, in s: Score) -> Double {
        if t < s.modulatorRampIn { return 0 }
        if t < s.modulatorHoldStart {
            return ((t - s.modulatorRampIn) / (s.modulatorHoldStart - s.modulatorRampIn)) * s.modulatorBoost
        }
        if t < s.modulatorHoldEnd { return s.modulatorBoost }
        if t < s.modulatorRampOut {
            return s.modulatorBoost * (1 - (t - s.modulatorHoldEnd) / (s.modulatorRampOut - s.modulatorHoldEnd))
        }
        return 0
    }

    // MARK: Awakening-peak binaural integration
    //
    // The principle: the deepest binaural state belongs at the awakening
    // peak, not the shadow plateau. As the crescendo modulator rises, the
    // running beat Hz drops toward the deepest state for the track's
    // element. Hands off entirely if the user has dragged the Player
    // CONTROL BEAT slider this session (`hasBeatOverride`).
    private func updateBinauralDepth() {
        let dsw = DSPWireService.shared
        guard !dsw.hasBeatOverride else { return }
        let depth = crescendoModulator
        let base = dsw.currentTrackBeatHz
        // 1.0 → base, modulatorBoost (0.8) → base × (1 - 0.8 × 0.55) = base × 0.56
        // i.e. ~44% reduction at full crescendo — theta drops toward delta.
        let target = base * (1.0 - Float(depth) * 0.55)
        BinauralEngine.shared.updateBeat(target)
    }

    // MARK: Archetype presence

    /// Formulas for a scored track — phase- and modulator-aware.
    private func updateScoredArchetypePresence(elapsed t: Double, score s: Score) {
        var p: [ArchetypeName: Double] = [:]

        // Bindu — always lead, always 1.0
        p[.bindu] = 1.0

        // Gaia — ground. Enters gradually after t = 2s, full by t = 6s.
        let gaiaEntry = 2.0
        p[.gaia] = min(1, max(0, (t - gaiaEntry) / 4.0))

        // Sid — column. Always present, pulses on a 5.5s drone cycle.
        let phase = (t.truncatingRemainder(dividingBy: 5.5)) / 5.5
        let dronePulse = (cos(phase * .pi * 2) + 1) / 2
        p[.sid] = 0.5 + dronePulse * 0.5

        // Arch — chant. Builds with the music's RMS energy.
        p[.arch] = min(1, max(0, energy * 1.5))

        // Karishma — silence. Strongest inside score silence windows.
        // Outside silence, follows inverse energy (loud → quiet Karishma).
        p[.karishma] = inSilence ? 0.85 : max(0, 1 - energy) * 0.5

        // Sakshi — witness. Always at periphery, steady.
        p[.sakshi] = 0.6

        // Ashrey — synthesis. Grows with the crescendo modulator.
        p[.ashrey] = crescendoModulator * 0.9

        // Shweta — crystal. Fires only inside the peak window (160..162),
        // with a half-second attack + half-second release ramp.
        if t >= 160 && t <= 162 {
            let attack = min(1, (t - 160) / 0.5)
            let release = min(1, (162 - t) / 0.5)
            p[.shweta] = attack * release
        } else {
            p[.shweta] = 0
        }

        // Neev — foundation. Bookends only: first 4s, last 2s.
        p[.neev] = (t < 4 || t > s.totalDuration - 2) ? 0.8 : 0

        // Lalita — late arrival. Past t > 204, ramps in over 3s.
        p[.lalita] = min(1, max(0, (t - 204) / 3.0))

        archetypePresence = p
    }

    /// Formulas for ambient mode (no score loaded). Same shapes, but with
    /// score-dependent terms muted — no crescendo, no scheduled events.
    private func updateAmbientArchetypePresence() {
        var p: [ArchetypeName: Double] = [:]

        p[.bindu] = 1.0
        p[.gaia]  = 0.4
        // Drone pulse still cycles in ambient mode — keeps Sid alive.
        let phase = (elapsed.truncatingRemainder(dividingBy: 5.5)) / 5.5
        let dronePulse = (cos(phase * .pi * 2) + 1) / 2
        p[.sid]   = 0.5 + dronePulse * 0.5
        p[.arch]  = min(1, max(0, energy * 1.5))
        p[.karishma] = max(0, 1 - energy) * 0.5
        p[.sakshi] = 0.6
        p[.ashrey] = 0
        p[.shweta] = 0
        p[.neev]   = 0
        p[.lalita] = 0

        archetypePresence = p
    }
}
