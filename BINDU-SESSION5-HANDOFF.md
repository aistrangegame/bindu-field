# Bindu Field — Session 5 Handoff
**Branch:** `feat/constellation-lab-oracle`
**Depends on:** Session 4 (`feat/dsp-wire-player-upgrade`) merged to main
**Scope:** Constellation upgrade · Lab enhancements · Practice-aware Oracle

Three features. Three commits. None touch the audio engine, DSPWireService, VisualizerView, or PlayerView — those are Session 4 territory. All additions are purely visual and data-layer.

Read `CLAUDE.md` first. Authoritative on conventions, file structure, and state management patterns.

---

## FIRST MOVE

```bash
git checkout main
git checkout -b feat/constellation-lab-oracle
```

---

## Feature 1 — Constellation Upgrade
**File:** `Views/Tabs/FieldView.swift`
**Commit:** `feat: constellation — visual states, depth fog, element lines`

Current: Fibonacci sphere, element colors, uniform orb rendering regardless of play history. Every orb looks the same whether you've been in that track 20 times or never.

Three layers. Implement in order — each builds on previous.

### Layer A — Play state visual differentiation

Read session history to know which tracks have been played:

```swift
@State private var sessionStore = SessionStore.shared
@State private var catalog = CatalogStore.shared
```

Compute played track IDs from session history. Check the actual `Session` model for how track sessions are typed — extract the track ID field accordingly. Result: `Set<Int>` of track IDs that appear in `sessionStore.sessions`.

**Three visual states per orb:**

| State | Condition | Rendering |
|---|---|---|
| Playing | `store.currentTrack?.id == track.id` | Keep existing pulse behavior |
| Played before | id in played set | Element color · 1.0 opacity · inner glow ring |
| Never played | not in set, not playing | Element color · 0.55 opacity |

**Inner glow ring** (played state): a second circle behind the orb at 1.4× its radius, same element color, 0.25 opacity. This is the mark: *you've been here.*

### Layer B — Depth fog

Currently all orbs render at identical opacity regardless of z-position. The sphere has no sense of depth.

The existing layout already computes a depth value (used for the hit-test filter). Use it for rendering:

```swift
// depth: 0.0 = front face, 1.0 = back face
let fogFactor: Double = 1.0 - (depth * 0.5)  // back orbs reach 50% opacity floor
let foggedOpacity = baseOpacity * fogFactor

let sizeScale: Double = 1.0 - (depth * 0.2)   // back orbs 80% the size of front
```

Apply both to the orb canvas draw call. Front of sphere is present and close; back recedes naturally.

### Layer C — Element connection lines (implement if clean, skip if noisy)

Very subtle lines between orbs of the same element. For each element with 2+ visible tracks:
- One line per pair within the element group
- Only draw when both orbs are on the front hemisphere (depth < 0.5)
- Stroke: element color · opacity 0.07 · lineWidth 0.5

If this visually clutters the sphere or measurably impacts frame rate — omit it. Layers A and B are the priority.

---

## Feature 2 — Lab Enhancements
**Files:** 3 new + LabView.swift
**Commit:** `feat: lab — frequency presets and explanations`

Lab becomes a knowledge tool, not just a frequency toy. Saved combinations with names. Information that makes sound meaningful.

### 2A — FrequencyPreset model (new: `Models/FrequencyPreset.swift`)

```swift
struct FrequencyPreset: Codable, Identifiable {
    let id: UUID
    var name: String
    var carrierHz: Float
    var beatHz: Float
    var note: String?
    let createdAt: Date
    let isSystem: Bool

    static let systemPresets: [FrequencyPreset] = [
        FrequencyPreset(id: UUID(), name: "Earth Tone",
            carrierHz: 136.1, beatHz: 7.83,
            note: "Schumann resonance. The Earth's electromagnetic heartbeat.",
            createdAt: .distantPast, isSystem: true),
        FrequencyPreset(id: UUID(), name: "Deep Delta",
            carrierHz: 136.1, beatHz: 1.5,
            note: "Below the dreaming threshold. Cellular restoration.",
            createdAt: .distantPast, isSystem: true),
        FrequencyPreset(id: UUID(), name: "Theta Gate",
            carrierHz: 136.1, beatHz: 5.5,
            note: "The entry point. Between waking and sleep.",
            createdAt: .distantPast, isSystem: true),
        FrequencyPreset(id: UUID(), name: "Creative",
            carrierHz: 174.0, beatHz: 7.0,
            note: "Low carrier, theta beat. Open and grounded simultaneously.",
            createdAt: .distantPast, isSystem: true),
        FrequencyPreset(id: UUID(), name: "Presence",
            carrierHz: 432.0, beatHz: 10.0,
            note: "Alternative concert pitch. Relaxed alertness.",
            createdAt: .distantPast, isSystem: true),
    ]
}
```

### 2B — PresetStore (new: `Stores/PresetStore.swift`)

Pattern mirrors `LetterStore.swift` exactly.

```swift
@MainActor @Observable
final class PresetStore {
    static let shared = PresetStore()
    private init() { load() }

    private(set) var userPresets: [FrequencyPreset] = []

    var allPresets: [FrequencyPreset] {
        FrequencyPreset.systemPresets + userPresets
    }

    func save(name: String, carrierHz: Float, beatHz: Float, note: String? = nil) {
        let preset = FrequencyPreset(
            id: UUID(), name: name,
            carrierHz: carrierHz, beatHz: beatHz,
            note: note, createdAt: Date(), isSystem: false
        )
        userPresets.insert(preset, at: 0)
        persist()
    }

    func delete(_ preset: FrequencyPreset) {
        guard !preset.isSystem else { return }
        userPresets.removeAll { $0.id == preset.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(userPresets) else { return }
        UserDefaults.standard.set(data, forKey: "binduPresets.v1")
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "binduPresets.v1"),
              let saved = try? JSONDecoder().decode([FrequencyPreset].self, from: data)
        else { return }
        userPresets = saved
    }
}
```

### 2C — FrequencyInfo data (new: `Models/FrequencyInfo.swift`)

Pure data file. No observable state. Lookup for explanations.

**Brainwave state explanations** — adapt cases to the actual `BrainwaveState` enum in the codebase:

| State | Range | Essence | Detail |
|---|---|---|---|
| delta | 0.5–4 Hz | Deep dreamless sleep. Cellular restoration. | The deepest oscillation the brain makes. Profound rest, healing, and states beyond ordinary awareness. In Bindu Field, delta carries the heaviest songs — the ones that touch the root. |
| theta | 4–8 Hz | The threshold. REM dreaming. Deep meditation. | The border between waking and sleep. Where inner knowing speaks and creative breakthroughs arise without effort. The largest territory in Bindu Field. |
| theta-alpha | 8–10 Hz | The bridge. Relaxed alert. Light trance. | The integration zone. Calm enough to receive, awake enough to remember. Where insight becomes usable. |
| alpha | 8–13 Hz | Calm presence. Here without effort. | Relaxed wakefulness. The natural resting state of a mind not under threat. Light flows here — clarity without striving. |
| beta | 13–30 Hz | Active thinking. Focused attention. | Normal waking consciousness. The Lab enters this territory above 13 Hz. |
| gamma | 30+ Hz | Peak perception. Heightened coherence. | Brief, intense. Associated with moments of heightened clarity and insight. |

**Notable carrier frequency notes** — shown when carrier slider is near a recognized value (±0.5 Hz):

| Carrier Hz | Note |
|---|---|
| 136.1 | OM frequency. Earth's natural resonance. Most universal carrier. |
| 174.0 | Foundation frequency. Grounding at the low register. |
| 285.0 | Tissue and field restoration association. |
| 396.0 | Solfeggio: Liberation. Releasing what no longer serves. |
| 417.0 | Solfeggio: Facilitating change. Clearing stagnant patterns. |
| 432.0 | Alternative concert pitch. Warmer resonance than 440 Hz. |
| 528.0 | Solfeggio: Transformation. Love frequency. |
| 639.0 | Solfeggio: Connection. Harmonizing relationships. |

### 2D — LabView UI additions (`Views/Tabs/LabView.swift`)

Three additions. Add them in this order.

**Preset row** — horizontal ScrollView between sliders and play button:

Each preset renders as a small chip. System presets: `Capsule().fill(theme.muted.opacity(0.15))`. User presets: `Capsule().fill(theme.text.opacity(0.08))`. Text: preset name in small caps with `.tracking(1.5)`.

Tap any preset chip → animate carrier and beat sliders to preset values:
```swift
withAnimation(.easeOut(duration: 0.4)) {
    carrierHz = preset.carrierHz
    beatHz = preset.beatHz
    // Also update BinauralEngine if currently playing
}
```

"+ Save" chip at end of row: tap → small inline text field appears for naming. Confirm → `PresetStore.shared.save(name:carrierHz:beatHz:)`. Cancel → dismiss. No modal or sheet — inline only.

Long-press any user preset chip → confirmation alert to delete. System presets: no long-press action.

**Brainwave state info card** — directly below the state label:

Collapsed: state label only (existing). Tap state label → card expands below it showing range + essence + detail from `FrequencyInfo`. Tap again → collapses. Smooth height animation. Text in serif italic at small size, `theme.muted` color.

```swift
@State private var stateInfoExpanded = false

// On tap of state label:
withAnimation(.easeInOut(duration: 0.25)) {
    stateInfoExpanded.toggle()
}
```

**Carrier frequency note** — next to the carrier Hz display value:

When `FrequencyInfo.carrierNote(for: carrierHz)` returns non-nil: show a small `"·"` dot (theme.accent or similar subtle color) next to the Hz value. Tap the dot → brief overlay or popover showing the note text. Tap anywhere else → dismisses. Choose the simplest iOS overlay approach that doesn't introduce dependencies.

---

## Feature 3 — Practice-Aware Oracle
**Files:** `Stores/OracleService.swift` · `Views/Tabs/OracleView.swift`
**Commit:** `feat: oracle — practice-aware recommendations`

Small, targeted change. Oracle should know what you've played recently — it shouldn't keep recommending the same tracks.

### OracleService.swift

Add `recentlyPlayed: [Int]` parameter to the `ask(...)` method signature.

The catalog line builder currently outputs verb, song, artist, element, state. Extend it to include `recognitionStatement` when non-empty:

```swift
// In the catalog line builder, extend each track line:
let recognition = track.recognitionStatement.isEmpty ? "" : " (\(track.recognitionStatement))"
// Append recognition to the track's catalog entry
```

This gives the Oracle genuine knowledge of what each song IS, not just its metadata. When a listener says "I feel lost" the Oracle can recognize which song holds what they're circling — because it knows the recognition, not just the element tag.

In the system prompt, after the track catalog, append:

```swift
if !recentlyPlayed.isEmpty {
    let recentNames = recentlyPlayed.compactMap { id in
        tracks.first { $0.id == id }.map { "\($0.verb) — \($0.song)" }
    }.joined(separator: ", ")
    systemPrompt += "\n\nRecently played by this person (deprioritize unless most relevant to their current state): \(recentNames)."
}
```

**Note:** `Track` will need a `recognitionStatement: String` property (defaulting to `""`) added alongside the Airtable decode. The Airtable field ID is `fldFW1HEDvfC4gOJy`. Add it to `AirtableFields` with key `"Recognition Statement"` and map through to `Track`. Empty for most tracks initially — the Oracle skips it gracefully when absent.

### OracleView.swift

Add session store read and compute recently played track IDs:

```swift
@State private var sessionStore = SessionStore.shared

var recentTrackIDs: [Int] {
    // Extract track IDs from session history, deduplicated, most recent first, max 10
    // Adapt to actual Session model shape — check how track sessions store their ID
    let ids = sessionStore.sessions
        .compactMap { /* extract track id */ }
    return Array(ids.uniqued().prefix(10))
}
```

Add `uniqued()` as a private extension on `Array where Element: Hashable` in the same file (no imports needed):
```swift
private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
```

Pass `recentlyPlayed: recentTrackIDs` into the `oracle.ask(...)` call.

---

## Verification

```bash
# Confirm no Session 4 files were touched:
git diff --name-only main | grep -E "BinauralEngine|BinauralListener|BinduDSP|DSPWire|VisualizerView|PlayerView"
# Should return nothing

# Build:
xcodebuild -scheme "Bindu Field" -destination "generic/platform=iOS" -configuration Debug build
# Zero errors. Zero new warnings.
```

**Device tests (Neev):**
- [ ] Constellation: tracks played before show inner glow ring; never-played tracks are dimmer
- [ ] Constellation: back-of-sphere orbs are visibly smaller and more transparent than front
- [ ] Lab: preset chips visible; tapping loads carrier and beat values with animation
- [ ] Lab: saving a preset persists across app kill and relaunch
- [ ] Lab: long-pressing a user preset offers delete; system presets cannot be deleted
- [ ] Lab: tapping brainwave state label expands info card with explanation text
- [ ] Lab: notable carrier values show dot; tapping shows note text
- [ ] Oracle: after playing multiple tracks, recent ones are deprioritized in suggestions
- [ ] Oracle: existing functionality (prompt → recommendation → play) unaffected

---

## Hard Constraints

Do not touch:
- `BinauralEngine.swift`, `BinauralListener.swift`, all DSP files
- `DSPWireService.swift` (Session 4)
- `VisualizerView.swift`, `PlayerView.swift` (Session 4)
- `SpaceImmersedView.swift`, `SpaceSetupView.swift`, `ChakraProtocol.swift`
- `RitualSetupView.swift`, `RitualRunningView.swift`
- `LetterView.swift`, `LetterRecordView.swift`, `LetterPlaybackView.swift`
- `LabView.swift` audio playback logic — only extend the UI

---

## Commit Sequence

```bash
git add .
git commit -m "feat: constellation — visual states, depth fog, element lines"

git add .
git commit -m "feat: lab — frequency presets and explanations"

git add .
git commit -m "feat: oracle — practice-aware recommendations"
```

Surface: what changed, any warnings, device test results. Leave on `feat/constellation-lab-oracle` — do not merge.
