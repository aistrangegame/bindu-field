# Bindu Field — Architecture Audit

Scope: every Swift file in the target as of branch `feat/dsp-wire-player-upgrade` (HEAD `467bc68`). Three sections: real defects, elevations, and unfinished wiring. Severity scale: **critical** (will misbehave on device for normal users) / **medium** (misbehaves under specific but plausible conditions) / **low** (latent / cosmetic / edge).

No code is changed by this document.

---

## 1. BUGS

### Audio session & engine lifecycle

| # | File | Issue | Severity | Fix direction |
|---|---|---|---|---|
| B1 | `NowPlayingService.swift`, `BinauralEngine.swift`, `BinauralListener.swift`, `RecorderService.swift` | Four independent owners call `AVAudioSession.setCategory` / `setActive(true)`. `RecorderService.start()` flips to `.playAndRecord` and `.stop()`/`.cancel()` flip back to `.playback`, with no coordination if music is playing elsewhere. Last writer wins. | medium | Single `AudioSessionCoordinator` owning category transitions; engines/recorder request, don't dictate. |
| B2 | `BinauralEngine.swift` `stop()` | Fades over ~2 s by setting `gainTarget = 0` and dispatches `engine.stop()` 2.5 s later. If `start()` is called inside that window, `isRunning` is still true, the new `start()` returns early (`if isRunning { return }`), but the *pending* dispatched closure will still run and stop the engine right after the user restarts. | medium | Capture a generation counter; only stop if generation matches when the closure fires. Also reset `gainTarget` to a sensible non-zero on `start()`. |
| B3 | `BinauralListener.swift` `handleAnalysisTap` ↔ `allocateMonoBuffer` | The audio-thread tap reads `monoBuffer` (pointer) without acquiring `monoBufferLock`. If `frameCount > monoBufferCapacity` ever fires, `allocateMonoBuffer` deallocates the old pointer on the main thread while the audio thread may still hold a reference. Initial 8192-capacity makes this rare but the race is real. | critical (latent) | Pre-allocate to a worst-case ceiling at `configure()` and never realloc; or use an atomic pointer swap with hazard-pointer / RCU-style reclamation. |
| B4 | `BinauralListener.swift` `scheduleFile` completion | `completionCallbackType: .dataPlayedBack` fires when buffered data is played back. When the user manually stops mid-track, the callback can still fire shortly after, which posts `.binduPlaybackComplete`. Downstream, `PlayerView` opens the Integration Chamber on a user-initiated stop. | medium | Distinguish natural completion from user stop — set a `userStoppedFlag` in `stopSession()`, check it in the completion handler before posting. |
| B5 | `Stores/PlayerStore.swift` `play()` | Calls `BinauralEngine.shared.stop()` AND `TrackPlaybackService.shared.stop()` (which itself stops both engines). The Engine receives `stop()` twice; the second is a no-op but the duplication is a smell that can mask real-world ordering bugs. Same pattern in `PlayerStore.stop()`. | low | Pick one tear-down path. `TrackPlaybackService.stop()` already handles both engines. |
| B6 | `Stores/TrackPlaybackService.swift` `elapsed` | Computed from wall clock (`Date().timeIntervalSince(startTime)`), not the audio clock. After a background suspension, an audio interruption, or any sample-rate hiccup, the scrubber's elapsed drifts relative to actual playback position. | medium | Derive elapsed from `AVAudioPlayerNode.lastRenderTime`, falling back to wall clock only when the node hasn't started. |
| B7 | `Views/Tabs/LabView.swift` carrier slider `onCommit` | Calls `store.startBinaural(carrier: newCarrier, beat: beat)`. `startBinaural` → `BinauralEngine.start(carrierHz:)`, which guards `if isRunning { return }`. **Sliding the carrier while playing silently does nothing.** Beat works because `setBeat` is on a separate path. | medium | Call `BinauralEngine.setCarrier(newCarrier)` directly when `isPlaying`; only `start(...)` from a stopped state. |

### Notifications & state coordination

| # | File | Issue | Severity | Fix direction |
|---|---|---|---|---|
| B8 | `Views/Player/PlayerView.swift` Integration Chamber `dismissIntegration` | Calls `store.closePlayer()` → `stop()` → `finalizeCurrentSession(completed: false)`. The hardcoded `false` means a session that ran to natural end is recorded as `completed: false` in the Archive. The completion signal exists (`trackPlayer.hasCompleted` / `.binduPlaybackComplete`) but is dropped at the finalize boundary. | medium | Add a parameter to `PlayerStore.closePlayer(completed:)` (default false) and `finalizeCurrentSession(completed:)`; the chamber's natural-end path passes `true`. |
| B9 | `Stores/NowPlayingService.swift` `registerRemoteCommands` | Calls `addTarget` for stop/pause/togglePlayPause/play with no idempotency guard. Currently invoked once from `RootView.onAppear` so it's safe, but any future re-trigger (deep link, scene reactivation) stacks handlers and runs the stop closure N times per remote tap. | low | Track a `didRegister` flag; or call `removeTarget` before re-adding. |
| B10 | `Stores/DSPWireService.swift` carrier-lock pulse race | The 500 ms reset is a free `Task` launched from the observer. Two carrier-derived events within 500 ms stack two Tasks; the second's reset may fire before the first finishes, blanking the second visual ack. Unlikely in practice (derivation runs once per session) but the structure invites bugs. | low | Store the reset Task; cancel before scheduling a new one. |
| B11 | `Stores/DSPWireService.swift` `Timer.scheduledTimer` | Defaults to `.default` run-loop mode, which pauses during scroll-tracking. The 10 Hz polling halts whenever the user scrolls — gain freezes at whatever value it last wrote. | low | `RunLoop.main.add(timer, forMode: .common)`. |
| B12 | `Stores/DSPWireService.swift` drone gain after `handleMusicEnded` | Drone gain is set once at music end (`userPresence * 0.2 * settings.gain`). If the user adjusts the presence slider after the drone starts, the engine gain doesn't follow — polling has stopped. | low | Keep a low-rate ticker alive during the drone phase, or recompute on `userPresence` `didSet` when `!isMusicPlaying`. |
| B13 | `Stores/CatalogStore.swift` `refresh()` | If Airtable returns an empty `records` array (mis-shared base, permissions issue), `tracks` is replaced with `[]` AND the cache is overwritten with `[]`. The user's previously-good cache is lost. | medium | Don't overwrite cache when the fetched array is empty unless `loadError == nil` AND the request explicitly succeeded with zero records. |
| B14 | `Views/Letter/LetterRecordView.swift` recorded-file leak | If the user swipes the sheet down during the `.review` phase (not blocked — only `.recording` and `.countdown` are), `recordedURL` points to an m4a in `Documents/Letters/` that was never saved to `LetterStore`. The file is orphaned. | low | `.onDisappear`: if `phase == .review` and not saved, call `discardLetter()`. |
| B15 | `Bindu_FieldApp.swift` `.onAppear` triple-effect | `NowPlayingService.configureAudioSession() + PlayerStore.configureEngine() + registerRemoteCommands + CatalogStore.refresh` all run unguarded. `RootView` is the root and doesn't disappear in normal flow, so this fires once today. But anything that recreates `RootView` (multi-window, scene reactivation) will repeat the registration and re-fetch the catalog. | low | Wrap in `@State var didLaunch = false`; gate the side effects. |

### Data model & catalog

| # | File | Issue | Severity | Fix direction |
|---|---|---|---|---|
| B16 | `Stores/AirtableService.swift` pagination | The URL hardcodes `?pageSize=100`. Airtable responses with >100 records include an `offset` token and the client must follow it. Current catalog is 22 records, but any growth past 100 silently truncates. | low (today) / medium (after growth) | Loop until response has no `offset`; concatenate `records`. |
| B17 | `Stores/AirtableService.swift` token validation | Only rejects empty + two literal placeholders. A user can keep a stale "abcd" string and the service will hit Airtable, get 401, and surface the API error — works, but it's a soft signal. | low | Validate format (`pat[A-Za-z0-9]{14,}\.[a-f0-9]{40,}`) before the network call. |
| B18 | `Stores/AudioCache.swift` cache growth | No size cap, no eviction policy, no purge UI surfaced anywhere. Indefinite use accumulates mp3s in `Caches/BinduTracks/` until the OS evicts them on storage pressure (which it may do unpredictably). | low / medium | Track size, cap at e.g. 200 MB, evict LRU; add "clear cache" to Settings. |

---

## 2. OPPORTUNITIES

### Code reuse

| # | File | Issue | Severity | Fix direction |
|---|---|---|---|---|
| O1 | ~14 views | Every view re-declares `private let theme = ThemeData.void`. Mechanical, brittle to a future theme switch (which is what `dusk` / `mist` were apparently for). | low | `@Environment(\.binduTheme)` key with `ThemeData.void` as default; switch in one place. |
| O2 | `Stores/PlayerStore.swift`, `Views/Tabs/LabView.swift`, `Views/Space/SpaceImmersedView.swift`, `Views/Letter/LetterRecordView.swift`, `Views/Letter/LetterPlaybackView.swift` | All call BinauralEngine through `PlayerStore.startBinaural/stopBinaural/setBeat/setGain`. The wrapper layer is thin but inconsistent — Lab calls `setBeat` directly, Space calls `setBeat` too, Letters re-start. | low | One `BinauralController` actor exposing a small typed API; remove the engine-shaped methods from `PlayerStore`. |
| O3 | `Views/Letter/LetterPlaybackView.swift` + `Views/Player/PlayerView.swift` | Two parallel "playback" surfaces with formatting helpers (`formatTime`, `formatPlayerTime`) that do the same thing. | low | One `String.formatPlaybackTime(_ seconds:)` helper. |
| O4 | `Views/Tabs/ArchiveView.swift` `DateFormatter.archiveDate` / `archiveTime` | Private extension on `DateFormatter`. Other date displays (`Letter` timestamp, session timestamps) reimplement formatting inline. | low | Promote to a shared `DateFormatter` extension. |
| O5 | `Stores/PlayerStore.swift`, `Stores/LetterStore.swift`, `Stores/SessionStore.swift` | Same JSON-in-UserDefaults persistence pattern, copy-pasted. | low | One generic `UserDefaultsCodableStore<T>` helper. |

### Performance

| # | File | Issue | Severity | Fix direction |
|---|---|---|---|---|
| O6 | `Stores/AirtableService.swift` `fetchTracks` | `@MainActor`; URLSession await yields the main actor, but JSON decoding runs on it. Fine for 22 records, suboptimal at growth. | low | Hop decoding to a detached task. |
| O7 | `Stores/AudioCache.swift` `fetch` | `@MainActor`; URLSession download is async, but main-actor isolation forces continuation hops to main for bookkeeping. | low | Make the class non-MainActor and pass URLs/IDs as values. |
| O8 | `Views/Player/VisualizerView.swift` `.onChange(of: t)` | Fires every animation frame (~60 Hz) just to ask "have 40 ms elapsed?". The throttle is correct, but the callback wakes 60 times/sec for a yes-no check. | low | Drive the trail sampling from a coarser `Timer` or use `timeline.cadence` to gate. |
| O9 | `Views/Player/VisualizerView.swift` `binduPosition` recomputed | Computed twice per frame — once at the top of the GeometryReader closure (`let bindu = binduPosition(...)`), and read inside the Canvas closure. The `let` makes it once-per-frame but a second compute could appear if anyone later moves logic around. | low | Capture once at top of TimelineView body and pass down. |
| O10 | `Models/Letter.swift` `lettersDirectory` | Static computed property that does `FileManager.fileExists` + `createDirectory` every access. Each `LetterRow` evaluating `letter.audioURL` triggers this chain. | low | Memoize via `static let` (set once in `+initialize` or on first access). |

### UX & polish

| # | File | Issue | Severity | Fix direction |
|---|---|---|---|---|
| O11 | `Stores/SettingsStore.swift` `gain` setter ↔ `Stores/DSPWireService.swift` `tick` | Setting gain in Settings immediately calls `BinauralEngine.updateGain`, but DSPWire's next tick (within 100 ms) overwrites with its own RMS-curve computation that re-multiplies by `SettingsStore.gain` — so the slider works, but the immediate write is redundant during playback. | low | When playback is active, let DSPWire be the sole writer; SettingsStore just stores the value. |
| O12 | `Views/Settings/SettingsView.swift` | Settings exposes "default duration" chips and a session-history "clear archive" button but no "clear audio cache" and no "refresh catalog" button. The catalog refresh path is opaque to the user. | low | Add cache size readout + clear; add "refresh catalog" with `loadError` surface. |
| O13 | `Stores/NowPlayingService.swift` `updateForLab` | Doesn't set `MPMediaItemPropertyPlaybackDuration`, so the lock screen shows no progress bar for Lab sessions. | low | Include duration (Lab is open-ended — pass a large sentinel or omit cleanly). |
| O14 | `Stores/NowPlayingService.swift` remote commands | All transport commands (play, pause, togglePlayPause, stop) map to the *stop* handler. The lock-screen play/pause button always stops audio. Users expecting "pause" lose all state. | low / medium | Wire pause to `BinauralEngine.updateGain(0)` (or implement true pause if BinauralListener is opened up later). |
| O15 | `Views/BinduBirthView.swift` | Sequenced via nested `DispatchQueue.main.asyncAfter` blocks. Works but reads as legacy. | low | Rewrite as `Task { await Task.sleep(...) ... }` chain. |
| O16 | `Views/Tabs/ArchiveView.swift` `SessionRow` | Doesn't display the new `Session.note` field. | low | Show note as a third line, or a "•" indicator that taps to a detail view. |
| O17 | `Stores/PlayerStore.swift` `play()` rapid retap of same track | A second tap on the same track during fetch starts a parallel download path, then both continuations call `TrackPlaybackService.play(...)` — the second tears down the first's audio and re-establishes. Audible bump. | low | Guard early on `currentTrack?.id == track.id && isLoadingTrack`. |
| O18 | `Stores/CatalogStore.swift` | Every launch hits the network. There's a UserDefaults cache but no "skip if fresh" check, no ETag, no last-fetched timestamp. | low | Add `lastRefreshedAt`; if <1 h old and `tracks` non-empty, skip the refresh. |
| O19 | `Stores/OracleService.swift` | No retry on transient errors (rate limit, 5xx). | low | Exponential backoff with 2 retries on 429/5xx. |

### Robustness

| # | File | Issue | Severity | Fix direction |
|---|---|---|---|---|
| O20 | `BinauralEngine.swift`, `BinauralListener.swift` | Audio session and engine errors are `NSLog`'d and the method returns silently. The app continues with no audio and no user-visible signal. | medium | Surface an audio-error state through an observable; show a banner in `RootView` when the engine fails. |
| O21 | `Stores/AudioCache.swift`, `Stores/PlayerStore.swift` | If `AudioCache.fetch` throws `.notFound` (bad URL, 404), `PlayerStore.play`'s catch arm falls through to *binaural-only* without telling the user the track is unavailable. Looks like the music silently disappeared. | medium | Surface fetch errors as a transient banner / toast inside `PlayerView`. |
| O22 | `Views/Tabs/FieldView.swift` central Bindu | Long-press to open Oracle is undiscoverable. No visual hint, no first-time tooltip. | low | One-time hint overlay, or pulse-on-hold animation. |
| O23 | `Models/Letter.swift`, `Stores/AudioCache.swift` | Force unwraps on `FileManager.default.urls(for:in:).first!`. Will crash if the system ever returns an empty array (sandboxed Documents missing). | low | Optional-chain or trap with a clear `fatalError` so crash logs are actionable. |
| O24 | `Views/Ritual/RitualSetupView.swift` | `ChakraData.all[chakraName]!` force unwrap. Defensive only — all 9 names are in the table — but the bang invites trouble if `ChakraName` ever grows. | low | `guard let` and skip; or make `ChakraData.all` total via `Dictionary` initializer that fatal-errors at startup. |
| O25 | `Stores/KeychainHelper.swift` | No `kSecAttrAccessible` attribute set. Defaults to `kSecAttrAccessibleWhenUnlocked` — fine for foreground, but background launches before unlock can't read the key. | low | Set `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. |

---

## 3. GAPS — Wiring designed but not finished

### Computed but unread / posted but unobserved

| # | File | Issue | Severity | Fix direction |
|---|---|---|---|---|
| G1 | `BinauralListener.swift` `spectrumSnapshot` | Bridged via `BinduDSPBridge.spectrumSnapshot` (returns 512-bin magnitude array). No caller. | low | Either consume in `VisualizerView` for a richer rendering, or drop the bridge method. |
| G2 | `BinauralListener.swift` `diagnostics()` / `BinauralEngine.swift` `diagnostics()` | Both define rich diag dictionaries (sample rate, current carrier, glide values, frames produced, session age). No caller. | low | Surface in a dev-only Settings row, or remove. |
| G3 | `BinauralListener.swift` `carrierDerivationTimer` | Declared as `private var ... Timer?`. Set nowhere; invalidated in `stopSession()`. The actual derivation uses `DispatchQueue.main.asyncAfter`. Dead state. | low | Delete the property and the `invalidate` line. |
| G4 | `BinauralListener.swift` `getCarrierProfile()` | Public bridge returning the derived carrier as a dict. The notification path is what's wired today; this accessor is unreferenced. | low | Pick the notification or the accessor; remove the unused one. |
| G5 | `Stores/AudioCache.swift` `purgeAll()` | Exists; no caller. | low | Wire to a "clear cache" row in Settings (see O12). |
| G6 | `Stores/SettingsStore.swift` `defaultSessionDuration` | After removing duration chips from `PlayerView` (commit `467bc68`), the only consumer is `SettingsView` itself (chip group). It's stored, surfaced in UI, never read by anything that matters. | low | Either delete (and the Settings row), or wire to Lab / Letter / Space sessions as a per-feature default. |
| G7 | `Models/Theme.swift` `ThemeData.dusk` / `ThemeData.mist` | Defined; never referenced. The Settings screen has no theme picker. | low | Build a theme picker (see O1), or delete the unused themes. |
| G8 | `Models/Track.swift` `youtubeID` | Decoded from Airtable; surfaced nowhere in the UI. | low | Either show a "watch on YouTube" affordance in the Player, or drop the field. |
| G9 | `Stores/NowPlayingService.swift` `pauseCommand` / `togglePlayPauseCommand` | Registered and enabled. Their handlers fire `stopHandler`, not a real pause. The user-visible affordance lies about what the button does. | low / medium | Either disable the commands or implement real pause. Today, leaving them as "stop in disguise" is misleading. |
| G10 | `Stores/DSPWireService.swift` `hasOnset` exposure | Set every tick from `frame["onsetFlag"]`. The flag persists across polls until DSP clears it. `VisualizerView` debounces with `lastOnsetEmittedAt`, but `DSPWireService` itself doesn't model "onset edge" — any external consumer would have to re-implement debouncing. | low | Make `hasOnset` a one-shot "edge" pulse; or expose `onsetCount` and let consumers diff. |

### Designed-for-but-not-built

| # | File | Issue | Severity | Fix direction |
|---|---|---|---|---|
| G11 | `Views/Tabs/ArchiveView.swift` | `Session.note` field exists; the row doesn't display it; no session detail view. The Integration Chamber writes notes that are then invisible. | medium | Add note display in `SessionRow`, or a tap-to-detail route. |
| G12 | `Stores/AirtableService.swift` ↔ `Stores/CatalogStore.swift` | No way to manually trigger a refresh from the UI. If Airtable updates and the cache hasn't expired, the user is stuck. | low | "Refresh catalog" row in Settings (see O12). |
| G13 | `BinauralListener.swift` carrier feedback loop end-to-end | Carrier derivation runs once per session at +10 s. `DSPWireService` applies it. But if the user plays a second track without ending the session in some flows (Field tab → Player → swipe down → tap another orb), `BinauralListener.stopSession()` is called from `TrackPlaybackService.play` indirectly, and a new derivation runs. The carrier-lock visual confirms each one. But the engine carrier is now derived from a *song*, while binaural beat values still come from Airtable's `carrierHz` field (which `PlayerStore` set at play time). Mixed sources of truth. | medium | Decide: Airtable `carrierHz` is a hint; derived carrier overrides. Or: Airtable is authoritative and the derived value is ignored. Document the choice. |
| G14 | `Stores/CatalogStore.swift` `loadError` | Surfaced in `FieldView` as a bottom overlay when tracks are empty. Not surfaced anywhere when the cache *has* tracks but the latest refresh failed — the user gets stale data with no signal. | low | Show a subtle "offline" indicator when `tracks` non-empty AND `loadError != nil`. |
| G15 | `Models/Track.swift` `chakra: ChakraName?` | Useful field — could drive a chakra-grouped Field filter, or a "chakra mode" overlay. Today nothing reads it for grouping or filtering; `PlayerStore` no longer reads it (carrier/beat come from Airtable directly). | low | Either build the chakra-grouped browse mode, or accept it as metadata for future use. |
| G16 | `Bindu_FieldApp.swift` | No `.onChange(of: scenePhase)` handler. When the app goes to background mid-track, engines keep running (correct, `audio` background mode is set), but on return there's no resync — the visualizer keeps drawing from stale DSP frames, etc. | low | Observe `scenePhase`; on `.active`, ensure `DSPWireService.startPolling()` is consistent with `TrackPlaybackService.isPlaying`. |
| G17 | `Stores/NowPlayingService.swift` `updateElapsed` | Defined but never called. The lock-screen progress bar never advances during playback. | medium | Drive from `TrackPlaybackService.elapsed` or `DSPWireService.tick`. |
| G18 | `Views/Player/PlayerView.swift` scrubber | Read-only by design (deferred until BinauralListener scope opens), but the affordance *looks* tappable. Users will try to scrub. | low | Either visually flatten it (slimmer, less prominent) or label "no scrub" with a serif annotation. |
| G19 | `BinauralEngine.swift` `updateAMDepth` | Public setter; no caller anywhere. AM depth is fixed at the static `amDepthTarget = 0.15`. | low | Wire to Settings or Lab, or document why it's fixed. |
| G20 | `Stores/DSPWireService.swift` `carrierLocked` | Visualized in `VisualizerView`. Not surfaced in the binaural pill or anywhere textual. A user who can't see the visual cue has no way to know derivation has happened. | low | Add a "carrier · derived" line in the expanded pill, or a one-time toast. |

### Tests, observability, dev affordances

| # | File | Issue | Severity | Fix direction |
|---|---|---|---|---|
| G21 | *project-wide* | No test target. `BinduDSP.cpp` is non-trivial real-time C++; `DSPWireService` has a critical gain curve; `AirtableService` has decoding. All untested. | medium | Add a unit test target. Start with `AirtableService` (deterministic JSON) and the gain curve. |
| G22 | *project-wide* | No structured logging. Everything uses `NSLog` or `print`. Hard to correlate when the engine misbehaves on device. | low | Adopt `os.Logger` with subsystem `com.bindufield`; tag categories (audio, dsp, catalog, oracle). |
| G23 | `Stores/DSPWireService.swift` | No diagnostic counters (frames consumed, gain updates per second, RMS distribution). Hard to verify the loop is actually doing work on device. | low | Expose counters; add a debug Settings panel. |
| G24 | `generate_bindu_icon.swift` (project root, not in target) | Standalone CG script for the app icon. Lives outside `Bindu Field/`; not run by any build phase. | low | Move under `Tools/`, add a README line explaining how to regenerate. |

---

## Summary

**Highest-priority fixes** (impact × likelihood, today's app, today's user):

1. **B4** — `.binduPlaybackComplete` fires on manual stop → Integration Chamber appears when the user just wanted to quit a track. Visible misbehavior on every cancel.
2. **B8** — `Session.completed` always recorded as `false`. The Archive is silently wrong about which sessions finished.
3. **B7** — Lab carrier slider does nothing mid-play. A user testing frequencies will be confused.
4. **B13** — `CatalogStore` empty-fetch wipes the cache. One bad Airtable response and the catalog is gone offline.
5. **G17** — Lock-screen progress bar never advances. Visible every time the user looks at the lock screen.

**Highest-priority gaps to close** (work already designed, just not wired):

1. **G11** — Display `Session.note` in the Archive (Integration Chamber writes vanish today).
2. **G13** — Make the carrier source of truth explicit (Airtable vs. derived).
3. **B1** — Audio session coordinator (eliminates the four-owner problem).
4. **B3** — Pre-allocate the mono buffer to the worst case (closes the latent realloc race).

**Lowest-cost cleanups** (dead code, single-file removals):

- `BinauralListener.carrierDerivationTimer` (G3), `purgeAll` (G5), `ThemeData.dusk`/`mist` (G7), `updateAMDepth` (G19), `getCarrierProfile`/`spectrumSnapshot`/`diagnostics` (G1, G2, G4).

Total: **18 bugs**, **25 opportunities**, **24 gaps** identified across 44 Swift files. None require touching `BinauralEngine.swift` or `BinauralListener.swift` to address the highest-priority items except B3, B4, and B7 (which all live inside the engine layer by definition).
