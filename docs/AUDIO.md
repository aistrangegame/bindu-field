# Audio engine architecture

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

## Key facts

- **DSP output IS read.** `DSPWireService` is the consumer. RMS modulates `BinauralEngine.updateGain` 10×/sec (inverse curve, sqrt floor at 0.1). Onsets edge-count into `onsetCount` so `Performer` and `VisualizerView` can emit beat rings. Carrier derivation (10s in) drives `BinauralEngine.setCarrier`. `VisualizerView` is fully audio-reactive — RMS bloom, onset rings, carrier-lock 1.5× pulse, comet trail along a multi-harmonic Lissajous.
- **`AudioSessionCoordinator` is the only owner of `AVAudioSession.setCategory`.** Engines and `RecorderService` request a mode (`.playback` / `.playAndRecord`) by string identifier; the coordinator ref-counts and only flips the category when the highest-priority mode changes. Recording wins over playback.
- **`AudioExclusivityCoordinator` is the only owner of *who renders to output*.** Each surface (Field/Map/Oracle-driven Track, Lab, Space, Ritual) claims a source on entry and releases on exit. Lab no longer renders over a Field track or vice versa — the new requester explicitly evicts the prior owner.
- **Interruption recovery is wired.** The coordinator observes `AVAudioSession.interruptionNotification` + `mediaServicesWereResetNotification`. On `.ended` with `.shouldResume`: `setActive(true)` + post `.binduAudioSessionShouldRestart`. Both engines listen and call their own `restartIfNeeded()` which compares Swift-side `isRunning` flag to `engine.isRunning` and re-starts if they disagree. `BinauralListener` additionally re-issues `playerNode.play()`; AVAudioPlayerNode preserves sample-accurate scheduled position across the restart.
- **Background audio works.** `UIBackgroundModes = [audio]` is in the built Info.plist (verified via `PlistBuddy`). Locking the screen or backgrounding the app no longer kills audio.
- **Pause/resume is sample-accurate.** `TrackPlaybackService.isPaused` is the @Observable source of truth; pause/resume halts both engines + the DSP wire without tearing the audio graph down. The player node's sample clock freezes, so `elapsed` pauses naturally.
- **`Performer` is the visualization driver.** Started by `PlayerStore.play(_:)` with the track's authored `Score?` (nil = ambient), it ticks at 60Hz, reads `TrackPlaybackService.elapsed` + `DSPWireService`, and exposes `crescendoModulator` / `beatPulse` / `energy` / `archetypePresence` for the Cathedral and other vocabularies. It also drives the *awakening-peak binaural integration* — at crescendo peak it interpolates the binaural beat Hz down to `currentTrackBeatHz × (1 - 0.8 × 0.55) ≈ 0.56` (only when `wire.hasBeatOverride == false`, so a user CONTROL-slider drag always wins). Not an audio-path component; lives outside the diagram above.

## Audio session lifecycle

1. App launch (`Bindu_FieldApp.runLaunchSetupIfNeeded`, gated by `didLaunch`):
   `NowPlayingService.configureAudioSession()` → `AudioSessionCoordinator.configureForLaunch()` → `setCategory(.playback) + setActive(true)`.
   `PlayerStore.configureEngine()` → `BinauralEngine.configure()` (creates source node, requests playback). Then registers remote commands.
2. First track play: `TrackPlaybackService.play(...)` → `AudioExclusivityCoordinator.request(.track)` → `BinauralListener.configure()` (requests playback, starts engine, installs tap), then `startSession(trackURL:)`. `BinauralEngine.start(carrierHz:)`. `DSPWireService.startPolling()`.
3. `scenePhase` reconciler (G16): on return to `.active`, if `TrackPlaybackService.isPlaying` but `DSPWireService.isMusicPlaying` is false, restart polling. Does NOT stop anything on `.background`.
4. `.binduPlaybackComplete` from `BinauralListener` (file drained): `DSPWireService.handleMusicEnded()` drops polling and holds a drone at `userPresence × 0.2 × gain` — *the field dissipates, it doesn't die.* `PlayerView` also raises the Integration Chamber on this notification.

## Info.plist quirk (Xcode 26)

`GENERATE_INFOPLIST_FILE = YES` and `INFOPLIST_FILE = Info.plist` coexist: the file is treated as the base, generated keys merge in on top.

The `INFOPLIST_KEY_UIBackgroundModes` build setting was silently dropped by Xcode 26's plist generator and is the reason the Foundation cleanup's other work didn't translate to working background audio on Neev's device until the `b02def8` fix that put `UIBackgroundModes = [audio]` directly in `Info.plist` at the project root.

No Capabilities entry in Xcode UI for this — it's declared via the file at the project root. If a future Xcode version repopulates the build setting and re-merges in a conflicting way, double-check `PlistBuddy -c "Print :UIBackgroundModes"` on the built bundle after every Xcode upgrade.
