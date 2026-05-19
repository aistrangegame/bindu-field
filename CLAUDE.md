# Bindu Field — Project State

iOS / SwiftUI app. Binaural-beat instrument layered on a catalogue of music tracks, with a constellation browser, breath-driven chakra sessions, an Oracle (Claude API) track recommender, voice-letter recorder, freeform frequency lab, and ritual sequencer.

Single Xcode target, dark-mode-only, ultraLight serif type, void/black palette. **No SPM dependencies — frameworks linked are Accelerate only.** The catalogue is loaded dynamically from Airtable; audio MP3s stream from a static aistrangegame.com host with a 200 MB LRU disk cache. The Oracle calls api.anthropic.com directly with a key the user pastes into Settings.

Last audited: **2026-05-19**, currently on `main` at `b02def8` (post-merge of `feat/constellation-lab-oracle`, post-background-audio fix). Build clean, zero warnings, zero errors.

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
│   │   └── Track.swift                         # Track + BrainwaveState + ChakraName + TrackType enums; recognitionStatement?
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
│   │   ├── PlayerStore.swift                   # top-level playback orchestration (play track / startBinaural / stop / Integration note)
│   │   ├── PresetStore.swift                   # user-saved frequency presets JSON in UserDefaults `binduPresets.v1`
│   │   ├── RecorderService.swift               # AVAudioRecorder for Letters
│   │   ├── SessionStore.swift                  # Sessions JSON in UserDefaults `binduSessions.v1`
│   │   ├── SettingsStore.swift                 # gain (Float) + defaultSessionDuration (TimeInterval) in UserDefaults
│   │   ├── TrackPlaybackService.swift          # coordinates BinauralListener + BinauralEngine + DSPWireService; audio-clock elapsed
│   │   └── UserDefaultsCodable.swift           # tiny T-Codable-in-UserDefaults helper used by Session/Letter/Preset stores
│   │
│   └── Views/
│       ├── BinduBirthView.swift                # First-launch Task-chain birth animation
│       ├── RootView.swift                      # TabView + birth/headphone overlays + audio error banner
│       ├── Components/
│       │   ├── Chip.swift                      # filter chips (capsule, italic serif)
│       │   ├── DateFormatters.swift            # archiveDate / archiveTime / letterTitle (shared, memoized)
│       │   ├── ElementColors.swift             # Color.bindu(element:) — single source of truth for 10 element hues
│       │   └── PlaybackTime.swift              # TimeInterval.asPlaybackTime (M:SS)
│       ├── Letter/
│       │   ├── LetterPlaybackView.swift        # AVAudioPlayer + optional binaural re-layer
│       │   └── LetterRecordView.swift          # 4-phase recorder (setup / countdown / recording / review); orphan-cleanup on B14
│       ├── Player/
│       │   ├── PlayerView.swift                # fullscreen player modal — arrival ceremony, scrubber, binaural pill, Integration Chamber
│       │   └── VisualizerView.swift            # Lissajous Bindu w/ comet trail, RMS bloom, onset rings, carrier-lock pulse
│       ├── Ritual/
│       │   ├── RitualRunningView.swift         # chains SpaceImmersedView per step, advances only on natural completion
│       │   └── RitualSetupView.swift           # drag-reorder queue + per-step duration cycler
│       ├── Settings/
│       │   └── SettingsView.swift              # audio · session · oracle · data · catalog · (triple-tap diagnostics) · about
│       ├── Space/
│       │   ├── SpaceImmersedView.swift         # breath ring × beat modulation × rotating affirmation
│       │   └── SpaceSetupView.swift            # chakra picker + duration chips
│       └── Tabs/                               # one container per top-level tab
│           ├── ArchiveView.swift               # grouped session list w/ Integration notes; gear → SettingsView
│           ├── FieldView.swift                 # 3D constellation, played/never visual states, depth fog, element lines
│           ├── LabView.swift                   # sliders + preset row + brainwave info card + carrier-note popover
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
- **Fields** (Airtable column → `Track` property): `Track ID` → `id: Int`, `Verb` → `verb`, `Song Title` → `song`, `Artist` → `artist`, `Track Type` → `type` (chakra/music/meditate/family), `Element` → `element` (Earth/Water/Fire/Air/Light/Crown/Soul/Dissolution/Meditate/Family), `Brainwave State` → `state` (delta/theta/theta-alpha/alpha), `Chakra` → `chakra?`, `Audio URL` → `audioURL`, `YouTube ID` → `youtubeID?`, `Carrier Hz` → `carrierHz: Double`, `Beat Hz` → `beatHz: Double`, `Seed Phrase` → `seed`, **`Recognition Statement` → `recognitionStatement: String?`** (newest field — empty for most tracks today; Oracle includes it in the catalog line only when non-empty).
- `CatalogStore` caches the array as JSON under `binduCatalog.v1`, with a `binduCatalog.v1.lastRefreshedAt` timestamp. Refresh policy: skip network if cache <1 hour old; force-refresh available from Settings; never overwrite cache with an empty-array response (B13). Decode failures swallow silently — old caches still decode after a Track-shape evolution because `recognitionStatement` is optional.
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
| Gain / default duration | UserDefaults | `binduSettings.gain`, `binduSettings.defaultDuration` |
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
| 3 | **Lab** | `LabView` | Carrier + beat sliders (40–440 Hz, 0.5–30 Hz). Big monospaced beat readout. **State label expands** on tap to show range + essence + detail from `FrequencyInfo`. **Carrier dot**: small accent dot next to carrier value when near a notable frequency → tap → popover with the note. **Preset row**: system + user chips; tap loads values (animated 0.4s easeOut + live `setCarrier`/`setBeat` if playing); long-press user chip → delete alert (system presets ignore long-press); inline `+ save` chip flips to text field. No Archive entry (by design). |
| 4 | **Archive** | `ArchiveView` (+ `SettingsView` toolbar sheet) | Sessions grouped by full date (descending), each row shows verb-or-Sanskrit, song/artist-or-English-center, optional Integration note ("…" in serif italic at `subtle`), duration mono and short-time. Empty state if none. Settings cog top-right. |
| 5 | **Ritual** | `RitualView` → `RitualSetupView` ↔ `RitualRunningView` (reuses `SpaceImmersedView`) | Build a queue of chakra steps (drag to reorder, swipe to delete, tap mins chip to cycle 3/5/10/15). Requires ≥2 steps to start. Running view chains `SpaceImmersedView` with `ritualProgress: (current, total)`. Advances on natural completion, exits on cancel. |
| 6 | **Letter** | `LetterView` → `LetterRecordView` / `LetterPlaybackView` | List of Sound Letters. Recorder: 4 phases (setup → 3-2-1 countdown → recording w/ red pulse meter → review/title). Optional binaural underlay (delta/theta/alpha/silent) plays while recording so the speaker hears it through headphones. Playback: optional binaural re-layer when `letter.beat > 0`. Share via `ShareLink`. `interactiveDismissDisabled` during countdown/recording. Orphan-m4a cleanup if user swipes away in review without saving (B14). |

### Player modal (PlayerView)

Presented as `fullScreenCover` from `RootView` whenever `PlayerStore.isPresentingPlayer == true`. Single tap toggles HUD (top bar, info chips) which auto-hides after 3.8s. Binaural pill is OUTSIDE the HUD opacity so the toggle is always reachable.

Components, top to bottom:
- **Background**: `RadialGradient` from `Color.bindu(element:) × 0.12` to `theme.bg`.
- **VisualizerView** (320×320) OR loading state ("fetching the field…" + spinner).
- **Top bar** (HUD): minimize chevron · elapsed monospaced · close X. (Both buttons are 44×44 hit-targets — accessibility floor.)
- **Verb**: 64pt ultraLight serif italic in element color, with element-color shadow (radius 20).
- **Song + artist**: serif title + muted artist.
- **Scrubber** (G18): read-only (no seek). Slim 2pt capsule, element-color fill on muted track, labelled "flowing" in serif italic between elapsed / remaining timestamps. The bar is intentionally slim so users don't mistake it for an interactive seek bar.
- **Stop control**: always visible, independent of HUD. Capsule-stroke style — "stop" in serif italic. Closes player, finalizes session as `completed: false`.
- **Seed phrase**: 16pt serif italic at 70% text opacity, centered, max 340pt wide.
- **InfoChip row** (HUD): carrier / beat / state, monospaced numerics under tiny tracking-2 uppercase labels.
- **Binaural pill** (top-anchored, `ultraThinMaterial`): collapsed = 8pt dot (filled=on / stroked=off) + "BINAURAL" label + chevron. Expanded reveals binaural toggle, PRESENCE slider (0–100% writing `wire.userPresence`), and "carrier · derived" badge when `wire.carrierLocked` (G20).
- **Integration Chamber**: black/0.78 overlay, "what did you remember?" prompt, multi-line `TextField` in `theme.surface`, "close" / "save note" capsule buttons. Auto-dismisses after 30s. Only raised on natural playback completion — user-initiated stops do NOT trigger it. Saved note attaches to the session via `PlayerStore.pendingNote` and renders in Archive rows.
- **Arrival ceremony**: content opacity 0→1 and scale 0.96→1.0 over 0.6s `easeOut` on appear.

---

## 6. State management patterns

Uniform use of the Swift Observation framework (`@Observable` + `import Observation`), not `@StateObject`/`@ObservedObject`/`@EnvironmentObject`.

### Stores
- Every store is `@MainActor @Observable final class`, exposed as a `static let shared` singleton with `private init()`.
- Consumed via `@State private var store = SomeStore.shared` in each view.
- Stores: `PlayerStore`, `SettingsStore`, `SessionStore`, `LetterStore`, `PresetStore`, `NavigationStore`, `TrackPlaybackService`, `DSPWireService`, `CatalogStore`, `AudioSessionCoordinator`.

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

## 9. What works (current truth, post-`b02def8`)

- **All 7 tabs** boot and run their golden paths. First-launch shows the Task-chain BinduBirthView, then the headphones tip.
- **Field tracks**: Airtable refresh → catalogue → tap orb → `AudioCache.fetch` (download or cache hit) → `TrackPlaybackService.play` → music + binaural layer + DSP wire + visualizer. Cache miss falls back to binaural-only with a surfaced error.
- **Oracle**: Keychain-gated, terse error states, retry on 429/5xx, recently-played hint included, recognition statements appended only when present.
- **Space**: breath-modulated binaural, beat ×1.0/1.1/0.8 across inhale/hold/exhale, affirmations rotate every 20s, lock-screen metadata, session saved if ≥5s.
- **Lab**: live carrier + beat, state label expands info card, carrier dot → popover, preset row, inline save, long-press delete, persistence across launch.
- **Archive**: grouped by date, Integration notes rendered, settings cog, clear archive + clear audio cache flows.
- **Ritual**: queue ≥2 steps, drag-reorder, duration cycler, chained immersed sessions advance on natural completion only.
- **Letter**: mic permission, 3-2-1 countdown, m4a recording with live meter, optional binaural underlay, review with editable title, save / share / delete / swipe-orphan-cleanup, playback re-layers binaural when applicable.
- **Settings**: gain slider (live), default-duration chips, API key add/replace/remove (masked), clear archive, clear audio cache (size displayed), catalog refresh with last-refreshed time + offline banner, hidden DSP diagnostics (triple-tap version).
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

---

## 12. Where the design pass should land

Sub-areas where the existing visual language is the strongest, in case Lalita wants to lean into them:
- The Player verb — 64pt ultraLight serif italic in element color with element-color glow shadow.
- The breath ring in Space — element-radial-gradient circle scaling with breath, ring annulus animating linearly to match.
- The Lissajous Bindu — multi-harmonic Lissajous path with a 20-sample comet trail, RMS bloom, onset rings.
- The Bindu birth — black → core → pulse → dissolve in ~3.4s.
- The constellation depth-fog feel — opacity × `(1 − depth × 0.5)`, size × `(1 − depth × 0.2)`.

Sub-areas that are functional but visually plain, in case Lalita wants to upgrade:
- Settings sections (`SettingsSection` wrapper around `RoundedRectangle 14 / surface fill / 1pt muted stroke`).
- Letter row + Archive row layouts (functional, low-personality).
- The Lab readout — the 76pt monospaced beat number is brutalist by accident, not by intent.
- The Ritual queue row — drag-list utility look, no atmosphere.
- The tab bar — SF Symbols at default weight; the verb-rich rest of the app deserves an icon set that doesn't read as iOS-default.
- The headphones tip — pill capsule, low ceremony for a first-launch message.

Things to NOT touch unless asked:
- `BinauralEngine.swift`, `BinauralListener.swift`, all DSP files. Audio behavior is settled.
- `AudioSessionCoordinator.swift`. Settled.
- `DSPWireService.swift`. Settled.
- `Info.plist` + the `INFOPLIST_*` build settings. Settled.

---

## 13. Uncommitted work

`BINDU-SESSION5-HANDOFF.md` is untracked (kept as reference, not committed by design). No other uncommitted changes at the time of this audit.
