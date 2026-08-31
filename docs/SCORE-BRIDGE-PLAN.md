# Score → Performer bridge — implementation plan

*The landmark seam. Written 2026-08-31 from a verified read of the app code, the
`bindu-field` skill, and the live Airtable. This is a plan, not shipped code —
it is meant to be executed by a session that can compile against Xcode and test
on device. Nothing here has been built.*

---

## The divergence this closes

The `bindu-field` **skill** grew a whole Score system — Score Format v2.0 (24
sections, 9 required), a batch pipeline, the Twelve Discoveries. The **table**
received most of it: as of 2026-08-31 the live catalog (`app248ZTWhYJlvQj2` /
`tblv3WvMZ90Sfhun6`) holds **60 rows, 46 marked `Score Status = Drafted`**, with
~36 KB `Score JSON` bodies on ~35 of them. The **app cannot see any of it.**
`Track` decodes 19 catalog fields; `Score JSON`, `Score Status`, and `Audio Data
URL` appear in neither `AirtableFields.CodingKeys` nor the model, and grep finds
zero references. Every track except one falls back to the generic renderer.

Today the app has exactly **one** Score — `Score.cross`, a hardcoded Swift
literal for Track 27 (Sound of Silence). `Score.forTrack(id:)` is a two-case
switch: `27 → .cross`, everything else `→ nil → ambient mode`. This document is
how the app comes to read authored Scores from Airtable and drive the Performer
from them.

---

## What already exists in the app (verified)

The machinery to *drive* from a Score is fully built and consuming Performer
state today — **only the Score source is hardcoded.**

- **`Performer.swift`** — a 60 Hz `@Observable` clock. Reads
  `TrackPlaybackService.shared.elapsed` + live `DSPWireService` analysis;
  publishes `currentPhase`, `timeIntoPhase`, `crescendoModulator`, `inSilence`,
  `energy`, `beatPulse`, `onsetCount`, and a 10-key `archetypePresence`.
- **The Swift `Score` struct** (thin — a fraction of Score JSON v2):
  ```swift
  enum ScorePhase: String { case silence, intro, build, peak, descent, outro }  // CLOSED, 6 cases
  struct PhaseWindow   { let phase: ScorePhase; let start, end: Double }
  struct SilenceWindow { let start, end: Double }
  struct BeatEvent     { let time: Double }
  struct Score {
      let trackID: Int
      let totalDuration: Double
      let phases: [PhaseWindow]
      let silenceWindows: [SilenceWindow]
      let beatSchedule: [BeatEvent]           // currently unused; cross derives beats from onsets
      let modulatorRampIn, modulatorHoldStart, modulatorHoldEnd, modulatorRampOut, modulatorBoost: Double
      let mirrorWords: [String]?
  }
  ```
- **`Score.cross`** — `trackID 27`, `totalDuration 268`; phases silence 0–8 /
  intro 8–68 / build 68–145 / peak 145–200 / descent 200–248 / outro 248–268;
  silence windows `[0–8, 42–50]`; modulator `rampIn 145, holdStart 160, holdEnd
  180, rampOut 195, boost 0.8`; `mirrorWords ["pn","open","breathe",…]`.
- **Consumers of Performer state:**
  - `VisualizerView` / the Cathedral renderer — gates tiers on
    `crescendoModulator` (arches > 0, keystone/earth-rising > 0.25), spawns beat
    rings when `beatPulse` crosses 0.9, draws ensemble layers gated on each
    `archetypePresence[...]`. **The only real-time reader of the full surface.**
  - `Performer.updateBinauralDepth()` — the one place a Score bends the audio:
    `BinauralEngine.updateBeat(base * (1 - crescendoModulator * 0.55))`, guarded
    by `!DSPWireService.hasBeatOverride`. ~44 % beat-Hz drop at full crescendo.
  - `ConsciousnessLoopCoordinator` — reads **only** `Score.forTrack(id:).mirrorWords`
    as a fallback (precedence: `Track.mirrorWords` Airtable → Score → universal
    default). Decoupled from live Performer state.
- **Ambient mode** (nil Score): continuous Cathedral tier + Bindu + live audio
  reactivity (`beatPulse`, `energy`, Sid drone, gaia 0.4, arch = energy×1.5,
  karishma = inverse energy, sakshi 0.6). **No** phase name, **no** crescendo /
  climax tiers, **no** silence emphasis, **no** scored archetypes.

---

## The impedance mismatch (why this is XL, not a decode)

Score JSON v2 is far richer than the Swift `Score`. Map honestly:

| Maps cleanly | v2 source → Swift target |
|---|---|
| Phases | `score.phases[]` `{name,start,end}` → `PhaseWindow` (needs a `name` field added — see below) |
| Silence | `score.silence_windows[]` → `SilenceWindow` (drop `role`) |
| Crescendo | `score.tiers.t4_climax.global_boost` `{ramp_in,hold_start/…,factor}` → the 5 `modulator*` scalars — **already 1:1** with cross's 145/160/180/195/0.8 |
| Mirror words | `score.mirror_system.families` (flatten) → `mirrorWords: [String]` |

| Does **not** map | why |
|---|---|
| Phase names | `ScorePhase` is a **closed 6-case enum**; v2 phase names are open free text (3–12 of them, e.g. `"Threshold Valley"`, `"Bells in the Dimness"`). Must add a `String` label to `PhaseWindow`, or lossily snap onto the 6 cases. |
| Beat schedule | v2 authors a **12-segment** brainwave arc with designed Schumann / 2.69 Hz windows + carrier dropouts; the app models one modulator-driven deepening. |
| **Archetype presence** | **The decisive gap.** `archetypePresence` is **not authored in the Score at all** — it is computed by cross-specific hardcoded formulas inside `Performer` (Shweta fires t=160–162, Lalita ramps t>204, Neev bookends, Gaia at 2s…). Even a fully decoded Score renders **cross's** archetype choreography for every song until those formulas are datafied. And v2's `ensemble` section authors hue/orbit/reads but **not** the presence-over-time envelope — so this is a schema gap on *both* sides. |
| Vocabulary module | v2 `metaphor.vocabulary_module` is explicitly Layer-3 **drawing code** ("cannot be data"). Only a module *name* can come from JSON; the renderer must already hold that module. |
| Extracted audio_data | v2's `H/E/B/P/T…` streams are for the web build's pre-extracted playback. **The iOS app reads live DSP (`DSPWireService`) — ignore the entire extracted half of every Score.** |

**Content reality that bounds the payoff:** of the 46 Drafted rows, only ~3 Scores
are *fully authored* (cross/abide/thunderclouds) and only **cross (Track 38)** is
in the catalog — and cross has **no hosted audio**, so it can't sound. The other
Drafted rows are STEP 1/6/7 stubs (carrier + extraction + validate; `metaphor`
null, `peak_t` extraction-only and flagged `needs_listening`, tiers/mirror_system
null). **So the bridge lights up structure the drafts don't yet fully author.**
First real on-device test must use a track that is *both* Drafted-with-real-phases
*and* hosted — pick from Runs 1–3 (a hosted, playing song), not cross.

---

## Stage 0 — land the raw fields (S, safe, do first)

Identical to the `phaseLabels` field-add already shipped — the proven cache-safe
`decodeIfPresent` + memberwise-arg pattern. No behavior change; gets the data
flowing so later stages build against real bytes.

1. `Track.swift`: add `let scoreJSON: String?` and `let scoreStatus: String?`;
   add to `CodingKeys`; `decodeIfPresent` in the custom `init(from:)`.
2. `AirtableService.swift` `AirtableFields`: add `let scoreJSON: String?` +
   `case scoreJSON = "Score JSON"`, `let scoreStatus: String?` +
   `case scoreStatus = "Score Status"`; pass both at the `fetchTracks` call site.

**Cost note:** `scoreJSON` adds ~36 KB to every cached `Track` row
(`binduCatalog.v1` grows from a few KB to ~1–2 MB across the catalog). Acceptable
for UserDefaults but not free — consider fetching Score JSON lazily per-track
(a second Airtable GET by record id when a scored track starts) instead of
bulk-caching it, if cache size becomes a problem. **Decide this before Stage 1.**

---

## Stage 1 — the minimal decode slice (L)

Goal: per-track **phases + silence emphasis + crescendo + authored mirror words**
for every scored track, through the **existing Cathedral**, with zero renderer
rewrite. Explicitly accept that archetype timing still borrows cross's until
Stage 2.

1. **Add a label to `PhaseWindow`** so free-text v2 phase names survive:
   ```swift
   struct PhaseWindow { let phase: ScorePhase; let label: String?; let start, end: Double }
   ```
   Snap the free-text name onto the nearest `ScorePhase` case for tier-gating
   (the Cathedral gates on the enum, not the name), and keep `label` for display
   (e.g. a future PHASES-tab cross-reference). A defensive snapper: match on
   keywords (`silence/quiet → .silence`, `intro/arrival → .intro`,
   `build/climb/rise → .build`, `peak/climax/apex → .peak`,
   `descent/return/fall → .descent`, `outro/close/drone → .outro`); default
   `.build`.

2. **Define `AuthoredScore` Codable** over ONLY the fields that map, tolerant of
   missing sections (everything optional; a malformed Score must decode to `nil`
   and fall through to the existing switch, never crash a playback start):
   ```swift
   struct AuthoredScore: Decodable {
       struct Phase: Decodable { let name: String?; let start: Double?; let end: Double? }
       struct Silence: Decodable { let start: Double?; let end: Double? }
       struct GlobalBoost: Decodable { let ramp_in, hold_start, hold_end, ramp_out, factor: Double? }
       struct Tiers: Decodable { let t4_climax: T4? ; struct T4: Decodable { let global_boost: GlobalBoost? } }
       struct MirrorSystem: Decodable { let families: [String: [String]]? }
       struct Identity: Decodable { let track_id: Int?; let duration_seconds: Double? }
       let identity: Identity?
       let phases: [Phase]?
       let silence_windows: [Silence]?
       let tiers: Tiers?
       let mirror_system: MirrorSystem?
   }
   ```
   The real v2 wraps everything under a top-level `score` object plus a sibling
   `audio_data_ref` — decode the wrapper first (`struct ScoreDoc { let score: AuthoredScore }`),
   confirm against `references/score-format-v2.md` §schema before finalizing key
   names (they are snake_case in the JSON).

3. **A projector** `Score.from(authored:trackID:) -> Score?` — flatten
   `phases → [PhaseWindow]` (snap names), `silence_windows → [SilenceWindow]`,
   `tiers.t4_climax.global_boost → the 5 modulator scalars` (default to cross-like
   values only if you *choose* to; better to leave modulator flat/zero when a
   Score authors no boost, so unscored-but-drafted tracks don't fake a crescendo),
   `mirror_system.families.values.flatMap → mirrorWords`. Return `nil` if there
   aren't enough real phases to be worth driving.

4. **Rewire `Score.forTrack(id:)`** to prefer a decoded per-track Score:
   ```swift
   static func forTrack(id: Int) -> Score? {
       if let raw = CatalogStore.shared.track(id: id)?.scoreJSON,
          let doc = try? JSONDecoder().decode(ScoreDoc.self, from: Data(raw.utf8)),
          let s = Score.from(authored: doc.score, trackID: id) { return s }
       switch id { case 27: return .cross; default: return nil }   // keep cross as the proof/fallback
   }
   ```
   (Confirm `CatalogStore` exposes a `track(id:)` lookup; if not, add one, or
   thread the `Track` through `PlayerStore.play` which already has it.)

**What lights up after Stage 1:** every Drafted track with real phases gets
named phase tracking, silence-window emphasis in the Cathedral, an authored
crescendo when one exists, and authored mirror words in the Loop — with **no**
renderer change. What stays wrong: archetype choreography (Stage 2).

---

## Stage 2 — datafy archetype presence (L, the real depth)

`Performer.updateScoredArchetypePresence()` hardcodes cross's timeline. Replace
the magic numbers with a small envelope model read from the Score:

```swift
struct ArchetypeEnvelope { let archetype: ArchetypeName; let window: ClosedRange<Double>; let attack, release: Double; let curve: Curve }
```
Populate cross's envelopes from the current constants first (behavior-preserving
refactor — verify cross renders identically on device), have
`updateScoredArchetypePresence` iterate envelopes, THEN design the matching
Score-JSON section (v2's `ensemble` authors hue/orbit but not presence-over-time
— this needs a new authored sub-section, coordinated with the skill). Do this
**after** Stage 1 ships; it is the step that makes a decoded Score actually change
a song's archetype choreography instead of borrowing cross's.

---

## Stage 3 — authored beat schedule (optional, M)

Only if per-track binaural arcs are in scope. Decode `score.binaural.beat_schedule[]`
(ordered by `until`, final `until: null`) and drive `BinauralEngine.updateBeat`
from it instead of the single modulator-depth model — still guarded by
`!DSPWireService.hasBeatOverride`. Honor `designed: true` (a *placed* frequency,
e.g. cross's 2.69 Hz / 7.83 Schumann pass-throughs) vs found ones. Defer unless
asked; the single crescendo-depth model is a fine ceiling for v1.

---

## Never / out of scope

- **Vocabulary modules stay in code.** Only a module *name* can come from JSON.
- **Ignore the extracted `audio_data` streams entirely** — the app reads live DSP.
- **Do not promote an auto-detected `peak_t` to anything.** Extraction is not
  reproducible on peak_t (184.5 s vs 170.0 s on the same file); the drafts flag
  it `needs_listening`. The app should treat draft phase timings as provisional.

---

## Validation plan (needs a compiler + a device)

1. Build; run the existing catalog — confirm no regression to unscored tracks
   (they must still enter ambient mode) and old caches still decode.
2. Unit-test `AuthoredScore` decode + `Score.from` against 3–4 real Score JSON
   bodies pulled from Airtable (a fully-authored one and a batch-draft stub).
   Assert malformed / partial JSON yields `nil`, never a throw at playback start.
3. First real on-device test: a **hosted, playing, Drafted** track (Runs 1–3),
   NOT cross (cross has no audio). Confirm phases + silence + crescendo read from
   the Score and not from cross.
4. Regression-test Track 27: with cross still in the fallback switch, Sound of
   Silence must render exactly as before.

---

## Open questions (carry to the building session)

- Bulk-cache Score JSON (simple, ~36 KB/row) or lazy per-track fetch (leaner
  cache, one extra GET per scored play)? Decide in Stage 0.
- Preserve free-text phase names verbatim (adds a display surface) or snap-only?
- Is per-track authored beat scheduling (Stage 3) wanted, or is the single
  crescendo-depth model the intended ceiling?
- The archetype-presence envelope is a **schema gap on both sides** — the skill
  must author a presence-over-time section before Stage 2 can be fully data-driven.
- Score Status gating: should the app hide or badge non-`Verified` rows (all
  rows are `Drafted`, zero `Verified` today) or show everything?
