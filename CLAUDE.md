# Bindu Field — Project State

iOS / SwiftUI app. Binaural-beat instrument layered on a catalogue of music tracks, with a constellation browser, breath-driven chakra sessions, an Oracle (Claude API) track recommender, voice-letter recorder, freeform frequency lab, and ritual sequencer.

Single Xcode target, dark-mode-only, ultraLight serif type, void/black palette. **No SPM dependencies — frameworks linked are Accelerate only.** The catalogue is loaded dynamically from Airtable; audio MP3s stream from a static aistrangegame.com host with a 200 MB LRU disk cache. The Oracle calls api.anthropic.com directly with a key the user pastes into Settings.

Last audited: **2026-05-19**, currently on `feat/lalita-pass` at `efc8005` (post Phase 1–6 of the Lalita design pass + four post-review gap fixes; branch is staged for device verification, not merged). Build clean, zero warnings, zero errors.

---

## 1. Project structure

Project root: `/Users/ashrey/Bindu Field/`

```
.
├── .gitignore                                  # ignores Secrets.swift, DerivedData, .DS_Store
├── ARCHITECTURE-AUDIT.md                       # the audit (B1–B18 bugs · O1–O25 ops · G1–G24 gaps) that drove the foundation cleanup
├── BINDU-FIELD-HANDOFF.md                      # original session 1 handoff (pre-Airtable baseline)
├── BINDU-FOUNDATION-HANDOFF.md                 # foundation-cleanup handoff
├── BINDU-SESSION4-HANDOFF.md                   # session 4 (DSP-wire, visualizer, player upgrade)
├── BINDU-SESSION5-HANDOFF.md                   # session 5 (constellation, lab presets, practice-aware Oracle)
├── BINDU-LALITA-PASS-HANDOFF.md                # Lalita pass — six-phase design architecture (Phases 1–6 landed)
├── DESIGN-GAP-REPORT.md                        # post-Phase-6 diagnostic + four gap-fix commits
├── design_handoff_lalita_pass/                 # live HTML/JS design prototypes (Player, Lab, Performance, Archetypes, Lalita)
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
│   │   ├── ChakraProtocol.swift                # 9 chakras + ChakraData.all (breath rhythm, beat, carrier, hue, affirmations)
│   │   ├── FrequencyInfo.swift                 # pure-data lookup — brainwave info + notable-carrier notes
│   │   ├── FrequencyPreset.swift               # Codable preset + 5 system presets (Earth Tone, Deep Delta, Theta Gate, Creative, Presence)
│   │   ├── Letter.swift                        # Voice-letter record (audio in Documents/Letters/)
│   │   ├── Session.swift                       # Practice history entry (.track or .chakra; sourceID is String)
│   │   ├── Theme.swift                         # `Theme` struct + ThemeData.void + @Environment(\.binduTheme)
│   │   └── Track.swift                         # Track + BrainwaveState + ChakraName + TrackType enums; recognitionStatement? + lyricalWordsReading + frequencyReading + videoPulseReading + lalitasPerspective?
│   │
│   ├── Stores/                                 # @MainActor @Observable singletons (one shared instance each)
│   │   ├── AirtableService.swift               # paginated REST fetch from Airtable base/table
│   │   ├── AudioCache.swift                    # MP3 download + 200 MB LRU disk cache in Caches/BinduTracks/
│   │   ├── AudioSessionCoordinator.swift       # single owner of AVAudioSession category + interruption observers
│   │   ├── BinduConfig.swift                   # resolves Track.audioURL by ID
│   │   ├── CatalogStore.swift                  # Track cache + Airtable refresh, JSON in UserDefaults `binduCatalog.v1`
│   │   ├── DSPWireService.swift                # 10 Hz poll: RMS → engine gain, onset → visualizer, carrier-derived → engine carrier
│   │   ├── KeychainHelper.swift                # Claude API key (AfterFirstUnlockThisDeviceOnly)
│   │   ├── LetterStore.swift                   # Letters JSON in UserDefaults `binduLetters.v1`
│   │   ├── NavigationStore.swift               # selectedTab (Int) — used to deep-link from Field → Oracle
│   │   ├── NowPlayingService.swift             # MPNowPlayingInfoCenter + remote commands (stop = full stop, pause/toggle = soft-mute, play = restore gain)
│   │   ├── OracleService.swift                 # claude-haiku-4-5 messages call w/ catalog + recently-played hint
│   │   ├── Performer.swift                     # 60Hz score state machine — phase + crescendoModulator + archetypePresence; awakening-peak binaural depth integration
│   │   ├── PlayerStore.swift                   # top-level playback orchestration (play track / startBinaural / stop / Integration note); starts/stops Performer
│   │   ├── PresetStore.swift                   # user-saved frequency presets JSON in UserDefaults `binduPresets.v1`
│   │   ├── RecorderService.swift               # AVAudioRecorder for Letters
│   │   ├── SessionStore.swift                  # Sessions JSON in UserDefaults `binduSessions.v1`
│   │   ├── SettingsStore.swift                 # gain (Float) + defaultSessionDuration (TimeInterval) + vizMode (String) in UserDefaults
│   │   ├── TrackPlaybackService.swift          # coordinates BinauralListener + BinauralEngine + DSPWireService; audio-clock elapsed; resetForNewTrack on the wire
│   │   └── UserDefaultsCodable.swift           # tiny T-Codable-in-UserDefaults helper used by Session/Letter/Preset stores
│   │
│   └── Views/
│       ├── BinduBirthView.swift                # First-launch Task-chain birth animation
│       ├── RootView.swift                      # TabView + birth/headphone overlays + audio error banner
│       ├── Components/
│       │   ├── BinauralWaveformView.swift      # Lab animated waveform — L / R / beat-envelope sine layers (Phase 1)
│       │   ├── Chip.swift                      # filter chips (capsule, italic serif)
│       │   ├── DateFormatters.swift            # archiveDate / archiveTime / letterTitle (shared, memoized)
│       │   ├── ElementColors.swift             # Color.bindu(element:) — single source of truth for 10 element hues
│       │   └── PlaybackTime.swift              # TimeInterval.asPlaybackTime (M:SS)
│       ├── Letter/
│       │   ├── LetterPlaybackView.swift        # AVAudioPlayer + optional binaural re-layer
│       │   └── LetterRecordView.swift          # 4-phase recorder (setup / countdown / recording / review); orphan-cleanup on B14
│       ├── Player/
│       │   ├── PlayerView.swift                # three-mode player — FIELD / CONTROL / READING; binaural status pill; Integration Chamber; gradient fades
│       │   └── VisualizerView.swift            # Cathedral renderer (Tiers 1–4) + ensemble archetypes + Bindu Lissajous; honours vizMode setting
│       ├── Ritual/
│       │   ├── RitualRunningView.swift         # chains SpaceImmersedView per step, advances only on natural completion
│       │   └── RitualSetupView.swift           # drag-reorder queue + per-step duration cycler
│       ├── Settings/
│       │   └── SettingsView.swift              # audio · visualization (ensemble/singular) · session · oracle · data · catalog · (triple-tap diagnostics) · about
│       ├── Space/
│       │   ├── SpaceImmersedView.swift         # breath ring × beat modulation × rotating affirmation
│       │   └── SpaceSetupView.swift            # chakra picker + duration chips
│       └── Tabs/                               # one container per top-level tab
│           ├── ArchiveView.swift               # grouped session list w/ Integration notes; gear → SettingsView
│           ├── FieldView.swift                 # 3D constellation, played/never visual states, depth fog, element lines
│           ├── LabView.swift                   # animated waveform + carrier/beat sliders w/ direct-edit + sacred frequency map + intelligent randomize + sacred badge + preset row
│           ├── LetterView.swift                # Sound Letter list + ShareLink
│           ├── OracleView.swift                # text input → Claude → result; passes recently-played for deprioritization
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

`GENERATE_INFOPLIST_FILE = YES` and `INFOPLIST_FILE = Info.plist` coexist: the file is treated as the base, generated keys merge in on top. The `Bindu Field/` source directory is auto-included as a synchronized group; the root-level `Info.plist` is *outside* that group so it isn't double-bundled as a resource.

---

## 3. Audio engine architecture

Two `AVAudioEngine` instances + one C++ DSP kernel, with a single coordinator for `AVAudioSession`.

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
```

### Key facts that diverge from any earlier CLAUDE.md you may have seen

- **DSP output IS read.** `DSPWireService` is the consumer. RMS modulates `BinauralEngine.updateGain` 10×/sec (inverse curve, sqrt floor at 0.1). Onsets edge-count into `onsetCount` so `VisualizerView` can emit beat rings. Carrier derivation (10s in) drives `BinauralEngine.setCarrier`. `VisualizerView` is fully audio-reactive — RMS bloom, onset rings, carrier-lock 1.5× pulse, comet trail along a multi-harmonic Lissajous.
- **`AudioSessionCoordinator` is the only owner of `AVAudioSession.setCategory`.** Engines and `RecorderService` request a mode (`.playback` / `.playAndRecord`) by string identifier; the coordinator ref-counts and only flips the category when the highest-priority mode changes. Recording wins over playback.
- **Interruption recovery is wired.** The coordinator observes `AVAudioSession.interruptionNotification` + `mediaServicesWereResetNotification`. On `.ended` with `.shouldResume`: `setActive(true)` + post `.binduAudioSessionShouldRestart`. Both engines listen and call their own `restartIfNeeded()` which compares Swift-side `isRunning` flag to `engine.isRunning` and re-starts if they disagree. `BinauralListener` additionally re-issues `playerNode.play()`; AVAudioPlayerNode preserves sample-accurate scheduled position across the restart.
- **Background audio works.** `UIBackgroundModes = [audio]` is in the built Info.plist (verified via `PlistBuddy`). Locking the screen or backgrounding the app no longer kills audio.
- **Elapsed playback time is sample-accurate.** `TrackPlaybackService.elapsed` prefers `AVAudioPlayerNode.lastRenderTime` and only falls back to wall-clock before the node has produced a sample.
- **`Performer` is the visualization driver.** Started by `PlayerStore.play(_:)` with the track's authored `Score?` (nil = ambient), it ticks at 60Hz, reads `TrackPlaybackService.elapsed` + `DSPWireService`, and exposes `crescendoModulator` / `beatPulse` / `energy` / `archetypePresence` for the Cathedral renderer. It also drives the *awakening-peak binaural integration* — at crescendo peak it interpolates the binaural beat Hz down to `currentTrackBeatHz × 0.56` (only when `wire.hasBeatOverride == false`, so a user CONTROL-slider drag always wins). Not an audio-path component; lives outside the diagram above.

### Audio session lifecycle

1. App launch (`Bindu_FieldApp.runLaunchSetupIfNeeded`, gated by `didLaunch`):
   `NowPlayingService.configureAudioSession()` → `AudioSessionCoordinator.configureForLaunch()` → `setCategory(.playback) + setActive(true)`.
   `PlayerStore.configureEngine()` → `BinauralEngine.configure()` (creates source node, requests playback). Then registers remote commands.
2. First track play: `TrackPlaybackService.play(...)` → `BinauralListener.configure()` (requests playback, starts engine, installs tap), then `startSession(trackURL:)`. `BinauralEngine.start(carrierHz:)`. `DSPWireService.startPolling()`.
3. `scenePhase` reconciler (G16): on return to `.active`, if `TrackPlaybackService.isPlaying` but `DSPWireService.isMusicPlaying` is false, restart polling. Does NOT stop anything on `.background`.
4. `.binduPlaybackComplete` from `BinauralListener` (file drained): `DSPWireService.handleMusicEnded()` drops polling and holds a drone at `userPresence × 0.2 × gain` — *the field dissipates, it doesn't die.* `PlayerView` also raises the Integration Chamber on this notification.

---

## 4. Data layer

### Track catalogue — Airtable spine

- **Source**: `https://api.airtable.com/v0/app248ZTWhYJlvQj2/tblv3WvMZ90Sfhun6` (PAT in `Secrets.swift`).
- `AirtableService` does paginated GETs (`pageSize=100`, follows `offset` until exhausted). Decoding hops to a detached task so JSON parsing doesn't pin main.
- **Fields** (Airtable column → `Track` property): `Track ID` → `id: Int`, `Verb` → `verb`, `Song Title` → `song`, `Artist` → `artist`, `Track Type` → `type` (chakra/music/meditate/family), `Element` → `element` (Earth/Water/Fire/Air/Light/Crown/Soul/Dissolution/Meditate/Family), `Brainwave State` → `state` (delta/theta/theta-alpha/alpha), `Chakra` → `chakra?`, `Audio URL` → `audioURL`, `YouTube ID` → `youtubeID?`, `Carrier Hz` → `carrierHz: Double`, `Beat Hz` → `beatHz: Double`, `Seed Phrase` → `seed`, **`Recognition Statement` → `recognitionStatement: String?`**, **`Lyrical Words Reading` → `lyricalWordsReading: String`**, **`Frequency Reading` → `frequencyReading: String`**, **`Video Pulse Reading` → `videoPulseReading: String`**, **`Lalita's Perspective` → `lalitasPerspective: String?`** (Reading-space fields — surfaced by the Player's READING sheet tabs; empty for most tracks today).
- `CatalogStore` caches the array as JSON under `binduCatalog.v1`, with a `binduCatalog.v1.lastRefreshedAt` timestamp. Refresh policy: skip network if cache <1 hour old; force-refresh available from Settings; never overwrite cache with an empty-array response (B13). Decode failures swallow silently. `Track` carries a custom `init(from:)` in an extension that defaults the three new non-optional Reading-space String fields to `""`, so old `binduCatalog.v1` caches written before the Lalita pass continue to decode without dropping the catalog.
- 22 tracks today.

### Chakra catalogue — hardcoded

`Models/ChakraProtocol.swift` declares 9 chakras (root → maya) with `inhale/hold/exhale` (seconds), `beat`, `carrier`, `hue`, `essence`, and 5 `affirmations` each. Ordering for grid display lives in `SpaceSetupView` as `chakraOrder`.

### Frequency presets

`FrequencyPreset` is Codable with `isSystem: Bool`. Five system presets (Earth Tone 7.83 Hz, Deep Delta 1.5 Hz, Theta Gate 5.5 Hz, Creative 7.0 Hz on 174 Hz carrier, Presence 10 Hz on 432 Hz carrier) ship in code. `PresetStore` persists user-saved presets under `binduPresets.v1`. System presets cannot be deleted.

### Frequency knowledge

`FrequencyInfo` is a pure-data enum (no observable state). `brainwaveInfo(forLabel:)` returns range + essence + detail for `delta / theta / theta-alpha / alpha / beta / gamma`. `carrierNote(for:)` matches ±0.5 Hz against eight notable carriers (136.1 OM, 174.0, 285, 396/417/528/639 Solfeggio, 432 alt concert pitch).

### Persistence (UserDefaults / Documents / Caches / Keychain)

| What | Where | Key / Path |
|---|---|---|
| Sessions | UserDefaults | `binduSessions.v1` (JSON) |
| Letters (metadata) | UserDefaults | `binduLetters.v1` (JSON) |
| Letters (audio) | Documents | `Documents/Letters/<UUID>.m4a` |
| User frequency presets | UserDefaults | `binduPresets.v1` (JSON) |
| Track catalogue cache | UserDefaults | `binduCatalog.v1` + `binduCatalog.v1.lastRefreshedAt` |
| Track audio cache | Caches | `Caches/BinduTracks/track-{id}.mp3` — 200 MB LRU cap, evicts to 75% on overflow |
| Gain / default duration / viz mode | UserDefaults | `binduSettings.gain`, `binduSettings.defaultDuration`, `binduSettings.vizMode` (`"ensemble"` default · `"singular"` toggle) |
| First-launch flags | UserDefaults | `binduFirstLaunch.seen`, `binduFirstLaunch.tipSeen`, `binduFirstLaunch.oracleHintSeen` |
| Claude API key | Keychain | service `com.bindufield.apikeys` · account `claude_api_key` · `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| Airtable PAT | Code | `Secrets.swift` (gitignored; template at `Secrets.swift.template`) |

`UserDefaultsCodable<T: Codable>` is a tiny helper used by `SessionStore`, `LetterStore`, and `PresetStore` to deduplicate the encode-write / read-decode dance.

---

## 5. Tab structure

`RootView.swift` — `TabView` over `NavigationStore.selectedTab` (tags 0–6). Programmatic switch via the store (e.g. long-press the central Bindu in Field → tab 1 Oracle).

| Tag | Tab | Composing views | Behavior |
|---|---|---|---|
| 0 | **Field** | `FieldView` → `PlayerView` (`fullScreenCover`) | Golden-angle Fibonacci sphere of 22 orbs. Filter chips (all / delta / theta / theta-alpha / alpha). Drag to spin around Y. Tap an orb → play. **Three orb states**: playing (existing pulse) · played-before (full opacity + 1.4× inner glow ring at 0.25 — "you've been here") · never-played (0.55 opacity). **Depth fog**: 0 front → 1 back via normalized `rzz`; opacity × `(1 − depth × 0.5)`, radius × `(1 − depth × 0.2)`. **Element lines**: 0.07 opacity / 0.5pt stroke between same-element pairs both in the front hemisphere. **Central Bindu**: animated #E5524E core + radial glow, breathes at ~0.1 Hz; long-press 0.6s → Oracle (with first-launch "hold for Oracle" serif tooltip). Loading + offline-cache states surfaced as captions. |
| 1 | **Oracle** | `OracleView` (+ `SettingsView` sheet) | Text input → POSTs to `api.anthropic.com/v1/messages` (`claude-haiku-4-5-20251001`) with full catalog inlined as `id=N | verb=… | song — artist | state=… | element=… | seed=…` lines (recognition appended only when present) + recently-played track IDs as a deprioritize-these-unless-most-relevant hint. Two-retry exponential backoff on 429/5xx. JSON-mode response → renders verb / song / why / Begin button. Empty state if no Keychain key (link to Settings). |
| 2 | **Space** | `SpaceView` → `SpaceSetupView` ↔ `SpaceImmersedView` | Pick chakra + duration (3/5/10/15 min, clamped to `defaultSessionDuration` initial). Immersed: breath ring expands on `inhale`, holds, contracts on `exhale` (seconds from `ChakraProtocol`). Beat modulation across phases (×1.0 / ×1.10 / ×0.80). Affirmation rotates every 20s. Lock-screen Now Playing. Saves a `.chakra` `Session` on exit (skipped if < 5s). |
| 3 | **Lab** | `LabView` | Top: header dot + "frequency lab" italic + "craft your own permission slip" caption. **Animated binaural waveform** (`BinauralWaveformView`) — 120pt Canvas drawing L (cream 0.14) + R (state-hued 0.38) + bright beat envelope; ghost wave when inactive. Carrier + 76pt beat are **direct-editable** via `TextField(.decimalPad)` (clamps 40–440 / 0.5–44). State card (chevron-expandable) with the design's 5-band palette: delta=15°, theta=260°, alpha=210°, beta=165°, gamma=50°. Custom hairline sliders. **Sacred frequency strip** — 7 dots (136.1 OM, 174, 285, 396 UT, 417 RE, 432, 440) + glowing state-color carrier cursor. **`SacredBadge`** appears inline on the carrier row when ±1.2 Hz of a sacred carrier (OM · C#3, 432 · A4♭, etc.). **"let the field choose"** — weighted-state randomize (δ12/θ33/α37/β13/γ5%) + sacred-carrier ±0.5 jitter + 10-step animated cycling + spring lock. Preset row + inline save + long-press delete preserved. No Archive entry (by design). |
| 4 | **Archive** | `ArchiveView` (+ `SettingsView` toolbar sheet) | Sessions grouped by full date (descending), each row shows verb-or-Sanskrit, song/artist-or-English-center, optional Integration note ("…" in serif italic at `subtle`), duration mono and short-time. Empty state if none. Settings cog top-right. |
| 5 | **Ritual** | `RitualView` → `RitualSetupView` ↔ `RitualRunningView` (reuses `SpaceImmersedView`) | Build a queue of chakra steps (drag to reorder, swipe to delete, tap mins chip to cycle 3/5/10/15). Requires ≥2 steps to start. Running view chains `SpaceImmersedView` with `ritualProgress: (current, total)`. Advances on natural completion, exits on cancel. |
| 6 | **Letter** | `LetterView` → `LetterRecordView` / `LetterPlaybackView` | List of Sound Letters. Recorder: 4 phases (setup → 3-2-1 countdown → recording w/ red pulse meter → review/title). Optional binaural underlay (delta/theta/alpha/silent) plays while recording so the speaker hears it through headphones. Playback: optional binaural re-layer when `letter.beat > 0`. Share via `ShareLink`. `interactiveDismissDisabled` during countdown/recording. Orphan-m4a cleanup if user swipes away in review without saving (B14). |

### Player modal (PlayerView) — three modes of being

Presented as `fullScreenCover` from `RootView` whenever `PlayerStore.isPresentingPlayer == true`. Three modes — `field` / `control` / `reading` — drive layout via a `PlayerMode` enum; transitions use spring `response: 0.45, damping: 0.85`. The field never stops; the Bindu always moves.

**FIELD mode** (default on arrival)
- VisualizerView at full width × 60% screen height, top-anchored. Renders the Cathedral (Tier 1 continuous → Tier 2 ensemble → Tier 3 crescendo → Tier 4 climax) + ensemble archetypes + the Bindu Lissajous on top — or just the Bindu Lissajous when `vizMode == "singular"`.
- Top status-bar gradient: always-on 88pt fade (theme.bg @ 0.80 → clear) for legibility over cathedral arches that reach the top.
- Bottom viz→bg gradient: FIELD-mode-only fade at 48% of screen height, 86pt tall (clear → theme.bg) — softens the visualizer's lower edge into the background where the verb floats.
- Field content overlay: 62pt ultraLight serif italic verb in element color with element-color glow shadow, song · artist subtitle, optional recognition statement in curly quotes — text block anchored via `.padding(.top, geo.size.height * 0.56)` so the verb floats over the dissolving lower edge.
- Slim "flowing" scrubber pinned to the screen bottom (read-only, 2pt, percent + label).
- Tap anywhere → CONTROL.

**CONTROL mode** (55% bottom sheet)
- Visualizer shrinks to 45% screen height and dims to opacity 0.55.
- `UnevenRoundedRectangle` top corners 32pt, `ultraThinMaterial` + element-tinted overlay + subtle 1pt stroke.
- Drag handle → 56pt play/pause circle (wired to `TrackPlaybackService.togglePlayPause`) → **BINAURAL** section with custom 44×24 toggle + ON/OFF label + breathing dot (`scaleEffect 1.0↔1.15` over 2s while `wire.binauralEnabled`) → PRESENCE slider → BEAT slider with Δ/Θ/α zone ticks + state badge → CARRIER readout with sticky DERIVED chip (driven by `wire.hasDerivedCarrier`).
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
- Always rendered at 56pt from the top. Pure status indicator now (Fix 1 of the gap-fix pass) — a single `Button { enterControl() }` showing only: 6pt dot (filled element-color when binaural is on, outlined when off, breathing 1.0↔1.25 at 1.3s ease-in-out via a `pillBreathePhase` @State flipped on appear) + "BINAURAL" label + "›" chevron. No expansion, no toggle, no slider — those live exclusively in the CONTROL sheet.

**Integration Chamber**
- Unchanged from prior architecture. Black/0.78 overlay, "what did you remember?", multi-line `TextField`, close / save-note capsules, 30s auto-dismiss. Only raised on natural playback completion — user-initiated stops do NOT trigger it. Saved note attaches via `PlayerStore.pendingNote` and renders in Archive rows.

**Arrival ceremony**
- Content opacity 0→1 + scale 0.96→1.0 over 0.6s easeOut on appear.

**Removed in this pass**
- The old chevron-up minimize and X-close buttons are gone (no top-bar chrome in any mode). Closing the player happens via END SESSION in CONTROL. The minimize-while-keeping-audio path is logged as a follow-up after the Lalita pass.

---

## 6. State management patterns

Uniform use of the Swift Observation framework (`@Observable` + `import Observation`), not `@StateObject`/`@ObservedObject`/`@EnvironmentObject`.

### Stores
- Every store is `@MainActor @Observable final class`, exposed as a `static let shared` singleton with `private init()`.
- Consumed via `@State private var store = SomeStore.shared` in each view.
- Stores: `PlayerStore`, `SettingsStore`, `SessionStore`, `LetterStore`, `PresetStore`, `NavigationStore`, `TrackPlaybackService`, `DSPWireService`, `Performer`, `CatalogStore`, `AudioSessionCoordinator`.

### Non-observed singletons
- `BinauralEngine.shared`, `BinauralListener.shared` (NSObject, audio-thread state).
- `NowPlayingService.shared`, `OracleService.shared`, `AudioCache.shared`, `RecorderService.shared`, `AirtableService.shared`.
- `KeychainHelper` is a static enum.
- `BinduConfig` is a static enum.
- `FrequencyInfo` is a static enum.

### Theme via environment (O1)

Views read the theme as `@Environment(\.binduTheme) private var theme`. The default value is `ThemeData.void`. **Every view file uses this**; the legacy `private let theme = ThemeData.void` pattern has been fully migrated out. Switching to a different palette app-wide would be a single `.environment(\.binduTheme, ThemeData.someOther)` modifier at the `RootView` root.

### View-local state
`@State` for filters, sliders, modal flags, recording phase. `@FocusState` for text input focus. `@Environment(\.dismiss)` for sheet dismissal.

### Notifications

Two `Notification.Name` extensions in the codebase:
- `BinauralListener.swift` defines `.binduCarrierDerived` (posted at 10s) and `.binduPlaybackComplete` (file drained).
- `AudioSessionCoordinator.swift` defines `.binduAudioSessionShouldRestart` (after interruption ended).

Observers: `DSPWireService` listens for the carrier-derived + playback-complete pair. Each engine listens for `.binduAudioSessionShouldRestart`. `PlayerView` listens for `.binduPlaybackComplete` to raise the Integration Chamber.

---

## 7. Design tokens — for the Lalita pass

### Palette — `ThemeData.void` (the only theme today; `Theme` was a `struct`, alternate palettes can be added without renaming the type)

| Token | Value (sRGB) | Notes |
|---|---|---|
| `bg` | `#020208` (very near-black with a hint of blue) | full-bleed background |
| `bg2` | `#05050F` | rarely used today — slight elevation |
| `text` | `#F5E2D6` (warm off-white, the "Bindu cream") | all primary text, button fill |
| `muted` | `text @ 0.55` | secondary text, button strokes |
| `subtle` | `text @ 0.28` | labels, tiny captions, hint copy |
| `accent` | `#D46453` (warm coral-red) | the Bindu red — selection, slider tint, active toggles, "Begin" buttons |
| `gold` | `#C4A862` (defined but rarely surfaced) | available for ceremonial accent |
| `border` | `white @ 0.08` | rarely used directly |
| `surface` | `white @ 0.042` | card / input field background |
| `cornerRadius` | 10 | reference; many surfaces use 12 / 14 / 16 / 18 directly |
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

### Chakra colors — derived from `ChakraProtocol.hue` (degrees) at `saturation 0.55, brightness 0.92`

Muladhara 15 · Svadhisthana 210 · Manipura 35 · Anahata 140 · Vishuddha 200 · Ajna 250 · Sahasrara 280 · Aatma 265 · Maya 190.

### Typography

- **Display verbs / headlines** — `.font(.system(size: 64 / 32 / 28 / 24, weight: .ultraLight, design: .serif)).italic()`. The verb at 64pt in element color with element-color shadow `radius: 20` is the strongest single visual gesture in the app.
- **Body / inline narration** — `.font(.system(size: 13–17, design: .serif)).italic()`. Almost everything emotional reads in italic serif: prompts, affirmations, "flowing", "fetching the field…", "the Oracle is listening", "speak from this state".
- **Section labels / chip captions** — `.font(.system(size: 9–11, weight: .light)).tracking(1.5–3).textCase(.uppercase)`. Tracking widens with importance; section headers use `tracking: 2.5`.
- **Numerics** — `.font(.system(size: 11–76, design: .monospaced))`. Carrier, beat, elapsed, percentages.
- **Tabs / system UI** — SF default (set by `Label`).

### Surface vocabulary

- **Capsule, filled** — primary action: `Capsule().fill(theme.text)` + `foregroundColor(theme.bg)` (i.e. the cream button with near-black text). Used for Begin / Save / listen / save note.
- **Capsule, stroked** — secondary: `Capsule().stroke(theme.muted.opacity(0.3), lineWidth: 1)` with `theme.muted` text. Used for stop / close / cancel.
- **Capsule, accent-filled** — selected chip: `Capsule().fill(theme.accent.opacity(0.2))` + `Capsule().stroke(theme.muted.opacity(0.3))` overlay. Used for selected duration chip in Space.
- **Capsule, ultraThinMaterial** — overlay surface: binaural pill (collapsed).
- **RoundedRectangle, surface-filled** — card: `theme.surface` fill + `theme.muted.opacity(0.15–0.25)` stroke. Used for Settings sections, Oracle input, Integration Chamber input, ChakraTile, Letter recorder review.
- **Radial gradients** — element/chakra-color × 0.12–0.25 from center → `theme.bg`. PlayerView, SpaceImmersedView, LabView background, LetterRecordView recording.

### Motion vocabulary

| Duration | Easing | Used for |
|---|---|---|
| 0.10–0.20s | linear / easeInOut | breath ring scale, meter follows |
| 0.25s | easeInOut | state-info expand/collapse, preset-name field flip, pill expand |
| 0.30s | easeInOut | tab program-switch, countdown digit cross-fade |
| 0.40s | easeInOut / easeOut | chip selection, headphone-tip dismiss, audio-error banner |
| 0.60s | easeOut / easeInOut | Player arrival ceremony, recording-bg color follow, Bindu pulse |
| 0.18–0.25s | easeOut | carrier-lock 1.5× pulse |
| ~10s (cycle) | linear | central Bindu breathing in Field (sin 0.628 Hz) |
| seconds-scale | TimelineView .animation | Visualizer Lissajous, breath ring, constellation rotation |

### Iconography

Tab bar: `circle.dotted` (Field), `ear` (Oracle), `moon.stars` (Space), `waveform.path` (Lab), `book.closed` (Archive), `flame` (Ritual), `envelope` (Letter). All SF Symbols, all ultraLight weight when used at large size.

Other recurring icons: `chevron.up/down/left` for collapsibles · `xmark` for close · `stop.fill` / `play.fill` / `pause.fill` · `headphones` (tip) · `gearshape` (settings) · `arrow.clockwise` (refresh) · `square.and.arrow.up` (share) · `speaker.slash` (error banner) · `wifi.slash` (offline catalogue) · `scope` (carrier-derived).

### Voice

Lowercase serif italic prompts. "the constellation". "speak, and you will be met". "find your own frequency". "weave a sequence". "breathe with the field". "the Oracle awaits a key". Labels are usually a verb or a noun, never a sentence. Buttons say "Begin" or "Begin Ritual" — capitalized, the rare break from lowercase.

---

## 8. Conventions visible in the code

**File / folder layout**
- One root group `Bindu Field/` synced by `PBXFileSystemSynchronizedRootGroup` — no manual file listing in pbxproj.
- Top-level Swift sources contain only `Bindu_FieldApp.swift` + four audio/DSP files. Everything else lives in `Models/`, `Stores/`, `Views/`.
- Views split into `Tabs/` (the 7 top-level shells) + per-feature folders (`Player/`, `Letter/`, `Ritual/`, `Space/`, `Settings/`) + shared `Components/`. Container tab views are thin shells that pick between setup/active sub-views.

**File / type naming**
- View files end in `View.swift` and contain a struct of the same name.
- Service / store types end in `Service` (lifecycle, side effects) or `Store` (observable state).
- DSP namespace is `ASG::` in C++.
- Persistence keys all prefixed `bindu*`. Collection keys carry `.v1` suffix.

**SwiftUI style**
- Theme via `@Environment(\.binduTheme) private var theme`. (`ThemeData.void` is referenced directly only in a handful of places where the Environment isn't reachable — `RootView`'s `tint`, the audio error banner, the headphones tip — those are the exceptions.)
- Backgrounds: `theme.bg.ignoresSafeArea()` for flat tabs; `RadialGradient` from an element/chakra color to `theme.bg` for immersive contexts.
- Buttons reimplement the capsule pattern inline rather than via a shared `ButtonStyle` — there's no `BinduButtonStyle`. If a design pass wants consistency, that's the natural extraction point.
- HUDs auto-hide via `Task { try? await Task.sleep(...); hudVisible = false }`, cancellable on tap.
- 44×44 hit targets on chrome buttons (top-bar back/close) — accessibility floor.

**Persistence style**
- `Codable` everything that crosses a boundary. UserDefaults for small structured data; Documents for user-generated audio; Caches for downloaded audio (OS may evict).
- Wrap UserDefaults Codable reads/writes through `UserDefaultsCodable<T>` when possible.

**Logging**
- `os.Logger` subsystem `com.bindufield`, categories `audio.engine`, `audio.listener`, `audio.session`. Filter on device with `log show --predicate 'subsystem == "com.bindufield"' --info --last 5m`.

---

## 9. What works (current truth, post-`efc8005`)

- **All 7 tabs** boot and run their golden paths. First-launch shows the Task-chain BinduBirthView, then the headphones tip.
- **Field tracks**: Airtable refresh → catalogue → tap orb → `AudioCache.fetch` (download or cache hit) → `TrackPlaybackService.play` → music + binaural layer + DSP wire + Performer + visualizer. Cache miss falls back to binaural-only (Performer still starts in ambient mode) with a surfaced error.
- **Oracle**: Keychain-gated, terse error states, retry on 429/5xx, recently-played hint included, recognition statements appended only when present.
- **Space**: breath-modulated binaural, beat ×1.0/1.1/0.8 across inhale/hold/exhale, affirmations rotate every 20s, lock-screen metadata, session saved if ≥5s.
- **Lab (Lalita pass, Phase 1)**: animated 3-layer binaural waveform (L / R / beat envelope) + carrier and 76pt-beat readouts that are tap-to-edit via decimal pad + custom hairline sliders + sacred-frequency map strip (7 dots + glowing carrier cursor) + inline sacred badge (OM · C#3 etc. when ±1.2 Hz) + "let the field choose" weighted randomize + 5-band state palette (delta/theta/alpha/beta/gamma) + preset row with inline save and long-press delete.
- **Player (Lalita pass, Phase 3, post gap-fixes)**: three-mode architecture — FIELD with verb / song / recognition / scrubber floating over a top-status-bar + bottom-viz-fade gradient; CONTROL 55%-sheet with 56pt play/pause + breathing BINAURAL toggle + PRESENCE / BEAT-with-Δ/Θ/α-ticks / CARRIER-with-sticky-DERIVED + READING + END SESSION; READING 80%-sheet with WORDS / FREQUENCY (live structured) / VIDEO / LALITA tabs reading from `Track.lyricalWordsReading|frequencyReading|videoPulseReading|lalitasPerspective`. Binaural pill at top is a pure status indicator (tap → CONTROL). 4-second CONTROL auto-hide returns to FIELD; tap above sheet steps back one mode.
- **Performer (Lalita pass, Phase 4)**: `Performer.shared` ticks at 60Hz, tracking `currentPhase`, `timeIntoPhase`, `crescendoModulator` (the Zimmer move), `inSilence`, `energy`, `beatPulse`, `onsetCount`, and ten archetype-presence values. `Score.cross` ships for Track 27 (Sound of Silence — 6 phases, 2 silence windows, modulator 145/160/180/195/0.8). All other tracks run in ambient mode (no phase / no modulator). Drives the *awakening-peak binaural integration* — beat Hz deepens toward `currentTrackBeatHz × 0.56` at peak unless the user has overridden BEAT.
- **Cathedral renderer (Lalita pass, Phase 5)**: SwiftUI Canvas in `VisualizerView`. Tier 1 continuous: floor (7 radials + 10 perspective horizontals + horizon beat pulse) · Sid columns (drone-pulsed brightness + capital ticks) · vault ceiling (3 stacked Bezier arches + 4 rib vaults per column) · atmospheric grain (80-particle 30Hz step loop) · Gaia ground (52s breathing radial). Tier 2 ensemble (presence-gated): Arch chant (Bezier arc + 5 ghost echoes + 3 traveling phrase-lights) · Sakshi gesture (rotating 72%-arc + 3 ghost trails + leading tip). Tier 3 crescendo (mod > 0): 7 sequentially-triggered rising arches + 7 additive convergence lines. Tier 4 climax (mod > 0.25): keystone radial cascade + 4 cycling expanding rings + Schumann-window earth-rising gradient (elapsed 161–166) + 22-shard Shweta crystallization (peak window). Bindu Lissajous always on top — beat-Hz-driven multi-harmonic path with 120-sample comet trail, RMS bloom, beat rings on `performer.beatPulse > 0.9` edge, carrier-lock 1.5× core pulse.
- **Ensemble layer (Lalita pass, Phase 6)**: three additional archetypes that the Cathedral doesn't manifest. Karishma (paradox-radial dark void + faint element-color rim + 3 depth rings, deepens during silence windows) · Ashrey (multi-hue 40-sample trail through the running centroid of six positioned archetypes) · Neev (5 contracting rings descending floor at bookends — first 4s + last 2s of a scored session).
- **Visualization mode setting**: Settings → visualization → Ensemble (default — full Cathedral) or Singular (just the Bindu Lissajous). Persisted under `binduSettings.vizMode`.
- **Archive**: grouped by date, Integration notes rendered, settings cog, clear archive + clear audio cache flows.
- **Ritual**: queue ≥2 steps, drag-reorder, duration cycler, chained immersed sessions advance on natural completion only.
- **Letter**: mic permission, 3-2-1 countdown, m4a recording with live meter, optional binaural underlay, review with editable title, save / share / delete / swipe-orphan-cleanup, playback re-layers binaural when applicable.
- **Settings**: gain slider (live), visualization picker (ensemble / singular), default-duration chips, API key add/replace/remove (masked), clear archive, clear audio cache (size displayed), catalog refresh with last-refreshed time + offline banner, hidden DSP diagnostics (triple-tap version).
- **Lock-screen / Control Center**: now-playing metadata per context, elapsed advances, stop = full stop, pause/togglePlayPause = soft-mute, play = restore gain.
- **Background audio**: locking the screen or backgrounding the app keeps audio playing. Phone calls / Siri / mediaServicesReset → engines pause → on resume, `AudioSessionCoordinator` re-activates the session and engines restart themselves.

---

## 10. Known issues / open items

No `TODO`, `FIXME`, `HACK`, `XXX`, `stub`, `placeholder`, or "not implemented" markers in source.

Live issues visible from reading the code:

- **Two parallel `AVAudioEngine` instances render to hardware simultaneously, unmixed.** `BinauralEngine` + `BinauralListener` each carry their own `AVAudioEngine` and route to `mainMixerNode` at default gain 1.0. `SettingsStore.gain` is passed only to `BinauralEngine.updateGain`; the music plays at its file level. There is no shared output mixer, no ducking, no headphone-level governor. This is by design today (the binaural is meant to sit *underneath* the music perceptually) but the absence of a master limiter means a hot mp3 + a high gain could clip.
- **`OracleResponse.trackID` is `String`; `Track.id` is `Int`.** Comparison is stringified at the call site. Works as long as the model returns a bare numeric. (The error path surfaces "unknown track ID" already.)
- **Test target is scaffold only** (`Bindu Field Tests/Bindu_Field_Tests.swift` is the Swift Testing template). No real test coverage exists.
- **No Capabilities entry in Xcode UI** — `UIBackgroundModes` is declared via the file at the project root. If a future Xcode version repopulates the build setting (`INFOPLIST_KEY_UIBackgroundModes`) and re-merges in a conflicting way, double-check `PlistBuddy -c "Print :UIBackgroundModes"` on the built bundle after every Xcode upgrade.
- **No analytics, no remote config, no crash reporting, no auth.** No backend other than the Claude messages API + the static aistrangegame.com mp3 host + Airtable.
- **Visual fidelity audit pending** on the Lalita pass. The math matches the design specs (cathedral floor proportions, modulator timings, archetype formulas) but the composition wants Neev's eyes on a real device — especially Track 27's awakening-peak window (2:25–3:15) where Tiers 3 + 4 + Shweta crystallization + Ashrey trail + Neev bookend landing all stack. Sub-areas to inspect: verb-over-gradient legibility in FIELD, Cathedral arch glow against bg, Bindu vs. cathedral-floor relative scale, grain particle density across screen sizes, atmospheric balance when `vizMode == "singular"` vs `"ensemble"`.
- **Player minimize-while-keeping-audio** removed in Phase 3 (the old chevron-down + X buttons are gone — the design has no top-bar chrome in any mode). Logged as a post-Lalita follow-up; the natural home is a swipe-down DragGesture on the FIELD background.
- **Phase 7 — `LalitaEngine`** is the most sophisticated piece of the original handoff (3 phases · 6 mathematical pattern curves · background inversion from void to warm cream). Not implemented; deferred to a separate session per the handoff's explicit decision.

---

## 11. Session ledger (chronological)

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
| `1bd0453` | docs: Lalita pass handoff + design reference package (Player / Lab / Performance / Archetypes / Lalita HTML + JS engines + README) |
| `644647a` | **Lab redesign (Phase 1)** — `BinauralWaveformView` + sacred frequency strip + direct-edit carrier/beat + "let the field choose" weighted randomize + sacred badge + 5-band state palette |
| `f42bdc5` | **Track Reading-space fields (Phase 2)** — `lyricalWordsReading`, `frequencyReading`, `videoPulseReading` (non-optional `String`) + `lalitasPerspective?` (optional) + custom `init(from:)` for backwards-compat decode of older `binduCatalog.v1` caches |
| `ed72622` | **Player three-mode architecture (Phase 3)** — `PlayerMode { field, control, reading }`; 55%/80% bottom sheets; CONTROL play/pause + binaural toggle + PRESENCE + BEAT + CARRIER + READING + END SESSION; READING with WORDS/FREQUENCY/VIDEO/LALITA tabs; additive `DSPWireService` extension (`userBeatHz`, `currentTrackBeatHz`, `currentCarrierHz`, `hasDerivedCarrier`, `hasBeatOverride`, `resetForNewTrack`) |
| `e673d38` | **Performer score state machine (Phase 4)** — `Performer.shared` + `Score.cross` (Track 27) + crescendo modulator (Zimmer move) + 10 archetype-presence formulas + awakening-peak binaural depth integration; wired from `PlayerStore.play` / `stop` |
| `7a3d659` | **Cathedral renderer Tier 1 + Bindu (Phase 5a)** — cathedral floor / Sid columns / vault ceiling / atmospheric grain (80-particle system) / Gaia ground; beat-Hz-driven multi-harmonic Lissajous with 120-sample comet trail, RMS bloom, beat rings, carrier-lock pulse. Visualizer expands from 320×320 box to wide-and-short full-width × mode-dependent height |
| `36bb775` | **Cathedral renderer Tier 2 ensemble (Phase 5b)** — Arch chant (Bezier arc + 5 ghost echoes + 3 phrase-lights) + Sakshi unmade gesture (rotating 72%-arc + 3 ghost trails + leading tip) |
| `8601b06` | **Cathedral renderer Tier 3 + 4 (Phase 5c)** — 7 sequentially-triggered rising arches + 7 additive convergence lines (crescendo) + keystone radial cascade + 4 cycling expanding rings + Schumann earth-rising gradient + 22-shard Shweta crystallization with 14 diffraction dashes (climax) |
| `66a271a` | **Ensemble layer (Phase 6)** — Karishma (paradox-radial dark void + rim + depth rings) + Ashrey (multi-hue trail through 6-archetype centroid) + Neev (5 contracting rings descending to floor at bookends). Lalita remains Phase 7, deferred. |
| `72a4df7` | **Fix 1** — binaural pill becomes status-indicator only (no expansion, tap → CONTROL). Eliminates duplicate controls. |
| `20960fb` | **Fix 2** — FIELD content floats over visualizer via ZStack overlay + top status-bar gradient + bottom viz→bg fade gradient |
| `112ff46` | **Fix 3** — `vizMode` setting added (Ensemble / Singular) under `binduSettings.vizMode`; singular path renders only Bindu Lissajous |
| `efc8005` | **Fix 4** — CONTROL-sheet toggle-row dot breathes continuously (`scaleEffect 1.0↔1.15` over 2s) while `wire.binauralEnabled`, replacing the 500ms carrier-lock pulse |

---

## 12. Where the design pass landed (and what's still ahead)

The Lalita pass shipped on `feat/lalita-pass` across six phases plus four post-review gap fixes — see Session ledger above. The branch is staged for device verification, not merged.

**What landed**
- **Lab redesign** (Phase 1) — animated waveform, direct number editing, sacred frequency strip, "let the field choose" randomize, sacred badge, 5-band state palette.
- **Track Reading-space fields** (Phase 2) — four new Airtable fields surfaced on `Track` with cache-compatible decoding.
- **Player three-mode architecture** (Phase 3) — FIELD / CONTROL / READING. Binaural pill, four reading-tabs, additive `DSPWireService` extension for in-session BEAT control and the sticky DERIVED chip.
- **Performer state machine** (Phase 4) — 60Hz tick, scored phase tracking for Track 27, crescendo modulator, archetype-presence formulas, awakening-peak binaural integration.
- **Cathedral renderer** (Phase 5a/b/c) — full SwiftUI Canvas reimagining of the visualizer. Continuous tier (floor / columns / vault / grain / Gaia), ensemble tier (Arch / Sakshi), crescendo (rising arches + convergence lines), climax (keystone cascade + earth-rising + Shweta crystallization).
- **Ensemble layer** (Phase 6) — Karishma / Ashrey / Neev. The three archetypes the Cathedral doesn't already manifest.
- **vizMode setting** + four gap fixes (status-only pill, gradient fades, vizMode in Settings, breathing CONTROL dot) — the post-Phase-6 audit captured in `DESIGN-GAP-REPORT.md`.

**Still ahead**
- **Phase 7 — `LalitaEngine`** is deferred to a separate session per the original handoff. Reference: `design_handoff_lalita_pass/Bindu Lalita.html` + `README.md` Section 5. Three phases, six mathematical pattern curves, background inversion from void to warm cream.
- **Visual fidelity audit on device** — confirm the Cathedral composition against the design HTML for at least Track 27's awakening peak (2:25–3:15) and the ambient default for an unscored track.
- **Player minimize gesture** — the chevron/X chrome was removed in Phase 3 to match the design; the natural replacement is a swipe-down on the FIELD background that calls `PlayerStore.minimizePlayer()`.
- **More authored Scores** — only Track 27 (Sound of Silence) has a `Score.cross` today. Other tracks run ambient. Adding scores is a `Score.forTrack(id:)` case + a hardcoded `Score(...)` literal per track.

**Sub-areas not yet upgraded** (carried from the original speculative list — still candidates if you want to keep pushing the visual pass)
- Settings sections (`SettingsSection` wrapper around `RoundedRectangle 14 / surface fill / 1pt muted stroke`).
- Letter row + Archive row layouts (functional, low-personality).
- The Ritual queue row — drag-list utility look, no atmosphere.
- The tab bar — SF Symbols at default weight; the verb-rich rest of the app deserves an icon set that doesn't read as iOS-default.
- The headphones tip — pill capsule, low ceremony for a first-launch message.

**Things to NOT touch unless asked** (unchanged from prior audit)
- `BinauralEngine.swift`, `BinauralListener.swift`, all DSP files. Audio behavior is settled.
- `AudioSessionCoordinator.swift`. Settled.
- `DSPWireService.swift` — settled in spirit; additive extensions for Performer/Player wiring are the only changes the Lalita pass made.
- `Info.plist` + the `INFOPLIST_*` build settings. Settled.

---

## 13. Uncommitted work

`BINDU-SESSION5-HANDOFF.md` is untracked (kept as reference, not committed by design). `DESIGN-GAP-REPORT.md` is also untracked — produced by the post-Phase-6 diagnosis session that drove the four gap-fix commits; kept at the project root as a reference artifact.

This CLAUDE.md update itself is the only working-tree modification at the time of this audit.
