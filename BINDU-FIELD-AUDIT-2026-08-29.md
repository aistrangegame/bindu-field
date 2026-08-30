# Bindu Field — State of the App Audit

*Compiled 2026-08-29 from full recon: the `bindu-field` skill, the seven `docs/` reference files, git history, the live source tree (77 Swift files, ~16,550 LOC), and the live ASG Airtable base (`app248ZTWhYJlvQj2` / `tblv3WvMZ90Sfhun6`). Written to be portable — paste into a chat to work up upgrades.*

---

## 0. TL;DR — the five things that matter most right now

1. **The app is feature-complete and content is now ~74% authored.** The single biggest change since the docs were last refreshed: the Airtable reading content that every doc still describes as *"Empty for all 22 — CONTENT WORK NEEDED"* has actually been written. 25 of 34 catalog records now carry full Recognition / Lyrical / Frequency / Lalita prose. **The docs are stale on this point and should be corrected.**
2. **Nine ambient music tracks are still "seed-only"** (no reading content) and **Video Pulse Reading is empty for all 34 records.** These are the two real remaining content gaps.
3. **A write-capable Airtable PAT is now embedded in the shipping binary**, and the app performs live writes with it (the new "App Activity" ledger on Loop seal). This is the most significant *new* risk surface and deserves a decision before any wider release.
4. **Data hygiene issues in the Airtable schema**: one orphaned content record with no Track ID (won't load in-app), and several single-select fields polluted with stray choices (Element/Brainwave/Chakra options cross-contaminated).
5. **The engineering is genuinely solid** — settled audio architecture, clean separation of concerns, backwards-compatible decoders, fail-closed safety gating. The frontier work is now **content, device-QA, and a few deferred features (LalitaEngine, more authored Scores)** — not firefighting.

---

## 1. What the app is (one paragraph)

Bindu Field is a dark-mode-only SwiftUI iOS instrument that layers a real-time **binaural-beat tone engine** underneath a curated catalogue of music tracks, wrapping the whole thing in a contemplative "consciousness" experience: a **33-chakra Map** (front door), a **22-orb constellation Field**, a **7-step Consciousness Loop** ceremony, breath-driven **AKASH** sessions, a **Claude-API Oracle** that recommends tracks, **Sound Letters** (voice-over-binaural recordings), a freeform frequency **Lab**, and a **Ritual** sequencer. It has **no SPM dependencies** (Accelerate.framework only), streams MP3s from a static host with a 200 MB LRU cache, loads its catalogue dynamically from Airtable, and calls `api.anthropic.com` directly with a user-pasted key. Two `AVAudioEngine` instances (tone + music) + a C++ DSP kernel drive audio-reactive visuals through nine per-element "vocabulary" renderers plus a Cathedral scene.

---

## 2. Current build & branch state

| Fact | Value |
|---|---|
| Current branch | `main` (clean, up to date with `origin/main`) |
| Other branches | `feat/stabilize` (local + remote), `feat/app-activity-field` (local) |
| HEAD | `5338bfb` — docs: Xcode Cloud Secrets.swift note |
| Swift files | 77 · ~16,553 LOC |
| Build status | Documented **clean, zero warnings/errors** at last audit (2026-05-27). **Not re-verified in this session** — recommend a fresh build before merge/release. |
| Deployment target | iOS 17.6 · also configured for macOS 26.4 / visionOS 26.5 (device family `1,2,7`) |

**⚠️ Docs drift:** `CLAUDE.md` and `docs/` describe the state at HEAD `90c9d67` and say *"Currently on `feat/stabilize`."* Four commits have landed on `main` since:

- `b9c2918` **feat: theming + legibility + loop fix + tab swap + mirror words**
- `e30c913` **feat: app activity — Field's first Airtable write on Loop seal**
- `23ae7ef` **ci: generate Secrets.swift on Xcode Cloud from AIRTABLE_PAT**
- `5338bfb` docs: CLAUDE.md note on the above

None of these four are reflected in `docs/STATUS.md` / `SESSIONS.md`. **A doc refresh is the cheapest high-value cleanup available.**

### What those four commits actually changed (not yet in docs)

- **Light/dark theming** — `ThemeData.light` palette added; `SettingsStore.themeMode` + `activeTheme` + `preferredColorScheme`; injected in `RootView`; a Settings appearance picker. Immersive Canvas scenes are pinned to void regardless of theme. *(The docs still say "dark-mode-only, void/black palette" — no longer strictly true.)*
- **Contrast overhaul** — `subtle` 0.28→0.40, `muted` 0.55→0.68, plus faint-affordance bumps (Loop tap-to, Oracle idle, Map header, Player recognition).
- **Player FIELD tap-zone fix** — "BEGIN THE LOOP" was being swallowed by the full-screen enter-CONTROL zone; now reachable.
- **Tab swap** — Lab promoted into the primary tab bar; Oracle demoted into the More menu.
- **Per-track mirror words** — `Track.mirrorWords: [String]`, parsed from a new Airtable `Mirror Words` column, with Loop precedence over the hardcoded Track-27 set and the universal 5-word default.
- **App Activity write-back** — the app's **first write to Airtable** (see §5).

---

## 3. Feature completeness — what works today

All eight tabs boot and run their golden paths. Condensed from `docs/STATUS.md` + `docs/UI.md`:

| Area | State |
|---|---|
| **Map** (33 chakra nodes) | ✅ 3 render states (locked/available/danced), detail sheet, journey persistence, marks danced only on natural completion |
| **Field** (22-orb constellation) | ✅ Fibonacci sphere, filter chips, played/never states, depth fog, verbs under front orbs, long-press → Oracle |
| **Oracle** (Claude recommender) | ✅ 4-state void (idle/typing/waiting/response), cancellable in-flight request, keychain-gated, drifting fog |
| **AKASH** (breath sessions) | ✅ Intention grid → 11 Airtable-backed sessions, fail-closed screened gate, breath-modulated binaural, Reading Space |
| **Archive** | ✅ Date-grouped sessions, integration notes, settings, clear flows |
| **Lab** | ✅ `TuningCluster` × 2 + `MeaningPanel`, honesty-tier pills, weighted randomize, presets |
| **Ritual** | ✅ Queue ≥2 chakra steps, drag-reorder, chained immersed sessions |
| **Letter** | ✅ 4-phase recorder, optional binaural underlay, playback re-layer, share, orphan cleanup |
| **Player** (3-mode + Loop) | ✅ FIELD/CONTROL/READING, binaural pill, Consciousness Loop over live music, MiniPlayer |
| **Audio engine** | ✅ Background audio, interruption recovery, pause/resume sample-accurate, exclusivity coordinator, lock-screen metadata |
| **Visuals** | ✅ 9 element vocabularies + Cathedral (Tier 1–4) + Bindu Lissajous; ensemble/singular modes |

No `TODO`/`FIXME`/`HACK`/stub markers exist in source. This is a mature, coherent codebase.

---

## 4. Content state — the live Airtable audit (the big delta)

**34 records total** in `tblv3WvMZ90Sfhun6`: **22 loadable music/chakra/meditate/family tracks + 11 breath sessions + 1 orphaned record.**

### Reading-field fill (of 34 records)

| Field | Filled | Gap |
|---|---:|---|
| Seed Phrase | 33 | 1 missing (the orphan) |
| Recognition Statement | 25 | 9 seed-only tracks empty |
| Lyrical Words Reading | 25 | same 9 |
| Frequency Reading | 25 | same 9 |
| **Video Pulse Reading** | **0** | **universally empty** |
| Lalita's Perspective | 25 | same 9 |

### The 9 "seed-only" music tracks (no reading content authored)

`0 Faded` · `1 Sit Around The Fire` · `2 Dream` · `4 Opus` · `5 A Sky Full of Stars` · `8 Howling` · `10 Overthinker` · `14 Earth` · `22 Habits (Stay High)`

These load and play fine (binaural + visuals + verb), but the Player's READING sheet and the Loop's Fruit step fall through to generic defaults for them. They're all `music`/`meditate` type — the ambient layer, not the composed chakra dances.

### Fully-authored (25 records)

The 9 composed chakra dances (`23 Iron` → `31 Love Is the Only Thing`), plus `33 Genesis`, `34 Where'd You Go + Thunderclouds`, `35 In Shadow`, `36 Kingdom`, and **all 11 breath sessions** (`101–111`) carry complete Recognition + Lyrical + Frequency + Lalita prose. **Only Video Pulse is missing across the board.**

### ⚠️ Data-integrity findings (worth fixing at the source)

1. **Orphaned record `recYqGHG4sYRJDOSP` — the known `levelup` WIP row** ("Levels + Beautiful Now", Avicii / Zedd ft. Jon Bellion; a Family entry for "Rey"). Per the authoring skill's `content-registry.md` it was created in Session 8 with its full reading prose but **six catalog cells left pending: Track ID (suggested 37), Element, Track Type/Category = Family, Person = Rey, Artist, Beat Hz = 2.69** (the awakening signature). Because the iOS decoder requires `id`/`element`/`seed` as non-optional, it silently never loads until those cells are filled. Not junk — an unfinished intentional row. *(Parked per your call; tracked here and in STATUS.md.)*
2. **Polluted single-select options.** Several fields have cross-contaminated choices, presumably from mis-pastes:
   - `Element` also lists `chakra / meditate / music / family` (Track-Type values leaked in).
   - `Brainwave State` also lists `Earth / Water / Fire / … / Family` (10 leaked Element values). *(Note: `beta` here is NOT stray — a breath session uses it.)*
   - `Chakra` also lists `delta / theta / theta-alpha / alpha` (4 leaked Brainwave values).
   - `Track Type` has a stray `Active` choice.
   These don't break the app (the decoder reads the string), but they make the base error-prone to edit and would confuse any future automation. All the stray choices above are verified unused by any record. **The Airtable API cannot delete select choices**, so this cleanup must be done by hand in the Airtable UI (open each field → delete the stray options). Watch the lowercase-vs-capitalized trap on Element/Brainwave — the leaked duplicates are the odd-case-out ones.
3. **Two `multipleRecordLinks` fields** now link this table to `tblJlBeiHnqGpYrL7` (the App Activity ledger) — new, from the write-back feature.

---

## 5. New capability & new risk — the App Activity write-back

`e30c913` gives the app its **first write path to Airtable**. On the Consciousness Loop's `.lalita → .done` transition, `AirtableService.logAppActivity(...)` POSTs a *"Ceremony Sealed"* row to a shared **App Activity** table, with `Link to Field` pointing back at the catalog record (via `Track.recordID`, now captured at fetch time).

**Why this matters for the audit:**

- **The write uses `Secrets.airtableToken`** — the same PAT that ships compiled into the app binary (`Secrets.swift`, gitignored in the repo but present in the build; regenerated on CI from the `AIRTABLE_PAT` secret). A **read-only** embedded token is a modest risk; a **write-capable** one that can be extracted from a distributed IPA and used to write (or, depending on PAT scope, modify/delete) the base is a materially larger one.
- **Recommendation (decision needed, not a code fix yet):** before any TestFlight/App Store distribution, move writes behind a minimal serverless proxy (or a scoped, write-only automation endpoint) so the client never holds a broadly-scoped PAT. For a personal single-device build on "Neev," the current approach is acceptable — but it should be a conscious choice, documented.
- Error handling on the write is clean (fails silently on non-2xx, logs via `os.Logger`), and it's fire-and-forget `async`, so it won't block the UI. Good.

---

## 6. Known issues / technical debt (curated, most-actionable first)

Pulled from `docs/STATUS.md` and verified against source, plus this session's findings:

1. **Docs are stale** (§2, §4) — content-state claims and the four unlisted commits. Cheapest fix, highest clarity payoff.
2. **Embedded write-capable PAT** (§5) — the one item with an external-risk dimension.
3. **Orphaned + polluted Airtable data** (§4) — source-of-truth hygiene.
4. **Two `AVAudioEngine` instances both render to hardware with no master limiter.** By design (tone-over-music *is* the product), but a hot MP3 + high gain could clip. There's no shared output mixer / ducking / headphone-level governor — only surface exclusivity. A soft limiter on the summed output is a reasonable safety add.
5. **`OracleResponse.trackID` is `String` while `Track.id` is `Int`** — compared stringified at the call site. Works while the model returns a bare numeric; brittle. Type-tighten when convenient.
6. **Test target is scaffold-only** — zero real coverage. For an app this size the highest-value tests are pure-logic: `BreathProtocolMetadata.merge/resolveSafety` (fail-closed safety is security-adjacent), the `Track` backwards-compat decoder, DSP-wire gain curve, catalog cache "never overwrite with empty."
7. **Only Track 27 has an authored `Score`.** Every other track runs Performer in ambient mode (no phase/crescendo/climax). Mirror words are now Airtable-authored per-track (good), but the full Cathedral crescendo arc still only fires for one song.
8. **Breath-session source-of-truth is split** — `hue / oneLine / carrierTiers / beatTiers` still live in `BreathProtocolMetadata.all` (code), everything else in Airtable. Documented and deliberate; a future migration would consolidate.
9. **Breath sessions archive as `.chakra`-typed `Session`** (no `.breath` case) — cosmetic; blocks per-type filtering later.
10. **`MapDetailSheet` "track not yet linked" path is string-matched** (`track.chakra.rawValue.lowercased() == chakra.name.lowercased()`) — a stray space/typo in Airtable surfaces the unlinked copy. Needs a guardrail.
11. **On-device visual-fidelity QA still pending** for the 8 non-Air vocabularies and the Lab v3 / AKASH flows — they've shipped only against the design HTML, not verified on Neev.
12. **Xcode-26 Info.plist quirk** — `UIBackgroundModes = [audio]` lives in the root `Info.plist`, not the Capabilities UI. Re-verify with `PlistBuddy` after any Xcode upgrade.
13. **Song Phase Labels are authored but inert in-app (filled ≠ rendered).** All 14 scored songs have `Phase Labels` written in Airtable, but the iOS `Track` model has no `phaseLabels` field — only `BreathSession` decodes them and only `BreathReadingSpaceView` renders them. So the songs' phase-arc content never surfaces. **Fix is app-side:** add `phaseLabels: String?` to `Track` + a render path (a fifth Reading-sheet tab, or fold into an existing tab). The authoring skill (`content-registry.md`) also recommends a broader **breath field-mapping audit** — verify every populated breath field actually renders somewhere, since Phase Labels proved "filled ≠ rendered."

*Note: the authoritative per-record content state lives in the authoring skill's `references/content-registry.md` (record IDs + per-field ✓/✗), and the roadmap/frontiers in `references/next-horizons.md` (Gateway/Hemi-Sync mapping, astral-body sound fields, the 33-song "Sonar Ears" threshold, threshold sessions). This code-focused audit and those content-side docs agree on the numbers (14 songs + 11 breaths fully read).*

---

## 7. Deferred / not-yet-built (roadmap the codebase already anticipates)

- **Phase 7 — `LalitaEngine`** — the most sophisticated deferred piece: 3 phases, 6 mathematical pattern curves, background inversion from void → warm cream. Reference lives in `design_handoff_lalita_pass/`.
- **More authored `Score`s** — bespoke crescendo arcs beyond Track 27.
- **Video Pulse Reading content** — 0/34 authored.
- **The 9 seed-only ambient tracks' reading prose.**
- **`youtubeID`** is captured on `Track` but no "watch on YouTube" affordance exists yet.
- **`chakra` metadata on `Track`** retained for a future chakra-grouped Field filter/overlay — not consumed today.

---

## 8. My ideas for improvements

*Opinion, not gospel — grouped by how much they move the needle vs. how much they cost. Take the framing to chat and cut what doesn't fit the vision.*

### A. High leverage, low effort (do these first)

1. **Refresh the docs to current `main`** — correct the content-state claims, add the four missing commits to `SESSIONS.md`, update the "dark-mode-only" line now that light theming exists. Keeps future-you (and future Claude) from working off a false map.
2. **Fix the orphaned "Levels" record and clean the polluted selects** — one Airtable sitting, removes a whole class of silent bugs and edit confusion.
3. **Author the 9 seed-only tracks' Recognition Statements at minimum.** Recognition is the one line that shows in FIELD mode *and* feeds the Oracle's catalog knowledge — the highest-visibility field. Even without full Lyrical/Frequency/Lalita, a Recognition line lifts those 9 from "generic" to "seen."
4. **Add a soft output limiter** on the summed audio — a few lines of protection against clipping, purely additive safety.

### B. Medium leverage — content & intelligence

5. **Batch-generate Video Pulse Readings** for the tracks that have a `youtubeID`, using the same Reading-Space methodology already established. It's the last empty dimension and the tab already exists to hold it.
6. **Make the Oracle catalog-content-aware, not just metadata-aware.** It already receives Recognition Statements; now that Lyrical/Frequency prose exists for 25 tracks, feeding a compact digest could make recommendations dramatically richer. Watch the token budget — summarize, don't inline everything.
7. **Author 2–3 more full `Score`s** for the most-played chakra dances so the Cathedral crescendo arc isn't a one-song showcase. This is where the app's most ambitious visual writing already lives, under-used.
8. **Turn the new App Activity ledger into something the user sees.** Right now it writes silently. A gentle "your field" surface (streaks, sealed ceremonies, chakras danced over time) would close the loop and give the write-back a felt purpose — the Map already tracks danced state; this is the temporal companion to it.

### C. Structural / release-readiness

9. **Decide the PAT posture before wider distribution** (§5) — proxy the writes, or scope the token to write-only on a single table, or keep it personal-build-only and document that. This is the one thing that should gate a TestFlight invite to anyone but you.
10. **Seed a real test suite around the safety-critical logic** — `resolveSafety` fail-closed behavior, the `[105]` backstop, the catalog "never cache empty" guard, and the backwards-compat decoders. Small surface, high consequence.
11. **Add lightweight crash/os_log breadcrumbs** (no third-party SDK needed — you already use `os.Logger`) so on-device issues on Neev are diagnosable from Console without a debugger attached.
12. **Consider a `.breath` `SessionType`** so Archive can label and filter breath work distinctly — small model change, unlocks later archive richness.

### D. Bigger swings (only if the vision calls for them)

13. **Ship `LalitaEngine` (Phase 7)** — the deferred crown jewel of the visual system.
14. **Chakra-grouped Field overlay** using the `chakra` metadata already on `Track` — a bridge between the Map's topology and the Field's constellation.
15. **A "watch on YouTube" affordance** wiring up the captured `youtubeID` — cheap, and pairs naturally with the Video Pulse Readings from idea #5.

---

## 9. Suggested sequencing for the upgrade session

1. **Hygiene pass** (ideas 1–2): docs refresh + Airtable cleanup. ~1 sitting, unblocks accurate reasoning for everything after.
2. **Content pass** (ideas 3, 5): Recognition lines for the 9 + Video Pulse for the video tracks. This is *the* frontier — the app is built; it's hungry for words.
3. **Release-readiness pass** (ideas 9, 10, 4): PAT decision + safety tests + limiter. Gate for sharing beyond Neev.
4. **Depth pass** (ideas 6, 7, 8, 13): richer Oracle, more Scores, the "your field" surface, LalitaEngine — the "make it sing" work.

---

*Recon sources: `bindu-field` skill · `CLAUDE.md` + `docs/{STATUS,UI,AUDIO,DATA-LAYER,BREATH-SESSIONS,DESIGN,SESSIONS}.md` · git log/diffs · live ASG Airtable base `app248ZTWhYJlvQj2/tblv3WvMZ90Sfhun6` (34 records, schema + fill audited). Build not re-compiled this session.*
