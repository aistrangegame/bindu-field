# Bindu Field — Project State

iOS / SwiftUI app. Binaural-beat instrument layered on a catalogue of music tracks, with a 33-chakra Map (front door), a constellation Field, a 7-step Consciousness Loop, breath-driven AKASH sessions, a four-state Oracle (Claude API) track recommender, Sound Letters, a freeform Lab, and a Ritual sequencer.

Single Xcode target, dark-mode-only, ultraLight serif type, void/black palette. **No SPM dependencies — Accelerate.framework only.** Catalogue loaded dynamically from Airtable; audio MP3s stream from a static aistrangegame.com host with a 200 MB LRU disk cache. Oracle calls api.anthropic.com directly with a key the user pastes into Settings.

Project root: `/Users/ashrey/Bindu Field/`. Currently on `feat/stabilize`, ahead of `origin/feat/stabilize`, not pushed, not merged to main. Build clean, zero warnings, zero errors. Last audited 2026-05-27.

---

## Deeper context — load on demand

This file is the always-loaded index. Detailed reference lives in `docs/` — read the right one when its topic comes up:

| When working on… | Read |
|---|---|
| Audio engine, DSP, AVAudioSession, background audio, interruption recovery, exclusivity coordinator, Info.plist quirk | `docs/AUDIO.md` |
| Airtable schema (tracks), chakra catalogues, frequency presets, scored tracks, persistence details | `docs/DATA-LAYER.md` |
| AKASH breath sessions — Airtable+seed join, fail-closed safety, `[105]` backstop, what's in Airtable vs hardcoded | `docs/BREATH-SESSIONS.md` |
| Tab behaviors, Player modal three-mode architecture, the Map, the Consciousness Loop, element vocabularies | `docs/UI.md` |
| Palette, typography, glow / surface / motion vocabularies, iconography, voice | `docs/DESIGN.md` |
| What works today, known issues, open items, current uncommitted work | `docs/STATUS.md` |
| Chronological commit ledger, what the design pass shipped vs what's still ahead | `docs/SESSIONS.md` |

The legacy `*-HANDOFF.md` and `*-REPORT.md` files at the project root are historical session notes — kept for archaeology, not curated. The `design_handoff_lalita_pass/` folder is the live HTML/JS design prototype reference (notably needed for Phase 7 — the deferred `LalitaEngine`).

---

## Project structure

```
.
├── CLAUDE.md                                   # this file (always loaded)
├── docs/                                       # scoped reference docs (load on demand)
│   ├── AUDIO.md · DATA-LAYER.md · BREATH-SESSIONS.md
│   ├── UI.md · DESIGN.md · STATUS.md · SESSIONS.md
├── Info.plist                                  # UIBackgroundModes = [audio]; see docs/AUDIO.md
├── Bindu Field.xcodeproj/                      # PBXFileSystemSynchronizedRootGroup (Xcode 26)
├── Bindu Field/                                # source root (synced as a single group)
│   ├── Assets.xcassets/                        # AppIcon (Bindu.png), AccentColor
│   ├── Bindu_FieldApp.swift                    # @main — RootView, audio session, remote commands, scenePhase reconciler
│   ├── Bindu-Field-Bridging-Header.h           # imports BinduDSPBridge.h
│   ├── BinauralEngine.swift                    # AVAudioSourceNode tone generator
│   ├── BinauralListener.swift                  # AVAudioPlayerNode music + analysis tap → BinduDSP
│   ├── BinduDSP.{h,cpp}                        # C++ DSP kernel (FFT, RMS, flux, onset, carrier derivation)
│   ├── BinduDSPBridge.{h,mm}                   # ObjC++ wrapper around the C++ kernel
│   ├── Secrets.swift                           # gitignored — Airtable PAT (template at Secrets.swift.template)
│   ├── Models/                                 # Track · ChakraNode · ChakraProtocol · ChakraRegistry · BreathSession · FrequencyPreset · FrequencyInfo · HonestyTier · BrainwaveStateInfo · Letter · Session · Theme
│   ├── Stores/                                 # see "Stores" below
│   └── Views/
│       ├── BinduBirthView.swift
│       ├── RootView.swift                      # 8-tab TabView + birth/headphone overlays + audio error banner + MiniPlayer
│       ├── Components/                         # BinauralWaveformView · BinduGlow · BinduTabIcons · Chip · DateFormatters · ElementColors · PlaybackTime
│       ├── Letter/                             # LetterPlaybackView · LetterRecordView
│       ├── Loop/                               # LoopHostView · LoopStepViews (7 steps)
│       ├── Map/                                # MapView · MapDetailSheet
│       ├── Oracle/                             # OraclePresenceView
│       ├── Player/                             # MiniPlayerView · PlayerView · VisualizerView · VocabularyRenderer
│       ├── Ritual/                             # RitualRunningView · RitualSetupView
│       ├── Settings/                           # SettingsView
│       ├── Space/                              # BreathImmersedView · BreathReadingSpaceView · IntentionGridView · ScreenedGateView · SessionDetailView · SpaceImmersedView · SpaceSetupView · SubSelectionView
│       └── Tabs/                               # ArchiveView · FieldView · LabView · LetterView · OracleView · RitualView · SpaceView
│
├── Bindu Field Tests/                          # Swift Testing scaffold only (G21)
└── Tools/                                      # not in app target — generate_bindu_icon.swift
```

The `Bindu Field/` source directory is auto-included as a `PBXFileSystemSynchronizedRootGroup` — **new folders are picked up automatically, no pbxproj edits needed.** The root-level `Info.plist` is *outside* that group so it isn't double-bundled as a resource.

---

## Build config

| Setting | Value |
|---|---|
| Bundle ID | `com.bindufield.Bindu-Field` |
| Marketing version | 1.0 (build 1) |
| iOS deployment target | 17.6 |
| macOS deployment target | 26.4 |
| visionOS deployment target | 26.5 |
| Targeted device family | `1,2,7` (iPhone, iPad, Vision) |
| Swift version | 5.0 |
| Swift default actor isolation | `MainActor` (project-wide) |
| C++ standard | gnu++17 (target) / gnu++20 (project) |
| Bridging header | `Bindu Field/Bindu-Field-Bridging-Header.h` |
| Code-sign style | Automatic |
| Development team | `VADN2G8B83` |
| Background modes | **`audio`** — declared in `Info.plist` at project root, merged via `INFOPLIST_FILE`. See `docs/AUDIO.md` for the Xcode-26 quirk. |
| Microphone usage description | "Used to record Sound Letters while in a binaural session." |
| Frameworks linked | `Accelerate.framework` (only) |
| SPM dependencies | **None** |
| Xcode tooling | Xcode 26.5 — `objectVersion = 77`, `PBXFileSystemSynchronizedRootGroup` |
| App Sandbox + Hardened Runtime | Enabled |
| Test target | `Bindu Field Tests` — scaffold only, no real tests |

---

## Tabs

`RootView.swift` — `TabView` over `NavigationStore.selectedTab` (tags 0–7). **iOS auto-collapses tabs 5–7 (Lab, Ritual, Letter) into the More menu** because the primary array exceeds 5. Full per-tab behavior in `docs/UI.md`.

| Tag | Tab | One-line |
|---|---|---|
| 0 | Map | 33 chakra nodes, the conceptual front door. Three render states (locked / available / danced). |
| 1 | Field | 22-orb constellation, default landing post-Birth. Long-press central Bindu → Oracle. |
| 2 | Oracle | Four-state Claude-API track recommender (idle / typing / waiting / response). |
| 3 | AKASH (file: `SpaceView`) | 8-tile intention grid over 11 Airtable-backed breath sessions; screened-tier sessions gate. |
| 4 | Archive | Session history grouped by date with integration notes. Settings cog top-right. |
| 5 | Lab | Frequency lab — `TuningCluster` per beat/carrier + `MeaningPanel` + presets. |
| 6 | Ritual | Build & run a queue of chakra steps; reuses `SpaceImmersedView`. |
| 7 | Letter | Sound Letter list, recorder (4-phase), playback (optional binaural re-layer). |

---

## Stores (all `@MainActor @Observable final class`, `static let shared`, `private init()` unless noted)

`PlayerStore`, `SettingsStore`, `SessionStore`, `LetterStore`, `PresetStore`, `NavigationStore`, `TrackPlaybackService`, `DSPWireService`, `Performer`, `CatalogStore`, `BreathSessionStore`, `AudioSessionCoordinator`, `AudioExclusivityCoordinator`, `ChakraJourneyStore`, `ConsciousnessLoopCoordinator`.

View-local (not singletons): `OraclePresenceModel` — owned by `OracleView`, passed into `OraclePresenceView`.

Non-`@Observable` singletons: `BinauralEngine.shared`, `BinauralListener.shared` (NSObject, audio-thread state), `NowPlayingService.shared`, `OracleService.shared`, `AudioCache.shared`, `RecorderService.shared`, `AirtableService.shared`. `KeychainHelper`, `BinduConfig`, `FrequencyInfo`, `ChakraRegistry`, `ElementVocabulary` are static enums.

---

## Persistence quick reference

| What | Where | Key / Path |
|---|---|---|
| Sessions | UserDefaults | `binduSessions.v1` |
| Letters (metadata) | UserDefaults | `binduLetters.v1` |
| Letters (audio) | Documents | `Documents/Letters/<UUID>.m4a` |
| User frequency presets | UserDefaults | `binduPresets.v1` |
| Track catalogue cache | UserDefaults | `binduCatalog.v1` + `binduCatalog.v1.lastRefreshedAt` |
| Breath sessions cache | UserDefaults | `binduBreathSessions.v1` + `.lastRefreshedAt` |
| Track audio cache | Caches | `Caches/BinduTracks/track-{id}.mp3` (200 MB LRU) |
| Chakra journey (Map dance log) | UserDefaults | `binduJourney.v1` |
| Settings | UserDefaults | `binduSettings.gain`, `binduSettings.defaultDuration`, `binduSettings.vizMode` |
| First-launch flags | UserDefaults | `binduFirstLaunch.seen`, `binduFirstLaunch.tipSeen`, `binduFirstLaunch.oracleHintSeen` |
| Claude API key | Keychain | service `com.bindufield.apikeys` · account `claude_api_key` · `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| Airtable PAT | Code | `Secrets.swift` (gitignored; template at `Secrets.swift.template`) |

`UserDefaultsCodable<T: Codable>` (in `Stores/`) is the encode-write / read-decode helper used by `SessionStore`, `LetterStore`, `PresetStore`, `ChakraJourneyStore`.

---

## State management rules

- Stores: `@MainActor @Observable final class`, `static let shared`, `private init()`. Consume via `@State private var store = SomeStore.shared`.
- Theme via `@Environment(\.binduTheme) private var theme`. The legacy `private let theme = ThemeData.void` pattern has been fully migrated out — every view reads from the environment.
- **NEVER use `@StateObject` / `@ObservedObject` / `@EnvironmentObject`** — Observation framework only.
- `@State` for filters, sliders, modal flags, recording phase, Loop showing flags, Map selected node. `@FocusState` for text input focus. `@Environment(\.dismiss)` for sheet dismissal.

Notifications used to coordinate across modules:

- `.binduCarrierDerived`, `.binduPlaybackComplete` (`BinauralListener`)
- `.binduAudioSessionShouldRestart` (`AudioSessionCoordinator`)
- `.binduLabStop`, `.binduSpaceStop`, `.binduRitualStop` (`AudioExclusivityCoordinator`)

---

## Conventions

- One root group `Bindu Field/` synced by `PBXFileSystemSynchronizedRootGroup`. No manual file listing in pbxproj.
- View files end in `View.swift` and contain a struct of the same name. Service / store types end in `Service` (lifecycle, side effects) or `Store` (observable state). DSP namespace is `ASG::` in C++.
- Persistence keys all prefixed `bindu*`. Collection keys carry `.v1` suffix.
- Backgrounds: `theme.bg.ignoresSafeArea()` for flat tabs; `vocab.bg.ignoresSafeArea()` in PlayerView; `RadialGradient` from an element/chakra color to `theme.bg` for immersive contexts.
- Buttons reimplement the capsule pattern inline rather than via a shared `ButtonStyle` — no `BinduButtonStyle` exists. `BinduGlow.swift` (`.binduGlow(color:tight:wide:)`) is the closest shared style — a two-layer tight+ambient shadow halo.
- 44×44 hit targets on chrome buttons (top-bar back/close) — accessibility floor.
- HUDs auto-hide via `Task { try? await Task.sleep(...); hudVisible = false }`, cancellable on tap. The Player's CONTROL sheet uses an explicit `scheduleAutoHide()` helper reset on every touch.
- Canvas idioms: every Canvas-drawn view wraps in `TimelineView(.animation(minimumInterval: 1.0/30.0))`; the Cathedral uses 60Hz. JavaScript canvas → SwiftUI Canvas mappings are uniform (`gc.fill(Path(...))`, `.radialGradient(...)`, `var local = gc; local.blendMode = .screen`).
- Logging: `os.Logger` subsystem `com.bindufield`, categories `audio.engine`, `audio.listener`, `audio.session`. On device: `log show --predicate 'subsystem == "com.bindufield"' --info --last 5m`.

---

## Don't touch unless asked

- `BinauralEngine.swift`, `BinauralListener.swift`, all DSP files — settled.
- `AudioSessionCoordinator.swift` — settled. (`AudioExclusivityCoordinator` is a separate concern that lives alongside it.)
- `DSPWireService.swift` — settled in spirit; additive extensions for Performer/Player wiring are the only changes the Lalita pass made.
- `Info.plist` + the `INFOPLIST_*` build settings — settled. See `docs/AUDIO.md` for the Xcode-26 plist-generator quirk.
