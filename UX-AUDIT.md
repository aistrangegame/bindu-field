# UX Audit — Bindu Field

Audit date: 2026-05-20. Covers every file under `Bindu Field/Views/`.
Read-only. No code changed.

---

## 1. Readability

Criteria flagged: text under 11pt **and** opacity below ~0.28, OR any text whose
effective opacity (foreground color × multipliers) is so low it disappears on
device. Sizes in pt. "Effective opacity" = base color alpha × any `.opacity()`
on the Text view. Theme tokens: `subtle = 0.28`, `muted = 0.55`.

### Unreadable (effective opacity < 0.20 at small size)

- `Player/PlayerView.swift:268-272` — recognition statement at **13pt / opacity 0.12** over the visualizer in FIELD mode. *The Bindu Pass design's signature copy is unreadable.* The same statement is rendered at **17pt / element color** (legible) in the READING sheet header at L805, so the unreadable copy is the one the user lands on first.
- `Player/PlayerView.swift:284-294` — "BEGIN THE LOOP" capsule at **8.5pt, tracking 3.0, opacity 0.55 × elementColor**. The primary path into the ceremonial Loop is the tiniest button in the app.
- `Player/PlayerView.swift:376-379` — % readout at **9pt** monospaced at `theme.subtle.opacity(0.55)` ≈ **0.154 effective**. Progress percentage is invisible.
- `Player/PlayerView.swift:487-490` — "BINAURAL" section label, **9pt** at `subtle.opacity(0.6)` ≈ **0.168**.
- `Player/PlayerView.swift:722-727` — Δ / Θ / α zone labels under BEAT slider at **8pt** at `subtle.opacity(0.55)` ≈ **0.154**.
- `Player/PlayerView.swift:701-715` — brainwave badge ("DELTA"/"THETA"/…) at **8pt** with `tracking 1.4`. Legible only because of the tinted background pill, but borderline.
- `Player/PlayerView.swift:750` — "DERIVED" chip at **8pt**.
- `Player/PlayerView.swift:1234-1237` — FrequencyRow labels at **9pt** at `theme.subtle` (0.28). Borderline.
- `Tabs/LabView.swift:337-341` — "0.5–4 Hz · brainwave band" at **9pt** at `subtle.opacity(0.7)` ≈ **0.196**.
- `Tabs/LabView.swift:471-473` — sacred-frequency dot labels (OM, 174, 285, UT, RE, 432, 440) at **7pt** monospaced, `tracking 0.4`, at `subtle.opacity(0.5)` ≈ **0.14** when not the hit. The whole calibration legend is unreadable until a hit lights it.
- `Tabs/LabView.swift:498-502` — "PRESETS" header at **9pt** at `subtle.opacity(0.55)` ≈ **0.154**.
- `Tabs/LabView.swift:653-657` — sacred badge name (OM, UT, RE…) at **8pt** at element color × the tinted pill. Readable but tiny.
- `Tabs/OracleView.swift:212-219` — "THE ORACLE" idle label at **7pt, tracking 5.0, opacity 0.14**. The only persistent affordance is barely visible.
- `Tabs/OracleView.swift:227-232` — ◌ glyph at **9pt opacity 0.10**. Visual hint for "tap to enter typing" is invisible.
- `Tabs/OracleView.swift:170-174` — no-key state's "THE ORACLE" at **8pt opacity 0.20**.
- `Tabs/OracleView.swift:259-263` and `Tabs/OracleView.swift:362-366` — top-left "THE ORACLE" in typing + response states at **7.5pt opacity 0.20**.
- `Loop/LoopStepViews.swift:121-124` — "tap to enter" affordance at **8pt opacity 0.22**, only after a 6s delay.
- `Loop/LoopStepViews.swift:170-176` — "tap to offer" at **7.5pt opacity 0.18**.
- `Loop/LoopStepViews.swift:319-325` — "tap to continue" in Dance step at **7pt opacity 0.18**.
- `Loop/LoopStepViews.swift:470-477` — "tap to continue" in Fruit step at **7.5pt opacity 0.16**.
- `Loop/LoopStepViews.swift:532-536` — "close the loop" at **7.5pt opacity 0.20**.
- `Loop/LoopStepViews.swift:445-453` — FRUIT step word header at **9pt** at hue × **opacity 0.35** (effective ≈ 0.21).
- `Loop/LoopHostView.swift:147-153` — step name ("PRE-ROLL", "SEED", …) at **7pt** at hue × **opacity 0.45**.
- `Loop/LoopHostView.swift:186-198` — chakra label at **7.5pt opacity 0.35**, track title at **7.5pt opacity 0.18**.
- `Loop/LoopHostView.swift:97-102` — corner "close" affordance at **9pt opacity 0.30**. The Loop's only escape is camouflaged into the void.
- `Map/MapView.swift:43-49` — "THE MAP" header at **8pt opacity 0.20**; "a body has thirty-three doors" at **11pt opacity 0.30**. Borderline.
- `Map/MapDetailSheet.swift:37-46` — system + state badges at **8pt** with `tracking 2.4`. "DANCED" at element soft × 0.75 reads; "LOCKED" at `0.25` does not.

### Small but readable (size < 11pt, opacity ≥ 0.28)

- `Player/PlayerView.swift:135-141` — close X icon at **12pt** at `theme.subtle` (0.28), 36×36 hit target. Hit is fine but the X disappears against the visualizer in FIELD mode for tracks where Crown / Soul / Light hues bloom in the top region.
- `Player/PlayerView.swift:611-617` (sliderRow label) — section labels uniformly **9pt** at `subtle` (0.28). The whole CONTROL sheet uses a label scale that is at the edge of WCAG 4.5:1 contrast on the warm-cream-on-near-black palette.
- `Components/Chip.swift` — chip text **12pt** italic serif at `muted` (0.55) when unselected. Fine.
- `Tabs/LabView.swift:158-163` — "craft your own permission slip" at **10pt** at `subtle` (0.28). Atmospheric but borderline.
- `Settings/SettingsView.swift:60` — gain % readout at **12pt** monospaced at `muted` (0.55). Fine.

### What's actually large enough

The verb (62–72pt italic serif element-color) is the only typography in the app
that wins at a glance. Everything else is small and quiet — atmosphere by
design — but the design has crossed below "atmospheric" into "illegible" in
roughly 25 places.

---

## 2. Dead ends — can you always navigate back?

### Hard dead ends (no visible exit)

- **`Letter/LetterRecordView.swift:55`** — `interactiveDismissDisabled(phase == .recording || phase == .countdown)` during countdown and recording. The setup-phase Cancel button is gone. The Stop button (`L204-216`) is the only escape and it advances to review rather than discarding. A user who taps Begin and immediately changes their mind has to stop a session and then Cancel out of review (which does delete the m4a, but the path is non-obvious).
- **`Oracle/OracleView.swift:308` (TypingContent)** — keyboard up, focused on appear, no cancel/back affordance. Tapping outside the text field does not exit. ASK is disabled when empty. The only escape is the OS tab bar — which works, but means the user can't return to the idle void without changing tabs first.
- **`Oracle/OracleView.swift:311-332` (WaitingContent)** — no cancel. If the network hangs, the user has nothing to tap; they must tab away. The Oracle does have 2-retry backoff per CLAUDE.md, but UI offers no abort.
- **`Map/MapDetailSheet.swift:151-156`** — locked nodes show "this dance has not yet been composed" with no button. Dismissal is by sheet-handle swipe-down, which is conventional but undiscoverable for a first-time user who taps a locked dot.
- **`Map/MapDetailSheet.swift:113-148`** — if `state == .available` but `track == nil` (chakra has no Track row), the CTA silently degrades to the locked copy. The badge still reads "AVAILABLE" while the CTA reads "not yet composed." Mismatched state.
- **`RootView.swift:128-151` AudioErrorBanner** — no dismiss action. Lives until `AudioSessionCoordinator.lastError` self-clears on the next successful transition. If the session never recovers, the banner is permanent and uninteractable.
- **`BinduBirthView.swift:48-90`** — no skip. The first-launch sequence is ~3.5s and always plays to completion. Not strictly a dead end, but a forced 3.5s gate before first interaction.

### Soft dead ends (exit exists but is hard to find)

- **`Player/PlayerView.swift:131-146`** — top-right X close is at **12pt at `theme.subtle` (0.28)** with no background pill. Against the Cathedral renderer's bright upper region (rising arches, climax keystone, Shweta crystallization), it disappears. Compound: the X is the *only* persistent close affordance after the gesture cheat sheet is removed; the Field-mode drag-down threshold is 60pt and undocumented.
- **`Player/PlayerView.swift:1029-1087` Integration Chamber** — auto-dismisses after 30s, but during those 30s the only escape is "close" or "save note." No top-corner X.
- **`Loop/LoopHostView.swift:93-106`** — the Loop ceremony's close button is at **9pt opacity 0.30 at bottom-trailing**. It does exist on every step, but is intentionally faint. New users will not find it.
- **`Space/SpaceImmersedView.swift:119-124`** — top-right X at **16pt at `theme.muted` (0.55)**. Reasonable. Borderline at 0.55 over the chakra-color radial.

### No dead ends found in

`FieldView`, `LabView`, `ArchiveView`, `RitualSetupView`, `LetterView`,
`LetterPlaybackView`, `SettingsView`, `RootView` tab bar, `MapView`.

---

## 3. Empty states — Airtable degradation

The Track model carries four post-Lalita-pass fields:
`recognitionStatement?`, `lyricalWordsReading`, `frequencyReading`,
`videoPulseReading`, `lalitasPerspective?` (per CLAUDE.md §4).
Per CLAUDE.md, these are "empty for most tracks today."

### Graceful

- `Player/PlayerView.swift:268-277` — FIELD-mode recognition: `if let rs = …, !rs.isEmpty` guard. Empty → not rendered. **But:** the visible recognition that IS rendered (when present) is at opacity 0.12, so the field reads visually identical empty vs. populated. Not really a *degradation* problem; rather, the populated state is itself broken — see §1.
- `Player/PlayerView.swift:877-884` (Words tab) — `ReadingContent` with empty fallback `"the words reading for this song is still forming."`
- `Player/PlayerView.swift:915-937` (Video tab) — `if .isEmpty` → boxed placeholder card "video arrives in a future session."
- `Player/PlayerView.swift:940-963` (Lalita tab) — empty fallback paragraph "The Lalita reading for this song is still forming. What you've brought to it is part of the reading. Return when the field calls you back." This is the most cared-for empty state in the app.
- `Player/PlayerView.swift:887-912` (Frequency tab) — composes from `track.state`, `wire.userBeatHz`, `wire.currentCarrierHz`, `track.element`, and the chakra protocol's breath cadence. The structured rows always populate; the `frequencyReading` prose is appended only when non-empty.
- `Loop/LoopHostView.swift:62-71` — LalitaStep falls back to `"I see you. You have always been here."` when `lalitasPerspective` is nil/empty.
- `Tabs/FieldView.swift:259-277` — catalog empty + loading → "loading the field…"; catalog empty + error → renders `catalog.loadError`.
- `Tabs/OracleView.swift:168-194` — no-key state with "the Oracle awaits a key" + ADD API KEY button.
- `Tabs/ArchiveView.swift:36-48` — book.closed icon + "Your practice will accumulate here."
- `Tabs/LetterView.swift:41-56` — envelope icon + "speak from this state" + + button hint.

### Ungraceful or inconsistent

- **`Map/MapDetailSheet.swift:113-148`** — when a node is `.available` or `.danced` but `catalog.tracks` has no matching chakra, the CTA falls through to `lockedCopy`. The state badge keeps saying AVAILABLE/DANCED while the body says "not yet composed." Either the journey state shouldn't have promoted the node, or the CTA should say "track not yet linked" to distinguish data-not-present from compositionally-locked.
- **`Player/PlayerView.swift:879-884`** (Words tab fallback) — `lyricalWordsReading` is a non-optional `String` with default `""` per the CLAUDE.md compatibility decoder. When old caches resurrect tracks pre-Lalita-pass, every track shows "the words reading for this song is still forming." This is correct fallback behavior, but if catalog refresh fails, the user could see this for *every* track in the Reading sheet. No way to distinguish "Airtable hasn't been written yet" from "we couldn't fetch the new fields."
- **`Player/PlayerView.swift:740-766` CARRIER row** — when `wire.hasDerivedCarrier` is false (first 10s of a track or any binaural-only session), the DERIVED chip is hidden but `currentCarrierHz` still renders. The user has no indication whether the value is the track's authored carrier or a placeholder. There is no symmetric "AUTHORED" chip.
- **`Tabs/OracleView.swift:124-130`** — when the Oracle returns a `trackID` that's not in the catalog: `errorMessage = "the Oracle returned an unknown track"` and dumps the user back to idle. This is a graceful empty state for the technical failure but says nothing about what to do next (refresh catalog? change the question? wait?).
- **`Tabs/FieldView.swift:268-276`** — when catalog fails AND has no cache, the only thing shown is the error text in serif italic muted. No retry button. The user must scroll up, navigate to Settings (via Archive's gear icon — non-obvious), and refresh.

---

## 4. Broken interactions

Every Button / Slider / Toggle / Gesture across the view tree was traced.

### All functional

I did not find a single dead button, dummy gesture, or wired-but-stubbed
control. Every action either calls a store method, posts a notification,
mutates @State, or invokes a closure that the parent owns. The codebase is
clean of TODO/FIXME (matches CLAUDE.md §10).

### Subtle interaction issues

- **`Player/PlayerView.swift:285-296` (BEGIN THE LOOP)** — wired to `presentLoop()` which calls `ConsciousnessLoopCoordinator.shared.begin(track:)` and presents `LoopHostView`. *But* this button is only available in FIELD mode (the bottom 45% sheet content hides it in CONTROL/READING). The Loop is essentially undiscoverable from CONTROL where users actually spend time.
- **`Player/PlayerView.swift:396-403` (FIELD background DragGesture)** — `minimumDistance: 40` and `value.translation.height > 60`. The threshold composition means a slow downward drag of ~60pt triggers `closePlayer()`. Discoverability: zero. The chevron / X chrome was removed in Phase 3 (per CLAUDE.md), and this gesture is the only swipe-to-dismiss replacement.
- **`Player/PlayerView.swift:683-689` BEAT slider** — `.opacity(0.01)` invisible Slider behind a custom thumb. Hit area is the full 28pt strip but the thumb rendering at L679-684 ignores hits (`allowsHitTesting(false)`). This works in practice but means a tap *on the visible thumb* and a drag on the invisible track are the same gesture — accessibility tools (VoiceOver) will see only the iOS Slider.
- **`Tabs/FieldView.swift:324-328` `lastRotY`** — hit-test recomputes rotation from `Date().timeIntervalSinceReferenceDate * 0.08 + committedRotY + dragRotY`, while the Canvas renders from `TimelineView`'s `timeline.date`. These can drift by frames. Orbs that are visibly near a tap may miss because the hit-test sees them at a slightly different rotation. CLAUDE.md doesn't flag this as an issue, and in practice the 36pt threshold absorbs the drift.
- **`Map/MapView.swift:33-38` MapView gesture** — `DragGesture(minimumDistance: 0).onEnded` is being used as a tap recognizer. Works, but means *any* drag (even unintentional) fires `handleTap`. A user dragging their finger across the map will pick whichever node is nearest the lift point — possibly not the one they touched first.
- **`Map/MapView.swift:282-289` hit radius** — locked nodes use a 12pt hit; lit nodes use 28pt. The map detail sheet is *always* shown if anything is within hit radius, so a tap halfway between a locked node and the screen edge will surface the locked sheet. The "you have to mean it" intent is technically enforced but the hit asymmetry between locked and lit makes lit nodes *steal* taps from nearby locked ones.
- **`Tabs/FieldView.swift:225-228`** — central Bindu has `contentShape(Circle().size(width: 80, height: 80))` for tap target. Fine. But the long-press gesture lives on the *whole overlay alignment center* via `.onLongPressGesture` after the TimelineView block — meaning the long-press fires from anywhere in the overlay region, not just the 80pt circle. Likely intentional but worth verifying on-device.
- **`Player/PlayerView.swift:404-419` modeTapZone for CONTROL/READING** — the top portion of the screen is a `Color.clear.contentShape(Rectangle()).onTapGesture { returnToField() / enterControl() }`. This sits *above* the visualizer layer (`.allowsHitTesting(false)`) and *below* the sheets. Works, but means a user trying to interact with the dimmed visualizer (which is still rendering) can't — they can only step back one mode.
- **`Settings/SettingsView.swift:64-70` gain slider** — range `0.0...0.10`, with display `"%.0f%%" % (gain * 100 / 0.10)`. So the displayed value is `gain / 0.10 * 100 = gain * 1000`. At gain 0.04 → 40%, gain 0.10 → 100%. Math is right, but the UserDefaults-persisted value is the raw 0.0–0.10, not the displayed percentage. No bug, but the slider's effective range is so compressed (0–0.10 of full audio) that small finger movements jump 10–20 percentage points.

### Reachability

- The Headphones tip (`RootView.swift:153-180`) is dismissable by tapping anywhere on the pill, which has a transparent area between icon and X that may or may not register. The whole pill should be the hit target — it is, via the outer `.onTapGesture` at L178.

---

## 5. Tab bar — picking 5 of 8

`RootView.swift:12-70` registers 8 tabs:

| Tag | Tab | Role |
|---|---|---|
| 0 | Map | 33-chakra journey map (front door per CLAUDE.md §13) |
| 1 | Field | 22-track constellation |
| 2 | Oracle | AI track recommender (long-press from Field also gets here) |
| 3 | Space | Solo chakra breath session |
| 4 | Lab | Custom-frequency binaural builder |
| 5 | Archive | Practice history + Settings gear |
| 6 | Ritual | Chained chakra sequence builder |
| 7 | Letter | Voice-letter recorder over binaural |

iOS TabView collapses to 5 + More automatically when there are 6+ items.
"More" is a stack-style overflow that hides discoverability of those tabs.

### Recommended primary 5

1. **Map** — explicit front door per project decision. Highest-value first impression.
2. **Field** — primary discovery surface (22 tracks). FieldView's central Bindu long-press is the documented gesture to reach Oracle, so Field must be a top-level tab for that to feel native.
3. **Oracle** — the magic moment. The "ask in plain language, get a track" surface that distinguishes this app from a meditation player.
4. **Space** — most accessible practice (pick a chakra, breathe). No music required; works offline.
5. **Archive** — re-engagement loop. The user returns here to see what they did and read Integration notes.

### Recommended More (3)

- **Lab** — power-user; users who want to dial in their own carrier/beat (sacred frequency strip, "let the field choose" randomizer). Not the entry experience.
- **Ritual** — only useful once the user has used Space and understands chakra sessions. Requires ≥2-step queue to do anything (`RitualSetupView.swift:122`).
- **Letter** — niche, distinct mode (recording, not listening). Worth keeping but doesn't belong adjacent to discovery.

### Trade-offs to flag

- Archive vs Lab in the primary 5 is the real argument. Lab is what makes Bindu Field a "binaural-beat instrument" rather than another meditation app. If the brand emphasis tilts toward instrument-craft, swap Archive (visible via Settings gear in any tab toolbar already) into More and bring Lab forward.
- Map and Field share semantic territory (both are "browse what's available"). If you wanted to demote one to More to make room for Lab, Map is the candidate — it's gorgeous but currently has many locked nodes per CLAUDE.md §13 ("only Track 27 has a `Score.cross` today").

### Hard constraint

The Player long-press gesture in `FieldView.swift:227-238` deep-links to
`NavigationStore.shared.selectedTab = 2` (Oracle). If Oracle is demoted to
More, this gesture stops feeling instant — More-menu tabs animate through a
NavigationStack push. Keep Oracle in primary or rewire the gesture to a
sheet presentation.

---

## 6. Cognitive load — what competes per screen

Per screen: count of distinct attention surfaces, identified primary action,
and whether the primary is visually dominant.

### Low (≤ 3 competing elements, primary obvious)

- **`OracleView` idle** (`OracleView.swift:199-243`) — 2 elements: dim "THE ORACLE" label + ◌ glyph. Primary = tap anywhere. Issue: opacity 0.10–0.14 makes both affordances *invisible*, so the user faces an apparently empty screen.
- **`OracleView` typing** — 2 elements: text field + ASK button. Primary = type then submit.
- **`OracleView` waiting** — 1 element: 3 breathing dots. Primary = wait.
- **`LetterView`** (`LetterView.swift:10-39`) — list + `+` button. Primary = +.
- **`ArchiveView`** (`ArchiveView.swift:8-34`) — list + gear. Primary = scroll/read.
- **`LetterRecordView` setup** (`LetterRecordView.swift:77-149`) — title + 4 state chips + Begin. Primary = Begin.
- **`LetterRecordView` recording** (`LetterRecordView.swift:165-221`) — pulsing red orb + timer + Stop. Primary = Stop.
- **`LetterPlaybackView`** (`LetterPlaybackView.swift:14-86`) — Done + Share + title + state + progress + Play. ~6 elements but Play is 96pt circle, unambiguously dominant.
- **`SpaceSetupView`** (`SpaceSetupView.swift:36-105`) — title + 9 chakra tiles + 4 duration chips + Begin. The 9 tiles are uniform so they read as a single grid (one decision); two decisions total. Primary = Begin.
- **`Loop/*StepView`s** — each step is single-focus by design (a question, an offered word, a flashing series, a peak word, three paragraphs, a closing line). Low per-step load.

### Moderate (4–7 competing elements)

- **`MapView`** (`MapView.swift:17-69`) — 33 nodes (3 visual tiers) + title block + sheet. The visual hierarchy carries it: locked dots recede, lit dots breathe, danced dots have orbit rings. Eye is drawn to lit + danced. Primary = tap a lit node. **Risk**: the lit/danced/locked distinction is small at device scale; users may not realize most nodes are locked.
- **`FieldView`** (`FieldView.swift:42-281`) — 22 orbs + 5 filter chips + animated center Bindu + title + (first-launch) tooltip. The center Bindu competes hard with orb taps because it pulses and is brighter (`#E5524E` vs muted element hues at 0.55–1.0 opacity). Primary action is ambiguous: tap an orb, or long-press the Bindu? On first launch the tooltip helps; after that it's hidden behavior.
- **`SpaceImmersedView`** (`SpaceImmersedView.swift:103-191`) — breath ring + phase word + countdown digit + affirmation + chakra Sanskrit + chakra English + remaining timer + X. 7 surfaces. They're nested visually so the breath ring dominates; primary = breathe. Workable.
- **`RitualSetupView`** (`RitualSetupView.swift:30-127`) — title + queue list + totals + 9-tile picker + Begin. Two-step workflow (add steps, then Begin). Begin disabled until ≥2 steps. Moderate.
- **`Player/PlayerView` READING sheet** (`PlayerView.swift:771-872`) — recognition header + 4-tab bar + scroll content. The tab bar is the only competing element with the active content; 4 tabs is a moderate decision space.
- **`SettingsView`** — 7 sections in a long scroll. Linear and predictable. Moderate cumulative load but each section is small.
- **`Player/PlayerView` FIELD mode** (`PlayerView.swift:249-311`) — visualizer (huge) + verb (62pt) + song line + recognition (invisible) + BEGIN THE LOOP (tiny) + scrubber + binaural pill + X close. ~8 surfaces. **The verb at 62pt wins by an order of magnitude**, so cognitive load is actually low — but the hidden affordances (tap → CONTROL, drag down → close, tiny BEGIN THE LOOP for Loop entry) are a discoverability tax.

### High (8+ competing elements; primary ambiguous)

- **`Player/PlayerView` CONTROL sheet** (`PlayerView.swift:425-553`) — drag handle + 56pt play/pause + BINAURAL toggle row (4 sub-elements: toggle, ON/OFF label, breathing dot, label) + PRESENCE slider (label + track + thumb + readout) + BEAT slider (label + track + zone ticks + thumb + readout + state badge + zone strip) + CARRIER row (label + value + DERIVED chip) + READING button + END SESSION button. By component count: ~14 distinct controls in 55% of screen height. Primary = play/pause (centered, largest), but BEAT alone is a 7-component sub-widget. This is the densest screen in the app.
- **`Tabs/LabView`** (`LabView.swift:59-138`) — header + dot + waveform + 76pt beat readout + carrier readout + sacred badge + state info card (expandable) + 2 sliders + sacred frequency strip (7 dots + carrier cursor) + presets row (variable, ≥5) + save chip + "let the field choose" button + ACTIVATE button. **~13 attention surfaces in one tab**. The 76pt beat number wants to be the primary, but ACTIVATE is the action verb, and randomize is the "feature." Three competing primaries.
- **`Player/PlayerView` Integration Chamber** (`PlayerView.swift:1029-1087`) — title + textarea + close + save note. Only 4 elements, but it appears unannounced when a track completes and the textarea autofocuses — so cognitive load is *temporal*, not spatial. Moderate.

### Primary-action recommendations (only flagging where it's unclear today)

- **`LabView`** — needs a primary. Either ACTIVATE (capsule-filled, dominant, currently in the right spot) or the 76pt beat readout (visually dominant but not actionable). The "let the field choose" button at the same weight as ACTIVATE creates the conflict. Consider lowering randomize to italic-serif text-only (already does this — but it's the same size as ACTIVATE, so it competes).
- **`Player/PlayerView` CONTROL** — needs visual ladder. Today: play/pause (56pt) >> sliders (1pt track, 13pt thumb) >> labels (9pt). The BEAT slider's sub-widget (with zone ticks + badge) is the densest patch on screen and competes with the centered play/pause for attention. Consider folding the brainwave badge into the CARRIER row or eliminating the zone-label strip below the slider.
- **`FieldView`** — central Bindu and orb taps are two distinct primaries and the user has to know which. The "hold for Oracle" tooltip handles first-launch; after that, no signal. Worth considering a persistent (low-opacity) hint, or making the long-press a distinct visual state (e.g., the Bindu visibly anticipates the hold past 0.3s).

---

## Appendix — files audited (32)

```
Views/BinduBirthView.swift
Views/RootView.swift
Views/Components/{BinauralWaveformView,BinduGlow,BinduTabIcons,Chip,DateFormatters,ElementColors,PlaybackTime}.swift
Views/Letter/{LetterPlaybackView,LetterRecordView}.swift
Views/Loop/{LoopHostView,LoopStepViews}.swift
Views/Map/{MapDetailSheet,MapView}.swift
Views/Oracle/OraclePresenceView.swift
Views/Player/{PlayerView,VisualizerView,VocabularyRenderer}.swift
Views/Ritual/{RitualRunningView,RitualSetupView}.swift
Views/Settings/SettingsView.swift
Views/Space/{SpaceImmersedView,SpaceSetupView}.swift
Views/Tabs/{ArchiveView,FieldView,LabView,LetterView,OracleView,RitualView,SpaceView}.swift
```

No code modified.
