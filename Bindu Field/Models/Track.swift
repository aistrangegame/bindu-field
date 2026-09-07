import Foundation

enum BrainwaveState: String, Codable {
    case delta, theta, alpha
    case thetaAlpha = "theta-alpha"
}

enum ChakraName: String, Codable {
    case muladhara = "Muladhara"
    case svadhisthana = "Svadhisthana"
    case manipura = "Manipura"
    case anahata = "Anahata"
    case vishuddha = "Vishuddha"
    case ajna = "Ajna"
    case sahasrara = "Sahasrara"
    case aatma = "Aatma"
    case maya = "Maya"
}

enum TrackType: String, Codable {
    case chakra, music, meditate, family
}

struct Track: Codable, Hashable {
    let id: Int
    let verb: String
    let song: String
    let artist: String
    let element: String
    let state: BrainwaveState

    /// G15: optional chakra association. Retained as metadata for a future
    /// chakra-grouped Field filter / overlay; not consumed today. Airtable
    /// continues to be authoritative for `carrierHz` / `beatHz`.
    let chakra: ChakraName?

    let type: TrackType
    let audioURL: String

    /// G8: optional YouTube video ID. Intentionally retained for a future
    /// "watch on YouTube" affordance in `PlayerView`. Not surfaced today.
    let youtubeID: String?

    let seed: String
    let carrierHz: Double
    let beatHz: Double

    /// One-line statement of what this track IS, passed to the Oracle so
    /// it has knowledge beyond verb/element/state. `nil` when the
    /// Airtable column has not been populated (or in older on-disk
    /// caches that pre-date the field — the custom decoder below uses
    /// `decodeIfPresent`). The Oracle treats `nil` and empty as the same
    /// and skips the catalog suffix in either case.
    let recognitionStatement: String?

    /// Long-form prose for the Player's READING sheet · WORDS tab.
    /// Empty string when not yet written for a track.
    let lyricalWordsReading: String

    /// Long-form prose for the Player's READING sheet · FREQUENCY tab.
    /// Empty string when not yet written for a track.
    let frequencyReading: String

    /// Long-form prose for the Player's READING sheet · VIDEO tab.
    /// Empty string when not yet written for a track.
    let videoPulseReading: String

    /// Lalita's perspective on the song — surfaced in the Player's READING
    /// sheet · LALITA tab. `nil` when not yet written.
    let lalitasPerspective: String?

    /// Per-track mirror words flashed during the Consciousness Loop's Dance
    /// step. Authored in Airtable (`Mirror Words` column, comma/newline
    /// separated), parsed to `[String]` by `AirtableService`. Empty when not
    /// authored — the Loop then falls back to the Track-27 hardcoded set or
    /// its universal default. See `ConsciousnessLoopCoordinator`.
    let mirrorWords: [String]

    /// Per-track phase labels — the composed arc of the song, authored in
    /// Airtable (`Phase Labels` column) in the web-player object-array
    /// format `[{t, name, sub}, …]`. Surfaced in the Player READING sheet's
    /// PHASES tab via `SongPhaseParser`. `nil` when not authored (older
    /// caches, or tracks whose arc hasn't been composed). Breath sessions
    /// carry the same column but in a paragraph format decoded separately.
    let phaseLabels: String?

    /// The Airtable record id ("rec…") for this catalog row, when known.
    /// Set at fetch time by `AirtableService`; persisted in the cache.
    /// Enables linked-record writes back to the catalog (App Activity →
    /// Link to Field). `nil` for older caches that pre-date this field.
    let recordID: String?

    /// Explicit `CodingKeys` so the custom decoder below can resolve them
    /// from outside the primary declaration. Synthesized keys are private
    /// and not accessible from extensions.
    enum CodingKeys: String, CodingKey {
        case id, verb, song, artist, element, state, chakra, type
        case audioURL, youtubeID, seed, carrierHz, beatHz
        case recognitionStatement
        case lyricalWordsReading, frequencyReading, videoPulseReading
        case lalitasPerspective
        case mirrorWords
        case phaseLabels
        case recordID
    }
}

extension Track {
    /// Backwards-compatible decoder. The three Reading Space fields are
    /// non-optional `String` for consumer ergonomics but default to `""`
    /// when missing from an older `binduCatalog.v1` cache that pre-dates
    /// the Lalita pass. Without this, decoding an old cache would fail
    /// and `CatalogStore.loadFromCache` would silently drop the catalog
    /// until the next Airtable refresh.
    ///
    /// Declared in an extension so the synthesized memberwise initializer
    /// is preserved for `AirtableService` to call directly.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        verb = try c.decode(String.self, forKey: .verb)
        song = try c.decode(String.self, forKey: .song)
        artist = try c.decode(String.self, forKey: .artist)
        element = try c.decode(String.self, forKey: .element)
        state = try c.decode(BrainwaveState.self, forKey: .state)
        chakra = try c.decodeIfPresent(ChakraName.self, forKey: .chakra)
        type = try c.decode(TrackType.self, forKey: .type)
        audioURL = try c.decode(String.self, forKey: .audioURL)
        youtubeID = try c.decodeIfPresent(String.self, forKey: .youtubeID)
        seed = try c.decode(String.self, forKey: .seed)
        carrierHz = try c.decode(Double.self, forKey: .carrierHz)
        beatHz = try c.decode(Double.self, forKey: .beatHz)
        recognitionStatement = try c.decodeIfPresent(String.self, forKey: .recognitionStatement)
        lyricalWordsReading = try c.decodeIfPresent(String.self, forKey: .lyricalWordsReading) ?? ""
        frequencyReading = try c.decodeIfPresent(String.self, forKey: .frequencyReading) ?? ""
        videoPulseReading = try c.decodeIfPresent(String.self, forKey: .videoPulseReading) ?? ""
        lalitasPerspective = try c.decodeIfPresent(String.self, forKey: .lalitasPerspective)
        // Defaults to `[]` for older `binduCatalog.v1` caches that pre-date
        // the mirror-words field, mirroring the reading-field pattern above.
        mirrorWords = try c.decodeIfPresent([String].self, forKey: .mirrorWords) ?? []
        phaseLabels = try c.decodeIfPresent(String.self, forKey: .phaseLabels)
        recordID = try c.decodeIfPresent(String.self, forKey: .recordID)
    }
}
