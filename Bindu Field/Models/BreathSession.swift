import Foundation

/// One of the 11 breath sessions (Airtable Track ID 101–111, Track Type
/// = "breath"). The Airtable spine holds song/verb/state/carrier/beat/seed
/// and the Reading-space prose. The breath-specific protocol metadata
/// (intention, inhale/hold/exhale, safety, special cue) is also stored
/// in Airtable as of the 2026-05-22 migration — `BreathProtocolMetadata.all`
/// remains as a code-level seed/fallback that fills in any missing field.
///
/// See `joined()` for the merged surface used by views: Airtable values
/// win; the hardcoded fallback only fills gaps.
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

    // Protocol metadata pulled from Airtable (migration 2026-05-22).
    // Optional everywhere; the merge in `joined()` falls back to the
    // hardcoded `BreathProtocolMetadata.all` seed table when a field is
    // missing. Cached `binduBreathSessions.v1` from before the migration
    // decodes with all of these nil — same end result as a fresh
    // Airtable fetch where the column is empty.
    let inhaleSec: Int?
    let holdSec: Int?
    let exhaleSec: Int?
    let intentionKey: String?         // Airtable "Intention"   — singleSelect raw name
    let safetyKey: String?            // Airtable "Safety"      — singleSelect raw name
    let specialCueKey: String?        // Airtable "Special Cue" — singleSelect raw name

    enum CodingKeys: String, CodingKey {
        case id, name, verb, stateKey, carrierHz, beatHz, seed
        case recognitionStatement, lyricalWordsReading, frequencyReading
        case lalitasPerspective, phaseLabels
        case inhaleSec, holdSec, exhaleSec
        case intentionKey, safetyKey, specialCueKey
    }

    init(
        id: Int,
        name: String,
        verb: String,
        stateKey: String,
        carrierHz: Float,
        beatHz: Float,
        seed: String,
        recognitionStatement: String?,
        lyricalWordsReading: String,
        frequencyReading: String,
        lalitasPerspective: String?,
        phaseLabels: String?,
        inhaleSec: Int? = nil,
        holdSec: Int? = nil,
        exhaleSec: Int? = nil,
        intentionKey: String? = nil,
        safetyKey: String? = nil,
        specialCueKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.verb = verb
        self.stateKey = stateKey
        self.carrierHz = carrierHz
        self.beatHz = beatHz
        self.seed = seed
        self.recognitionStatement = recognitionStatement
        self.lyricalWordsReading = lyricalWordsReading
        self.frequencyReading = frequencyReading
        self.lalitasPerspective = lalitasPerspective
        self.phaseLabels = phaseLabels
        self.inhaleSec = inhaleSec
        self.holdSec = holdSec
        self.exhaleSec = exhaleSec
        self.intentionKey = intentionKey
        self.safetyKey = safetyKey
        self.specialCueKey = specialCueKey
    }

    /// Backwards-compatible decoder. The six migration fields use
    /// `decodeIfPresent` so a cached `binduBreathSessions.v1` written
    /// before the migration still decodes (all six come through nil and
    /// the merge falls back to the hardcoded table).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        verb = try c.decode(String.self, forKey: .verb)
        stateKey = try c.decode(String.self, forKey: .stateKey)
        carrierHz = try c.decode(Float.self, forKey: .carrierHz)
        beatHz = try c.decode(Float.self, forKey: .beatHz)
        seed = try c.decode(String.self, forKey: .seed)
        recognitionStatement = try c.decodeIfPresent(String.self, forKey: .recognitionStatement)
        lyricalWordsReading = try c.decodeIfPresent(String.self, forKey: .lyricalWordsReading) ?? ""
        frequencyReading = try c.decodeIfPresent(String.self, forKey: .frequencyReading) ?? ""
        lalitasPerspective = try c.decodeIfPresent(String.self, forKey: .lalitasPerspective)
        phaseLabels = try c.decodeIfPresent(String.self, forKey: .phaseLabels)
        inhaleSec = try c.decodeIfPresent(Int.self, forKey: .inhaleSec)
        holdSec = try c.decodeIfPresent(Int.self, forKey: .holdSec)
        exhaleSec = try c.decodeIfPresent(Int.self, forKey: .exhaleSec)
        intentionKey = try c.decodeIfPresent(String.self, forKey: .intentionKey)
        safetyKey = try c.decodeIfPresent(String.self, forKey: .safetyKey)
        specialCueKey = try c.decodeIfPresent(String.self, forKey: .specialCueKey)
    }
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
///
/// Raw values match the Airtable "Special Cue" singleSelect option names
/// exactly, so `BreathSpecialCue(rawValue:)` decodes Airtable strings
/// directly. Unknown / unrecognized strings return nil (graceful: the
/// view renders no cue without crashing).
enum BreathSpecialCue: String, Codable, Hashable {
    case hum          = "hum"            // 103 The Hum — humming on exhale
    case ocean        = "ocean"          // 110 The Ocean Breath — ujjayi throat on exhale
    case doublePulse  = "double_pulse"   // 111 The Night Protocol — inhale · pause · inhale
    case activePhase  = "active_phase"   // 105 The Stoke — faster active-phase breath

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
    ///
    /// The hardcoded `all` table is the SEED / FALLBACK as of the
    /// 2026-05-22 migration — it still contains the canonical values
    /// because the merge in `BreathSession.joined()` reads from it when
    /// Airtable is missing a field. Do not delete.
    static func `for`(id: Int) -> BreathProtocolMetadata {
        all[id] ?? BreathProtocolMetadata(
            id: id, intention: .balance, hue: 210,
            inhale: 5, hold: 0, exhale: 5, safety: .open,
            special: nil,
            oneLine: "An equal breath. The simplest container.",
            carrierTiers: [.tradition], beatTiers: [.science]
        )
    }

    /// Code-level backstop: these IDs are always routed through the
    /// screened gate, regardless of what Airtable says. Defense in
    /// depth — a bad Airtable edit (an accidental "open" on session 105,
    /// for instance) cannot un-gate a session the code knows is intense.
    ///
    /// Today only 105 (The Stoke) lives here. Any future screened
    /// session should add its ID here as soon as it ships, before its
    /// Airtable row exists.
    static let knownScreenedIDs: Set<Int> = [105]

    /// Merge Airtable-provided values onto a code-level fallback.
    ///
    /// Field-by-field rules:
    /// - inhale/hold/exhale: Airtable wins when present; else fallback.
    ///   Note `0` is a valid value (e.g. Hold Sec = 0 for sessions with
    ///   no held breath) — the `Int?` decode preserves it.
    /// - intention: Airtable's string decodes via `BreathIntention(rawValue:)`.
    ///   Unknown / empty → fallback intention.
    /// - special: if Airtable has a non-empty value, trust it
    ///   (unknown → no cue, never crash). Only an EMPTY/nil Airtable
    ///   value falls through to the hardcoded special.
    /// - safety: FAIL CLOSED. Only an explicit Airtable `"open"` →
    ///   `.open`. Empty / nil / `"screened"` / unknown → `.screened`.
    ///   `knownScreenedIDs` is an additional backstop that overrides
    ///   any `"open"` for code-flagged intense sessions.
    /// - hue, oneLine, carrierTiers, beatTiers: not migrated; come from
    ///   the fallback table. Hue carries occasional intentional
    ///   divergence from `intention.hue` (e.g. 109/111 use a different
    ///   hue than their intention) so it cannot just be derived.
    static func merge(airtable s: BreathSession) -> BreathProtocolMetadata {
        let fallback = BreathProtocolMetadata.for(id: s.id)

        let intention: BreathIntention = {
            if let key = s.intentionKey?.trimmingCharacters(in: .whitespaces),
               !key.isEmpty,
               let parsed = BreathIntention(rawValue: key) {
                return parsed
            }
            return fallback.intention
        }()

        let special: BreathSpecialCue? = {
            // Empty / nil → fallback. Non-empty → trust Airtable (unknown
            // value decodes to nil; that's the intended "no cue" outcome,
            // not a fallback trigger — see the prompt).
            guard let raw = s.specialCueKey?.trimmingCharacters(in: .whitespaces),
                  !raw.isEmpty
            else { return fallback.special }
            return BreathSpecialCue(rawValue: raw)
        }()

        return BreathProtocolMetadata(
            id: s.id,
            intention: intention,
            hue: fallback.hue,
            inhale: s.inhaleSec ?? fallback.inhale,
            hold:   s.holdSec   ?? fallback.hold,
            exhale: s.exhaleSec ?? fallback.exhale,
            safety: resolveSafety(airtableKey: s.safetyKey, id: s.id),
            special: special,
            oneLine: fallback.oneLine,
            carrierTiers: fallback.carrierTiers,
            beatTiers: fallback.beatTiers
        )
    }

    /// Fail-closed safety resolver.
    ///
    /// Returns `.open` only when:
    ///   1. The id is NOT in `knownScreenedIDs`, AND
    ///   2. Airtable's Safety value is exactly `"open"`.
    ///
    /// Everything else (nil / empty / `"screened"` / unknown string) →
    /// `.screened`, so the contraindication gate shows by default.
    static func resolveSafety(airtableKey: String?, id: Int) -> BreathSafety {
        if knownScreenedIDs.contains(id) { return .screened }
        let trimmed = airtableKey?.trimmingCharacters(in: .whitespaces)
        if trimmed == "open" { return .open }
        return .screened
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
    /// Join Airtable data with in-app protocol metadata. Airtable values
    /// win; the hardcoded `BreathProtocolMetadata.all` table is the
    /// fallback only. Safety always fails closed (see
    /// `BreathProtocolMetadata.resolveSafety`).
    func joined() -> JoinedBreathSession {
        JoinedBreathSession(session: self, metadata: .merge(airtable: self))
    }
}
