# UI subsystems

Full per-tab behavior, the Player modal three-mode architecture, the Map, the Consciousness Loop, and the 9 element vocabularies.

---

## Tabs (full)

`RootView.swift` — `TabView` over `NavigationStore.selectedTab` (tags 0–7). Programmatic switch via the store (e.g. long-press the central Bindu in Field → tab 2 Oracle). **iOS auto-collapses tabs 5–7 (Lab, Ritual, Letter) into the More menu** because the primary array exceeds 5.

Tab glyphs are custom 28×28 SwiftUI Canvas drawings (`Views/Components/BinduTabIcons.swift`) — concentric geometry, sparse strokes, no fills beyond a central dot. They replace the SF Symbols used pre-Session-B. The same `BinduTabIcon.Tab` enum covers all 8 tabs; cream color travels through `BinduTabIcon.color`, active state = full opacity, inactive = 0.40.

| Tag | Tab | Composing views | Behavior |
|---|---|---|---|
| 0 | **Map** | `MapView` → `MapDetailSheet` (`.sheet`, fraction 0.55) | The front door. 33 chakra nodes on a 393×780 design canvas scaled to device. Connections drawn as element-tinted quadratic curves (both-lit = 0.18 opacity gradient between hues; either-lit = 0.09 cream; neither-lit = 0.045 cream). Nodes render in three states: **locked** (tiny cream-0.18 dot, smaller for tier 3, larger for tier 2), **available** (composed in `ChakraProtocol` but not danced — element-hued core + breathing aura, ~9pt radius), **danced** (~11pt core + two breathing orbit rings + denser aura). Tap a node → `MapDetailSheet` with `system` + `state` badges, the chakra name + Sanskrit, the essence line, and a state-aware CTA: ENTER THIS DANCE / DANCE AGAIN (when a Track exists for that chakra) · "this dance has not yet been composed" (locked) · "track not yet linked to catalog" (composed but no Track). Tap on CTA → `PlayerStore.play(track)`. |
| 1 | **Field** | `FieldView` → `PlayerView` (`fullScreenCover`) | Golden-angle Fibonacci sphere of 22 orbs. Filter chips (all / delta / theta / theta-alpha / alpha). Drag to spin around Y. Tap an orb → play. **Three orb states**: playing (existing pulse) · played-before (full opacity + 1.4× inner glow ring at 0.25 — "you've been here") · never-played (0.55 opacity). **Depth fog**: 0 front → 1 back via normalized `rzz`; opacity × `(1 − depth × 0.5)`, radius × `(1 − depth × 0.2)`. **Verbs labelled below front-hemisphere orbs** (italic serif, 9pt, opacity tracks the orb's fog factor so labels dim with the orb). **Element lines**: 0.07 opacity / 0.5pt stroke between same-element pairs both in the front hemisphere. **Central Bindu**: animated #E5524E core + radial glow, breathes at ~0.1 Hz; **long-press 0.6s → tab 2 (Oracle)** with first-launch "hold for Oracle" serif tooltip. Loading + offline-cache states surfaced as captions; an inline "refresh catalog" capsule appears when the catalog failed with no cache to fall back on. |
| 2 | **Oracle** | `OracleView` (drives `OraclePresenceModel` consumed by `OraclePresenceView`) + `SettingsView` sheet | Four-state void: **idle** (centered "THE ORACLE" + ◌ glyph fade in after 2.2s — tap to begin), **typing** (a 26pt italic-serif TextField centered in the void, cancel top-right), **waiting** (3 breathing dots; a "cancel" capsule appears after 15s so a hung request can be aborted), **response** (track verb @ 72pt in element color → song → why → ENTER THE FIELD + "ask again" — staged arrival at 0.4/2.2/3.4/5.6s). `OraclePresenceView` renders a single drifting radial fog at 14s breath cycle behind every state — neutral warm fog when idle, element-hued fog once a response arrives. POSTs to `api.anthropic.com/v1/messages` (`claude-haiku-4-5-20251001`) with full catalog inlined + recently-played track IDs as a deprioritize hint. The in-flight Task is genuinely cancellable; the cancel button throws CancellationError out of `try await` and returns to idle without an error banner. Empty state if no Keychain key (ADD API KEY capsule raises Settings sheet). |
| 3 | **AKASH** (tab label) / `SpaceView` (file) | `SpaceView` orchestrator → `IntentionGridView` → `SubSelectionView` (multi-session intentions) → `SessionDetailView` → `ScreenedGateView` (only when `safety == .screened`) → `BreathImmersedView` (`audioSource: .space`) ↔ `BreathReadingSpaceView` | **Front door is the intention grid**, not the chakra grid. Eight tiles (ground/activate/open/clarify/dissolve/expand/rest/balance); multi-session intentions show a `N sessions` hint and route through `SubSelectionView`. Today: `.open` → [103, 110]; `.rest` → [106, 111]; `.balance` → [102, 109]. Reads the 11 breath sessions (IDs 101–111, Track Type = `breath`) from Airtable via `BreathSessionStore` on first appear; offline banner if the cache is stale or empty. `SessionDetailView` shows the session name, one-line, recognition statement, breath-cycle blocks (inhale/hold/exhale seconds from Airtable with seed-fallback), frequency lines with inline `HonestyBadge` pills, duration chips (3/5/10/15 min), seed phrase, Begin. `ScreenedGateView` fires when `safety == .screened` (105 The Stoke today, with the [105] backstop set guarding against bad Airtable edits) — a warm, non-clinical self-check; selecting any condition surfaces a gentler-alternative suggestion (names The Long Release for 105); user can always proceed. `BreathImmersedView` mirrors `SpaceImmersedView`'s breath-circle mechanics and adds: mid-session recognition fade (~45% through, 4s window), session name + seed at the bottom, READ capsule (bottom-right) to open Reading Space, special-cue italic-serif line under the circle on the relevant phase, and phase-word override (`mmm` for `.hum`, `haaa` for `.ocean`). `BreathReadingSpaceView` mirrors the music Player's READING mode — four tabs (WORDS · FREQUENCY · LALITA · PHASES); FREQUENCY auto-styles inline `[SCIENCE]`/`[TRADITION]`/`[CLAIM]` paragraphs as tier cards; tier legend at the bottom. Saves a `.chakra`-typed `Session` on exit (skipped if < 5s) — the archive type is unchanged because the session model has no `.breath` case today. The legacy `SpaceSetupView.swift` remains in source but is not on the AKASH path; `RitualRunningView` continues to use `SpaceImmersedView` (chakra-driven) for chained chakra rituals. |
| 4 | **Archive** | `ArchiveView` (+ `SettingsView` toolbar sheet) | Sessions grouped by full date (descending), each row shows verb-or-Sanskrit, song/artist-or-English-center, optional Integration note ("…" in serif italic at `subtle`), duration mono and short-time. Empty state if none. Settings cog top-right. |
| 5 | **Lab** | `LabView` | Top: header dot + "frequency lab" italic + "craft your own permission slip" caption. **Animated binaural waveform** (`BinauralWaveformView`) — 96pt Canvas drawing L (cream 0.14) + R (state-hued 0.38) + bright beat envelope; ghost wave when inactive. **`TuningCluster` × 2 — the heart of the rebuild.** Each cluster (Beat first, then Carrier) is one block: label + **hero readout** (40pt DM Mono, tap-to-type via decimal pad — clamped to 0.5–44 / 40–440), draggable slider with sacred-carrier markers (Carrier) or `δ/θ θ/α α/β β/γ` zone-boundary markers (Beat), and **flanking ± steppers** sized to match the readout precision: carrier reads 1 decimal and steps by **0.1 Hz**; beat reads 2 decimals and steps by **0.01 Hz**. The slider snap step is 0.1 for both — slider is the coarse control, steppers are the precise one (a user can tap their way to 136.1 / 2.69 without falling back to the keyboard). Only the **nearest marker** within 2.8 Hz renders a floating label, so labels never collide (the explicit fix for the prior label-collision bug). State-color theming travels through `BrainwaveStateInfo`: delta=15°, theta=260°, alpha=210°, beta=165°, gamma=50°. **`MeaningPanel`** — calm at rest, one italic-serif line that synthesizes beat→state and carrier→sacred with inline letter-only `HonestyBadge` pills; tap to expand the full per-state detail + per-carrier detail + tier legend. **"let the field choose"** — weighted-state randomize (δ12/θ33/α37/β13/γ5%) + sacred-carrier ±0.5 jitter + 10-step animated cycling + spring lock. Preset row + inline save + long-press delete preserved (leading/trailing spacer fixes the old first-chip clip). **Audio exclusivity**: claims `.lab` on ACTIVATE, releases on stop. Listens for `.binduLabStop`. No Archive entry (by design). |
| 6 | **Ritual** | `RitualView` → `RitualSetupView` ↔ `RitualRunningView` (reuses `SpaceImmersedView` with `audioSource: .ritual`) | Build a queue of chakra steps (drag to reorder, swipe to delete, tap mins chip to cycle 3/5/10/15). Requires ≥2 steps to start. Running view chains `SpaceImmersedView` with `ritualProgress: (current, total)`. Advances on natural completion, exits on cancel. The `.ritual` audio claim lets a Field track or Lab tone evict the ritual cleanly via the coordinator. |
| 7 | **Letter** | `LetterView` → `LetterRecordView` / `LetterPlaybackView` | List of Sound Letters. Recorder: 4 phases (setup → 3-2-1 countdown → recording w/ red pulse meter → review/title). Optional binaural underlay (delta/theta/alpha/silent) plays while recording so the speaker hears it through headphones. Playback: optional binaural re-layer when `letter.beat > 0`. Share via `ShareLink`. `interactiveDismissDisabled` during countdown/recording. Orphan-m4a cleanup if user swipes away in review without saving (B14). |

---

## Player modal (PlayerView) — three modes of being

Presented as `fullScreenCover` from `RootView` whenever `PlayerStore.isPresentingPlayer == true`. Three modes — `field` / `control` / `reading` — drive layout via a `PlayerMode` enum; transitions use spring `response: 0.45, damping: 0.85`. The field never stops; the Bindu always moves.

The background is no longer pure void: `PlayerView.background` reads `ElementVocabulary.forTrack(track).bg` and renders the vocabulary's element-tinted near-black. The visualizer (`VisualizerView`) reads the same `forTrack` mapping and dispatches to one of nine vocabulary draws — Air goes to the Cathedral, everything else goes to a `drawX(in:size:t:intens:)` from `VocabularyRenderer.swift`. The Bindu Lissajous always renders on top.

### FIELD mode (default on arrival)
- VisualizerView at full width × 60% screen height, top-anchored. Renders the vocabulary appropriate to the track (Air→Cathedral with all four tiers + ensemble archetypes; every other element→its own draw function) + the Bindu Lissajous on top — or just the Bindu Lissajous when `vizMode == "singular"`.
- Top status-bar gradient: always-on 88pt fade (theme.bg @ 0.80 → clear) for legibility over vocabulary layers that reach the top.
- Bottom viz→bg gradient: FIELD-mode-only fade at 48% of screen height, 86pt tall (clear → theme.bg) — softens the visualizer's lower edge into the background where the verb floats.
- Field content overlay: 62pt ultraLight serif italic verb in element color with element-color glow shadow, song · artist subtitle, optional recognition statement in curly quotes — text block anchored via `.padding(.top, geo.size.height * 0.59)` so the verb floats over the dissolving lower edge.
- **BEGIN THE LOOP** capsule sits below the recognition statement (11pt tracked label, element-color stroke). Opens the 7-step Consciousness Loop as a `fullScreenCover` over the player; music continues underneath.
- Slim "flowing" scrubber pinned to the screen bottom (read-only, 2pt, percent + label).
- Tap anywhere on the background → CONTROL. **Swipe down > 60pt on the FIELD background → `store.closePlayer()`** (the swipe-to-minimize is the only top-bar-less gesture path back out).

### CONTROL mode (55% bottom sheet)
- Visualizer shrinks to 45% screen height and dims to opacity 0.55.
- `UnevenRoundedRectangle` top corners 32pt, near-opaque dark panel + `ultraThinMaterial.opacity(0.25)` + 1pt cream-0.07 stroke.
- Drag handle → 56pt play/pause circle (wired to `TrackPlaybackService.togglePlayPause`) → **BINAURAL** section with custom 44×24 toggle + ON/OFF label + breathing dot (`scaleEffect 1.0↔1.25` over 2s while `wire.binauralEnabled`) → PRESENCE slider → BEAT slider with Δ/Θ/α zone ticks + state badge → CARRIER readout with sticky DERIVED / AUTHORED chip (driven by `wire.hasDerivedCarrier`).
- Bottom row: READING + END SESSION capsules.
- 4-second auto-hide returns to FIELD; every touch inside the sheet resets the timer via a `simultaneousGesture(TapGesture())`.
- Tap above the sheet (top 45% of screen) → returnToField.

### READING mode (80% bottom sheet)
- Visualizer shrinks further to 20% screen height, opacity 0.32.
- Recognition statement at top in 17pt element-color serif italic with element-color glow.
- 4-tab bar with element-color underline on the active tab: **WORDS** (`track.lyricalWordsReading`) · **FREQUENCY** (live structured rows: State / Beat / Carrier / Element / Breath — derived from `ChakraData.all[chakra]?.inhale/hold/exhale`; plus `track.frequencyReading` prose if present) · **VIDEO** (`track.videoPulseReading` or placeholder card) · **LALITA** (`track.lalitasPerspective` or "the Lalita reading for this song is still forming…" placeholder).
- `ReadingContent` helper splits paragraphs on blank lines and surfaces the closing paragraph in element color with a hairline top-rule.
- Tap above the sheet (top 20%) → CONTROL.

### Binaural pill (status indicator, anchored top)
- 56pt from the top. Pure status indicator — a single `Button { enterControl() }` showing only: 6pt dot (filled element-color when binaural is on, outlined when off, breathing 1.0↔1.25 at 1.3s ease-in-out) + "BINAURAL" label + "›" chevron. No expansion, no toggle, no slider — those live exclusively in the CONTROL sheet.

### Top-right X close
- 36×36 button at top-right with a 28pt black-0.25 disc behind a 12pt `xmark`. Always visible across all three modes (sits above the centered pill). Calls `store.closePlayer()` — full session teardown. The disc backing keeps the icon legible against bright vocabulary regions (e.g. Air's rising arches, Shweta crystallization).

### Integration Chamber
- Black/0.78 overlay, "what did you remember?", multi-line `TextField`, close / save-note capsules, 30s auto-dismiss. Only raised on natural playback completion — user-initiated stops do NOT trigger it. Saved note attaches via `PlayerStore.pendingNote` and renders in Archive rows.

### Arrival ceremony
- Content opacity 0→1 + scale 0.96→1.0 over 0.6s easeOut on appear.

---

## The Map (33-chakra tree of life)

The conceptual front door. Replaces the old "Field as front door" mental model — Field is now the constellation of *tracks*, Map is the topology of *consciousness*.

- **Data**: `ChakraRegistry.all` is a static array of 33 `ChakraNode` structs, organized by `ChakraSystem` (`.energy` 7 · `.body` 10 · `.mind` 9 · `.tree` 7). Each node carries hue, canvas coordinates in a 393×780 design space, tier (1–4, locked-node radius), essence, and Sanskrit Devanagari. `ChakraRegistry.connections` is the directed edge graph — 50+ tuples wiring the four systems together.
- **State per node** (`ChakraJourneyStore.state(for:)`):
  - `.locked` — not in `composedIDs`. There's no authored dance for this chakra yet.
  - `.available` — in `composedIDs` but not in `dancedIDs`. The user has access but hasn't entered.
  - `.danced` — the user has completed a session for this chakra. Persisted in `binduJourney.v1`.
- **Marking danced**: `PlayerStore.finalizeCurrentSession` calls `ChakraJourneyStore.shared.markDanced(track.chakra.rawValue.lowercased())` *only when the session completed naturally* (the Integration Chamber close path). User stops do not advance the journey.
- **Tap behavior**: Locked nodes are tappable too (hit radius 12pt vs lit-node 28pt). The MapDetailSheet's copy distinguishes "this dance has not yet been composed" (locked) from "track not yet linked to catalog" (composed but no Track in the Airtable catalog).
- **The 9 composed chakras**: `sahasrara, ajna, vishuddha, anahata, manipura, svadhisthana, muladhara, maya, aatma`. These are the same 9 that ship in `ChakraData.all` — the registry's `composedIDs` set is the authoritative overlap.

---

## The Consciousness Loop (7-step ceremony)

A bounded ritual presented as a `fullScreenCover` over the PlayerView. Music continues underneath; the coordinator does not touch playback. Triggered by the BEGIN THE LOOP capsule in PlayerView's FIELD mode.

`Stores/ConsciousnessLoopCoordinator.swift` owns the state machine (`LoopState` enum: `idle → preRoll → seed → offering → dance → reveal → fruit → lalita → done`). `Views/Loop/LoopHostView.swift` dispatches to one of seven step views in `Views/Loop/LoopStepViews.swift`.

| Step | View | Behavior |
|---|---|---|
| 1 · Pre-Roll | `PreRollStepView` | A 5.5s breath ring at the element hue. After one full inhale → exhale cycle a "tap to enter" affordance fades in. |
| 2 · Seed | `SeedStepView` | "What word has been waiting in you?" rendered in serif italic. Tap to advance. |
| 3 · Offering | `OfferingStepView` | A blank field for the user to type one word. Bound to `coord.offeredWord`. Tap submit to lock. |
| 4 · Dance | `DanceStepView` | Flashes mirror words sequentially — uses `Score.mirrorWords` if the track has an authored score, otherwise the coordinator's 5-word default `["return", "listen", "open", "soften", "trust"]`. |
| 5 · Reveal | `RevealStepView` | The user's offered word displayed large, in element color. Tap to advance. |
| 6 · Fruit | `FruitStepView` | Three paragraphs derived from `track.lyricalWordsReading` (split on blank lines, prefix-3) or generated defaults that name the offered word. |
| 7 · Lalita | `LalitaStepView` | A single closing line — `track.lalitasPerspective` or fallback "I see you. You have always been here." Tap close to end. |

**Vocabulary background**: `LoopHostView` draws the track's vocabulary (via the file-level `drawX(in:size:t:intens:)` helpers) behind a Color.black-0.55 veil. Opacity ramps per step — 0 on the first three (the words breathe), 0.55 on dance, 0.85 on reveal, 0.45 on fruit, 0.25 on lalita. Air's full Cathedral is too much for a backdrop, so it falls through to `drawAmbient(..., hue: 195)`.

A step indicator (top-left) and chakra+song corner info (top-right) decorate every step. A "close" capsule sits bottom-right at all times — the ceremony is always escapable.

---

## Element vocabularies (9 visual languages)

The visualizer is no longer Cathedral-only. `Views/Player/VocabularyRenderer.swift` (1014 lines) is a switchboard of `drawX(in:size:t:intens:)` functions, one per element. `ElementVocabulary.forTrack(track)` maps the Airtable element string + a Track-27 override to a vocabulary id; `VisualizerView` dispatches inside its `Canvas` after computing intensity from Performer state.

| Vocabulary | Element string(s) | Render concept |
|---|---|---|
| `.earth` | "Earth" | Layered terracotta strata; slow tectonic motion. |
| `.water` | "Water" | Flowing horizontal currents; surface ripples react to RMS. |
| `.fire` | "Fire" | Particle plumes rising; intensity drives flame height + saturation. |
| `.air` | "Air" | **The Cathedral** — Tier 1 floor/columns/vault/grain/Gaia + Tier 2 Arch/Sakshi + Tier 3 rising arches/convergence + Tier 4 keystone cascade/earth-rising/Shweta + ensemble Karishma/Ashrey/Neev. The lalita-pass renderer is now just one element. |
| `.ether` | (Track 27 override; otherwise none) | Vishuddha's throat vocabulary — concentric crystalline shells. |
| `.constellation` | "Light" | Ajna's vocabulary — sparse points in a sparse field, connected on RMS edges. |
| `.crown` | "Crown" | Sahasrara — radial petals breathing outward. |
| `.soul` | "Soul" | Aatma — deep violet drifting bands. |
| `.dissolution` | "Dissolution" | Maya — desaturated cyan fade fields. |
| `.meditate`, `.family` | "Meditate" / "Family" | Ambient draw at the vocabulary's hue (no specialized world). |

Each vocabulary exposes `.bg` (an element-tinted near-black) and `.hue`. `PlayerView.background` reads `vocab.bg`; `LoopHostView`'s background reads from the same dispatch.

Track 27 (Sound of Silence) is special-cased: labeled "Air" in Airtable but routed to `.ether` because its visual world belongs to Vishuddha.

`drawVocabBindu` is the still anchor at the center of every vocabulary — a 5.5pt element-hued dot with a 32pt aura and a 0.65 + 0.35sin(t·1.15) breath modulation. The Bindu Lissajous in `VisualizerView` overlays its own audio-reactive Bindu on top.

`vizMode == "singular"` skips all vocabulary draws and the Cathedral entirely — only the Bindu Lissajous renders. Background still flows from `vocab.bg` so the element breathes through. Singular ↔ ensemble transitions clear the Ashrey trail and the grain particle buffer so a return to ensemble doesn't briefly paint stale data.
