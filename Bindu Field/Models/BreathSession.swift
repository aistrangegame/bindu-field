import Foundation

/// One of the 11 breath sessions (Airtable Track ID 101–111, Track Type
/// = "breath"). The Airtable spine holds song/verb/state/carrier/beat/seed
/// and the Reading-space prose. The breath-specific protocol metadata
/// (intention, inhale/hold/exhale, safety, special cue, honesty tiers) is
/// not in Airtable today — it lives in `BreathProtocolMetadata` keyed by
/// `id`. See `joined(with:)` for the joined surface used by views.
struct BreathSession: Codable, Hashable, Identifiable {
    let id: Int
    let name: String                  // Airtable "Song Title" — e.g. "Come Home"
    let verb: String                  // Airtable "Verb"        — e.g. "ground"
    let stateKey: String              // Airtable "Brainwave State" — e.g. "delta"
    let carrierHz: Float
    let beatHz: Float
    let seed: String                  // Airtable "Seed Phrase"
    let recognitionStatement: String? // Airtable "Recognition Statement"
    let lyricalWordsReading: String   // Airtable "Lyrical Words Reading"
    let frequencyReading: String      // Airtable "Frequency Reading"
    let lalitasPerspective: String?   // Airtable "Lalita's Perspective"
    let phaseLabels: String?          // Airtable "Phase Labels" — used by the Reading Space PHASES tab
}

/// Eight high-level intentions that group the 11 breath sessions into a
/// 2×4 front-door grid. `cohere` is folded into `balance` so 109 lands
/// somewhere meaningful without expanding the grid past eight tiles.
enum BreathIntention: String, CaseIterable, Codable, Hashable {
    case ground, activate, open, clarify, dissolve, expand, rest, balance

    var word: String { rawValue }

    /// One-line invitation rendered under the word.
    var phrase: String {
        switch self {
        case .ground:   return "come home to the body"
        case .activate: return "move and clear the field"
        case .open:     return "receive what is already here"
        case .clarify:  return "see without the filter"
        case .dissolve: return "let what is held release"
        case .expand:   return "breathe past the edge of known"
        case .rest:     return "give the system a long exhale"
        case .balance:  return "the even breath · the still point"
        }
    }

    /// Tile hue (degrees). Mirrors the design's `INTENTIONS` array. Two
    /// intentions share a hue (ground/rest both 15°) by design — they
    /// share the warm-earth family.
    var hue: Double {
        switch self {
        case .ground:   return 15
        case .activate: return 35
        case .open:     return 195
        case .clarify:  return 210
        case .dissolve: return 260
        case .expand:   return 50
        case .rest:     return 15
        case .balance:  return 140
        }
    }

    /// The Track IDs that this intention holds.
    ///
    /// Two multi-session intentions today:
    /// - `.open`  → 103 (The Hum) · 110 (The Ocean Breath)
    /// - `.rest`  → 106 (The Long Release) · 111 (The Night Protocol)
    /// - `.balance` → 102 (The Even Breath) · 109 (Home Frequency)
    ///   (Design omitted 109; we add it here because Airtable confirms it
    ///   exists and "Home Frequency" sits naturally with "balance · the
    ///   still point". Verified in Airtable on 2026-05-22.)
    var sessionIDs: [Int] {
        switch self {
        case .ground:   return [101]
        case .activate: return [105]
        case .open:     return [103, 110]
        case .clarify:  return [104]
        case .dissolve: return [107]
        case .expand:   return [108]
        case .rest:     return [106, 111]
        case .balance:  return [102, 109]
        }
    }
}

/// Safety tier for a breath session. Sessions tagged `.screened` route
/// through `ScreenedGateView` (the warm contraindication check) before
/// the immersed view.
enum BreathSafety: String, Codable, Hashable {
    case open, screened
}

/// Optional special breath cue layered over the immersed circle. The
/// circle's mechanics don't change — a small italic-serif line surfaces
/// on the relevant phase.
enum BreathSpecialCue: String, Codable, Hashable {
    case hum            // 103 The Hum — humming on exhale
    case ocean          // 110 The Ocean Breath — ujjayi throat on exhale
    case doublePulse    // 111 The Night Protocol — inhale · pause · inhale
    case activePhase    // 105 The Stoke — faster active-phase breath

    var cueLabel: String {
        switch self {
        case .hum:         return "on the exhale — a quiet hum, lips closed, continuous"
        case .ocean:       return "on the exhale — constrict the back of the throat gently"
        case .doublePulse: return "inhale · brief pause · inhale again — a double-pulse"
        case .activePhase: return "fast active inhale · short exhale — let it move"
        }
    }

    /// Single-syllable phase label that takes over the breath circle's
    /// phase word during the relevant phase ("mmm" on exhale for `hum`,
    /// "haaa" for `ocean`, etc.). nil → use the default phase word.
    func phaseLabel(for phase: BreathPhase) -> String? {
        switch (self, phase) {
        case (.hum, .exhale):   return "mmm"
        case (.ocean, .exhale): return "haaa"
        default:                return nil
        }
    }
}

/// Used by both the chakra and breath flows so SpaceImmersedView can
/// surface the right phase word.
enum BreathPhase: Equatable {
    case inhale, hold, exhale
    var defaultLabel: String {
        switch self {
        case .inhale: return "inhale"
        case .hold:   return "hold"
        case .exhale: return "exhale"
        }
    }
}

/// The breath-specific protocol metadata that doesn't yet live in
/// Airtable — intention assignment, breath rhythm, safety tier, special
/// cue, and honesty tiers on the carrier/beat lines. Joined to a
/// `BreathSession` by Track ID via `BreathProtocolMetadata.for(id:)`.
struct BreathProtocolMetadata: Codable, Hashable {
    let id: Int
    let intention: BreathIntention
    let hue: Double                  // Display hue per session (often matches intention.hue)
    let inhale: Int
    let hold: Int
    let exhale: Int
    let safety: BreathSafety
    let special: BreathSpecialCue?
    let oneLine: String              // Brief description shown in detail + sub-selection
    let carrierTiers: [HonestyTier]
    let beatTiers: [HonestyTier]

    /// Lookup keyed by Track ID. Falls back to a permissive default when
    /// an unknown ID is requested (lets a future Airtable-only session
    /// still surface in the app without a crash).
    static func `for`(id: Int) -> BreathProtocolMetadata {
        all[id] ?? BreathProtocolMetadata(
            id: id, intention: .balance, hue: 210,
            inhale: 5, hold: 0, exhale: 5, safety: .open,
            special: nil,
            oneLine: "An equal breath. The simplest container.",
            carrierTiers: [.tradition], beatTiers: [.science]
        )
    }

    static let all: [Int: BreathProtocolMetadata] = [
        101: BreathProtocolMetadata(
            id: 101, intention: .ground, hue: 15,
            inhale: 4, hold: 4, exhale: 8, safety: .open,
            special: nil,
            oneLine: "The most basic return. Breath to ground, ground to body, body to the field.",
            carrierTiers: [.tradition], beatTiers: [.science]
        ),
        102: BreathProtocolMetadata(
            id: 102, intention: .balance, hue: 140,
            inhale: 5, hold: 0, exhale: 5, safety: .open,
            special: nil,
            oneLine: "Equal inhale, equal exhale. The breath as a demonstration of center.",
            carrierTiers: [.tradition], beatTiers: [.science]
        ),
        103: BreathProtocolMetadata(
            id: 103, intention: .open, hue: 195,
            inhale: 4, hold: 2, exhale: 6, safety: .open,
            special: .hum,
            oneLine: "Inhale through the nose. On the exhale, a quiet hum — lips closed, throat open, sound continuous.",
            carrierTiers: [.tradition], beatTiers: [.science]
        ),
        104: BreathProtocolMetadata(
            id: 104, intention: .clarify, hue: 210,
            inhale: 4, hold: 0, exhale: 8, safety: .open,
            special: nil,
            oneLine: "Extended exhale activates the parasympathetic. The counting is the anchor.",
            carrierTiers: [.tradition], beatTiers: [.science]
        ),
        105: BreathProtocolMetadata(
            id: 105, intention: .activate, hue: 35,
            inhale: 6, hold: 0, exhale: 2, safety: .screened,
            special: .activePhase,
            oneLine: "Fast inhale, brief exhale. Builds charge — physical and energetic. A screened practice.",
            carrierTiers: [.tradition], beatTiers: [.science]
        ),
        106: BreathProtocolMetadata(
            id: 106, intention: .rest, hue: 15,
            inhale: 4, hold: 2, exhale: 12, safety: .open,
            special: nil,
            oneLine: "A very long exhale trains the nervous system toward rest. Nothing to do.",
            carrierTiers: [.tradition], beatTiers: [.science]
        ),
        107: BreathProtocolMetadata(
            id: 107, intention: .dissolve, hue: 260,
            inhale: 4, hold: 6, exhale: 8, safety: .open,
            special: nil,
            oneLine: "The pause after exhale is the dissolution point. Rest in the empty between.",
            carrierTiers: [.tradition], beatTiers: [.science, .tradition]
        ),
        108: BreathProtocolMetadata(
            id: 108, intention: .expand, hue: 50,
            inhale: 5, hold: 5, exhale: 5, safety: .open,
            special: nil,
            oneLine: "A slow, deliberate breath that softens the boundary between self and field.",
            carrierTiers: [.tradition, .claim], beatTiers: [.science]
        ),
        // Session 109 (Home Frequency) — confirmed in Airtable 2026-05-22.
        // Equal 5-5 breath like 102 but the carrier sits at 136.1 (OM /
        // Earth-year tone) where 102 also lives at 136.1; 109 reads
        // "the breath that needs no adjustment" — coherence rather than
        // demonstration.
        109: BreathProtocolMetadata(
            id: 109, intention: .balance, hue: 195,
            inhale: 5, hold: 0, exhale: 5, safety: .open,
            special: nil,
            oneLine: "The home frequency. Breath that needs no adjustment — only attention.",
            carrierTiers: [.tradition], beatTiers: [.science]
        ),
        110: BreathProtocolMetadata(
            id: 110, intention: .open, hue: 195,
            inhale: 4, hold: 0, exhale: 6, safety: .open,
            special: .ocean,
            oneLine: "Ujjayi — constrict the back of the throat on the exhale. The sound is the practice.",
            carrierTiers: [.tradition], beatTiers: [.science]
        ),
        111: BreathProtocolMetadata(
            id: 111, intention: .rest, hue: 260,
            inhale: 4, hold: 0, exhale: 8, safety: .open,
            special: .doublePulse,
            oneLine: "Designed for the threshold between waking and sleep. Do not resist the dissolve.",
            carrierTiers: [.tradition], beatTiers: [.science]
        ),
    ]
}

/// Joined surface used by the views — combines what Airtable gives us
/// (`BreathSession`) with the in-app protocol metadata
/// (`BreathProtocolMetadata`). Provides everything the IntentionGrid,
/// SessionDetail, immersed circle, and Reading Space need without each
/// view having to perform the join.
struct JoinedBreathSession: Identifiable, Hashable {
    let session: BreathSession
    let metadata: BreathProtocolMetadata

    var id: Int { session.id }
    var name: String { session.name }
    var verb: String { session.verb }
    var seed: String { session.seed }
    var recognitionStatement: String? { session.recognitionStatement }
    var carrierHz: Float { session.carrierHz }
    var beatHz: Float { session.beatHz }
    var stateInfo: BrainwaveStateInfo { .forLabel(session.stateKey) }
    var hue: Double { metadata.hue }
    var inhale: Int { metadata.inhale }
    var hold: Int { metadata.hold }
    var exhale: Int { metadata.exhale }
    var safety: BreathSafety { metadata.safety }
    var special: BreathSpecialCue? { metadata.special }
    var intention: BreathIntention { metadata.intention }
    var oneLine: String { metadata.oneLine }
    var carrierTiers: [HonestyTier] { metadata.carrierTiers }
    var beatTiers: [HonestyTier] { metadata.beatTiers }
    var lyricalWordsReading: String { session.lyricalWordsReading }
    var frequencyReading: String { session.frequencyReading }
    var lalitasPerspective: String? { session.lalitasPerspective }
    var phaseLabels: String? { session.phaseLabels }
}

extension BreathSession {
    /// Join Airtable data with in-app protocol metadata.
    func joined() -> JoinedBreathSession {
        JoinedBreathSession(session: self, metadata: .for(id: id))
    }
}
