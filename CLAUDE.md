# Bindu Field — Project State

iOS / SwiftUI app. Binaural-beat instrument layered on a catalogue of music tracks, with a 33-chakra tree-of-life map, a constellation browser, a 7-step consciousness-loop ceremony, breath-driven chakra sessions, a four-state Oracle (Claude API) track recommender, voice-letter recorder, freeform frequency lab, and ritual sequencer.

Single Xcode target, dark-mode-only, ultraLight serif type, void/black palette. **No SPM dependencies — frameworks linked are Accelerate only.** The catalogue is loaded dynamically from Airtable; audio MP3s stream from a static aistrangegame.com host with a 200 MB LRU disk cache. The Oracle calls api.anthropic.com directly with a key the user pastes into Settings.

Last audited: **2026-05-22**, currently on `feat/stabilize` at `9465e8e` (Lab v3 + Akash rebuild + the breath-protocol Airtable migration). On top of Session B's structure (Map · Field · Oracle · AKASH · Archive · Lab · Ritual · Letter), the Lab is now built around the unified `TuningCluster` + collapsible `MeaningPanel` with shared honesty-tier rendering; AKASH switched to an **intention-grid** front door over 11 Airtable-backed breath sessions (IDs 101–111, Track Type = `breath`) with on-demand Reading Space, screened gate for The Stoke, and four special-phase cues; and the breath protocol metadata (inhale/hold/exhale, intention, safety, special cue) now lives in Airtable as the source of truth, with `BreathProtocolMetadata.all` retained as a code-level seed/fallback. Branch is 3 commits ahead of `origin/feat/stabilize`, not merged to main, not pushed. Build clean, zero warnings, zero errors.

---

## 1. Project structure

Project root: `/Users/ashrey/Bindu Field/`

```
.
├── .gitignore                                  # ignores Secrets.swift, DerivedData, .DS_Store
├── ARCHITECTURE-AUDIT.md                       # the original audit (B1–B18 bugs · O1–O25 ops · G1–G24 gaps) that drove the foundation cleanup
├── BINDU-FIELD-HANDOFF.md                      # session 1 handoff (pre-Airtable baseline)
├── BINDU-FOUNDATION-HANDOFF.md                 # foundation-cleanup handoff
├── BINDU-SESSION4-HANDOFF.md                   # session 4 (DSP-wire, visualizer, player upgrade)
├── BINDU-SESSION5-HANDOFF.md                   # session 5 (constellation, lab presets, practice-aware Oracle)
├── BINDU-LALITA-PASS-HANDOFF.md                # Lalita pass — six-phase design architecture
├── BINDU-SESSION-A-HANDOFF.md                  # session A (tab icons, Loop scaffolding, Oracle redesign)
├── BINDU-SESSION-B-HANDOFF.md                  # session B (33-chakra Map, Mini Player, vocabularies)
├── DESIGN-GAP-REPORT.md                        # post-Phase-6 diagnostic
├── VISUAL-FIDELITY-REPORT.md                   # visual fidelity audit
├── UX-AUDIT.md                                 # post-Session-B UX audit
├── design_handoff_lalita_pass/                 # live HTML/JS design prototypes
│   ├── Bindu Map.html · Bindu Player.html · Bindu Lab.html · Bindu Oracle.html
│   ├── Bindu Loop.html · Bindu Archetypes.html · Bindu Tab Icons.html
│   ├── Bindu Vocabularies.html · Bindu Performance.html · Bindu Lalita.html
│   ├── bindu-performance-engine.js · bindu-ensemble.jsx · bindu-lissajous.jsx
│   ├── design-canvas.jsx · tweaks-panel.jsx
│   └── README.md · SESSION_HANDOFF.md · CLAUDE_CODE_HANDOFF.md
├── CLAUDE.md                                   # this file
├── Info.plist                                  # UIBackgroundModes = [audio]; merged with INFOPLIST_KEY_* settings
├── Bindu Field.xcodeproj/                      # PBXFileSystemSynchronizedRootGroup (Xcode 26)
├── Bindu Field/                                # source root (synced as a single group)
│   ├── Assets.xcassets/                        # AppIcon (Bindu.png), AccentColor
│   ├── Bindu_FieldApp.swift                    # @main — boots RootView, audio session, remote commands, scenePhase reconciler
│   ├── Bindu-Field-Bridging-Header.h           # imports BinduDSPBridge.h
│   ├── BinauralEngine.swift                    # AVAudioSourceNode tone generator + restartIfNeeded()
│   ├── BinauralListener.swift                  # AVAudioPlayerNode music + analysis tap → BinduDSP + restartIfNeeded()
│   ├── BinduDSP.{h,cpp}                        # C++ DSP kernel (FFT, RMS, flux, onset, carrier derivation)
│   ├── BinduDSPBridge.{h,mm}                   # ObjC++ wrapper around the C++ kernel
│   ├── Secrets.swift                           # gitignored — Airtable PAT (template at Secrets.swift.template)
│   ├── Secrets.swift.template
│   │
│   ├── Models/
│   │   ├── BrainwaveStateInfo.swift            # 5-band info + SacredCarrier reference (label, range, hue, essence, detail, tiers); shared by Lab + Akash
│   │   ├── BreathSession.swift                 # Airtable-backed breath-session spine + BreathIntention/Safety/SpecialCue/Phase enums + BreathProtocolMetadata seed-fallback table + JoinedBreathSession (the merged surface used by views)
│   │   ├── ChakraNode.swift                    # one node of the 33-chakra Map (id, name, hue, canvas coords, system, tier)
│   │   ├── ChakraProtocol.swift                # 9 dance protocols + ChakraData.all (breath rhythm, beat, carrier, hue, affirmations)
│   │   ├── ChakraRegistry.swift                # the 33 nodes + connection graph + composed-ID set (front door for the Map)
│   │   ├── FrequencyInfo.swift                 # pure-data lookup — brainwave info + notable-carrier notes
│   │   ├── FrequencyPreset.swift               # Codable preset + 5 system presets (Earth Tone, Deep Delta, Theta Gate, Creative, Presence)
│   │   ├── HonestyTier.swift                   # S/T/C tier enum + `HonestyBadge` view — shared by Lab + Akash + Reading Space
│   │   ├── Letter.swift                        # Voice-letter record (audio in Documents/Letters/)
│   │   ├── Session.swift                       # Practice history entry (.track or .chakra; sourceID is String)
│   │   ├── Theme.swift                         # `Theme` struct + ThemeData.void + @Environment(\.binduTheme)
│   │   └── Track.swift                         # Track + BrainwaveState + ChakraName + TrackType enums; reading-space fields
│   │
│   ├── Stores/                                 # @MainActor @Observable singletons (one shared instance each)
│   │   ├── AirtableService.swift               # paginated REST fetch from Airtable base/table — `fetchTracks()` (music + chakra + meditate + family records) and `fetchBreathSessions()` (Track Type = breath; permissive decoder because breath records carry a leaner schema than music)
│   │   ├── AudioCache.swift                    # MP3 download + 200 MB LRU disk cache in Caches/BinduTracks/
│   │   ├── BreathSessionStore.swift            # Airtable-backed cache of the 11 breath sessions; JSON in UserDefaults `binduBreathSessions.v1`; 1-hour freshness window like CatalogStore
│   │   ├── AudioExclusivityCoordinator.swift   # single-owner token (.track/.lab/.space/.ritual) — evicts prior source on request
│   │   ├── AudioSessionCoordinator.swift       # single owner of AVAudioSession category + interruption observers
│   │   ├── BinduConfig.swift                   # resolves Track.audioURL by ID
│   │   ├── CatalogStore.swift                  # Track cache + Airtable refresh, JSON in UserDefaults `binduCatalog.v1`
│   │   ├── ChakraJourneyStore.swift            # the user's danced set, persisted under `binduJourney.v1`; drives Map render state
│   │   ├── ConsciousnessLoopCoordinator.swift  # 7-step Loop state machine + per-track mirror words + fruit-paragraph derivation
│   │   ├── DSPWireService.swift                # 10 Hz poll: RMS → engine gain, onset → visualizer, carrier-derived → engine carrier
│   │   ├── KeychainHelper.swift                # Claude API key (AfterFirstUnlockThisDeviceOnly)
│   │   ├── LetterStore.swift                   # Letters JSON in UserDefaults `binduLetters.v1`
│   │   ├── NavigationStore.swift               # selectedTab (Int) — defaults to 1 (Field) post-Birth
│   │   ├── NowPlayingService.swift             # MPNowPlayingInfoCenter + remote commands (stop = full stop, pause/toggle = soft-mute)
│   │   ├── OracleService.swift                 # claude-haiku-4-5 messages call w/ catalog + recently-played hint
│   │   ├── Performer.swift                     # 60Hz score state machine — phase + crescendoModulator + archetypePresence; Score.mirrorWords
│   │   ├── PlayerStore.swift                   # top-level playback orchestration; starts Performer, marks Map dance on natural completion
│   │   ├── PresetStore.swift                   # user-saved frequency presets JSON in UserDefaults `binduPresets.v1`
│   │   ├── RecorderService.swift               # AVAudioRecorder for Letters
│   │   ├── SessionStore.swift                  # Sessions JSON in UserDefaults `binduSessions.v1`
│   │   ├── SettingsStore.swift                 # gain (Float) + defaultSessionDuration (TimeInterval) + vizMode (String) in UserDefaults
│   │   ├── TrackPlaybackService.swift          # coordinates BinauralListener + BinauralEngine + DSPWireService; isPaused; AudioSource claim
│   │   └── UserDefaultsCodable.swift           # tiny T-Codable-in-UserDefaults helper used by Session/Letter/Preset stores
│   │
│   └── Views/
│       ├── BinduBirthView.swift                # First-launch Task-chain birth animation
│       ├── RootView.swift                      # 8-tab TabView w/ custom Bindu glyphs + birth/headphone overlays + audio error banner + MiniPlayer overlay
│       ├── Components/
│       │   ├── BinauralWaveformView.swift      # Lab animated waveform — L / R / beat-envelope sine layers
│       │   ├── BinduGlow.swift                 # .binduGlow(color:tight:wide:) — two-layer element halo (tight + ambient)
│       │   ├── BinduTabIcons.swift             # 28×28 Canvas glyphs for all 8 tabs (map / field / oracle / space / lab / archive / ritual / letter)
│       │   ├── Chip.swift                      # filter chips (capsule, italic serif)
│       │   ├── DateFormatters.swift            # archiveDate / archiveTime / letterTitle (shared, memoized)
│       │   ├── ElementColors.swift             # Color.bindu(element:) + Color.binduHue(element:) + Color(hex:) — element palette source of truth
│       │   └── PlaybackTime.swift              # TimeInterval.asPlaybackTime (M:SS)
│       ├── Letter/
│       │   ├── LetterPlaybackView.swift        # AVAudioPlayer + optional binaural re-layer
│       │   └── LetterRecordView.swift          # 4-phase recorder (setup / countdown / recording / review); orphan-cleanup on B14
│       ├── Loop/
│       │   ├── LoopHostView.swift              # 7-step ceremony host — fullScreenCover over PlayerView, music continues underneath
│       │   └── LoopStepViews.swift             # the 7 step views: PreRoll / Seed / Offering / Dance / Reveal / Fruit / Lalita
│       ├── Map/
│       │   ├── MapDetailSheet.swift            # bottom sheet for a tapped chakra: locked / available / danced + CTA
│       │   └── MapView.swift                   # 33-node Canvas — front door of the app, scales 393×780 design canvas to device
│       ├── Oracle/
│       │   └── OraclePresenceView.swift        # drifting radial-fog presence behind every Oracle state, 14s breath cycle
│       ├── Player/
│       │   ├── MiniPlayerView.swift            # compact bar above tab bar when modal is dismissed but a track is loaded
│       │   ├── PlayerView.swift                # three-mode player — FIELD / CONTROL / READING; vocab-tinted bg; BEGIN THE LOOP; top-right X
│       │   ├── VisualizerView.swift            # vocabulary dispatcher — Air→Cathedral, every other element→VocabularyRenderer; Bindu always on top
│       │   └── VocabularyRenderer.swift        # 9 element draws (Earth/Water/Fire/Ether/Constellation/Crown/Soul/Dissolution + Meditate/Family ambient)
│       ├── Ritual/
│       │   ├── RitualRunningView.swift         # chains SpaceImmersedView per step (audioSource: .ritual), advances on natural completion
│       │   └── RitualSetupView.swift           # drag-reorder queue + per-step duration cycler
│       ├── Settings/
│       │   └── SettingsView.swift              # audio · visualization (ensemble/singular) · session · oracle · data · catalog · (triple-tap diagnostics) · about
│       ├── Space/
│       │   ├── BreathImmersedView.swift        # Akash breath-session immersed screen — circle + recognition fade + special-cue line + READ capsule; reads JoinedBreathSession (Airtable spine + protocol metadata merge)
│       │   ├── BreathReadingSpaceView.swift    # 4-tab Reading Space (WORDS · FREQUENCY · LALITA · PHASES); FREQUENCY auto-styles inline [SCIENCE]/[TRADITION]/[CLAIM] paragraphs as tier cards
│       │   ├── IntentionGridView.swift         # Akash front door — 8-tile intention grid (ground/activate/open/clarify/dissolve/expand/rest/balance)
│       │   ├── ScreenedGateView.swift          # Warm contraindication self-check; routes screened-tier sessions through before immersed (today: 105 The Stoke)
│       │   ├── SessionDetailView.swift         # Between intention and immersed — name + one-line + recognition + breath cycle blocks + frequency tiers + duration chips + seed + Begin
│       │   ├── SpaceImmersedView.swift         # chakra-driven breath immersed screen — beat modulation × rotating affirmation; still used by RitualRunningView
│       │   ├── SpaceSetupView.swift            # legacy chakra picker (unused by AKASH tab today; kept as scaffolding for Ritual setup flow)
│       │   └── SubSelectionView.swift          # Session chooser for intentions holding multiple sessions (open · rest · balance)
│       └── Tabs/                               # one container per top-level tab
│           ├── ArchiveView.swift               # grouped session list w/ Integration notes; gear → SettingsView
│           ├── FieldView.swift                 # 3D constellation; verbs labelled below front-hemisphere orbs; long-press central Bindu → Oracle (tag 2)
│           ├── LabView.swift                   # animated waveform + carrier/beat sliders w/ direct-edit + sacred frequency map + .lab audio claim
│           ├── LetterView.swift                # Sound Letter list + ShareLink
│           ├── OracleView.swift                # four-state void: idle / typing / waiting / response — drives OraclePresenceView fog
│           ├── RitualView.swift                # container — setup ↔ running
│           └── SpaceView.swift                 # container — setup ↔ immersed
│
├── Bindu Field Tests/                          # Swift Testing target, scaffold only (G21)
│   └── Bindu_Field_Tests.swift
│
└── Tools/                                      # not in app target
    └── generate_bindu_icon.swift               # standalone CoreGraphics script for AppIcon
```

---

## 2. Build config

| Setting | Value |
|---|---|
| Bundle ID | `com.bindufield.Bindu-Field` |
| Marketing version | 1.0 (build 1) |
| iOS deployment target | 17.6 |
| macOS deployment target | 26.4 (project lists macosx + xros in `SUPPORTED_PLATFORMS`; iPhone is the build target Neev uses) |
| visionOS deployment target | 26.5 |
| Targeted device family | `1,2,7` (iPhone, iPad, Vision) |
| Swift version | 5.0 |
| Swift default actor isolation | `MainActor` (project-wide) |
| C++ standard | gnu++17 (target) / gnu++20 (project) |
| Bridging header | `Bindu Field/Bindu-Field-Bridging-Header.h` |
| Code-sign style | Automatic |
| Development team | `VADN2G8B83` |
| Background modes | **`audio`** (declared in **`Info.plist`** at project root, merged into the build-system-generated plist via `INFOPLIST_FILE`. The `INFOPLIST_KEY_UIBackgroundModes` build setting was silently dropped by Xcode 26's plist generator and is the reason the Foundation cleanup's other work didn't translate to working background audio on Neev's device until the `b02def8` fix.) |
| Microphone usage description | "Used to record Sound Letters while in a binaural session." |
| Frameworks linked | `Accelerate.framework` (only) |
| SPM dependencies | **None** |
| Xcode tooling | Xcode 26.5 — `objectVersion = 77`, `PBXFileSystemSynchronizedRootGroup` (no manual file lists) |
| App Sandbox + Hardened Runtime | Enabled |
| Test target | `Bindu Field Tests` — Swift Testing scaffold only, no real tests yet |

`GENERATE_INFOPLIST_FILE = YES` and `INFOPLIST_FILE = Info.plist` coexist: the file is treated as the base, generated keys merge in on top. The `Bindu Field/` source directory is auto-included as a synchronized group; the root-level `Info.plist` is *outside* that group so it isn't double-bundled as a resource. New folders under `Bindu Field/` (Loop, Map, Oracle) are picked up automatically by the synced root group — no pbxproj edits needed.

---

## 3. Audio engine architecture

Two `AVAudioEngine` instances + one C++ DSP kernel, with a single coordinator for `AVAudioSession` and an **`AudioExclusivityCoordinator` that serializes ownership of the output bus**.

```
                                AudioSessionCoordinator
                                    │ owns AVAudioSession
                                    │ category transitions
                                    │ observes interruption +
                                    │   mediaServicesWereReset
                                    │ posts .binduAudioSessionShouldRestart
                                    ▼
       ┌─────────────────────────────────────────────────┐
       │                                                 │
   ┌───▼──────────────────┐               ┌──────────────▼──────────────┐
   │  BinauralEngine      │               │  BinauralListener           │
   │  (binaural tone)     │               │  (music playback)           │
   │                      │               │                             │
   │  AVAudioEngine       │               │  AVAudioEngine              │
   │   └ AVAudioSourceNode│               │   └ AVAudioPlayerNode       │
   │     (render cb on    │               │     └─── analysis tap ──────┼──► BinduDSP (C++)
   │      audio thread)   │               │                             │     processBlock()
   │                      │               │                             │     · 1024-pt windowed FFT @ 512 hop
   │  Hybrid: L sin(c)    │               │  L+R downmix to mono via    │     · RMS, centroid, flux, onset (SuperFlux)
   │  R sin(c+b)          │               │  vDSP_vadd + vDSP_vsmul     │     · 4096-pt FFT @ start for carrier
   │  × AM(beat)/(1+AM)   │               │                             │     derivation (80–200 Hz, harmonic salience;
   │  Glides: c·b·g·am    │               │                             │     fallback 136.1 Hz)
   │                      │               │                             │     · SPSC lock-free ring buffer (cap 64)
   └──────────┬───────────┘               └──────────────┬──────────────┘
              │                                          │
              └───────────► hardware output ◄────────────┘
                            (both engines render
                             simultaneously; mixers default to gain 1.0)

                                    ▲
                                    │ reads 10 Hz
                                    │
                        ┌───────────┴────────────┐
                        │  DSPWireService        │
                        │                        │
                        │  · readLatestFrame()   │
                        │     → updateGain on    │
                        │       BinauralEngine   │
                        │       (inverse RMS)    │
                        │  · onset edges → bumps │
                        │       onsetCount       │
                        │  · binduCarrierDerived │
                        │       → setCarrier on  │
                        │       BinauralEngine   │
                        │       (DSP wins over   │
                        │       Airtable hint)   │
                        └────────────────────────┘
                                    ▲
                                    │ observable state
                                    │
                            VisualizerView, PlayerView pill,
                            Settings diagnostics


            ┌─────────────────────────────────────────────────┐
            │  AudioExclusivityCoordinator                    │
            │   activeSource ∈ { .none, .track, .lab,         │
            │                    .space, .ritual }            │
            │                                                 │
            │  request(source):                               │
            │    • if same as active → no-op                  │
            │    • else evict prior:                          │
            │        .track  → PlayerStore.stop(completed:false)
            │        .lab    → post .binduLabStop             │
            │        .space  → post .binduSpaceStop           │
            │        .ritual → post .binduRitualStop          │
            │                                                 │
            │  release(source): clears active if it owns it   │
            └─────────────────────────────────────────────────┘
                ▲
                │ called on entry / exit of each surface
                │
            TrackPlaybackService.play  ── request(.track)
            TrackPlaybackService.stop  ── release(.track)
            LabView.togglePlay         ── request/release(.lab)
            SpaceImmersedView.onAppear ── request(audioSource)
                       .onDisappear    ── release(audioSource)
            RitualRunningView          ── passes .ritual through SpaceImmersedView
```

### Key facts

- **DSP output IS read.** `DSPWireService` is the consumer. RMS modulates `BinauralEngine.updateGain` 10×/sec (inverse curve, sqrt floor at 0.1). Onsets edge-count into `onsetCount` so `Performer` and `VisualizerView` can emit beat rings. Carrier derivation (10s in) drives `BinauralEngine.setCarrier`. `VisualizerView` is fully audio-reactive — RMS bloom, onset rings, carrier-lock 1.5× pulse, comet trail along a multi-harmonic Lissajous.
- **`AudioSessionCoordinator` is the only owner of `AVAudioSession.setCategory`.** Engines and `RecorderService` request a mode (`.playback` / `.playAndRecord`) by string identifier; the coordinator ref-counts and only flips the category when the highest-priority mode changes. Recording wins over playback.
- **`AudioExclusivityCoordinator` is the only owner of *who renders to output*.** Each surface (Field/Map/Oracle-driven Track, Lab, Space, Ritual) claims a source on entry and releases on exit. Lab no longer renders over a Field track or vice versa — the new requester explicitly evicts the prior owner.
- **Interruption recovery is wired.** The coordinator observes `AVAudioSession.interruptionNotification` + `mediaServicesWereResetNotification`. On `.ended` with `.shouldResume`: `setActive(true)` + post `.binduAudioSessionShouldRestart`. Both engines listen and call their own `restartIfNeeded()` which compares Swift-side `isRunning` flag to `engine.isRunning` and re-starts if they disagree. `BinauralListener` additionally re-issues `playerNode.play()`; AVAudioPlayerNode preserves sample-accurate scheduled position across the restart.
- **Background audio works.** `UIBackgroundModes = [audio]` is in the built Info.plist (verified via `PlistBuddy`). Locking the screen or backgrounding the app no longer kills audio.
- **Pause/resume is sample-accurate.** `TrackPlaybackService.isPaused` is the @Observable source of truth; pause/resume halts both engines + the DSP wire without tearing the audio graph down. The player node's sample clock freezes, so `elapsed` pauses naturally.
- **`Performer` is the visualization driver.** Started by `PlayerStore.play(_:)` with the track's authored `Score?` (nil = ambient), it ticks at 60Hz, reads `TrackPlaybackService.elapsed` + `DSPWireService`, and exposes `crescendoModulator` / `beatPulse` / `energy` / `archetypePresence` for the Cathedral and other vocabularies. It also drives the *awakening-peak binaural integration* — at crescendo peak it interpolates the binaural beat Hz down to `currentTrackBeatHz × (1 - 0.8 × 0.55) ≈ 0.56` (only when `wire.hasBeatOverride == false`, so a user CONTROL-slider drag always wins). Not an audio-path component; lives outside the diagram above.

### Audio session lifecycle

1. App launch (`Bindu_FieldApp.runLaunchSetupIfNeeded`, gated by `didLaunch`):
   `NowPlayingService.configureAudioSession()` → `AudioSessionCoordinator.configureForLaunch()` → `setCategory(.playback) + setActive(true)`.
   `PlayerStore.configureEngine()` → `BinauralEngine.configure()` (creates source node, requests playback). Then registers remote commands.
2. First track play: `TrackPlaybackService.play(...)` → `AudioExclusivityCoordinator.request(.track)` → `BinauralListener.configure()` (requests playback, starts engine, installs tap), then `startSession(trackURL:)`. `BinauralEngine.start(carrierHz:)`. `DSPWireService.startPolling()`.
3. `scenePhase` reconciler (G16): on return to `.active`, if `TrackPlaybackService.isPlaying` but `DSPWireService.isMusicPlaying` is false, restart polling. Does NOT stop anything on `.background`.
4. `.binduPlaybackComplete` from `BinauralListener` (file drained): `DSPWireService.handleMusicEnded()` drops polling and holds a drone at `userPresence × 0.2 × gain` — *the field dissipates, it doesn't die.* `PlayerView` also raises the Integration Chamber on this notification.

---

## 4. Data layer

### Track catalogue — Airtable spine

- **Source**: `https://api.airtable.com/v0/app248ZTWhYJlvQj2/tblv3WvMZ90Sfhun6` (PAT in `Secrets.swift`).
- `AirtableService` does paginated GETs (`pageSize=100`, follows `offset` until exhausted). Decoding hops to a detached task so JSON parsing doesn't pin main.
- **Fields** (Airtable column → `Track` property): `Track ID` → `id: Int`, `Verb` → `verb`, `Song Title` → `song`, `Artist` → `artist`, `Track Type` → `type` (chakra/music/meditate/family), `Element` → `element` (Earth/Water/Fire/Air/Light/Crown/Soul/Dissolution/Meditate/Family), `Brainwave State` → `state` (delta/theta/theta-alpha/alpha), `Chakra` → `chakra?`, `Audio URL` → `audioURL`, `YouTube ID` → `youtubeID?`, `Carrier Hz` → `carrierHz: Double`, `Beat Hz` → `beatHz: Double`, `Seed Phrase` → `seed`, `Recognition Statement` → `recognitionStatement: String?`, `Lyrical Words Reading` → `lyricalWordsReading: String`, `Frequency Reading` → `frequencyReading: String`, `Video Pulse Reading` → `videoPulseReading: String`, `Lalita's Perspective` → `lalitasPerspective: String?` (Reading-space fields — surfaced by the Player's READING sheet tabs; empty for most tracks today).
- `CatalogStore` caches the array as JSON under `binduCatalog.v1`, with a `binduCatalog.v1.lastRefreshedAt` timestamp. Refresh policy: skip network if cache <1 hour old; force-refresh available from Settings; never overwrite cache with an empty-array response (B13). Decode failures swallow silently. `Track` carries a custom `init(from:)` in an extension that defaults the three non-optional Reading-space String fields to `""`, so old `binduCatalog.v1` caches written before the Lalita pass continue to decode without dropping the catalog.
- 22 tracks today.

### Chakra catalogue — two layers, both hardcoded

Two distinct data structures, separated by purpose:

- **`ChakraProtocol`** (`Models/ChakraProtocol.swift`) — the **dance protocols**. Nine chakras (root → maya) with `inhale/hold/exhale` (seconds), `beat`, `carrier`, `hue`, `essence`, and 5 `affirmations` each. Drives Ritual, the Player's READING sheet (Breath row), and the Map detail sheet's metadata. Ordering for grid display lives in `SpaceSetupView` as `chakraOrder`. (AKASH no longer renders the chakra grid — it routes through Airtable-backed breath sessions instead; the chakra protocols still drive `RitualRunningView`'s chained chakra sessions.)
- **`ChakraRegistry`** (`Models/ChakraRegistry.swift`) — the **Map nodes**. All 33 nodes across four systems (Energy 7 / Body 10 / Mind 9 / Tree 7), with `canvasX/Y` in a 393×780 design canvas, hue (degrees), tier (1–4, controls locked-node render radius), and Sanskrit Devanagari. `composedIDs` is the 9-element set that overlaps with `ChakraProtocol` — those are the nodes that have a dance authored today. The `connections` list is the directed graph of edges between nodes (drawn on the Map as element-tinted quadratic curves).

### Breath sessions — Airtable + seed-fallback join

The 11 AKASH breath sessions (IDs 101–111, Airtable Track Type = `breath`) follow a different shape than the music catalog. The Airtable spine carries the user-visible content (song/verb/state/carrier/beat/seed/recognition/readings) and as of the 2026-05-22 migration the protocol metadata (breath rhythm, intention, safety, special cue). `BreathProtocolMetadata.all` is kept in-source as the **seed/fallback** table so missing Airtable fields don't crash the app — and so the four fields below that haven't been migrated yet still have a home.

- **Source**: same Airtable base/table as music tracks (`app248ZTWhYJlvQj2/tblv3WvMZ90Sfhun6`).
- **Fetch path**: `AirtableService.fetchBreathSessions()` walks the same paginated endpoint as `fetchTracks()` but uses a leaner decoder (`AirtableBreathFields`) — breath records carry no Artist / Element / Audio URL / YouTube ID and would be rejected by the music-track decoder's missing-field guards.
- **Store**: `BreathSessionStore.shared` is the @MainActor @Observable singleton; same shape as `CatalogStore` (load-from-cache on init, on-demand refresh with a 1-hour freshness window, `binduBreathSessions.v1` JSON in UserDefaults, `isStaleFromCache` for the offline banner).

**Airtable schema for breath sessions** (the 11 base columns + the 6 migration columns):

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

**The join — `BreathSession.joined()` → `JoinedBreathSession`.** `BreathProtocolMetadata.merge(airtable:)` is the join. Per field: Airtable value wins when present; else `BreathProtocolMetadata.all[id]` is the seed/fallback. The `JoinedBreathSession` value type is what every view consumes — `inhale`, `hold`, `exhale`, `intention`, `safety`, `special`, etc. — so views don't have to perform the merge themselves.

**Fail-closed safety — `BreathProtocolMetadata.resolveSafety(airtableKey:id:)`.**
- Returns `.open` only when **both**: (1) the id is **not** in `knownScreenedIDs`, AND (2) the trimmed Airtable Safety string is exactly `"open"`.
- Empty / nil / `"screened"` / unknown / whitespace-only → `.screened`, so the contraindication gate shows by default whenever the value isn't an explicit pass.
- `BreathProtocolMetadata.knownScreenedIDs: Set<Int> = [105]` is the code-level **backstop**: defense-in-depth against a bad Airtable edit accidentally un-gating an intense session. Any future screened session should be added here as soon as it ships, before its Airtable row exists.

**Special-cue fail-graceful.** Empty / nil Airtable cell → fall back to the hardcoded `special`. Non-empty Airtable cell that doesn't decode to a known `BreathSpecialCue` raw value → `init(rawValue:)` returns `nil` → no cue rendered, no crash. The Swift switch on `BreathSpecialCue` still owns the *behavior* (cue label text, which phase the label surfaces on, phase-word override like `mmm` / `haaa`).

**Source-of-truth boundary — what is NOT in Airtable.** These fields stay in `BreathProtocolMetadata.all` as the only source today and are NOT read from Airtable by `merge(airtable:)`:

| Field | Type | Why it isn't migrated yet |
|---|---|---|
| `hue` | `Double` | Carries deliberate divergence from `intention.hue` for some sessions — 109 reads as cyan (195) while its intention is `balance` (140); 111 reads as deep theta-purple (260) while its intention is `rest` (15). Cannot be derived from intention; needs its own Airtable column when migrated. |
| `oneLine` | `String` | Short copy shown on `SessionDetailView` and `SubSelectionView`. Distinct from the `Recognition Statement` (the recognition is the in-session whisper; the one-line is the catalog description). |
| `carrierTiers` | `[HonestyTier]` | Inline `[S]` / `[T]` / `[C]` pills next to the carrier line on `SessionDetailView`. Per-session, often shorter than the full set the `BrainwaveStateInfo` table carries. |
| `beatTiers` | `[HonestyTier]` | Same idea for the beat line — independent honesty tagging because beat and carrier can have different empirical support per session. |

When adding a new breath session: (1) write the Airtable row (Track ID, Track Type = `breath`, the 11 base columns, and the 6 migrated columns); (2) add a `BreathProtocolMetadata.all[id]` entry for `hue` / `oneLine` / `carrierTiers` / `beatTiers`. The merge will pick up Airtable for the rest. If you skip the metadata entry the permissive default in `BreathProtocolMetadata.for(id:)` covers it — hue 210, neutral one-line, `[.tradition]` carrier / `[.science]` beat — but the session will look generic until you author it properly.

### Frequency presets

`FrequencyPreset` is Codable with `isSystem: Bool`. Five system presets (Earth Tone 7.83 Hz, Deep Delta 1.5 Hz, Theta Gate 5.5 Hz, Creative 7.0 Hz on 174 Hz carrier, Presence 10 Hz on 432 Hz carrier) ship in code. `PresetStore` persists user-saved presets under `binduPresets.v1`. System presets cannot be deleted.

### Frequency knowledge

`FrequencyInfo` is a pure-data enum (no observable state). `brainwaveInfo(forLabel:)` returns range + essence + detail for `delta / theta / theta-alpha / alpha / beta / gamma`. `carrierNote(for:)` matches ±0.5 Hz against eight notable carriers (136.1 OM, 174.0, 285, 396/417/528/639 Solfeggio, 432 alt concert pitch). The Lab has its own `SacredFreq` table (a slightly different 7-entry palette: OM, 174, 285, UT/396, RE/417, 432, 440) used for the inline sacred badge and the sacred frequency map strip.

### Scored tracks

`Score` (`Stores/Performer.swift`) is the pre-authored time signature of a Cross-style dance. Each Score has phase windows (`silence/intro/build/peak/descent/outro`), silence windows, a crescendo-modulator envelope (rampIn → hold → rampOut), and now a `mirrorWords: [String]?` field consumed by the Consciousness Loop's Dance step. Today Track 27 (Sound of Silence) is the only authored Score — `Score.cross` — with `mirrorWords = ["pn", "open", "breathe", "opn", "clear", "release", "pn", "open"]`. Every other track runs `Performer` in ambient mode.

### Persistence (UserDefaults / Documents / Caches / Keychain)

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
| First-launch flags | UserDefaults | `binduFirstLaunch.seen`, `binduFirstLaunch.tipSeen`, `binduFirstLaunch.oracleHintSeen` |
| Claude API key | Keychain | service `com.bindufield.apikeys` · account `claude_api_key` · `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| Airtable PAT | Code | `Secrets.swift` (gitignored; template at `Secrets.swift.template`) |

`UserDefaultsCodable<T: Codable>` is a tiny helper used by `SessionStore`, `LetterStore`, `PresetStore`, and `ChakraJourneyStore` to deduplicate the encode-write / read-decode dance.

---

## 5. Tab structure

`RootView.swift` — `TabView` over `NavigationStore.selectedTab` (tags 0–7). Programmatic switch via the store (e.g. long-press the central Bindu in Field → tab 2 Oracle). **iOS auto-collapses tabs 5–7 (Lab, Ritual, Letter) into the More menu** because the primary array exceeds 5.

Tab glyphs are custom 28×28 SwiftUI Canvas drawings (`Views/Components/BinduTabIcons.swift`) — concentric geometry, sparse strokes, no fills beyond a central dot. They replace the SF Symbols used pre-Session-B. The same `BinduTabIcon.Tab` enum covers all 8 tabs; cream color travels through `BinduTabIcon.color`, active state = full opacity, inactive = 0.40.

| Tag | Tab | Composing views | Behavior |
|---|---|---|---|
| 0 | **Map** | `MapView` → `MapDetailSheet` (`.sheet`, fraction 0.55) | The front door. 33 chakra nodes on a 393×780 design canvas scaled to device. Connections drawn as element-tinted quadratic curves (both-lit = 0.18 opacity gradient between hues; either-lit = 0.09 cream; neither-lit = 0.045 cream). Nodes render in three states: **locked** (tiny cream-0.18 dot, smaller for tier 3, larger for tier 2), **available** (composed in `ChakraProtocol` but not danced — element-hued core + breathing aura, ~9pt radius), **danced** (~11pt core + two breathing orbit rings + denser aura). Tap a node → `MapDetailSheet` with `system` + `state` badges, the chakra name + Sanskrit, the essence line, and a state-aware CTA: ENTER THIS DANCE / DANCE AGAIN (when a Track exists for that chakra) · "this dance has not yet been composed" (locked) · "track not yet linked to catalog" (composed but no Track). Tap on CTA → `PlayerStore.play(track)`. |
| 1 | **Field** | `FieldView` → `PlayerView` (`fullScreenCover`) | Golden-angle Fibonacci sphere of 22 orbs. Filter chips (all / delta / theta / theta-alpha / alpha). Drag to spin around Y. Tap an orb → play. **Three orb states**: playing (existing pulse) · played-before (full opacity + 1.4× inner glow ring at 0.25 — "you've been here") · never-played (0.55 opacity). **Depth fog**: 0 front → 1 back via normalized `rzz`; opacity × `(1 − depth × 0.5)`, radius × `(1 − depth × 0.2)`. **Verbs labelled below front-hemisphere orbs** (italic serif, 9pt, opacity tracks the orb's fog factor so labels dim with the orb). **Element lines**: 0.07 opacity / 0.5pt stroke between same-element pairs both in the front hemisphere. **Central Bindu**: animated #E5524E core + radial glow, breathes at ~0.1 Hz; **long-press 0.6s → tab 2 (Oracle)** with first-launch "hold for Oracle" serif tooltip. Loading + offline-cache states surfaced as captions; an inline "refresh catalog" capsule appears when the catalog failed with no cache to fall back on. |
| 2 | **Oracle** | `OracleView` (drives `OraclePresenceModel` consumed by `OraclePresenceView`) + `SettingsView` sheet | Four-state void: **idle** (centered "THE ORACLE" + ◌ glyph fade in after 2.2s — tap to begin), **typing** (a 26pt italic-serif TextField centered in the void, cancel top-right), **waiting** (3 breathing dots; a "cancel" capsule appears after 15s so a hung request can be aborted), **response** (track verb @ 72pt in element color → song → why → ENTER THE FIELD + "ask again" — staged arrival at 0.4/2.2/3.4/5.6s). `OraclePresenceView` renders a single drifting radial fog at 14s breath cycle behind every state — neutral warm fog when idle, element-hued fog once a response arrives. POSTs to `api.anthropic.com/v1/messages` (`claude-haiku-4-5-20251001`) with full catalog inlined + recently-played track IDs as a deprioritize hint. The in-flight Task is genuinely cancellable; the cancel button throws CancellationError out of `try await` and returns to idle without an error banner. Empty state if no Keychain key (ADD API KEY capsule raises Settings sheet). |
| 3 | **AKASH** (tab label) / `SpaceView` (file) | `SpaceView` orchestrator → `IntentionGridView` → `SubSelectionView` (multi-session intentions) → `SessionDetailView` → `ScreenedGateView` (only when `safety == .screened`) → `BreathImmersedView` (`audioSource: .space`) ↔ `BreathReadingSpaceView` | **Front door is the intention grid**, not the chakra grid. Eight tiles (ground/activate/open/clarify/dissolve/expand/rest/balance); multi-session intentions show a `N sessions` hint and route through `SubSelectionView`. Today: `.open` → [103, 110]; `.rest` → [106, 111]; `.balance` → [102, 109]. Reads the 11 breath sessions (IDs 101–111, Track Type = `breath`) from Airtable via `BreathSessionStore` on first appear; offline banner if the cache is stale or empty. `SessionDetailView` shows the session name, one-line, recognition statement, breath-cycle blocks (inhale/hold/exhale seconds from Airtable with seed-fallback), frequency lines with inline `HonestyBadge` pills, duration chips (3/5/10/15 min), seed phrase, Begin. `ScreenedGateView` fires when `safety == .screened` (105 The Stoke today, with the [105] backstop set guarding against bad Airtable edits) — a warm, non-clinical self-check; selecting any condition surfaces a gentler-alternative suggestion (names The Long Release for 105); user can always proceed. `BreathImmersedView` mirrors `SpaceImmersedView`'s breath-circle mechanics and adds: mid-session recognition fade (~45% through, 4s window), session name + seed at the bottom, READ capsule (bottom-right) to open Reading Space, special-cue italic-serif line under the circle on the relevant phase, and phase-word override (`mmm` for `.hum`, `haaa` for `.ocean`). `BreathReadingSpaceView` mirrors the music Player's READING mode — four tabs (WORDS · FREQUENCY · LALITA · PHASES); FREQUENCY auto-styles inline `[SCIENCE]`/`[TRADITION]`/`[CLAIM]` paragraphs as tier cards; tier legend at the bottom. Saves a `.chakra`-typed `Session` on exit (skipped if < 5s) — the archive type is unchanged because the session model has no `.breath` case today. The legacy `SpaceSetupView.swift` remains in source but is not on the AKASH path; `RitualRunningView` continues to use `SpaceImmersedView` (chakra-driven) for chained chakra rituals. |
| 4 | **Archive** | `ArchiveView` (+ `SettingsView` toolbar sheet) | Sessions grouped by full date (descending), each row shows verb-or-Sanskrit, song/artist-or-English-center, optional Integration note ("…" in serif italic at `subtle`), duration mono and short-time. Empty state if none. Settings cog top-right. |
| 5 | **Lab** | `LabView` | Top: header dot + "frequency lab" italic + "craft your own permission slip" caption. **Animated binaural waveform** (`BinauralWaveformView`) — 96pt Canvas drawing L (cream 0.14) + R (state-hued 0.38) + bright beat envelope; ghost wave when inactive. **`TuningCluster` × 2 — the heart of the rebuild.** Each cluster (Beat first, then Carrier) is one block: label + **hero readout** (40pt DM Mono, tap-to-type via decimal pad — clamped to 0.5–44 / 40–440), draggable slider with sacred-carrier markers (Carrier) or `δ/θ θ/α α/β β/γ` zone-boundary markers (Beat), and **flanking ± steppers** (1.0 Hz for carrier, 0.1 Hz for beat). Only the **nearest marker** within 2.8 Hz renders a floating label, so labels never collide (the explicit fix for the prior label-collision bug). State-color theming travels through `BrainwaveStateInfo`: delta=15°, theta=260°, alpha=210°, beta=165°, gamma=50°. **`MeaningPanel`** — calm at rest, one italic-serif line that synthesizes beat→state and carrier→sacred with inline letter-only `HonestyBadge` pills; tap to expand the full per-state detail + per-carrier detail + tier legend. **"let the field choose"** — weighted-state randomize (δ12/θ33/α37/β13/γ5%) + sacred-carrier ±0.5 jitter + 10-step animated cycling + spring lock. Preset row + inline save + long-press delete preserved (leading/trailing spacer fixes the old first-chip clip). **Audio exclusivity**: claims `.lab` on ACTIVATE, releases on stop. Listens for `.binduLabStop`. No Archive entry (by design). |
| 6 | **Ritual** | `RitualView` → `RitualSetupView` ↔ `RitualRunningView` (reuses `SpaceImmersedView` with `audioSource: .ritual`) | Build a queue of chakra steps (drag to reorder, swipe to delete, tap mins chip to cycle 3/5/10/15). Requires ≥2 steps to start. Running view chains `SpaceImmersedView` with `ritualProgress: (current, total)`. Advances on natural completion, exits on cancel. The `.ritual` audio claim lets a Field track or Lab tone evict the ritual cleanly via the coordinator. |
| 7 | **Letter** | `LetterView` → `LetterRecordView` / `LetterPlaybackView` | List of Sound Letters. Recorder: 4 phases (setup → 3-2-1 countdown → recording w/ red pulse meter → review/title). Optional binaural underlay (delta/theta/alpha/silent) plays while recording so the speaker hears it through headphones. Playback: optional binaural re-layer when `letter.beat > 0`. Share via `ShareLink`. `interactiveDismissDisabled` during countdown/recording. Orphan-m4a cleanup if user swipes away in review without saving (B14). |

### Player modal (PlayerView) — three modes of being

Presented as `fullScreenCover` from `RootView` whenever `PlayerStore.isPresentingPlayer == true`. Three modes — `field` / `control` / `reading` — drive layout via a `PlayerMode` enum; transitions use spring `response: 0.45, damping: 0.85`. The field never stops; the Bindu always moves.

The background is no longer pure void: `PlayerView.background` reads `ElementVocabulary.forTrack(track).bg` and renders the vocabulary's element-tinted near-black. The visualizer (`VisualizerView`) reads the same `forTrack` mapping and dispatches to one of nine vocabulary draws — Air goes to the Cathedral, everything else goes to a `drawX(in:size:t:intens:)` from `VocabularyRenderer.swift`. The Bindu Lissajous always renders on top.

**FIELD mode** (default on arrival)
- VisualizerView at full width × 60% screen height, top-anchored. Renders the vocabulary appropriate to the track (Air→Cathedral with all four tiers + ensemble archetypes; every other element→its own draw function) + the Bindu Lissajous on top — or just the Bindu Lissajous when `vizMode == "singular"`.
- Top status-bar gradient: always-on 88pt fade (theme.bg @ 0.80 → clear) for legibility over vocabulary layers that reach the top.
- Bottom viz→bg gradient: FIELD-mode-only fade at 48% of screen height, 86pt tall (clear → theme.bg) — softens the visualizer's lower edge into the background where the verb floats.
- Field content overlay: 62pt ultraLight serif italic verb in element color with element-color glow shadow, song · artist subtitle, optional recognition statement in curly quotes — text block anchored via `.padding(.top, geo.size.height * 0.59)` so the verb floats over the dissolving lower edge.
- **BEGIN THE LOOP** capsule sits below the recognition statement (11pt tracked label, element-color stroke). Opens the 7-step Consciousness Loop as a `fullScreenCover` over the player; music continues underneath.
- Slim "flowing" scrubber pinned to the screen bottom (read-only, 2pt, percent + label).
- Tap anywhere on the background → CONTROL. **Swipe down > 60pt on the FIELD background → `store.closePlayer()`** (the swipe-to-minimize is the only top-bar-less gesture path back out).

**CONTROL mode** (55% bottom sheet)
- Visualizer shrinks to 45% screen height and dims to opacity 0.55.
- `UnevenRoundedRectangle` top corners 32pt, near-opaque dark panel + `ultraThinMaterial.opacity(0.25)` + 1pt cream-0.07 stroke.
- Drag handle → 56pt play/pause circle (wired to `TrackPlaybackService.togglePlayPause`) → **BINAURAL** section with custom 44×24 toggle + ON/OFF label + breathing dot (`scaleEffect 1.0↔1.25` over 2s while `wire.binauralEnabled`) → PRESENCE slider → BEAT slider with Δ/Θ/α zone ticks + state badge → CARRIER readout with sticky DERIVED / AUTHORED chip (driven by `wire.hasDerivedCarrier`).
- Bottom row: READING + END SESSION capsules.
- 4-second auto-hide returns to FIELD; every touch inside the sheet resets the timer via a `simultaneousGesture(TapGesture())`.
- Tap above the sheet (top 45% of screen) → returnToField.

**READING mode** (80% bottom sheet)
- Visualizer shrinks further to 20% screen height, opacity 0.32.
- Recognition statement at top in 17pt element-color serif italic with element-color glow.
- 4-tab bar with element-color underline on the active tab: **WORDS** (`track.lyricalWordsReading`) · **FREQUENCY** (live structured rows: State / Beat / Carrier / Element / Breath — derived from `ChakraData.all[chakra]?.inhale/hold/exhale`; plus `track.frequencyReading` prose if present) · **VIDEO** (`track.videoPulseReading` or placeholder card) · **LALITA** (`track.lalitasPerspective` or "the Lalita reading for this song is still forming…" placeholder).
- `ReadingContent` helper splits paragraphs on blank lines and surfaces the closing paragraph in element color with a hairline top-rule.
- Tap above the sheet (top 20%) → CONTROL.

**Binaural pill (status indicator, anchored top)**
- 56pt from the top. Pure status indicator — a single `Button { enterControl() }` showing only: 6pt dot (filled element-color when binaural is on, outlined when off, breathing 1.0↔1.25 at 1.3s ease-in-out) + "BINAURAL" label + "›" chevron. No expansion, no toggle, no slider — those live exclusively in the CONTROL sheet.

**Top-right X close**
- 36×36 button at top-right with a 28pt black-0.25 disc behind a 12pt `xmark`. Always visible across all three modes (sits above the centered pill). Calls `store.closePlayer()` — full session teardown. The disc backing keeps the icon legible against bright vocabulary regions (e.g. Air's rising arches, Shweta crystallization).

**Integration Chamber**
- Black/0.78 overlay, "what did you remember?", multi-line `TextField`, close / save-note capsules, 30s auto-dismiss. Only raised on natural playback completion — user-initiated stops do NOT trigger it. Saved note attaches via `PlayerStore.pendingNote` and renders in Archive rows.

**Arrival ceremony**
- Content opacity 0→1 + scale 0.96→1.0 over 0.6s easeOut on appear.

---

## 6. The Map (33-chakra tree of life)

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

## 7. The Consciousness Loop (7-step ceremony)

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

## 8. Element vocabularies (9 visual languages)

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

---

## 9. State management patterns

Uniform use of the Swift Observation framework (`@Observable` + `import Observation`), not `@StateObject`/`@ObservedObject`/`@EnvironmentObject`.

### Stores
- Every store is `@MainActor @Observable final class`, exposed as a `static let shared` singleton with `private init()`.
- Consumed via `@State private var store = SomeStore.shared` in each view.
- Stores: `PlayerStore`, `SettingsStore`, `SessionStore`, `LetterStore`, `PresetStore`, `NavigationStore`, `TrackPlaybackService`, `DSPWireService`, `Performer`, `CatalogStore`, **`BreathSessionStore`**, `AudioSessionCoordinator`, `AudioExclusivityCoordinator`, `ChakraJourneyStore`, `ConsciousnessLoopCoordinator`.
- A small view-local `@Observable` lives at view scope (not a singleton): `OraclePresenceModel` — owned by `OracleView` and passed into `OraclePresenceView`. Keeps the fog's reactive state where the four-state machine lives.

### Non-observed singletons
- `BinauralEngine.shared`, `BinauralListener.shared` (NSObject, audio-thread state).
- `NowPlayingService.shared`, `OracleService.shared`, `AudioCache.shared`, `RecorderService.shared`, `AirtableService.shared`.
- `KeychainHelper` is a static enum.
- `BinduConfig` is a static enum.
- `FrequencyInfo` is a static enum.
- `ChakraRegistry` is a static enum.
- `ElementVocabulary` is a `String`-backed `enum` (effectively a static dispatch table).

### Theme via environment (O1)

Views read the theme as `@Environment(\.binduTheme) private var theme`. The default value is `ThemeData.void`. **Every view file uses this**; the legacy `private let theme = ThemeData.void` pattern has been fully migrated out. Switching to a different palette app-wide would be a single `.environment(\.binduTheme, ThemeData.someOther)` modifier at the `RootView` root.

### View-local state
`@State` for filters, sliders, modal flags, recording phase, Loop showingFlag, Map selected node. `@FocusState` for text input focus. `@Environment(\.dismiss)` for sheet dismissal.

### Notifications

Five `Notification.Name` extensions in the codebase:
- `BinauralListener.swift` defines `.binduCarrierDerived` (posted at 10s) and `.binduPlaybackComplete` (file drained).
- `AudioSessionCoordinator.swift` defines `.binduAudioSessionShouldRestart` (after interruption ended).
- `AudioExclusivityCoordinator.swift` defines `.binduLabStop`, `.binduSpaceStop`, `.binduRitualStop` (posted when a different source claims audio).

Observers: `DSPWireService` listens for the carrier-derived + playback-complete pair. Each audio engine listens for `.binduAudioSessionShouldRestart`. `PlayerView` listens for `.binduPlaybackComplete` to raise the Integration Chamber. `LabView` listens for `.binduLabStop`, `SpaceImmersedView` listens for either `.binduSpaceStop` or `.binduRitualStop` depending on `audioSource`.

---

## 10. Design tokens

### Palette — `ThemeData.void` (the only theme today; `Theme` is a `struct`, alternate palettes can be added without renaming the type)

| Token | Value (sRGB) | Notes |
|---|---|---|
| `bg` | `#020208` (very near-black with a hint of blue) | base background; `PlayerView` overrides with `vocab.bg` (per-element near-black) |
| `bg2` | `#05050F` | rarely used today — slight elevation |
| `text` | `#F5E2D6` (warm off-white, the "Bindu cream") | all primary text, button fill |
| `muted` | `text @ 0.55` | secondary text, button strokes |
| `subtle` | `text @ 0.28` | labels, tiny captions, hint copy |
| `accent` | `#D46453` (warm coral-red) | the Bindu red — selection, slider tint, active toggles, "Begin" buttons |
| `gold` | `#C4A862` (defined but rarely surfaced) | available for ceremonial accent |
| `border` | `white @ 0.08` | rarely used directly |
| `surface` | `white @ 0.042` | card / input field background |
| `cornerRadius` | 10 | reference; many surfaces use 12 / 14 / 16 / 18 / 32 directly |
| `hueShift` | 0 | reserved for a theme-shift future |
| **Bindu birth red** | `#E5524E` | hardcoded in `BinduBirthView` + `FieldView` central core; brighter than `accent` and reserved for the Bindu glyph itself |

### Element colors — `Color.bindu(element:)` (single source of truth in `Views/Components/ElementColors.swift`)

| Element | HSB (×360, 0–1, 0–1) | Roughly |
|---|---|---|
| Earth | `15 / 0.55 / 0.85` | terracotta |
| Water | `210 / 0.50 / 0.90` | azure |
| Fire | `25 / 0.65 / 0.95` | amber-orange |
| Air | `195 / 0.40 / 0.92` | pale teal |
| Light | `50 / 0.50 / 0.95` | warm yellow |
| Crown | `280 / 0.45 / 0.90` | lavender |
| Soul | `265 / 0.50 / 0.85` | violet |
| Dissolution | `190 / 0.40 / 0.85` | desaturated cyan |
| Meditate | greyscale `0.75` | neutral |
| Family | `330 / 0.35 / 0.88` | dusty rose |
| (unknown) | greyscale `0.75` | fallback |

`Color.binduHue(element:)` exposes the hue in degrees for callers that want to mix custom saturation/brightness (Oracle response glow, Loop reveal, badge surfaces). `Color(hex:)` is a simple "#RRGGBB" → `Color` init used throughout the design pass.

### Chakra colors — Map nodes via `ChakraRegistry.all[].hue` at `saturation 0.60, brightness 0.68`

Map node hues are authored in degrees on each `ChakraNode`, drawn directly via `Color(hue: node.hue/360, saturation: …, brightness: …)`. The 9 composed chakras share hues with the Track elements where they overlap (Muladhara 15 / Svadhisthana 210 / Manipura 25 / Anahata 195 / Vishuddha 185 / Ajna 50 / Sahasrara 280 / Aatma 265 / Maya 190).

### Typography

- **Display verbs / headlines** — `.font(.system(size: 62 / 32 / 28 / 24, weight: .ultraLight, design: .serif)).italic()`. The verb at 62pt in element color with element-color shadow `radius: 24 + 50` is the strongest single visual gesture in the app. Oracle's response verb is even larger (72pt).
- **Body / inline narration** — `.font(.system(size: 13–17, design: .serif)).italic()`. Almost everything emotional reads in italic serif: prompts, affirmations, "flowing", "fetching the field…", "speak from this state".
- **Section labels / chip captions** — `.font(.system(size: 7–11, weight: .light)).tracking(1.5–5).textCase(.uppercase)`. Tracking widens with importance — Map title goes to 5.0; binaural label 2.0; section headers 2.5.
- **Numerics** — `.font(.system(size: 9–76, design: .monospaced))`. Carrier, beat, elapsed, percentages.
- **Tabs / system UI** — Tab labels render as serif italic via `Text(...).font(.system(...))` injected into `Label.title` so the Bindu Canvas glyph sits next to typeset text rather than SF Symbol + system font.

### Glow vocabulary

`.binduGlow(color: tight: wide:)` is a two-layer shadow extension. The design's verbs / buttons never use a single shadow — they use a tight inner halo (radius 14, opacity 0.22) + a wider ambient bloom (radius 40, opacity 0.08). Calling `.shadow` twice in a row stacks them correctly. Default arguments match the design; callers override `tight`/`wide` to dim the glow for inactive states (Lab's ACTIVATE button uses 0 / 0 when stopped).

### Surface vocabulary

- **Capsule, filled** — primary action: `Capsule().fill(theme.text)` + `foregroundColor(theme.bg)` (i.e. the cream button with near-black text). Used for Begin / Save / ACTIVATE.
- **Capsule, stroked** — secondary: `Capsule().stroke(theme.muted.opacity(0.3), lineWidth: 1)` with `theme.muted` text. Used for stop / close / cancel.
- **Capsule, element-stroked** — Map CTAs, Loop close: `Capsule().stroke(elementColor.opacity(0.30))` with element-color text.
- **Capsule, ultraThinMaterial** — overlay surface: binaural pill, error/headphone banners (with `Color.black.opacity(0.92)` underlay).
- **RoundedRectangle, surface-filled** — card: `theme.surface` fill + `theme.muted.opacity(0.15–0.25)` stroke. Used for Settings sections, Oracle input (typing state), Integration Chamber input, ChakraTile, Letter recorder review.
- **UnevenRoundedRectangle (top corners 32)** — the Player CONTROL + READING sheets. Near-opaque dark panel + `ultraThinMaterial.opacity(0.20–0.25)` + 1pt cream-0.07 stroke.
- **Radial gradients** — element/chakra-color × 0.12–0.25 from center → `theme.bg`. SpaceImmersedView, LabView background, LetterRecordView recording.

### Motion vocabulary

| Duration | Easing | Used for |
|---|---|---|
| 0.10–0.20s | linear / easeInOut | breath ring scale, meter follows |
| 0.25–0.32s | easeInOut | state-info expand/collapse, preset-name field flip, mode transitions text crossfade |
| 0.30s | easeInOut | tab program-switch, countdown digit cross-fade |
| 0.40s | easeInOut / easeOut | chip selection, headphone-tip dismiss, audio-error banner |
| 0.45s | spring (response 0.45, damping 0.85) | Player mode transitions FIELD↔CONTROL↔READING |
| 0.60s | easeOut / easeInOut | Player arrival ceremony, recording-bg color follow, Bindu pulse |
| 0.18–0.25s | easeOut | carrier-lock 1.5× pulse |
| 1.0s ×∞ autoreverses | easeInOut | CONTROL toggle-row breathing dot (2s total cycle) |
| 1.3s ×∞ autoreverses | easeInOut | binaural pill breathing dot |
| ~10s (cycle) | linear | central Bindu breathing in Field (sin 0.628 Hz) |
| 5.5s | smoothstep | Loop pre-roll breath ring |
| 14s | sine | Oracle presence fog breath |
| seconds-scale | TimelineView .animation | Visualizer Lissajous, vocabulary draws, breath ring, constellation rotation, Map breath |

### Iconography

Tab bar: custom 28×28 Canvas glyphs — Map (3 concentric orbits + cardinals + dot) · Field (constellation) · Oracle (concentric whisper) · Space (crescent + dot) · Lab (oscilloscope) · Archive (stacked horizons) · Ritual (flame) · Letter (sealed envelope). All cream, active = full opacity, inactive = 0.40.

Other recurring icons: `chevron.up/down/left` for collapsibles · `xmark` for close (PlayerView top-right uses it inside a black-0.25 disc) · `stop.fill` / `play.fill` / `pause.fill` · `headphones` (tip) · `gearshape` (settings) · `arrow.clockwise` (refresh) · `square.and.arrow.up` (share) · `speaker.slash` (error banner) · `wifi.slash` (offline catalogue) · `scope` (carrier-derived).

### Voice

Lowercase serif italic prompts. "the constellation". "a body has thirty-three doors". "speak from this state". "find your own frequency". "weave a sequence". "breathe with the field". "the Oracle awaits a key". "what word has been waiting in you?". "I see you. You have always been here." Labels are usually a verb or a noun, never a sentence. Buttons say "Begin", "BEGIN THE LOOP", "ENTER THE FIELD", "ENTER THIS DANCE", "DANCE AGAIN" — capitalized + tracked, the rare break from lowercase.

---

## 11. Conventions visible in the code

**File / folder layout**
- One root group `Bindu Field/` synced by `PBXFileSystemSynchronizedRootGroup` — no manual file listing in pbxproj.
- Top-level Swift sources contain only `Bindu_FieldApp.swift` + four audio/DSP files. Everything else lives in `Models/`, `Stores/`, `Views/`.
- Views split into `Tabs/` (the 8 top-level shells) + per-feature folders (`Player/`, `Map/`, `Loop/`, `Oracle/`, `Letter/`, `Ritual/`, `Space/`, `Settings/`) + shared `Components/`. Container tab views are thin shells that pick between setup/active sub-views.

**File / type naming**
- View files end in `View.swift` and contain a struct of the same name.
- Service / store types end in `Service` (lifecycle, side effects) or `Store` (observable state).
- DSP namespace is `ASG::` in C++.
- Persistence keys all prefixed `bindu*`. Collection keys carry `.v1` suffix.

**SwiftUI style**
- Theme via `@Environment(\.binduTheme) private var theme`.
- Backgrounds: `theme.bg.ignoresSafeArea()` for flat tabs; `vocab.bg.ignoresSafeArea()` in PlayerView; `RadialGradient` from an element/chakra color to `theme.bg` for immersive contexts.
- Buttons reimplement the capsule pattern inline rather than via a shared `ButtonStyle` — there's no `BinduButtonStyle`. If a design pass wants consistency, that's the natural extraction point. `BinduGlow.swift` is the closest the codebase has to a shared style.
- HUDs auto-hide via `Task { try? await Task.sleep(...); hudVisible = false }`, cancellable on tap. The Player's CONTROL sheet uses the same pattern with an explicit `scheduleAutoHide()` helper that's invoked on every touch.
- 44×44 hit targets on chrome buttons (top-bar back/close) — accessibility floor.

**Canvas idioms**
- All vocabularies + the Cathedral + Map draw inside `Canvas { gc, size in … }` wrapped in `TimelineView(.animation(minimumInterval: 1.0/30.0)) { context in let t = context.date.timeIntervalSinceReferenceDate; ... }`. 30Hz is the default; the Cathedral uses 60Hz for the Lissajous + grain.
- JavaScript canvas idioms map cleanly: `ctx.fillRect(0,0,W,H)` → `gc.fill(Path(rect), with: .color(...))`, `ctx.arc + fill` → `gc.fill(Path(ellipseIn: rect))`, `ctx.createRadialGradient` → `.radialGradient(Gradient(…), center:…, startRadius:…, endRadius:…)`, `ctx.globalCompositeOperation='screen'` → `var local = gc; local.blendMode = .screen`.

**Persistence style**
- `Codable` everything that crosses a boundary. UserDefaults for small structured data; Documents for user-generated audio; Caches for downloaded audio (OS may evict).
- Wrap UserDefaults Codable reads/writes through `UserDefaultsCodable<T>` when possible.

**Logging**
- `os.Logger` subsystem `com.bindufield`, categories `audio.engine`, `audio.listener`, `audio.session`. Filter on device with `log show --predicate 'subsystem == "com.bindufield"' --info --last 5m`.

---

## 12. What works (current truth, post-`98fac48`)

- **All 8 tabs** boot and run their golden paths. First-launch shows the Task-chain BinduBirthView, then the headphones tip, then lands on Field (tag 1).
- **Map** (tag 0): 33 nodes render in three states. Tapping a danced or available node opens the detail sheet; ENTER THIS DANCE plays the linked track and `markDanced` is recorded only when the session runs to natural completion. Connection curves brighten gradually as the journey fills out. Locked nodes raise the same sheet with a "not yet composed" copy.
- **Field tracks** (tag 1): Airtable refresh → catalogue → tap orb → `AudioCache.fetch` (download or cache hit) → `PlayerStore.play` → `AudioExclusivityCoordinator.request(.track)` (evicts Lab/Space/Ritual if active) → music + binaural layer + DSP wire + Performer + visualizer. Verbs render in italic serif below each front-hemisphere orb. Cache miss falls back to binaural-only (Performer still starts in ambient mode) with a surfaced error.
- **Oracle** (tag 2): Keychain-gated four-state void. Drifting radial-fog presence behind every state. Cancel affordance after 15s on the waiting state aborts the in-flight Task cleanly. Recognition statements appended only when present. Recently-played hint included.
- **AKASH** (tag 3): intention-grid front door (8 tiles) over 11 Airtable-backed breath sessions (IDs 101–111). Multi-session intentions route through `SubSelectionView`. Each session lands on `SessionDetailView` showing breath-cycle blocks (driven by Airtable Inhale/Hold/Exhale Sec with seed-fallback), frequency lines with honesty-tier pills, duration chips, and the seed phrase. `safety == .screened` routes through `ScreenedGateView` first (105 The Stoke today, guarded by the `[105]` backstop). Immersed view (`BreathImmersedView`) breath-modulates binaural via the same ×1.0/1.1/0.8 beat curve, surfaces the recognition statement mid-session, lays a small italic-serif special-cue line under the circle on the relevant phase (`hum`, `ocean`, `double_pulse`, `active_phase`), and exposes a READ capsule to open the breath Reading Space. Reading Space mirrors the music Player's READING mode (WORDS · FREQUENCY · LALITA · PHASES). Claims `.space` audio, session saved if ≥5s.
- **Archive** (tag 4): grouped by date, Integration notes rendered, settings cog, clear archive + clear audio cache flows.
- **Lab** (tag 5): animated 3-layer binaural waveform + **unified `TuningCluster`** per frequency (hero readout · slider with sacred-/zone-boundary markers · ± steppers · nearest-marker floating label) + **`MeaningPanel`** (calm one-liner with inline honesty-tier pills; tap to expand state + carrier detail + tier legend) + "let the field choose" weighted randomize + preset row with inline save and long-press delete. Claims `.lab` audio source on ACTIVATE; gives it up on a remote eviction.
- **Ritual** (tag 6): queue ≥2 steps, drag-reorder, duration cycler, chained immersed sessions advance on natural completion only; each immersed session inside the ritual claims `.ritual` so it can be cleanly evicted by a Track.
- **Letter** (tag 7): mic permission, 3-2-1 countdown, m4a recording with live meter, optional binaural underlay, review with editable title, save / share / delete / swipe-orphan-cleanup, playback re-layers binaural when applicable.
- **Player (3-mode + Loop + minimize)**: FIELD with verb / song / recognition / BEGIN THE LOOP / scrubber floating over a vocab-tinted bg + gradients; CONTROL 55%-sheet with play/pause + binaural toggle + PRESENCE / BEAT-with-Δ/Θ/α-ticks / CARRIER-with-DERIVED/AUTHORED + READING + END SESSION; READING 80%-sheet with WORDS / FREQUENCY / VIDEO / LALITA tabs. Binaural pill at top = pure status indicator (tap → CONTROL). Top-right X = full close. Swipe down > 60pt on FIELD background = also close. 4-second CONTROL auto-hide returns to FIELD.
- **MiniPlayer**: floats above the tab bar (49pt offset) whenever a track is loaded and the modal isn't presented. Element dot + verb + song + play/pause. Tap anywhere outside the button reopens the modal.
- **Consciousness Loop**: BEGIN THE LOOP → 7 steps over the live music. Mirror words from the track's Score or the default 5; fruit paragraphs from `lyricalWordsReading` (split on blank lines) or generated defaults that name the offered word. Always escapable via the bottom-right close capsule.
- **Performer (Lalita pass, Phase 4)**: `Performer.shared` ticks at 60Hz, tracking `currentPhase`, `timeIntoPhase`, `crescendoModulator`, `inSilence`, `energy`, `beatPulse`, `onsetCount`, and ten archetype-presence values. `Score.cross` ships for Track 27 (6 phases, 2 silence windows, modulator 145/160/180/195/0.8) with `mirrorWords` populated. Other tracks run in ambient mode (no phase / no modulator / no scored mirror words — the Loop falls through to the coordinator's default). Drives the *awakening-peak binaural integration* — beat Hz deepens toward `currentTrackBeatHz × 0.56` at peak unless the user has overridden BEAT.
- **Element vocabularies**: 9 distinct draws + Cathedral. `VisualizerView` dispatches via `ElementVocabulary.forTrack(track)`. PlayerView's background reads `vocab.bg`. Track 27 is overridden to `.ether`. `vizMode == "singular"` skips all vocabulary draws and renders only the Bindu Lissajous.
- **Cathedral renderer**: SwiftUI Canvas. Tier 1 continuous: floor / Sid columns / vault ceiling / atmospheric grain (80-particle 30Hz step loop) / Gaia ground (52s breathing radial). Tier 2 ensemble (presence-gated): Arch chant + Sakshi gesture. Tier 3 crescendo: 7 sequentially-triggered rising arches + 7 additive convergence lines. Tier 4 climax: keystone radial cascade + 4 cycling expanding rings + Schumann earth-rising gradient (elapsed 161–166) + 22-shard Shweta crystallization (peak window). Bindu Lissajous always on top. Ensemble Karishma/Ashrey/Neev layered in.
- **Audio exclusivity**: a Lab tone and a Field track can no longer render simultaneously. Requesting a new source explicitly evicts the prior one through `PlayerStore.stop` (Track) or a notification (Lab/Space/Ritual). The two `AVAudioEngine` instances still both render to hardware — that's intentional, since a binaural tone overlaid on music IS the product — but only one *surface* owns audio at a time.
- **Visualization mode setting**: Settings → visualization → Ensemble (default — vocabulary + Bindu) or Singular (just the Bindu Lissajous). Persisted under `binduSettings.vizMode`. Both modes still use the vocabulary's `vocab.bg` as the background, so the element still tints the void in singular.
- **Settings**: gain slider (live), visualization picker (ensemble / singular), default-duration chips, API key add/replace/remove (masked), clear archive, clear audio cache (size displayed), catalog refresh with last-refreshed time + offline banner, hidden DSP diagnostics (triple-tap version).
- **Lock-screen / Control Center**: now-playing metadata per context (Track / Lab / Space), elapsed advances, stop = full stop, pause/togglePlayPause = soft-mute, play = restore gain.
- **Background audio**: locking the screen or backgrounding the app keeps audio playing. Phone calls / Siri / mediaServicesReset → engines pause → on resume, `AudioSessionCoordinator` re-activates the session and engines restart themselves.

---

## 13. Known issues / open items

No `TODO`, `FIXME`, `HACK`, `XXX`, `stub`, `placeholder`, or "not implemented" markers in source.

Live issues visible from reading the code:

- **Two parallel `AVAudioEngine` instances still both render to hardware** (binaural tone over music). `SettingsStore.gain` is passed only to `BinauralEngine.updateGain`; the music plays at its file level. There is no shared output mixer, no ducking, no headphone-level governor. By design today — but no master limiter means a hot mp3 + a high gain could clip. The new `AudioExclusivityCoordinator` only governs *which surface* renders, not how the surface's two engines combine.
- **`OracleResponse.trackID` is `String`; `Track.id` is `Int`.** Comparison is stringified at the call site. Works as long as the model returns a bare numeric. (The error path surfaces "unknown track ID" already.)
- **Test target is scaffold only** (`Bindu Field Tests/Bindu_Field_Tests.swift` is the Swift Testing template). No real test coverage exists.
- **No Capabilities entry in Xcode UI** — `UIBackgroundModes` is declared via the file at the project root. If a future Xcode version repopulates the build setting (`INFOPLIST_KEY_UIBackgroundModes`) and re-merges in a conflicting way, double-check `PlistBuddy -c "Print :UIBackgroundModes"` on the built bundle after every Xcode upgrade.
- **No analytics, no remote config, no crash reporting, no auth.** No backend other than the Claude messages API + the static aistrangegame.com mp3 host + Airtable.
- **Score.mirrorWords default is a placeholder.** The 5-word default `["return", "listen", "open", "soften", "trust"]` is in `ConsciousnessLoopCoordinator.defaultMirrorWords` — it's universal enough to land for any element, but the Loop is meaningfully better when a Score is authored. Today only Track 27 has authored mirror words; everything else falls through to the default.
- **Fruit paragraph default is generic.** When `lyricalWordsReading` is empty, the Loop's Fruit step renders three sentences naming the offered word. They work; they're not bespoke. As more Tracks gain Reading-space prose, this surfaces less.
- **MapDetailSheet's "track not yet linked to catalog" path can fire** for chakras whose dance is composed (`composedIDs`) but whose Airtable Track row was renamed, deleted, or has a mismatched `Chakra` string. Lookup uses `track.chakra?.rawValue.lowercased() == chakra.name.lowercased()` so a stray space or typo on the Airtable side surfaces the unlinked copy. Worth a guardrail later.
- **Breath session source-of-truth is split.** `BreathSession.joined()` merges Airtable (inhale/hold/exhale/intention/safety/special) onto `BreathProtocolMetadata.all` (hue / oneLine / carrierTiers / beatTiers). A future migration that lifts the remaining four into Airtable would simplify session authoring; until then the table at `BreathProtocolMetadata.all` must be maintained alongside the Airtable row for each new session. Adding a brand-new breath session without a matching entry there still works (permissive default in `BreathProtocolMetadata.for(id:)` covers it) but the session will look generic.
- **Sessions archive type for breath sessions.** `BreathImmersedView.saveSession` writes a `.chakra`-typed `Session` because `SessionType` has no `.breath` case. Functionally equivalent for the Archive (which renders by displayName/secondary regardless), but a `.breath` type would let Archive filter or label breath sessions distinctly later.
- **Visual fidelity audit pending on device** for the non-Air vocabularies and the new Lab v3 / AKASH flows. The Cathedral is well-tested visually on Track 27; the other 8 vocabularies have shipped only against the design HTML. For the new flows: the `TuningCluster` thumb hit zone on narrow screens, the breath-cycle 3-block row when a session has only two phases (hold = 0), and the Reading Space's FREQUENCY tab rendering on real Airtable prose for sessions other than 101 (today's frequency prose doesn't widely use `[SCIENCE]` brackets, so the tier-card path will only fire if the writer adopts that convention).
- **Phase 7 — `LalitaEngine`** is the most sophisticated piece of the original handoff (3 phases · 6 mathematical pattern curves · background inversion from void to warm cream). Not implemented; deferred to a separate session per the original handoff's explicit decision. Reference: `design_handoff_lalita_pass/Bindu Lalita.html` + `README.md` Section 5.

---

## 14. Session ledger (chronological)

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
| `bce5295` | docs: update CLAUDE.md for lalita pass state *(prior CLAUDE.md was pinned to this commit)* |
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
| `7c6cace` | **fix: dead ends — exits and state corrections** — `7` files touched (Field/Oracle/MapDetail/PlayerView/RootView/AudioSession) |
| `838a0b1` | **feat: structure — tab bar, field verbs, akash rename, mini player** — `MiniPlayerView` added; FieldView labels verbs under front-hemisphere orbs; Space tab label becomes AKASH; NavigationStore default lands on Field (1) |
| `bf16fc1` | **fix: bindu solo** — restore singular lissajous mode |
| `98fac48` | **docs: check in session handoffs, audits, and design HTMLs** |
| `ac9c7f5` | **docs: refresh CLAUDE.md for feat/stabilize state** |
| `884630a` | **feat: lab v3 + akash rebuild — tuning clusters, intention grid, breath sessions** — `LabView` rewritten around `TuningCluster` + `MeaningPanel`; new shared models (`HonestyTier`, `BrainwaveStateInfo`, `SacredCarrier`); `BreathSession` / `BreathProtocolMetadata` / `BreathSessionStore` / `JoinedBreathSession`; AKASH front door is `IntentionGridView`; `SubSelectionView`, `SessionDetailView`, `ScreenedGateView`, `BreathImmersedView`, `BreathReadingSpaceView`. `AirtableService.fetchBreathSessions()` added. Old chakra grid in `SpaceSetupView` kept for Ritual. |
| `9465e8e` | **feat: airtable — migrate breath protocol metadata to airtable** *(current HEAD)* — six new Airtable columns on `tblv3WvMZ90Sfhun6` (Inhale/Hold/Exhale Sec, Intention, Safety, Special Cue); all 11 breath records populated. `BreathSession` gains six optional carriers + backwards-compat decoder so the pre-migration `binduBreathSessions.v1` cache still decodes. `BreathSpecialCue` raw values change to match Airtable strings ("double_pulse", "active_phase"). `BreathProtocolMetadata.merge(airtable:)` is the new join — Airtable wins per-field; `BreathProtocolMetadata.all` remains as the seed/fallback. `resolveSafety(airtableKey:id:)` fails closed: only an explicit `"open"` passes; everything else routes through the screened gate. `knownScreenedIDs: Set<Int> = [105]` is the code-level backstop. Hue / oneLine / carrierTiers / beatTiers are NOT migrated and still come from the fallback. |

---

## 15. Where the design pass landed (and what's still ahead)

The Lalita pass shipped on `feat/lalita-pass` across six phases plus four post-review gap fixes. Session A landed three more design pieces (Oracle redesign, Tab Icons, Consciousness Loop). Session B landed the Map, the Mini Player, Element Vocabularies, and the AKASH rename + Field verbs. Stabilize landed audio exclusivity, readability, and dead-end fixes. **The Lab v3 + Akash rebuild** then collapsed the Lab into unified `TuningCluster`s + a single `MeaningPanel`, replaced the AKASH chakra grid with an intention grid over 11 Airtable-backed breath sessions, added the breath Reading Space, and gated The Stoke through `ScreenedGateView`. The **breath-protocol Airtable migration** then moved inhale/hold/exhale/intention/safety/special_cue into Airtable as the source of truth, with `BreathProtocolMetadata.all` retained as the seed/fallback. The branch is 3 commits ahead of origin, not pushed, staged for device verification.

**What landed**
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
- **Breath protocol → Airtable migration** — six Airtable columns added on the same table (Inhale/Hold/Exhale Sec, Intention, Safety, Special Cue); 11 breath rows populated; `AirtableService.fetchBreathSessions()` reads them; `BreathSession` carries optional Airtable values; `BreathProtocolMetadata.merge(airtable:)` is the new join (Airtable wins per-field, hardcoded `all` is the seed/fallback). Safety fails closed; `[105]` is the code-level backstop. **What stayed in code:** `hue`, `oneLine`, `carrierTiers`, `beatTiers` — see Data Layer for the source-of-truth boundary.

**Still ahead**
- **Phase 7 — `LalitaEngine`** is deferred to a separate session per the original handoff. Reference: `design_handoff_lalita_pass/Bindu Lalita.html` + `README.md` Section 5. Three phases, six mathematical pattern curves, background inversion from void to warm cream.
- **Visual fidelity audit on device** for the non-Air vocabularies. The Cathedral is well-tested visually on Track 27; the other 8 vocabularies have shipped only against the design HTML.
- **More authored Scores** — only Track 27 (Sound of Silence) has a `Score.cross` today. Other tracks run ambient (no phase / modulator / scored mirror words). Adding a score is a `Score.forTrack(id:)` case + a hardcoded `Score(...)` literal per track.
- **More authored Reading-space prose** — most tracks have empty `lyricalWordsReading`, `frequencyReading`, `videoPulseReading`, `lalitasPerspective`. The Loop's Fruit step and the Player's READING sheet are functional but generic without them.
- **More authored mirror words** — `Score.mirrorWords` is only populated for Track 27. The Loop's Dance step falls back to a universal 5-word set otherwise.

**Sub-areas not yet upgraded** (carried from the original speculative list — still candidates if you want to keep pushing the visual pass)
- Settings sections (the `SettingsSection` wrapper looks correct; row-by-row typography could match the Player's READING-style hairline rules).
- Letter row + Archive row layouts (functional, low-personality).
- The Ritual queue row — drag-list utility look, no atmosphere.
- The headphones tip — pill capsule, low ceremony for a first-launch message.

**Things to NOT touch unless asked** (unchanged from prior audit)
- `BinauralEngine.swift`, `BinauralListener.swift`, all DSP files. Audio behavior is settled.
- `AudioSessionCoordinator.swift`. Settled (the new `AudioExclusivityCoordinator` is a separate concern that lives alongside it).
- `DSPWireService.swift` — settled in spirit; additive extensions for Performer/Player wiring are the only changes the Lalita pass made.
- `Info.plist` + the `INFOPLIST_*` build settings. Settled.

---

## 16. Uncommitted work

Only this CLAUDE.md refresh. Working tree was clean on `feat/stabilize` at `9465e8e`, three commits ahead of `origin/feat/stabilize`, not pushed. Commit this update to capture the post-migration state.
