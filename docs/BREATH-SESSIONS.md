# Breath sessions — Airtable + seed-fallback join

The 11 AKASH breath sessions (IDs 101–111, Airtable Track Type = `breath`) follow a different shape than the music catalog. The Airtable spine carries the user-visible content (song/verb/state/carrier/beat/seed/recognition/readings) and as of the 2026-05-22 migration the protocol metadata (breath rhythm, intention, safety, special cue). `BreathProtocolMetadata.all` is kept in-source as the **seed/fallback** table so missing Airtable fields don't crash the app — and so the four fields below that haven't been migrated yet still have a home.

- **Source**: same Airtable base/table as music tracks (`app248ZTWhYJlvQj2/tblv3WvMZ90Sfhun6`).
- **Fetch path**: `AirtableService.fetchBreathSessions()` walks the same paginated endpoint as `fetchTracks()` but uses a leaner decoder (`AirtableBreathFields`) — breath records carry no Artist / Element / Audio URL / YouTube ID and would be rejected by the music-track decoder's missing-field guards.
- **Store**: `BreathSessionStore.shared` is the @MainActor @Observable singleton; same shape as `CatalogStore` (load-from-cache on init, on-demand refresh with a 1-hour freshness window, `binduBreathSessions.v1` JSON in UserDefaults, `isStaleFromCache` for the offline banner).

## Airtable schema (the 11 base columns + the 6 migration columns)

| Column | Airtable type | Decoded as | Source-of-truth | Notes |
|---|---|---|---|---|
| Track ID | number | `Int` | Airtable | 101–111 today |
| Song Title | singleLineText | `name` | Airtable | e.g. "Come Home" |
| Verb | singleLineText | `verb` | Airtable | the action word, used by the immersed view's lock-screen title |
| Track Type | singleSelect | `trackType` filter | Airtable | `breath` qualifies for `fetchBreathSessions()` |
| Brainwave State | singleSelect | `stateKey` | Airtable | matches `BrainwaveStateInfo.forLabel` ("delta"/"theta"/"alpha"/"beta"/"gamma"/"theta-alpha") |
| Carrier Hz | number | `Float` | Airtable | feeds `BinauralEngine.setCarrier` |
| Beat Hz | number | `Float` | Airtable | feeds `BinauralEngine.updateBeat` |
| Seed Phrase | multilineText | `seed` | Airtable | shown bottom-center in the immersed view |
| Recognition Statement | multilineText | `recognitionStatement?` | Airtable | mid-session fade in the immersed view + header in Reading Space |
| Lyrical Words Reading | multilineText | `lyricalWordsReading` | Airtable | Reading Space · WORDS tab |
| Frequency Reading | multilineText | `frequencyReading` | Airtable | Reading Space · FREQUENCY tab (inline `[SCIENCE]`/`[TRADITION]`/`[CLAIM]` paragraphs become tier cards) |
| Lalita's Perspective | multilineText | `lalitasPerspective?` | Airtable | Reading Space · LALITA tab |
| Phase Labels | multilineText | `phaseLabels?` | Airtable | Reading Space · PHASES tab — blank-line-separated; `head — body` or `head: body` split for the column rule |
| **Inhale Sec** | number | `inhaleSec: Int?` | **Airtable (since 2026-05-22)** | with seed-fallback to `BreathProtocolMetadata.all[id].inhale` |
| **Hold Sec** | number | `holdSec: Int?` | **Airtable (since 2026-05-22)** | `0` is valid (means "no hold") and is preserved through the merge |
| **Exhale Sec** | number | `exhaleSec: Int?` | **Airtable (since 2026-05-22)** | with seed-fallback |
| **Intention** | singleSelect | `intentionKey: String?` | **Airtable (since 2026-05-22)** | decodes via `BreathIntention(rawValue:)`; unknown / empty → fallback intention. Choices: `ground · activate · open · clarify · dissolve · expand · rest · balance` |
| **Safety** | singleSelect | `safetyKey: String?` | **Airtable (since 2026-05-22)** | fails closed (see below). Choices: `open · screened` |
| **Special Cue** | singleSelect | `specialCueKey: String?` | **Airtable (since 2026-05-22)** | enum raw values match Airtable strings directly. Choices: `hum · ocean · double_pulse · active_phase`. Empty = no cue |

## The join — `BreathSession.joined()` → `JoinedBreathSession`

`BreathProtocolMetadata.merge(airtable:)` is the join. Per field: Airtable value wins when present; else `BreathProtocolMetadata.all[id]` is the seed/fallback. The `JoinedBreathSession` value type is what every view consumes — `inhale`, `hold`, `exhale`, `intention`, `safety`, `special`, etc. — so views don't have to perform the merge themselves.

## Fail-closed safety — `BreathProtocolMetadata.resolveSafety(airtableKey:id:)`

- Returns `.open` only when **both**: (1) the id is **not** in `knownScreenedIDs`, AND (2) the trimmed Airtable Safety string is exactly `"open"`.
- Empty / nil / `"screened"` / unknown / whitespace-only → `.screened`, so the contraindication gate shows by default whenever the value isn't an explicit pass.
- `BreathProtocolMetadata.knownScreenedIDs: Set<Int> = [105]` is the code-level **backstop**: defense-in-depth against a bad Airtable edit accidentally un-gating an intense session. **Any future screened session should be added here as soon as it ships, before its Airtable row exists.**

## Special-cue fail-graceful

Empty / nil Airtable cell → fall back to the hardcoded `special`. Non-empty Airtable cell that doesn't decode to a known `BreathSpecialCue` raw value → `init(rawValue:)` returns `nil` → no cue rendered, no crash. The Swift switch on `BreathSpecialCue` still owns the *behavior* (cue label text, which phase the label surfaces on, phase-word override like `mmm` / `haaa`).

## Source-of-truth boundary — what is NOT in Airtable

These fields stay in `BreathProtocolMetadata.all` as the only source today and are NOT read from Airtable by `merge(airtable:)`:

| Field | Type | Why it isn't migrated yet |
|---|---|---|
| `hue` | `Double` | Carries deliberate divergence from `intention.hue` for some sessions — 109 reads as cyan (195) while its intention is `balance` (140); 111 reads as deep theta-purple (260) while its intention is `rest` (15). Cannot be derived from intention; needs its own Airtable column when migrated. |
| `oneLine` | `String` | Short copy shown on `SessionDetailView` and `SubSelectionView`. Distinct from the `Recognition Statement` (the recognition is the in-session whisper; the one-line is the catalog description). |
| `carrierTiers` | `[HonestyTier]` | Inline `[S]` / `[T]` / `[C]` pills next to the carrier line on `SessionDetailView`. Per-session, often shorter than the full set the `BrainwaveStateInfo` table carries. |
| `beatTiers` | `[HonestyTier]` | Same idea for the beat line — independent honesty tagging because beat and carrier can have different empirical support per session. |

## Adding a new breath session

1. Write the Airtable row (Track ID, Track Type = `breath`, the 11 base columns, and the 6 migrated columns).
2. Add a `BreathProtocolMetadata.all[id]` entry for `hue` / `oneLine` / `carrierTiers` / `beatTiers`.

The merge will pick up Airtable for the rest. If you skip the metadata entry the permissive default in `BreathProtocolMetadata.for(id:)` covers it — hue 210, neutral one-line, `[.tradition]` carrier / `[.science]` beat — but the session will look generic until you author it properly. If the session is screened, also add its id to `BreathProtocolMetadata.knownScreenedIDs` *before* the Airtable row exists.
