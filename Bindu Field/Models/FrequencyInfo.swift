import Foundation

/// Pure-data lookup used by the Lab to give frequencies meaning.
/// No observable state, no side effects.
enum FrequencyInfo {

    struct BrainwaveInfo {
        let range: String
        let essence: String
        let detail: String
    }

    /// Lookup keyed by the same string labels the Lab already renders
    /// (delta / theta / theta-alpha / alpha / beta / gamma). `beta` and
    /// `gamma` are not cases in `BrainwaveState` but are produced by the
    /// Lab's `stateLabel` above 14 Hz.
    static func brainwaveInfo(forLabel label: String) -> BrainwaveInfo? {
        switch label {
        case "delta":
            return BrainwaveInfo(
                range: "0.5–4 Hz",
                essence: "Deep dreamless sleep. Cellular restoration.",
                detail: "The deepest oscillation the brain makes. Profound rest, healing, and states beyond ordinary awareness. In Bindu Field, delta carries the heaviest songs — the ones that touch the root."
            )
        case "theta":
            return BrainwaveInfo(
                range: "4–8 Hz",
                essence: "The threshold. REM dreaming. Deep meditation.",
                detail: "The border between waking and sleep. Where inner knowing speaks and creative breakthroughs arise without effort. The largest territory in Bindu Field."
            )
        case "theta-alpha":
            return BrainwaveInfo(
                range: "8–10 Hz",
                essence: "The bridge. Relaxed alert. Light trance.",
                detail: "The integration zone. Calm enough to receive, awake enough to remember. Where insight becomes usable."
            )
        case "alpha":
            return BrainwaveInfo(
                range: "8–13 Hz",
                essence: "Calm presence. Here without effort.",
                detail: "Relaxed wakefulness. The natural resting state of a mind not under threat. Light flows here — clarity without striving."
            )
        case "beta":
            return BrainwaveInfo(
                range: "13–30 Hz",
                essence: "Active thinking. Focused attention.",
                detail: "Normal waking consciousness. The Lab enters this territory above 13 Hz."
            )
        case "gamma":
            return BrainwaveInfo(
                range: "30+ Hz",
                essence: "Peak perception. Heightened coherence.",
                detail: "Brief, intense. Associated with moments of heightened clarity and insight."
            )
        default:
            return nil
        }
    }

    /// Note for a notable carrier value. Match window ±0.5 Hz. Returns
    /// nil when the slider is not near a recognised value, so the UI
    /// can hide the dot.
    static func carrierNote(for hz: Float) -> String? {
        let known: [(value: Float, note: String)] = [
            (136.1, "OM frequency. Earth's natural resonance. Most universal carrier."),
            (174.0, "Foundation frequency. Grounding at the low register."),
            (285.0, "Tissue and field restoration association."),
            (396.0, "Solfeggio: Liberation. Releasing what no longer serves."),
            (417.0, "Solfeggio: Facilitating change. Clearing stagnant patterns."),
            (432.0, "Alternative concert pitch. Warmer resonance than 440 Hz."),
            (528.0, "Solfeggio: Transformation. Love frequency."),
            (639.0, "Solfeggio: Connection. Harmonizing relationships."),
        ]
        for entry in known where abs(hz - entry.value) <= 0.5 {
            return entry.note
        }
        return nil
    }
}
