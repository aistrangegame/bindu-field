# Bindu Field — Claude Code Handoff
**Date:** May 19, 2026  
**Branch target:** `feat/airtable-catalog`  
**Scope:** Tier 0 (bug fixes) + Tier 1 (Airtable catalog wiring)

You have a `CLAUDE.md` at the project root. Read it first — it is authoritative on project structure, conventions, audio engine architecture, and current state. This document extends it with a specific mission and all specifications needed to execute without back-and-forth.

---

## CRITICAL FIRST MOVE — Before touching any code

**No git repo exists.** This is the first thing to do:

```bash
cd ~/Bindu\ Field
git init
git add .
git commit -m "chore: initial commit — pre-airtable baseline"
git checkout -b feat/airtable-catalog
```

Do not proceed until this is done. Every subsequent change happens on `feat/airtable-catalog`.

---

## TIER 0 — Bug Fixes + Cleanup
**Commit message:** `fix: tier-0 bug fixes and element color extraction`

Four changes. Do all four, then commit as one.

### Fix 1 — Drag rotation accumulation (FieldView.swift)
The Fibonacci sphere constellation resets rotation on each new drag gesture instead of accumulating. The symptom: lifting and re-placing the finger teleports the sphere back. Fix: preserve rotation state across gesture phases. The accumulated rotation should be stored and added to on each new drag.

### Fix 2 — handleTap depth filter too tight (FieldView.swift)
Back-half orbs on the sphere are unreachable. The depth filter `< 0.4` and 28pt hit threshold are too restrictive. Change depth bound to `< 0.7` and hit threshold to 36pt.

### Fix 3 — Player has no persistent stop/resume control (PlayerView.swift)
The HUD auto-hides after 3.8s. Duration chips disappear once music starts. There is no central stop/resume control visible during playback. Add a persistent stop/resume button at the vertical center of the player (below the visualizer, above the seed). It should always be visible, styled as a capsule matching the existing secondary button style (`Capsule().stroke(theme.muted.opacity(0.3))`).

### Fix 4 — Extract duplicated elementColor (new file + FieldView.swift + PlayerView.swift)
`PlayerView.elementColor(_:)` and `FieldView.elementColor(_:)` are identical 10-case switches. Extract to `Views/Components/ElementColors.swift` as a free function or `Color` extension. Both call sites become one-liners.

---

## TIER 1 — Airtable Catalog Wiring
**Commit message:** `feat: airtable catalog spine — dynamic track loading`

This replaces the hardcoded `TrackData.all` static array with live Airtable data. When complete, `TrackData.all` does not exist in the codebase.

### Step 1 — Secrets.swift (new file, gitignored immediately)

Create `.gitignore` at the project root if it does not exist. Add `Secrets.swift` to it.

Create `Secrets.swift.template` at the project root (checked in):
```swift
// Secrets.swift.template
// Copy to Secrets.swift and fill in values. Secrets.swift is gitignored.
enum Secrets {
    static let airtableToken = "YOUR_AIRTABLE_PAT_HERE"
}
```

Create `Secrets.swift` at the project root (gitignored):
```swift
enum Secrets {
    static let airtableToken = "PASTE_REAL_TOKEN_HERE"
}
```

**Note to Ashrey:** Paste your Airtable PAT into `Secrets.swift` before building. The PAT starts with `pat`.

---

### Step 2 — Refactor Track model (Models/Track.swift)

Current `Track` has `filename: String`, `baseURL: String`, and computed `audioURL`. The Airtable source provides the full URL directly. New fields `carrierHz` and `beatHz` replace what was previously inferred from ChakraData defaults.

**New Track struct:**
```swift
struct Track: Codable, Hashable {
    let id: Int
    let verb: String
    let song: String
    let artist: String
    let element: String
    let state: BrainwaveState   // keep existing enum
    let chakra: ChakraName?     // keep existing enum, optional
    let type: TrackType         // keep existing enum
    let audioURL: String        // full URL, direct from Airtable
    let youtubeID: String?
    let seed: String
    let carrierHz: Double
    let beatHz: Double
}
```

Remove `TrackData.all` entirely. Verify `AudioCache` uses `track.id` (not `track.filename`) for cache key `track-{id}.mp3` — if it references `filename`, update to `"\(track.id)"`.

---

### Step 3 — AirtableService (new file: Stores/AirtableService.swift)

Pattern mirrors `OracleService.swift`. Read that file first for style reference.

**Endpoint:** `https://api.airtable.com/v0/app248ZTWhYJlvQj2/tblv3WvMZ90Sfhun6`  
**Auth header:** `Authorization: Bearer \(Secrets.airtableToken)`  
**Method:** GET, `pageSize=100` (22 records, well under limit)

**Airtable JSON shape** (field names are the JSON keys):
```json
{
  "records": [
    {
      "id": "recXXX",
      "fields": {
        "Track ID": 23,
        "Verb": "press",
        "Song Title": "Iron",
        "Artist": "Woodkid",
        "Track Type": "chakra",
        "Element": "Earth",
        "Brainwave State": "delta",
        "Chakra": "Muladhara",
        "Audio URL": "https://aistrangegame.com/tree-of-life/muladhara.mp3",
        "YouTube ID": null,
        "Carrier Hz": 146.8,
        "Beat Hz": 2.5,
        "Seed Phrase": "You don't remember how you got here."
      }
    }
  ]
}
```

**Decoding intermediary** (maps Airtable field names → Swift properties):
```swift
private struct AirtableResponse: Decodable {
    let records: [AirtableRecord]
}

private struct AirtableRecord: Decodable {
    let fields: AirtableFields
}

private struct AirtableFields: Decodable {
    let trackID: Int?
    let verb: String?
    let songTitle: String?
    let artist: String?
    let trackType: String?
    let element: String?
    let brainwaveState: String?
    let chakra: String?
    let audioURL: String?
    let youtubeID: String?
    let carrierHz: Double?
    let beatHz: Double?
    let seedPhrase: String?

    enum CodingKeys: String, CodingKey {
        case trackID = "Track ID"
        case verb = "Verb"
        case songTitle = "Song Title"
        case artist = "Artist"
        case trackType = "Track Type"
        case element = "Element"
        case brainwaveState = "Brainwave State"
        case chakra = "Chakra"
        case audioURL = "Audio URL"
        case youtubeID = "YouTube ID"
        case carrierHz = "Carrier Hz"
        case beatHz = "Beat Hz"
        case seedPhrase = "Seed Phrase"
    }
}
```

Map `AirtableFields` → `Track` using existing `BrainwaveState`, `ChakraName`, and `TrackType` enums (check their raw value strings against what Airtable returns — they should match: "delta", "theta", "alpha", etc. for BrainwaveState; "chakra", "music", "meditate", "family" for TrackType).

**Service class:**
```swift
@MainActor
final class AirtableService {
    static let shared = AirtableService()
    private init() {}

    func fetchTracks() async throws -> [Track] {
        // build URLRequest with Authorization header
        // decode AirtableResponse
        // map records to [Track], drop any that fail mapping (guard let)
        // return sorted by id ascending
    }
}
```

---

### Step 4 — CatalogStore (new file: Stores/CatalogStore.swift)

Pattern mirrors `PlayerStore.swift`. Read that file first for style.

```swift
import Observation

@MainActor @Observable
final class CatalogStore {
    static let shared = CatalogStore()
    private init() { loadFromCache() }

    private(set) var tracks: [Track] = []
    private(set) var isLoading = false
    private(set) var loadError: String? = nil

    private let cacheKey = "binduCatalog.v1"

    func refresh() async {
        isLoading = true
        loadError = nil
        do {
            let fetched = try await AirtableService.shared.fetchTracks()
            tracks = fetched
            saveToCache(fetched)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([Track].self, from: data)
        else { return }
        tracks = cached
    }

    private func saveToCache(_ tracks: [Track]) {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}
```

Call `Task { await CatalogStore.shared.refresh() }` from `Bindu_FieldApp.swift` on launch (alongside existing audio session setup).

---

### Step 5 — Wire CatalogStore through the app

Update every site that currently reads `TrackData.all`. Do not change any logic — only the data source.

**FieldView.swift**
```swift
@State private var catalog = CatalogStore.shared
// Replace: TrackData.all → catalog.tracks
// Add loading state: if catalog.tracks.isEmpty && catalog.isLoading { ProgressView() }
```

**OracleService.swift**
The system prompt inlines the track catalog. Currently reads `TrackData.all`. Change to accept `[Track]` as a parameter passed in from `OracleView`. `OracleView` passes `CatalogStore.shared.tracks`.

**BinduConfig.swift**
`audioURL(for:)` walks `TrackData.all` by id. Change to walk `CatalogStore.shared.tracks`.

**Anywhere else** `TrackData.all` appears — find all with:
```bash
grep -r "TrackData" --include="*.swift" .
```
Update each callsite.

---

## Success Criteria

Tier 0 is done when:
- [ ] Drag rotation accumulates across gesture lifts
- [ ] Back-half constellation orbs are tappable
- [ ] Stop/resume button is visible during track playback
- [ ] `elementColor` lives in one place only

Tier 1 is done when:
- [ ] `TrackData` does not exist anywhere in the codebase (`grep -r "TrackData" --include="*.swift" .` returns nothing)
- [ ] App builds with zero errors and zero warnings introduced by these changes
- [ ] App installs and runs on device (Neev)
- [ ] Field tab renders all 22 tracks loaded from Airtable
- [ ] Tapping any track plays correctly (audio + binaural layer)
- [ ] Killing the app and reopening shows tracks instantly from UserDefaults cache
- [ ] OracleService still returns track suggestions correctly

---

## Hard Constraints — Do Not Touch

These files are out of scope for this session:

- `BinauralEngine.swift`
- `BinauralListener.swift`
- `BinduDSP.h` / `BinduDSP.cpp` / `BinduDSPBridge.h` / `BinduDSPBridge.mm`
- `SpaceImmersedView.swift` (ChakraData breath protocol stays hardcoded)
- `ChakraProtocol.swift` (chakra breath data is separate from track catalog)
- `Session.swift`, `SessionStore.swift`
- `Letter.swift`, `LetterStore.swift`, `RecorderService.swift`
- `RitualSetupView.swift`, `RitualRunningView.swift`

If a constraint file needs updating to compile (e.g. a Track property rename), make the minimal change and note it. Do not refactor.

---

## After Both Tiers Pass

```bash
git add .
git commit -m "feat: tier-1 complete — airtable catalog live"
```

Then surface: what was changed, what compile warnings remain, what needs attention before merging to main. Do not merge — leave on `feat/airtable-catalog` for review.

