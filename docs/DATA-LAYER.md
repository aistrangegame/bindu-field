# Data layer

Track catalogue, chakra catalogues, frequency presets, frequency knowledge, scored tracks, persistence details. Breath sessions are documented separately in `BREATH-SESSIONS.md`.

## Track catalogue — Airtable spine

- **Source**: `https://api.airtable.com/v0/app248ZTWhYJlvQj2/tblv3WvMZ90Sfhun6` (PAT in `Secrets.swift`).
- `AirtableService` does paginated GETs (`pageSize=100`, follows `offset` until exhausted). Decoding hops to a detached task so JSON parsing doesn't pin main.
- **Fields** (Airtable column → `Track` property): `Track ID` → `id: Int`, `Verb` → `verb`, `Song Title` → `song`, `Artist` → `artist`, `Track Type` → `type` (chakra/music/meditate/family), `Element` → `element` (Earth/Water/Fire/Air/Light/Crown/Soul/Dissolution/Meditate/Family), `Brainwave State` → `state` (delta/theta/theta-alpha/alpha), `Chakra` → `chakra?`, `Audio URL` → `audioURL`, `YouTube ID` → `youtubeID?`, `Carrier Hz` → `carrierHz: Double`, `Beat Hz` → `beatHz: Double`, `Seed Phrase` → `seed`, `Recognition Statement` → `recognitionStatement: String?`, `Lyrical Words Reading` → `lyricalWordsReading: String`, `Frequency Reading` → `frequencyReading: String`, `Video Pulse Reading` → `videoPulseReading: String`, `Lalita's Perspective` → `lalitasPerspective: String?` (Reading-space fields — surfaced by the Player's READING sheet tabs). Plus `Mirror Words` → `mirrorWords: [String]` (comma/newline-separated in Airtable, parsed by `AirtableService`; consumed by the Consciousness Loop's Dance step with precedence over Score/default) and the Airtable record id → `recordID: String?` (captured at fetch time; enables the App Activity `Link to Field` back-reference). **Content state (2026-08-29 audit):** 25 of 34 records carry full Recognition / Lyrical / Frequency / Lalita prose; the 9 seed-only music tracks are empty; `videoPulseReading` is empty for all 34.
- `CatalogStore` caches the array as JSON under `binduCatalog.v1`, with a `binduCatalog.v1.lastRefreshedAt` timestamp. Refresh policy: skip network if cache <1 hour old; force-refresh available from Settings; never overwrite cache with an empty-array response (B13). Decode failures swallow silently. `Track` carries a custom `init(from:)` in an extension that defaults the three non-optional Reading-space String fields to `""`, so old `binduCatalog.v1` caches written before the Lalita pass continue to decode without dropping the catalog.
- 22 loadable music/chakra/meditate/family tracks today (34 records total in the table: 22 tracks + 11 breath sessions + 1 orphaned no-Track-ID record, `recYqGHG4sYRJDOSP` "Levels + Beautiful Now", which has reading prose but no `id`/`element`/`seed` so the decoder drops it).
- **Airtable write-back (as of `e30c913`):** `AirtableService.logAppActivity(...)` POSTs to a shared **App Activity** table (linked to this table via `Link to Field`) on Consciousness-Loop seal, authenticated with the embedded `Secrets.airtableToken`. It is the only write path from the client today. `tblv3WvMZ90Sfhun6` now carries two `multipleRecordLinks` columns to the App Activity table (`tblJlBeiHnqGpYrL7`).

## Chakra catalogue — two layers, both hardcoded

Two distinct data structures, separated by purpose:

- **`ChakraProtocol`** (`Models/ChakraProtocol.swift`) — the **dance protocols**. Nine chakras (root → maya) with `inhale/hold/exhale` (seconds), `beat`, `carrier`, `hue`, `essence`, and 5 `affirmations` each. Drives Ritual, the Player's READING sheet (Breath row), and the Map detail sheet's metadata. Ordering for grid display lives in `SpaceSetupView` as `chakraOrder`. (AKASH no longer renders the chakra grid — it routes through Airtable-backed breath sessions instead; the chakra protocols still drive `RitualRunningView`'s chained chakra sessions.)
- **`ChakraRegistry`** (`Models/ChakraRegistry.swift`) — the **Map nodes**. All 33 nodes across four systems (Energy 7 / Body 10 / Mind 9 / Tree 7), with `canvasX/Y` in a 393×780 design canvas, hue (degrees), tier (1–4, controls locked-node render radius), and Sanskrit Devanagari. `composedIDs` is the 9-element set that overlaps with `ChakraProtocol` — those are the nodes that have a dance authored today. The `connections` list is the directed graph of edges between nodes (drawn on the Map as element-tinted quadratic curves).

## Frequency presets

`FrequencyPreset` is Codable with `isSystem: Bool`. Five system presets (Earth Tone 7.83 Hz, Deep Delta 1.5 Hz, Theta Gate 5.5 Hz, Creative 7.0 Hz on 174 Hz carrier, Presence 10 Hz on 432 Hz carrier) ship in code. `PresetStore` persists user-saved presets under `binduPresets.v1`. System presets cannot be deleted.

## Frequency knowledge

`FrequencyInfo` is a pure-data enum (no observable state). `brainwaveInfo(forLabel:)` returns range + essence + detail for `delta / theta / theta-alpha / alpha / beta / gamma`. `carrierNote(for:)` matches ±0.5 Hz against eight notable carriers (136.1 OM, 174.0, 285, 396/417/528/639 Solfeggio, 432 alt concert pitch). The Lab has its own `SacredFreq` table (a slightly different 7-entry palette: OM, 174, 285, UT/396, RE/417, 432, 440) used for the inline sacred badge and the sacred frequency map strip.

## Scored tracks

`Score` (`Stores/Performer.swift`) is the pre-authored time signature of a Cross-style dance. Each Score has phase windows (`silence/intro/build/peak/descent/outro`), silence windows, a crescendo-modulator envelope (rampIn → hold → rampOut), and now a `mirrorWords: [String]?` field consumed by the Consciousness Loop's Dance step. Today Track 27 (Sound of Silence) is the only authored Score — `Score.cross` — with `mirrorWords = ["pn", "open", "breathe", "opn", "clear", "release", "pn", "open"]`. Every other track runs `Performer` in ambient mode. Note: since `b9c2918` the Loop's Dance step prefers per-track `Track.mirrorWords` (from the Airtable `Mirror Words` column) over `Score.mirrorWords`, so a track can have authored mirror words without a full Score.

## Persistence (full table)

| What | Where | Key / Path |
|---|---|---|
| Sessions | UserDefaults | `binduSessions.v1` (JSON) |
| Letters (metadata) | UserDefaults | `binduLetters.v1` (JSON) |
| Letters (audio) | Documents | `Documents/Letters/<UUID>.m4a` |
| User frequency presets | UserDefaults | `binduPresets.v1` (JSON) |
| Track catalogue cache | UserDefaults | `binduCatalog.v1` + `binduCatalog.v1.lastRefreshedAt` |
| Track audio cache | Caches | `Caches/BinduTracks/track-{id}.mp3` — 200 MB LRU cap, evicts to 75% on overflow |
| Breath sessions cache | UserDefaults | `binduBreathSessions.v1` + `binduBreathSessions.v1.lastRefreshedAt` (JSON `[BreathSession]`) — backwards-compatible decoder reads pre-migration caches with the 6 protocol fields as nil |
| Chakra journey (Map dance log) | UserDefaults | `binduJourney.v1` (JSON Array<String> of chakra IDs marked danced) |
| Gain / default duration / viz mode | UserDefaults | `binduSettings.gain`, `binduSettings.defaultDuration`, `binduSettings.vizMode` (`"ensemble"` default · `"singular"` toggle) |
| Theme mode | UserDefaults | `binduSettings.themeMode` (`"system"` default · `"light"` · `"dark"`) — consumed by `RootView` to inject `\.binduTheme` + set `preferredColorScheme` |
| First-launch flags | UserDefaults | `binduFirstLaunch.seen`, `binduFirstLaunch.tipSeen`, `binduFirstLaunch.oracleHintSeen` |
| Claude API key | Keychain | service `com.bindufield.apikeys` · account `claude_api_key` · `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| Airtable PAT | Code | `Secrets.swift` (gitignored; template at `Secrets.swift.template`) |

`UserDefaultsCodable<T: Codable>` is a tiny helper used by `SessionStore`, `LetterStore`, `PresetStore`, and `ChakraJourneyStore` to deduplicate the encode-write / read-decode dance.
