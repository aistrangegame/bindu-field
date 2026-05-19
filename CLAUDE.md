# Bindu Field — Project State

iOS / SwiftUI app. Binaural-beat instrument layered on a small catalogue of music tracks, with a constellation browser, breath-driven chakra sessions, an Oracle (Claude API) track recommender, voice-letter recorder, and a freeform frequency lab.

Single Xcode target. No git repo. No tests. No SPM dependencies.

---

## 1. Project structure

Project root: `/Users/ashrey/Bindu Field/`

```
Bindu Field/
├── .DS_Store
├── generate_bindu_icon.swift          # Standalone CoreGraphics script for AppIcon — NOT in target
├── Bindu Field.xcodeproj/             # PBXFileSystemSynchronizedRootGroup (Xcode 26)
└── Bindu Field/                       # Source root (synced as a single group)
    ├── Assets.xcassets/               # AppIcon, AccentColor
    ├── Bindu_FieldApp.swift           # @main — boots RootView, audio session, remote commands
    ├── Bindu-Field-Bridging-Header.h  # Imports BinduDSPBridge.h for Swift
    ├── BinauralEngine.swift           # Pure binaural tone generator (AVAudioSourceNode render cb)
    ├── BinauralListener.swift         # Music playback (AVAudioPlayerNode) + analysis tap → BinduDSP
    ├── BinduDSP.h                     # C++ DSP kernel header (FFT, RMS, flux, onset, carrier)
    ├── BinduDSP.cpp                   # C++ DSP implementation (vDSP / Accelerate)
    ├── BinduDSPBridge.h               # ObjC interface exposed to Swift
    ├── BinduDSPBridge.mm              # ObjC++ wrapper around C++ kernel
    │
    ├── Models/
    │   ├── ChakraProtocol.swift       # Chakra struct + hardcoded ChakraData.all (9 entries)
    │   ├── Letter.swift               # Voice-letter record (audio in Documents/Letters/)
    │   ├── Session.swift              # Practice history entry (track or chakra)
    │   ├── Theme.swift                # 3 themes (void/dusk/mist) — only `void` is referenced
    │   └── Track.swift                # Track struct + hardcoded TrackData.all (22 entries)
    │
    ├── Stores/
    │   ├── AudioCache.swift           # Downloads + caches mp3s to Caches/BinduTracks/
    │   ├── BinduConfig.swift          # Resolves remote audio URL via Track.audioURL
    │   ├── KeychainHelper.swift       # Stores Claude API key (com.bindufield.apikeys)
    │   ├── LetterStore.swift          # Letters persisted as JSON in UserDefaults
    │   ├── NavigationStore.swift      # Holds selectedTab (Int)
    │   ├── NowPlayingService.swift    # MPNowPlayingInfoCenter + MPRemoteCommandCenter
    │   ├── OracleService.swift        # Calls api.anthropic.com/v1/messages (claude-haiku-4-5)
    │   ├── PlayerStore.swift          # Top-level playback orchestration (singleton)
    │   ├── RecorderService.swift      # AVAudioRecorder for Letter mode
    │   ├── SessionStore.swift         # Sessions persisted as JSON in UserDefaults
    │   ├── SettingsStore.swift        # gain (Float), defaultSessionDuration (TimeInterval)
    │   └── TrackPlaybackService.swift # Coordinates BinauralListener + BinauralEngine
    │
    └── Views/
        ├── BinduBirthView.swift              # First-launch animated intro
        ├── RootView.swift                    # TabView + birth/headphone overlays
        ├── Components/
        │   └── Chip.swift                    # Reusable capsule chip
        ├── Letter/
        │   ├── LetterPlaybackView.swift      # AVAudioPlayer + optional binaural layer
        │   └── LetterRecordView.swift        # 4-phase recorder (setup/countdown/recording/review)
        ├── Player/
        │   ├── PlayerView.swift              # Fullscreen player modal (verb + visualizer)
        │   └── VisualizerView.swift          # Canvas pulse synced to beat Hz (open-loop)
        ├── Ritual/
        │   ├── RitualRunningView.swift       # Chains SpaceImmersedView per step
        │   └── RitualSetupView.swift         # Queue builder for chakra sequence
        ├── Settings/
        │   └── SettingsView.swift            # Gain, duration, API key, archive clear
        ├── Space/
        │   ├── SpaceImmersedView.swift       # Active breath-modulated chakra session
        │   └── SpaceSetupView.swift          # Chakra picker + duration chips
        └── Tabs/
            ├── ArchiveView.swift             # Grouped session list
            ├── FieldView.swift               # 3D constellation (golden-spiral sphere)
            ├── LabView.swift                 # Manual carrier/beat sliders
            ├── LetterView.swift              # Letter list + share
            ├── OracleView.swift              # Text input → Claude → track suggestion
            ├── RitualView.swift              # Container for setup/running
            └── SpaceView.swift               # Container for setup/immersed
```

---

## 2. Build config

| Setting | Value |
|---|---|
| Bundle ID | `com.bindufield.Bindu-Field` |
| Marketing version | 1.0 (build 1) |
| iOS deployment target | 17.6 |
| macOS deployment target | 26.4 (Mac Catalyst-style; project also targets `macosx`, `xros`, `xrsimulator`) |
| visionOS deployment target | 26.5 |
| Targeted device family | `1,2,7` (iPhone, iPad, Vision) |
| Supported platforms | `iphoneos iphonesimulator macosx xros xrsimulator` |
| Swift version | 5.0 |
| Swift default actor isolation | `MainActor` (project-wide) |
| C++ standard | gnu++17 (target) / gnu++20 (project) |
| Bridging header | `Bindu Field/Bindu-Field-Bridging-Header.h` |
| Code-sign style | Automatic |
| Development team | `VADN2G8B83` (free personal team — provisioning profile expiry not encoded in project; 7-day rotation is typical) |
| App Sandbox | Enabled |
| Hardened Runtime | Enabled |
| Background modes | `audio` |
| Info plist | Generated (`GENERATE_INFOPLIST_FILE = YES`) |
| Microphone usage description | "Used to record Sound Letters while in a binaural session." |
| Frameworks linked | `Accelerate.framework` (only) |
| SPM dependencies | **None** |
| Xcode tooling | Project created on Xcode 26.5 (`objectVersion = 77`, `PBXFileSystemSynchronizedRootGroup`) |

The `Bindu Field/` source directory is synchronized as a single group — files are picked up automatically, the `pbxproj` does not list individual sources.

---

## 3. Audio engine architecture

There are **two independent `AVAudioEngine` instances**, each with its own singleton, each calling `AVAudioSession.setCategory(.playback)`.

### `BinauralEngine` (BinauralEngine.swift) — tone generator
- Owns its own `AVAudioEngine` and an `AVAudioSourceNode` whose render callback synthesizes the binaural tone in real time.
- Left = `sin(2π·carrier·t)`, right = `sin(2π·(carrier+beat)·t)`, both multiplied by a normalized AM term at `beat` Hz (hybrid binaural + monaural beat).
- Exponential glides on carrier, beat, gain, and AM depth (no clicks).
- Setters: `setCarrier`, `updateBeat`, `updateGain`, `updateAMDepth`. Lifecycle: `configure`, `start(carrierHz:)`, `stop`.
- Output goes to hardware.

### `BinauralListener` (BinauralListener.swift) — music playback + analysis
- Owns a *separate* `AVAudioEngine` plus an `AVAudioPlayerNode` and a mixer.
- `startSession(trackURL:)` loads an `AVAudioFile`, schedules it on the player node, installs an analysis tap, plays.
- The tap downmixes to mono (`vDSP_vadd`/`vDSP_vsmul`) into a pre-allocated buffer and forwards each block to the C++ DSP via `BinduDSPBridge.processBlock(...)`.
- Output goes to hardware (separate signal path from BinauralEngine).
- Posts `BinduCarrierDerived` and `BinduPlaybackComplete` notifications.

### `BinduDSP` (BinduDSP.cpp / .h) — C++ feature extractor
- 1024-pt windowed FFT @ 512 hop. Per-frame: RMS, spectral centroid, normalized magnitude spectrum, SuperFlux flux + onset detection, adaptive flux threshold.
- 4096-pt parallel FFT for session-start carrier derivation, scanning 80–200 Hz with harmonic salience scoring; falls back to 136.1 Hz.
- Output is pushed to a lock-free SPSC `FrameRingBuffer` (capacity 64).
- vDSP-based throughout; allocated in `init`, real-time safe inside `processBlock`.

### `BinduDSPBridge` (BinduDSPBridge.mm / .h)
- ObjC++ wrapper holding a `std::unique_ptr<ASG::BinduDSP>`.
- Marshals `BinduFrame` → `NSDictionary` (omits `magnitudeSpectrum` from the dictionary form; `spectrumSnapshot` is a separate call).

### `TrackPlaybackService` (Stores/TrackPlaybackService.swift) — orchestrator
- `play(fileURL:carrier:beat:gain:)` calls `BinauralListener.configure() + startSession(trackURL:)` for the music and `BinauralEngine.start(...) + updateBeat + updateGain` for the binaural layer in parallel.
- Reports `duration` (from `AVAudioFile.length / sampleRate`) and `elapsed` (wall clock from `startTime`).
- `hasCompleted` is computed from elapsed vs duration.

### Wired vs. stubbed

**Wired and audible:**
- BinauralEngine tone output (Lab, Space, Letter, fallback in Field).
- BinauralListener music playback (Field tracks via TrackPlaybackService, when download succeeds).
- Lock-screen / Control Center stop command (single handler stops both engines).

**Computed but unconsumed:**
- `BinduDSP.readLatestFrame()` — exposed via `BinauralListener.readLatestFrame()` but **no view ever calls it**. RMS/centroid/flux/onset/spectrum data is generated and dropped.
- `BinduDSP.deriveCarrier()` — runs 10s after every track start. Result is stored in `BinauralListener.derivedCarrier` and posted as `.binduCarrierDerived`, but **no observer is registered anywhere** and the derived carrier is never fed back into `BinauralEngine.setCarrier(...)`. The carrier in use stays whatever PlayerStore set from `ChakraData` / state defaults.
- `BinauralListener.spectrumSnapshot` — never called.

**Visualizer is open-loop:** `VisualizerView` pulses on a `TimelineView` driven only by `store.currentBeat` — it does not read DSP output. The Field constellation's "playing" pulse is similarly synthetic.

---

## 4. Data layer

### Track catalog
- Hardcoded `static let all: [Track]` in `Models/Track.swift` (22 entries, mix of chakras / meditate / music / family categories).
- `Track` is `Codable`/`Hashable` with: `id (Int)`, `verb`, `song`, `artist`, `element`, `state` (`BrainwaveState`), `chakra?` (`ChakraName?`), `type` (`TrackType`), `filename`, `baseURL`, `youtubeID?`, `seed`.
- `audioURL` is computed: `"\(baseURL)\(filename).mp3"`. Two host roots in use: `https://aistrangegame.com/bindu/` and `https://aistrangegame.com/tree-of-life/`.

### Chakra catalog
- `Models/ChakraProtocol.swift` defines `ChakraProtocol` and `ChakraData.all: [ChakraName: ChakraProtocol]` — 9 chakras with `inhale/hold/exhale`, `beat`, `carrier`, `hue`, and 5 affirmations each.
- `chakraOrder` (in `SpaceSetupView.swift`) defines the canonical grid ordering: root → svadhisthana → manipura → anahata → vishuddha → ajna → sahasrara → aatma → maya.

### How views consume catalogs
- `FieldView` reads `TrackData.all` directly, filters by `BrainwaveState`, and lays out on a golden-spiral sphere.
- `OracleView` passes `TrackData.all` to `OracleService.ask(...)` which inlines a `id=… | verb=… | …` catalog into the system prompt, then resolves the returned id back to a `Track`.
- `SpaceSetupView` iterates `orderedChakras`. `RitualSetupView` builds `[RitualStep]` from the same source.
- `BinduConfig.audioURL(for:)` walks `TrackData.all` by id to resolve a stream URL.

### Persistence
- Sessions: `[Session]` JSON-encoded into `UserDefaults` under key `binduSessions.v1` (`SessionStore`).
- Letters: `[Letter]` JSON-encoded into `UserDefaults` under key `binduLetters.v1`; audio files in `Documents/Letters/*.m4a` (`LetterStore`, `RecorderService`).
- Settings: two `UserDefaults` keys — `binduSettings.gain`, `binduSettings.defaultDuration`.
- First-launch flags: `binduFirstLaunch.seen`, `binduFirstLaunch.tipSeen` (read/written from `RootView`).
- Claude API key: iOS Keychain via `KeychainHelper`, service `com.bindufield.apikeys`.
- Track mp3 cache: `Caches/BinduTracks/track-{id}.mp3` (`AudioCache`).

---

## 5. Tab structure

Defined in `RootView.swift` (tags 0–6). Selected tab kept in `NavigationStore.selectedTab` so other views can switch programmatically (e.g. long-pressing the central Bindu in Field navigates to Oracle).

| Tag | Tab | Composing views | What it does |
|---|---|---|---|
| 0 | **Field** | `FieldView` (+ `PlayerView` modal) | 22-track constellation on a rotating sphere (golden-angle Fibonacci layout). Filter chips (all/delta/theta/theta-alpha/alpha). Drag to spin, tap an orb to play. Central Bindu long-press → Oracle. |
| 1 | **Oracle** | `OracleView` (+ embedded `SettingsView` sheet) | Free-text "how are you arriving?" → POSTs to `api.anthropic.com/v1/messages` (claude-haiku-4-5-20251001) with the full catalog as system prompt → renders verb/song/why → "Begin" plays track. Empty state if no Keychain key. |
| 2 | **Space** | `SpaceView` → `SpaceSetupView` ↔ `SpaceImmersedView` | Pick a chakra + duration (3/5/10/15 min). Immersive session: breath ring expands/holds/contracts on `inhale/hold/exhale` seconds from `ChakraProtocol`; `PlayerStore.setBeat(baseBeat * mod)` where mod is 1.0/1.10/0.80 across phases. Affirmation rotates every 20s. Saves a `.chakra` session on exit. |
| 3 | **Lab** | `LabView` | Two sliders: carrier (40–440 Hz) and beat (0.5–30 Hz). Live `state` label (delta/theta/theta-alpha/alpha/beta/gamma) and color tint follow beat. Play button toggles `BinauralEngine`. Does NOT save sessions. |
| 4 | **Archive** | `ArchiveView` (+ `SettingsView` toolbar sheet) | `SessionStore.sessions` grouped by date, newest first. Empty state if none. Settings cog in toolbar. |
| 5 | **Ritual** | `RitualView` → `RitualSetupView` ↔ `RitualRunningView` (reuses `SpaceImmersedView`) | Build a queue of chakra steps (drag-reorder, swipe-delete, tap chip to cycle duration through 3/5/10/15). Requires ≥2 steps. `RitualRunningView` runs each step as a `SpaceImmersedView` with `ritualProgress`. Advances on natural completion, exits on cancel. |
| 6 | **Letter** | `LetterView` → `LetterRecordView` / `LetterPlaybackView` | List of Sound Letters. Recorder: 4 phases (setup → 3-2-1 countdown → recording w/ red pulse meter → review/title). Optional binaural layer (delta/theta/alpha) plays underneath while recording so the speaker hears it through headphones. Playback view replays the m4a; if `letter.beat > 0` it re-summons the binaural layer. Share via `ShareLink`. |

The Player modal (`PlayerView`) is presented as a `fullScreenCover` from `RootView` whenever `PlayerStore.isPresentingPlayer` is true. Tapping toggles a HUD that auto-hides after 3.8s.

The Bindu birth animation (`BinduBirthView`) and the headphones tip overlay are gated by the two first-launch UserDefaults keys and run on top of the TabView on first launch.

---

## 6. State management patterns

This codebase uses the **Swift Observation framework** uniformly (`@Observable` + `import Observation`), not the older `@StateObject`/`@ObservedObject`/`@EnvironmentObject` model.

- Every store is `@MainActor @Observable final class`, exposed as a `static let shared` singleton, with `private init()`.
  - `PlayerStore`, `SettingsStore`, `SessionStore`, `LetterStore`, `NavigationStore`, `TrackPlaybackService`.
- Views consume them via `@State private var store = SomeStore.shared`. There is no `@StateObject`, `@ObservedObject`, or `@EnvironmentObject` anywhere in the project.
- `@AppStorage` is not used. Persisted scalars are read/written directly through `UserDefaults.standard`:
  - `RootView` reads `binduFirstLaunch.seen` and `binduFirstLaunch.tipSeen` into `@State` bools at init.
  - `SettingsStore` reads/writes `binduSettings.gain` and `binduSettings.defaultDuration` in its property `didSet`s.
- View-local UI state uses `@State` (filters, sliders, modal flags, recording phase). Form input focus uses `@FocusState`. Sheet dismissals use `@Environment(\.dismiss)`.
- Non-observed singletons: `BinauralEngine.shared`, `BinauralListener.shared`, `NowPlayingService.shared`, `OracleService.shared`, `AudioCache.shared`, `RecorderService.shared`. `KeychainHelper` is a static enum.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set project-wide, so every type is on the main actor by default; explicit `@MainActor` on stores is therefore redundant but consistent.

Notifications:
- `BinauralListener` posts `BinduCarrierDerived` and `BinduPlaybackComplete`. No observers are registered for either.

---

## 7. Conventions visible in the code

**File / folder layout**
- One root group `Bindu Field/` synced by `PBXFileSystemSynchronizedRootGroup` — no manual file listing in pbxproj.
- Top-level Swift sources contain only `Bindu_FieldApp.swift` and the four audio/DSP files. Everything else lives in `Models/`, `Stores/`, `Views/`.
- Views are split into `Tabs/` (the 7 top-level tab containers) plus a per-feature folder (`Player/`, `Letter/`, `Ritual/`, `Space/`, `Settings/`) and a shared `Components/`. Container tab views are thin shells that pick between setup/active sub-views.

**File / type naming**
- View files end in `View.swift` and contain a struct of the same name.
- Service / store types end in `Service` (lifecycle, side effects: `OracleService`, `NowPlayingService`, `RecorderService`, `TrackPlaybackService`) or `Store` (observable state: `PlayerStore`, `SettingsStore`, etc.).
- The DSP namespace is `ASG::` in C++ (`namespace ASG`), with C++ classes (`BinduDSP`, `FrameRingBuffer`) and a constants struct (`BinduConstants`).
- Persistence keys are prefixed `bindu*` (`binduSessions.v1`, `binduLetters.v1`, `binduSettings.gain`, `binduFirstLaunch.seen`). The `.v1` suffix on collection keys is consistent.

**SwiftUI style**
- Theme accessed as `private let theme = ThemeData.void` declared in each view struct; the same line appears in dozens of files. `ThemeData.dusk` and `ThemeData.mist` are defined but not referenced anywhere.
- Backgrounds: `theme.bg.ignoresSafeArea()` or a `RadialGradient` (often from an element/chakra color → `theme.bg`).
- Typography: `Text(...).font(.system(size: N, weight: .ultraLight, design: .serif)).italic()` for headings/verbs; `.monospaced` for numeric values; small uppercase labels with `.tracking(2)` and `.textCase(.uppercase)`.
- Element colors are duplicated as a private `elementColor(_:)` switch in both `FieldView` and `PlayerView` (same 10-case mapping).
- Buttons styled as filled capsules: `Capsule().fill(theme.text)` with `foregroundColor(theme.bg)` for primary, capsule with `.stroke(theme.muted.opacity(0.3))` for secondary. The pattern is reimplemented inline per view rather than via a shared ButtonStyle.
- Lock-screen metadata strings live in `NowPlayingService` (one update method per context: Track / Chakra / Lab).
- HUDs auto-hide via `Task { try? await Task.sleep(...); hudVisible = false }` (`PlayerView`); breath ring drives `onChange(of: phase)` for live binaural beat modulation (`SpaceImmersedView`).

**Brain-state colors (Lab)** and **element colors (Field/Player)** are encoded as raw `Color(hue:saturation:brightness:)` tuples inline.

---

## 8. Known issues / TODOs

No `TODO`, `FIXME`, `HACK`, `XXX`, `stub`, `placeholder`, or "not implemented" markers exist anywhere in the source.

Issues visible from reading the code (factual, not opinion):

- **Two parallel `AVAudioEngine` instances.** `BinauralEngine` and `BinauralListener` each instantiate their own `AVAudioEngine` *and* each call `AVAudioSession.setCategory(.playback)` / `setActive(true)` in their own `configureAudioSession()`. `Bindu_FieldApp.swift` *also* calls `NowPlayingService.configureAudioSession()` on launch. They are not coordinated.
- **DSP output never read.** `BinauralListener.readLatestFrame`, `spectrumSnapshot`, and the `derivedCarrier` storage have no callers outside the class. The `BinduDSP` ring buffer fills and drains itself (the consumer never pops; latest-peek reads also never happen).
- **Carrier derivation result not applied.** After 10s, `performCarrierDerivation()` computes a carrier and posts `.binduCarrierDerived`, but no observer is registered, and the value is never passed back to `BinauralEngine.setCarrier(...)`. The actual carrier in use remains the one PlayerStore set from `ChakraData` / brainwave-state defaults.
- **Themes `dusk` and `mist` unused.** `ThemeData.dusk` / `ThemeData.mist` are defined but no view references them.
- **`RecorderService` switches audio session category to `.playAndRecord` on start and back to `.playback` on stop / cancel.** This races with the two engines' own session configuration.
- **`PlayerStore.startBinaural` calls `TrackPlaybackService.shared.stop()`** even when only a binaural tone is being started (Lab, Space, Letter). That's a no-op when the listener isn't playing but it does stop the listener engine if it was.
- **`AVAudioSession.setCategory` is called with no `.mixWithOthers` or duck options.** Two engines play to hardware simultaneously during Field track playback (BinauralListener's music + BinauralEngine's tone). The mixers' default gains are both 1.0.
- **`generate_bindu_icon.swift`** sits at the project root as a runnable Swift script (CoreGraphics icon generator). It is not part of the target.
- **No `.git` directory at the project root** — the repo is not initialized.
- **No test target.**
- **`AudioCache` does not enforce a size cap or eviction policy.** `purgeAll` exists but is unused.
- **`OracleResponse.trackID` is `String`; `Track.id` is `Int`.** Comparison is stringified at the callsite — works, but typed inconsistency.
- **`PlayerView.elementColor` and `FieldView.elementColor`** duplicate the same 10-case `switch` independently.
- **`AVAudioSession` config errors are swallowed** with `print`/`NSLog` and the engine simply returns; the user gets no signal.

---

## 9. Uncommitted changes / work-in-progress

Not a git repository — there is no `.git` directory at the project root, and `git status` from inside the tree reports `fatal: not a git repository`. There are therefore no branches, no commits, and no uncommitted changes to enumerate. Source mtimes cluster around 2026-05-18 (the most recently modified files are `BinauralListener.swift`, `BinauralEngine.swift`, `RootView.swift`, `BinduBirthView.swift`, `LetterStore.swift`, `PlayerStore.swift`).

---

## 10. Current State

### What works
- App boots, presents the 7-tab structure, runs the first-launch Bindu birth animation, then the headphones tip.
- **Field**: constellation renders, rotates, drags, taps select tracks. Track playback flows through `AudioCache` (download/cache → local mp3) → `TrackPlaybackService` → `BinauralListener` (music) + `BinauralEngine` (binaural layer). PlayerView modal presents with verb, song, artist, seed, visualizer.
- **Field fallback**: when an mp3 download fails, the catch arm starts `BinauralEngine` alone (binaural-only).
- **Oracle**: end-to-end. Requires Claude API key in Keychain. Reads `TrackData.all`, hits the messages API, parses JSON, renders verb/why, "Begin" plays the track via PlayerStore.
- **Space**: setup → immersed session. Breath ring, phase counter, affirmation rotation, beat modulation across breath phases, lock-screen metadata, session save on exit (if ≥5s).
- **Lab**: live sliders, color/state label updates, play/stop, lock-screen metadata. (No archive entry — by design.)
- **Archive**: groups stored sessions by date, displays duration / time, gear → SettingsView, clear-archive flow.
- **Ritual**: queue building, reorder, delete, chains step-by-step through `SpaceImmersedView`, advances on natural completion, exits on cancel.
- **Letter**: mic permission flow, 3-2-1 countdown, m4a recording with live meter, optional binaural layer during recording, review with editable title, save, list, swipe-delete, ShareLink, playback (with optional binaural re-layer).
- **Settings**: gain slider (live), default-duration chips, API key add/replace/remove (Keychain, masked display), clear-archive confirmation, app version readout.
- **Lock-screen / Control Center**: now-playing metadata is set per context; play/pause/stop/togglePlayPause all map to a single stop handler (BinauralEngine.stop + clear).
- **Persistence**: UserDefaults for Sessions, Letters, Settings, first-launch flags; Documents/Letters/ for m4a files; Caches/BinduTracks/ for downloaded mp3s; Keychain for API key.

### What's stubbed / unused (built but inert)
- **All BinduDSP feature output.** RMS, centroid, flux, onset detection, magnitude spectrum, host-time timestamps are computed every analysis frame inside the C++ kernel and pushed into the lock-free ring buffer, but no Swift code reads from `readLatestFrame`, `spectrumSnapshot`, or `framesProduced` outside of `BinauralListener.diagnostics()` (itself uncalled).
- **Carrier derivation.** Runs at session start + 10s, stores result in `derivedCarrier`, posts `BinduCarrierDerived` notification — no observer, no feedback into the live `BinauralEngine.setCarrier`. Carrier in use is always the ChakraProtocol / brainwave-default value PlayerStore picked at play time.
- **Visualizers are open-loop.** `VisualizerView` and the Field active-orb pulse derive their motion from `currentBeat` Hz on a `TimelineView` clock; nothing reads the actual playing audio.
- **`ThemeData.dusk` / `ThemeData.mist`** — defined, never referenced.
- **`BinauralEngine.diagnostics()` / `BinauralListener.diagnostics()`** — never called.
- **`AudioCache.purgeAll`** — never called.
- **`generate_bindu_icon.swift`** — sits at project root, not in target.

### What's broken / fragile (visible without running)
- **Dual `AVAudioSession` configuration.** Three different code paths call `setCategory(.playback)` / `setActive(true)` on the shared session (`NowPlayingService.configureAudioSession`, `BinauralEngine.configureAudioSession`, `BinauralListener.configureAudioSession`), plus `RecorderService` flips it to `.playAndRecord` and back. Order is App launch → BinauralEngine.configure (from PlayerStore.configureEngine, on `onAppear`) → BinauralListener.configure (lazily on first track play). Each later call re-asserts category and activates — no audible bug is guaranteed but the state is not centrally owned.
- **Dual `AVAudioEngine` outputs unmixed.** Both engines render to hardware simultaneously during a Field track play. There is no shared mixer, no ducking, no gain coordination beyond `SettingsStore.gain` being passed only to `BinauralEngine.updateGain`. The music plays at its file level; the binaural tone plays at the configured gain.
- **`AudioCache.fetch` runs on the main actor** (the class is `@MainActor`) and `await`s `URLSession.shared.download`. Downloads do not block UI in practice (URLSession is async), but cache misses while UI is alive will keep the main actor busy on JSON-free network bookkeeping.
- **No deduplication for repeat Field taps mid-load.** `play(_:)` early-returns the AudioCache continuation by checking `currentTrack?.id == myTrack.id`, but if the user taps a *different* track while the first is downloading, the first finishes, sees the id mismatch, and silently drops — fine. If the same track is tapped twice rapidly, both fetches resolve, the first call's continuation finishes (calls `TrackPlaybackService.play`), then the second does too (calls `stop()` then `play()` again).
- **`OracleResponse.trackID` is a string, `Track.id` is an Int.** Comparison goes through `String($0.id) == response.trackID`. Works as long as the model returns a bare numeric string; an off-by-anything answer surfaces as an "unknown track ID" error to the user.
- **`AVAudioSession` errors are logged, not surfaced.** Failure to configure or start an engine leaves the app in a no-audio state with only a `print`.

### What's intentionally not here
- No analytics, no remote config, no crash reporting, no auth.
- No backend other than the Claude messages API and a static aistrangegame.com mp3 host.
- No tests, no CI, no `.git`.
