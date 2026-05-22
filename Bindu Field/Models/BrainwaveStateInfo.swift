import SwiftUI

/// Brainwave-band info (label, range, hue, essence, detail, tiers).
/// Lab + Akash both surface this. Lookup keys are lowercase strings so
/// Airtable's "delta / theta / alpha / beta / gamma / theta-alpha" values
/// flow through unchanged.
struct BrainwaveStateInfo: Hashable {
    let key: String
    let label: String
    let range: String
    let hue: Double
    let essence: String
    let detail: String
    let tiers: [HonestyTier]
    let tierNotes: [HonestyTier: String]

    /// Render color at the canonical saturation/brightness used across the
    /// Lab and Akash screens.
    var color: Color {
        Color(hue: hue / 360, saturation: 0.55, brightness: 0.68)
    }

    /// Map a beat frequency (Hz) to its band info. Boundaries 4/8/13/30
    /// match the design's 5-band scheme.
    static func forBeat(_ hz: Float) -> BrainwaveStateInfo {
        switch hz {
        case ..<4:  return delta
        case ..<8:  return theta
        case ..<13: return alpha
        case ..<30: return beta
        default:    return gamma
        }
    }

    /// Look up by lowercase label. Falls back to alpha if unrecognized.
    /// `theta-alpha` collapses to theta for visual purposes.
    static func forLabel(_ label: String) -> BrainwaveStateInfo {
        switch label.lowercased() {
        case "delta": return delta
        case "theta", "theta-alpha": return theta
        case "alpha": return alpha
        case "beta":  return beta
        case "gamma": return gamma
        default:      return alpha
        }
    }

    // MARK: - Canonical bands

    static let delta = BrainwaveStateInfo(
        key: "delta",
        label: "DELTA",
        range: "0.5 – 4 Hz",
        hue: 15,
        essence: "deep root · healing · integration",
        detail: "The deepest ground state. The nervous system releases. The body repairs. The field reorganizes below ordinary awareness. Heavy, slow, immersive.",
        tiers: [.science, .tradition],
        tierNotes: [
            .science: "Delta-band EEG in slow-wave sleep is one of the most replicated findings in neuroscience.",
            .tradition: "\"Healing\" and \"integration\" are contemplative framings — the physiology is real, the meaning is traditional.",
        ]
    )

    static let theta = BrainwaveStateInfo(
        key: "theta",
        label: "THETA",
        range: "4 – 8 Hz",
        hue: 260,
        essence: "dream · creation · threshold",
        detail: "The border between waking and sleep. Images arrive without effort. Creativity flows from a place that does not know it is creating. Where inner knowing speaks.",
        tiers: [.science, .tradition],
        tierNotes: [
            .science: "Theta in REM sleep and deep meditation states has strong EEG support.",
            .tradition: "The \"threshold between worlds\" framing is a contemplative tradition, not a clinical description.",
        ]
    )

    static let alpha = BrainwaveStateInfo(
        key: "alpha",
        label: "ALPHA",
        range: "8 – 13 Hz",
        hue: 210,
        essence: "open · aware · present",
        detail: "Relaxed wakefulness. The witness is active but not grasping. You are here, and here is enough. The nervous system in its natural resting frequency.",
        tiers: [.science],
        tierNotes: [
            .science: "Alpha in relaxed, eyes-closed wakefulness is one of the strongest and most consistent findings in EEG research.",
        ]
    )

    static let beta = BrainwaveStateInfo(
        key: "beta",
        label: "BETA",
        range: "13 – 30 Hz",
        hue: 165,
        essence: "focus · processing · active",
        detail: "Active cognition. The analytical mind is engaged. Useful for focused work, intentional creation, clear thinking. The everyday field of attention.",
        tiers: [.science],
        tierNotes: [
            .science: "Beta during active cognitive tasks is well-documented in EEG literature.",
        ]
    )

    static let gamma = BrainwaveStateInfo(
        key: "gamma",
        label: "GAMMA",
        range: "30 + Hz",
        hue: 50,
        essence: "peak binding · insight · coherence",
        detail: "Brief, intense. Moments of heightened clarity. Some advanced practitioners can sustain this state. Associated with the binding of perception across brain regions.",
        tiers: [.science, .claim],
        tierNotes: [
            .science: "Gamma oscillations in perceptual binding have EEG support, though the mechanisms are still debated.",
            .claim: "\"Peak insight\" and heightened coherence claims go beyond what the current literature can confirm.",
        ]
    )
}

/// Sacred carrier-frequency reference — used by the Lab's tuning cluster
/// (slider markers + meaning panel), by the Akash session-detail screen's
/// carrier tier hints, and by anywhere else the app needs to say "this
/// carrier is OM / Solfeggio / standard concert pitch".
struct SacredCarrier: Hashable {
    let hz: Float
    let name: String
    let note: String
    let tiers: [HonestyTier]
    let essence: String
    let detail: String

    static let all: [SacredCarrier] = [
        SacredCarrier(
            hz: 136.1, name: "OM", note: "C#3",
            tiers: [.tradition],
            essence: "Earth-year tone · cosmic OM",
            detail: "Hans Cousto calculated the Earth's orbital period as 136.1 Hz. The OM association is a yogic tradition, not a measured physiological claim."
        ),
        SacredCarrier(
            hz: 174.0, name: "174", note: "F3",
            tiers: [.tradition, .claim],
            essence: "Solfeggio root · foundation",
            detail: "Part of the Solfeggio frequency system. Foundation and grounding associations are modern interpretations; the historical Solfeggio is a medieval musical tradition."
        ),
        SacredCarrier(
            hz: 285.0, name: "285", note: "D4",
            tiers: [.tradition, .claim],
            essence: "Solfeggio · field coherence",
            detail: "Solfeggio association; field coherence claims are contemporary and not empirically established."
        ),
        SacredCarrier(
            hz: 396.0, name: "UT", note: "G4",
            tiers: [.tradition, .claim],
            essence: "Solfeggio · liberation",
            detail: "The Ut (Do) of the historical Solfeggio scale. Liberation and fear-release are modern re-interpretations."
        ),
        SacredCarrier(
            hz: 417.0, name: "RE", note: "G#4",
            tiers: [.tradition, .claim],
            essence: "Solfeggio · facilitating change",
            detail: "Re of the Solfeggio. Change-facilitation claims are a modern, unverified extension of the tradition."
        ),
        SacredCarrier(
            hz: 432.0, name: "432", note: "A4♭",
            tiers: [.tradition, .claim],
            essence: "alternative concert pitch · natural resonance",
            detail: "Some musicians and instrument-makers prefer A=432 Hz. The \"more natural\" and \"harmonic with nature\" claims are widely circulated but contested — there is no strong empirical resolution to the 440 vs 432 debate."
        ),
        SacredCarrier(
            hz: 440.0, name: "440", note: "A4",
            tiers: [.science],
            essence: "ISO standard concert pitch",
            detail: "The ISO 16 standard (1975). Well-established. No special physiological claims attach to this frequency itself."
        ),
    ]

    /// Find the sacred carrier within `threshold` Hz of `hz`. Returns the
    /// closest entry if any; otherwise nil. The Lab uses 1.8 Hz; the inline
    /// badge uses 1.2 Hz for a tighter "lock".
    static func nearest(_ hz: Float, threshold: Float = 1.8) -> SacredCarrier? {
        let candidates = all.filter { abs($0.hz - hz) <= threshold }
        return candidates.min { abs($0.hz - hz) < abs($1.hz - hz) }
    }
}
