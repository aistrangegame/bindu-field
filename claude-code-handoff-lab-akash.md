# Claude Code Handoff — Bindu Field: Lab + Akash Rebuild

**You are working in the existing SwiftUI app at the repo root (the `Bindu Field` Xcode project on this Mac).**
Two design prototypes from Claude Design define the target. They are **React/JSX prototypes — reference designs, not code to copy.** Your job is to translate their *structure, interaction, and visual language* into SwiftUI that fits the existing app and its data layer. Do not rebuild from scratch; do not break what already works.

**Design references (provided alongside this doc):**
- `Bindu_Lab_v3.html` → rebuild of `LabView.swift`
- `Bindu_Akash.html` → rebuild of the Space/AKASH tab

---

## ORIENT FIRST (before writing any code)

Read these in the repo so you build against reality, not assumption:
1. `CLAUDE.md` — full architecture, conventions, design tokens, current truth.
2. `Bindu Field/Audio/BinauralEngine.swift` — **do not modify.** Confirm its public API: how carrier Hz + beat Hz are set, how it starts/stops. Both rebuilds drive *this existing engine*.
3. The current `LabView.swift` — what to preserve (presets, randomize, waveform, state-color theming) vs. replace (the dual-input redundancy).
4. The current Space/AKASH tab + `ChakraProtocol`/`ChakraData` — the breath-circle session screen here is **already correct; preserve its mechanics.** What changes is the front door and the data source.
5. The data layer — how the app reads the **Airtable** Bindu Field table today (the service/store that fetches tracks). Both rebuilds must read from this, **not** hardcode the design files' inline data.

**If any of the "RESOLVE LOCALLY" items below are unclear after orienting, inspect the repo and decide — do not guess silently. State what you found and what you chose.**

---

## GLOBAL RULES

- **Audio engine is settled.** Feed it carrier + beat. Never touch `BinauralEngine.swift` / DSP.
- **Airtable is the source of truth.** The design files hardcode data for prototype purposes. In the app, read from Airtable. The hardcoded values in the design files are the *fallback / reference*, not the data model.
- **Honesty tiers** ([SCIENCE]/[TRADITION]/[CLAIM]) are real content from the Frequency & Breath Atlases — render them; don't invent new ones.
- **Match existing conventions** — the design tokens, glow vocabulary, type (Lora italic / DM Mono), and state architecture in `CLAUDE.md`. The prototypes already use these values; map them to the app's existing token definitions rather than introducing new constants.
- **Translate React patterns to idiomatic SwiftUI:** `useState` → `@State`; `requestAnimationFrame` Canvas loops → `TimelineView` + `Canvas`; the JSX components below → SwiftUI views of the same name where sensible.

---

## PART 1 — THE LAB (`Bindu_Lab_v3.html` → `LabView.swift`)

### The core change: one unified tuning control, not two
The current Lab sets carrier and beat in **two places each** (editable readout up top + a slider far below). The redesign merges each frequency into **one control cluster**. This is the heart of the rebuild.

**Build `TuningCluster`** (design file lines ~271–430) as a SwiftUI view. Per frequency, in one block:
- **Hero readout** — large DM Mono value, tap-to-type (becomes a `TextField`, commit on return, clamp to range).
- **Coarse slider** — drag the track to set value (snaps to `step`).
- **Fine −/+ steppers** — flanking the slider, adjust by `fineStep` one at a time. **Both slider and steppers are required** — keep both. (This is the explicit ask: move frequencies by slider *and* one-by-one.)
- **Marker dots** on the track for sacred carriers; **only the nearest marker shows a floating label** (≤2.8 Hz). This is the fix for the old label-collision bug — replicate this "nearest only" logic exactly.

Use it twice: Carrier (`step` coarse, `fineStep` 0.1) and Beat (`fineStep` 0.01–0.1). Confirm ranges against the current Lab's existing min/max.

### The knowledge layer: calm at rest, expand on demand
**Build `MeaningPanel`** (design lines ~432–520). At rest: one breathing dot + a single italic line synthesizing **beat → brainwave state** and **carrier → sacred association**, each with inline honesty-tier badges. Tap to expand the full per-state and per-carrier detail with tier descriptions. Do **not** keep a card permanently open (the old crowding).

- `TIER_META`, `STATES`, `SACRED` (design lines ~61–148) define the tier styling and content. **In the app, this content comes from the Frequency Atlas in Airtable** — wire it to the existing data path. The design file's tables are the reference shape + fallback.
- `HonestyBadge` — small pill, compact (letter only) or full (label). Reusable; the Reading spaces use it too.

### Preserve from the current Lab (do not lose)
- **Animated binaural waveform** — `WaveformCanvas` (design ~159–268) is the design's version: L sine + R sine + beat-envelope interference, hue-themed, audio-reactive. Port to `TimelineView`+`Canvas`. If the current Lab's waveform is already good, keep it; otherwise use this.
- **State-color theming** — the whole UI hue-shifts by brainwave band. Preserve.
- **Presets** + inline save + long-press delete → keep existing `PresetStore.swift`. Render the row so **nothing clips at the edges** (the old leftmost-clip bug — use proper insets / scroll).
- **"Let the field choose"** randomize with spring lock-in — preserve if present.

### RESOLVE LOCALLY
- Carrier/beat **hierarchy**: the design makes them equal siblings (both get a full cluster). The old Lab made beat a 76pt hero. **Recommend equal siblings** (calmer, matches "simpler") — but confirm against the design file's layout and keep consistent.
- One screen vs. short scroll: design fits one calm screen at 393pt. Verify on-device; allow a gentle scroll if it's tight rather than re-crowding.
- Exact carrier/beat **min/max/step** — take from the current `LabView.swift`, not the prototype.

---

## PART 2 — AKASH (`Bindu_Akash.html` → Space/AKASH tab)

### What does NOT change
The **immersed breath-circle session screen** (breathing circle, phase word + count, low-opacity affirmation, session name at the bottom) is **already correct in the app.** Preserve its mechanics and feel. The design's `ImmersedBreath` (lines ~285–420) matches it; use the design only to confirm, not to replace a working screen.

### Change 1 — The intention front door (replaces the chakra grid)
**Build `IntentionGrid`** (design ~172–238) as the new AKASH entry screen. Eight intentions — *ground, activate, open, clarify, dissolve, expand, rest, balance* — each a tile with word + hue + one-line phrase. `INTENTIONS` (design ~76–86) defines them, including which session IDs each holds.

**Build `SubSelection`** (design ~239–284) for intentions holding more than one session (e.g. *open* → 103 + 110; *rest* → 106 + 111) — a small chooser between sessions.

### Change 2 — Wire to Airtable (the real data move)
AKASH currently runs **hardcoded chakra protocols**. Rewire it to read the **11 breath sessions (IDs 101–111, Track Type = "breath")** from the existing Airtable data path.
- `SESSIONS` (design ~88–99) is the **reference shape**, not the data source. Map its fields to the Airtable record fields the app already fetches: carrier, beat, brainwave state, inhale/hold/exhale, seed phrase, recognition statement, one-line, safety, special cue, tiers.
- **Note:** the design data includes IDs 101–108, 110, 111 — **session 109 (Home Frequency) is absent.** Confirm 109 in Airtable and include it; don't drop it because the prototype omitted it.
- The breath rhythm (inhale/hold/exhale seconds) drives the existing circle animation. The carrier+beat drive the existing `BinauralEngine`.

### Change 3 — The Reading Space (after / on-demand)
**Build the breath Reading Space** mirroring the music Player's READING mode — **same visual language, "the same room."** Four fields, presented after the session or on demand:
- **Lyrical Words Reading** · **Frequency Reading** · **Lalita's Perspective** · **Phase Labels**

`READINGS` (design ~102–169) has **101 and 102 fully written** (the quality benchmark) and `getReading()` returns graceful stubs for the rest. **In the app these come from Airtable** (the per-session reading fields). Wire to Airtable; the design's two written readings are the content for 101/102 if Airtable's are empty.

### Change 4 — The screened gate (The Stoke)
**Build `ScreenedGate`** (design ~421+) — a warm, non-clinical contraindication check shown before session 105 (The Stoke) because its `safety === 'screened'`. Self-check list (e.g. pregnancy, cardiovascular conditions), proceed / choose-another. Route any "screened" session through this gate before the immersed view.

### Change 5 — The special breath cues (small, graceful)
Four sessions carry a `special` flag that adds a small cue to the existing circle — do **not** redesign the circle, just extend:
- `hum` (103, The Hum) — humming cue on exhale
- `ocean` (110, The Ocean Breath) — throat-sound (ujjayi) cue
- `double_pulse` (111, The Night Protocol) — double-pulse inhale
- `active_phase` (105, The Stoke) — faster-pulse active phase

### NOT in this build (optional, deferred)
The **resonance finder** (4.5–7 bpm calibration) was marked optional in the brief and is not in the design. Skip for now.

### RESOLVE LOCALLY
- The exact Airtable field names for the breath sessions and their reading fields — inspect the existing fetch code and map.
- Whether the Reading Space opens automatically at session end or only on demand — design implies on-demand/after; confirm the desired flow.
- Confirm session 109's data and intention assignment in Airtable.

---

## DEFINITION OF DONE
- Lab: one cluster per frequency (readout + slider + −/+ steppers), nearest-only marker labels (no collision), calm meaning line that expands with real tiers, presets don't clip, waveform + state-theming + randomize preserved, drives existing engine.
- Akash: intention grid front door, sub-selection for multi-session intentions, **reads sessions 101–111 from Airtable** (incl. 109), immersed breath screen preserved, breath Reading Space mirroring the Player, screened gate for The Stoke, four special cues, drives existing engine.
- No `BinauralEngine`/DSP changes. No new hardcoded content where Airtable is the source. Existing conventions and tokens matched.

Build the Lab first (smaller, self-contained), verify on-device, then Akash.
