# Session ledger + design pass history

## Chronological ledger

| Commit | What it shipped |
|---|---|
| `ffcddae` | Initial commit — pre-Airtable hardcoded catalogue |
| `7e3bd56` | Tier-0 fixes + element color extraction into a shared helper |
| `0cd5cfa` | **Airtable catalogue spine** — `AirtableService`, `CatalogStore`, dynamic track loading, offline cache |
| `cbb3bd2` | docs: session 4 handoff |
| `37d7b43` | **DSP-wire** — `DSPWireService` polls listener, applies inverse-RMS gain, applies derived carrier (DSP wins) |
| `3a53c86` | **Visualizer rewrite** — Lissajous Bindu, comet trail, audio-reactive RMS bloom + onset rings + carrier-lock pulse |
| `adf9c23` | **Player upgrade** — arrival ceremony, slim "flowing" scrubber, binaural presence pill, Integration Chamber |
| `467bc68` | Removed the redundant session timer from Field player |
| `1bf2531` | Gated Integration Chamber on user intent (only natural completion raises it); recorded real completed-state |
| `2aef1f6` | docs: ARCHITECTURE-AUDIT.md (the audit) |
| `5a57f98` | **Pass 1 of foundation cleanup** — 18 bugs (B1–B18) fixed |
| `0d5f65e` | **Pass 2 + 3 of foundation cleanup** — opportunities (O1–O25) and gaps (G1–G24) |
| `33c6164` | Merge `feat/foundation-cleanup` → main |
| `d24d9f0` | **Constellation upgrade** — played/never visual states, depth fog, element pair lines |
| `3d3b877` | **Lab upgrade** — `FrequencyPreset` + `PresetStore` + `FrequencyInfo`; preset row + state info card + carrier-note popover |
| `ac80475` | **Oracle practice-aware** — `Track.recognitionStatement?`; `OracleService.ask` accepts `recentlyPlayed` |
| `b9814c6` | Merge `feat/constellation-lab-oracle` → main |
| `b02def8` | **Background audio fix** — `Info.plist` with `UIBackgroundModes = [audio]` + AVAudioSession interruption + media-reset observers in `AudioSessionCoordinator`; `restartIfNeeded()` on both engines |
| `de68d8c` | **Pause/resume across engines** — `TrackPlaybackService.pause/resume/togglePlayPause`, DSP-wire pause-safe, lock-screen pause = soft mute, play = restore gain |
| `c6cfdf0` | Merge `feat/pause-resume` → main |
| `1bd0453` | docs: Lalita pass handoff + design reference package |
| `644647a` | **Lab redesign (Phase 1)** — `BinauralWaveformView` + sacred frequency strip + direct-edit + weighted randomize + sacred badge + 5-band state palette |
| `f42bdc5` | **Track Reading-space fields (Phase 2)** — `lyricalWordsReading`, `frequencyReading`, `videoPulseReading` (non-optional `String`) + `lalitasPerspective?` + custom decoder |
| `ed72622` | **Player three-mode architecture (Phase 3)** — `PlayerMode { field, control, reading }`; 55%/80% bottom sheets; additive `DSPWireService` extension |
| `e673d38` | **Performer score state machine (Phase 4)** — `Performer.shared` + `Score.cross` + crescendo modulator + 10 archetype-presence formulas + awakening-peak binaural depth integration |
| `7a3d659` | **Cathedral renderer Tier 1 + Bindu (Phase 5a)** — floor / columns / vault / grain / Gaia + multi-harmonic Lissajous |
| `36bb775` | **Cathedral renderer Tier 2 ensemble (Phase 5b)** — Arch chant + Sakshi unmade gesture |
| `8601b06` | **Cathedral renderer Tier 3 + 4 (Phase 5c)** — rising arches + convergence + keystone cascade + earth-rising + Shweta crystallization |
| `66a271a` | **Ensemble layer (Phase 6)** — Karishma + Ashrey + Neev. Lalita remains Phase 7, deferred. |
| `72a4df7` | **Fix 1** — binaural pill becomes status-indicator only (no expansion, tap → CONTROL) |
| `20960fb` | **Fix 2** — FIELD content floats over visualizer via ZStack overlay + top status-bar gradient + bottom viz→bg fade gradient |
| `112ff46` | **Fix 3** — `vizMode` setting added (Ensemble / Singular) under `binduSettings.vizMode` |
| `efc8005` | **Fix 4** — CONTROL-sheet toggle-row dot breathes continuously while `wire.binauralEnabled` |
| `bce5295` | docs: update CLAUDE.md for lalita pass state |
| `c4d0c1a` | **fix: functional regressions** — lab sliders, player close |
| `056137b` | **fix: visual fidelity** — sheets, verb, recognition, weights; introduces `BinduGlow.swift` two-shadow halo |
| `c82cf9a` | **feat: element vocabularies** — `VocabularyRenderer.swift` (1014 lines, 9 element draws); `VisualizerView` becomes a dispatcher |
| `59b5803` | **feat: tab icons** — `BinduTabIcons.swift` (custom 28×28 Canvas glyphs for all 8 tabs) |
| `32abb1d` | **feat: oracle — listening void redesign** — four states (idle/typing/waiting/response); `OraclePresenceView` + `OraclePresenceModel`; `Color.binduHue(element:)` helper added |
| `9089652` | **feat: consciousness loop — 7-step ceremony** — `ConsciousnessLoopCoordinator`, `LoopHostView`, 7 step views (PreRoll/Seed/Offering/Dance/Reveal/Fruit/Lalita); `Score.mirrorWords` field on Performer |
| `011d0ec` | **feat: the map — 33-chakra tree of life** — `ChakraNode`, `ChakraRegistry` (33 nodes + connections), `ChakraJourneyStore` w/ `binduJourney.v1` persistence; `MapView` + `MapDetailSheet`; `PlayerStore.finalizeCurrentSession` calls `markDanced` on natural completion |
| `44a595d` | Merge `feat/session-b` into main — complete app |
| `ee6a1b9` | **fix: critical bugs — tab icons, audio exclusivity** — `AudioExclusivityCoordinator` introduced (.track/.lab/.space/.ritual); Lab/Space/Ritual gain a `.binduXxxStop` notification listener |
| `ad79836` | **fix: readability** — opacity floor 0.28 across 25 elements |
| `7c6cace` | **fix: dead ends — exits and state corrections** — 7 files touched (Field/Oracle/MapDetail/PlayerView/RootView/AudioSession) |
| `838a0b1` | **feat: structure — tab bar, field verbs, akash rename, mini player** — `MiniPlayerView` added; FieldView labels verbs under front-hemisphere orbs; Space tab label becomes AKASH; NavigationStore default lands on Field (1) |
| `bf16fc1` | **fix: bindu solo** — restore singular lissajous mode |
| `98fac48` | **docs: check in session handoffs, audits, and design HTMLs** |
| `ac9c7f5` | **docs: refresh CLAUDE.md for feat/stabilize state** |
| `884630a` | **feat: lab v3 + akash rebuild — tuning clusters, intention grid, breath sessions** — `LabView` rewritten around `TuningCluster` + `MeaningPanel`; new shared models (`HonestyTier`, `BrainwaveStateInfo`, `SacredCarrier`); `BreathSession` / `BreathProtocolMetadata` / `BreathSessionStore` / `JoinedBreathSession`; AKASH front door is `IntentionGridView`; `SubSelectionView`, `SessionDetailView`, `ScreenedGateView`, `BreathImmersedView`, `BreathReadingSpaceView`. `AirtableService.fetchBreathSessions()` added. Old chakra grid in `SpaceSetupView` kept for Ritual. |
| `9465e8e` | **feat: airtable — migrate breath protocol metadata to airtable** — six new Airtable columns on `tblv3WvMZ90Sfhun6` (Inhale/Hold/Exhale Sec, Intention, Safety, Special Cue); all 11 breath records populated. `BreathSession` gains six optional carriers + backwards-compat decoder so the pre-migration `binduBreathSessions.v1` cache still decodes. `BreathSpecialCue` raw values change to match Airtable strings ("double_pulse", "active_phase"). `BreathProtocolMetadata.merge(airtable:)` is the new join — Airtable wins per-field; `BreathProtocolMetadata.all` remains as the seed/fallback. `resolveSafety(airtableKey:id:)` fails closed: only an explicit `"open"` passes; everything else routes through the screened gate. `knownScreenedIDs: Set<Int> = [105]` is the code-level backstop. Hue / oneLine / carrierTiers / beatTiers are NOT migrated and still come from the fallback. |
| `49d31a1` | **docs: refresh CLAUDE.md for lab v3 + akash + airtable breath migration** — header bumped, project structure lists the new files, Data Layer gains a full "Breath sessions — Airtable + seed-fallback join" subsection with schema table and the explicit source-of-truth boundary (hue / oneLine / carrierTiers / beatTiers stay in code), Lab + AKASH tab descriptions rewritten, state-management and "what works" sections updated, ledger appended. |
| `da2921a` | **fix(lab): stepper precision matches readout precision** — carrier fineStep 1.0 → 0.1; beat fineStep 0.1 → 0.01. Slider snap step unchanged at 0.1 (still the coarse control). User can now tap-step to 136.1 (OM) and 2.69 Hz without falling back to the keyboard. |
| `90c9d67` | **docs: note lab stepper precision change in CLAUDE.md** |
| `2510b95` | **docs: split CLAUDE.md into always-loaded index + scoped `docs/` references** |
| `b9c2918` | **feat: theming + legibility + loop fix + tab swap + mirror words** — `ThemeData.light` warm-paper palette + `SettingsStore.themeMode` (`system`/`light`/`dark`) + `activeTheme`/`preferredColorScheme` + `RootView` injection + Settings appearance picker (immersive Canvas scenes pinned to void). Contrast overhaul: `subtle` 0.28→0.40, `muted` 0.55→0.68 + faint-affordance bumps (Loop tap-to, Oracle idle, Map header, Player recognition). Player FIELD tap-zone fix so BEGIN THE LOOP is reachable (was swallowed by the enter-CONTROL zone). Tab swap: Lab into the primary bar, Oracle into More. Per-track mirror words: `Track.mirrorWords` from a new Airtable `Mirror Words` column + Loop precedence over Score/default. |
| `e30c913` | **feat: app activity — Field's first Airtable write on Loop seal** — `AirtableService.logAppActivity(...)` POSTs a "Ceremony Sealed" row to the shared **App Activity** table on the Loop's `.lalita → .done` transition; `Track.recordID` (captured at fetch time) populates the row's `Link to Field` back-reference. Fire-and-forget `async`, fails silently on non-2xx. Uses the embedded `Secrets.airtableToken` — the first write path from the client (see the audit's PAT-posture note). |
| `23ae7ef` | **ci: generate Secrets.swift on Xcode Cloud from AIRTABLE_PAT** — `ci_scripts/ci_post_clone.sh` regenerates the gitignored `Secrets.swift` from the `AIRTABLE_PAT` (Secret) env var so clean CI checkouts compile `AirtableService`. |
| `5338bfb` | **docs: note Xcode Cloud Secrets.swift generation in CLAUDE.md build config** *(current HEAD)* |
| — | **audit 2026-08-29** (no commit) — full re-audit: docs refreshed to `main`; live Airtable content re-audited (25/34 records fully read, 9 seed-only music tracks + Video Pulse universally empty; one orphaned no-Track-ID record; polluted single-select choices flagged for manual UI cleanup). See `BINDU-FIELD-AUDIT-2026-08-29.md`. |

---

## Where the design pass landed (and what's still ahead)

The Lalita pass shipped on `feat/lalita-pass` across six phases plus four post-review gap fixes. Session A landed three more design pieces (Oracle redesign, Tab Icons, Consciousness Loop). Session B landed the Map, the Mini Player, Element Vocabularies, and the AKASH rename + Field verbs. Stabilize landed audio exclusivity, readability, and dead-end fixes. **The Lab v3 + Akash rebuild** then collapsed the Lab into unified `TuningCluster`s + a single `MeaningPanel`, replaced the AKASH chakra grid with an intention grid over 11 Airtable-backed breath sessions, added the breath Reading Space, and gated The Stoke through `ScreenedGateView`. The **breath-protocol Airtable migration** then moved inhale/hold/exhale/intention/safety/special_cue into Airtable as the source of truth, with `BreathProtocolMetadata.all` retained as the seed/fallback.

### What landed

- **Lab v3 rebuild** (post-Lalita) — collapses the dual carrier/beat controls (editable readout + far-below slider) into one `TuningCluster` per frequency: hero readout (tap-to-type), draggable slider, ± steppers, nearest-marker-only floating labels. Replaces the standalone state card + sacred-frequency-map strip + inline sacred badge with `MeaningPanel` (calm one-liner + tap-to-expand state/carrier detail + tier legend). Adds shared models — `HonestyTier` + `HonestyBadge`, `BrainwaveStateInfo`, `SacredCarrier` — used by both Lab and Akash.
- **Lab redesign** (Lalita Phase 1) — animated waveform, direct number editing, sacred frequency strip, "let the field choose" randomize, sacred badge, 5-band state palette.
- **Track Reading-space fields** (Lalita Phase 2) — four new Airtable fields surfaced on `Track` with cache-compatible decoding.
- **Player three-mode architecture** (Lalita Phase 3) — FIELD / CONTROL / READING. Binaural pill, four reading-tabs, in-session BEAT control with the sticky DERIVED/AUTHORED chip.
- **Performer state machine** (Lalita Phase 4) — 60Hz tick, scored phase tracking for Track 27, crescendo modulator, archetype-presence formulas, awakening-peak binaural integration. Later gained `Score.mirrorWords` for the Consciousness Loop.
- **Cathedral renderer** (Lalita Phase 5a/b/c) — full SwiftUI Canvas reimagining of the visualizer. Continuous tier (floor / columns / vault / grain / Gaia), ensemble tier (Arch / Sakshi), crescendo (rising arches + convergence lines), climax (keystone cascade + earth-rising + Shweta crystallization).
- **Ensemble layer** (Lalita Phase 6) — Karishma / Ashrey / Neev.
- **vizMode setting** + four gap fixes (status-only pill, gradient fades, vizMode in Settings, breathing CONTROL dot).
- **Visual fidelity fixes** — sheets, verb, recognition, weights; `BinduGlow.swift` two-shadow halo extension.
- **Element Vocabularies** (Session B) — 9 distinct draw functions ported from the design HTML. `VisualizerView` becomes a dispatcher. PlayerView background reads `vocab.bg`. Track 27 overridden to `.ether`.
- **Custom Tab Icons** (Session A) — 28×28 SwiftUI Canvas glyphs for all 8 tabs, replacing SF Symbols.
- **Oracle listening void** (Session A) — four-state machine + drifting radial-fog presence + cancel-after-15s on waiting.
- **Consciousness Loop** (Session A) — 7-step ceremony as a fullScreenCover over the player. Music continues underneath. Mirror words from Score or default; Fruit paragraphs from `lyricalWordsReading` or generated defaults.
- **The Map** (Session B) — 33 nodes on a 393×780 design canvas. Three render states. `binduJourney.v1` persistence. `MapDetailSheet` with state-aware CTAs. Tag 0 — the front door.
- **Mini Player** (Session B) — compact bar above the tab bar when the modal is dismissed but a track is loaded.
- **Field verbs** (Session B) — verbs labelled below front-hemisphere orbs in italic serif.
- **AKASH rename** (Session B) — Space tab label changes; SpaceView file/store names unchanged.
- **Audio exclusivity** (Stabilize) — `AudioExclusivityCoordinator` serializes ownership of the output surface; Lab + Track no longer overlap.
- **Readability + dead-end fixes** (Stabilize) — 0.28 opacity floor across 25 elements; corrected exits + state.
- **AKASH — intention grid + Airtable-backed breath sessions** — `IntentionGridView` replaces the chakra-grid front door; `SubSelectionView` for multi-session intentions; `SessionDetailView` between intention and immersed; `BreathImmersedView` mirrors the existing immersed mechanics + adds the recognition fade, special-cue line, READ capsule, and phase-word overrides; `BreathReadingSpaceView` mirrors the music Player's READING mode with WORDS / FREQUENCY / LALITA / PHASES tabs; `ScreenedGateView` for screened-tier sessions. `RitualRunningView` keeps using the original `SpaceImmersedView` for chained chakra rituals.
- **Breath protocol → Airtable migration** — six Airtable columns added on the same table (Inhale/Hold/Exhale Sec, Intention, Safety, Special Cue); 11 breath rows populated; `AirtableService.fetchBreathSessions()` reads them; `BreathSession` carries optional Airtable values; `BreathProtocolMetadata.merge(airtable:)` is the new join (Airtable wins per-field, hardcoded `all` is the seed/fallback). Safety fails closed; `[105]` is the code-level backstop. **What stayed in code:** `hue`, `oneLine`, `carrierTiers`, `beatTiers` — see `BREATH-SESSIONS.md` for the source-of-truth boundary.

### Still ahead

- **Phase 7 — `LalitaEngine`** is deferred to a separate session per the original handoff. Reference: `design_handoff_lalita_pass/Bindu Lalita.html` + `README.md` Section 5. Three phases, six mathematical pattern curves, background inversion from void to warm cream.
- **Visual fidelity audit on device** for the non-Air vocabularies. The Cathedral is well-tested visually on Track 27; the other 8 vocabularies have shipped only against the design HTML.
- **More authored Scores** — only Track 27 (Sound of Silence) has a `Score.cross` today. Other tracks run ambient (no phase / modulator / scored mirror words). Adding a score is a `Score.forTrack(id:)` case + a hardcoded `Score(...)` literal per track.
- **More authored Reading-space prose** — as of the 2026-08-29 content audit, 25 of 34 catalog records carry full Recognition / Lyrical / Frequency / Lalita prose (the 9 composed chakra dances, Genesis/Kingdom/In Shadow/family, and all 11 breath sessions). The gaps: **9 seed-only music tracks** (`0 Faded`, `1 Sit Around The Fire`, `2 Dream`, `4 Opus`, `5 A Sky Full of Stars`, `8 Howling`, `10 Overthinker`, `14 Earth`, `22 Habits`) have no reading prose, and **`videoPulseReading` is empty for all 34 records**. The Loop's Fruit step and the Player's READING sheet fall through to generic defaults for the seed-only tracks.
- **More authored mirror words** — mirror words are now Airtable-authored per-track (`Track.mirrorWords`, from the `Mirror Words` column) and take precedence in the Loop's Dance step. Where a track's column is empty, the Loop falls back to the Track-27 hardcoded `Score.mirrorWords`, then to the universal 5-word default. (A full authored `Score` — phase windows + crescendo modulator — still exists only for Track 27; every other track runs Performer in ambient mode.)

### Sub-areas not yet upgraded

Carried from the original speculative list — still candidates if you want to keep pushing the visual pass:

- Settings sections (the `SettingsSection` wrapper looks correct; row-by-row typography could match the Player's READING-style hairline rules).
- Letter row + Archive row layouts (functional, low-personality).
- The Ritual queue row — drag-list utility look, no atmosphere.
- The headphones tip — pill capsule, low ceremony for a first-launch message.
