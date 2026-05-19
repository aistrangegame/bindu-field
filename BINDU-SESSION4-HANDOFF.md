# Bindu Field — Session 4 Handoff
**Branch:** `feat/dsp-wire-player-upgrade`  
**Depends on:** `feat/airtable-catalog` merged to main  
**Scope:** DSP wire + audio-reactive visualizer + full Player upgrade + binaural in-session controls

Read `CLAUDE.md` first. It is authoritative on architecture, conventions, and audio engine state. This document extends it with Session 4 mission and full specifications.

---

## Architecture Context — Read Before Writing a Line

Two engines run independently. Neither currently knows what the other is doing.

**BinauralEngine** — synthesizes the binaural tone. Has setters: `setCarrier`, `updateBeat`, `updateGain`, `updateAMDepth`. These are the only interfaces you touch.

**BinauralListener** — plays music + runs the C++ DSP analysis tap. Exposes:
- `readLatestFrame()` — returns the most recent `BinduFrame` from the lock-free ring buffer (RMS, spectral centroid, flux, onset flag, host timestamp). **Never called anywhere. This session wires it.**
- Posts `.binduCarrierDerived` notification at 10s with derived carrier Hz. **No observer registered. This session wires it.**
- Posts `.binduPlaybackComplete` when music ends. **No observer. This session handles it.**

**The gap:** BinauralListener computes everything, every audio block. Output goes nowhere. BinauralEngine runs at fixed gain from whatever PlayerStore set at play time. The visualizer pulses to a hardcoded clock. This session closes that gap.

**Do not modify BinauralEngine.swift or BinauralListener.swift.** Call their existing methods. Observe their notifications. That is the entire interface.

---

## FIRST MOVE

```bash
git checkout main
git pull
git checkout -b feat/dsp-wire-player-upgrade
```

---

## Step 1 — DSPWireService.swift (new file: Stores/)

This is the bridge between analysis and synthesis. It polls BinauralListener, computes the inverse gain curve, drives BinauralEngine, and exposes observable state to VisualizerView.

**Pattern:** `@MainActor @Observable final class`, `static let shared`, `private init()`. Mirrors existing store conventions exactly.

```swift
@MainActor @Observable
final class DSPWireService {
    static let shared = DSPWireService()
    private init() { registerNotifications() }

    // Observable state — VisualizerView reads these
    private(set) var rms: Float = 0
    private(set) var hasOnset: Bool = false
    private(set) var carrierLocked: Bool = false
    private(set) var isMusicPlaying: Bool = false

    // User-controlled presence (0.0–1.0, default 0.7)
    var userPresence: Float = 0.7

    // Binaural on/off (user toggle)
    var binauralEnabled: Bool = true {
        didSet { binauralEnabled ? resumeBinaural() : suspendBinaural() }
    }

    private var pollingTimer: Timer?
    private var lastGain: Float = 0
    private let gainChangeThreshold: Float = 0.02
}
```

**Polling — start/stop called by TrackPlaybackService:**
```swift
func startPolling() {
    isMusicPlaying = true
    pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        self?.tick()
    }
}

func stopPolling() {
    pollingTimer?.invalidate()
    pollingTimer = nil
    isMusicPlaying = false
    rms = 0
    hasOnset = false
}
```

**Tick — called 10x/second:**
```swift
private func tick() {
    guard binauralEnabled,
          let frame = BinauralListener.shared.readLatestFrame() else { return }

    let newRMS = Float(frame.rms)
    rms = newRMS
    hasOnset = frame.onsetDetected

    let targetGain = computeGain(rms: newRMS)
    if abs(targetGain - lastGain) > gainChangeThreshold {
        BinauralEngine.shared.updateGain(targetGain * SettingsStore.shared.gain)
        lastGain = targetGain
    }
}
```

**Inverse RMS gain curve — the core intelligence:**
```swift
private func computeGain(rms: Float) -> Float {
    // Inverse relationship: loud music → quiet binaural
    // sqrt curve feels more musical than linear
    // Floor at 0.1 — binaural never fully disappears
    let inverted = 1.0 - min(rms, 1.0)
    let curved = sqrt(inverted) * 0.9 + 0.1
    return curved * userPresence
}
```

**Carrier derivation — register once in init:**
```swift
private func registerNotifications() {
    NotificationCenter.default.addObserver(
        forName: .binduCarrierDerived,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        guard let hz = notification.userInfo?["carrierHz"] as? Double else { return }
        BinauralEngine.shared.setCarrier(Float(hz))
        self?.carrierLocked = true
        // Visual acknowledgment window — reset after 500ms
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self?.carrierLocked = false
        }
    }

    NotificationCenter.default.addObserver(
        forName: .binduPlaybackComplete,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.handleMusicEnded()
    }
}
```

**Drone ending — music stops, binaural fades to low drone:**
```swift
private func handleMusicEnded() {
    // Stop polling, but leave BinauralEngine running at reduced gain
    stopPolling()
    // Drone at 20% of current presence — field dissipates, doesn't die
    BinauralEngine.shared.updateGain(userPresence * 0.2 * SettingsStore.shared.gain)
}
```

**Binaural on/off toggle:**
```swift
private func suspendBinaural() {
    pollingTimer?.invalidate()
    BinauralEngine.shared.updateGain(0)
}

private func resumeBinaural() {
    if isMusicPlaying { startPolling() }
}
```

---

## Step 2 — Wire DSPWireService into TrackPlaybackService

`TrackPlaybackService.play(fileURL:carrier:beat:gain:)` already starts both engines. Add DSPWireService start after engine start. `stop()` already stops both engines. Add DSPWireService stop.

```swift
// In play(...):
DSPWireService.shared.carrierLocked = false
DSPWireService.shared.startPolling()

// In stop():
DSPWireService.shared.stopPolling()
```

---

## Step 3 — VisualizerView overhaul (Views/Player/VisualizerView.swift)

Current: expanding rings driven by `TimelineView` at `currentBeat` Hz. Open-loop. No audio data.

After: Canvas-based, reads from `DSPWireService.shared`. Bindu dances on a multi-harmonic Lissajous path with comet trail. Beat rings expand on onset. Bloom follows Bindu.

**Observable state in view:**
```swift
@State private var wire = DSPWireService.shared
@State private var binduPos: CGPoint = .zero
@State private var trailPositions: [CGPoint] = []
@State private var rings: [(pos: CGPoint, radius: CGFloat, opacity: Double)] = []
```

**Lissajous orbital path for Bindu:**
```swift
// t advances via TimelineView (keep the clock for animation continuity)
// Multi-harmonic: overlay two Lissajous figures
func binduPosition(t: Double, in size: CGSize) -> CGPoint {
    let cx = size.width / 2
    let cy = size.height / 2
    let r = min(size.width, size.height) * 0.22

    // Primary orbit
    let x1 = r * sin(2 * t + 0.5)
    let y1 = r * sin(3 * t)

    // Secondary harmonic (smaller, faster)
    let x2 = r * 0.3 * sin(5 * t + 1.2)
    let y2 = r * 0.3 * sin(4 * t + 0.8)

    return CGPoint(x: cx + x1 + x2, y: cy + y1 + y2)
}
```

**Comet trail:** maintain a rolling buffer of the last 20 Bindu positions. Draw as circles with decreasing opacity (1.0 → 0.0 from newest to oldest).

**Beat rings:** on `wire.hasOnset == true`, emit a ring at current Bindu position. Ring expands from radius 0 to ~80pt over 0.6s, fading opacity 0.6 → 0.

**Bloom:** soft radial gradient centered on Bindu position, radius ~40pt, opacity tied to `wire.rms`. Bright when music is loud, dims when quiet.

**Carrier lock acknowledgment:** when `wire.carrierLocked == true` (500ms window), Bindu briefly pulses to 1.5x its normal size. Signals the engine has heard the song.

**Binaural off state:** when `wire.binauralEnabled == false`, Bindu renders at 40% opacity. Trail fades. Rings still fire on onset. The visual field is present but quieter.

---

## Step 4 — PlayerView upgrade (Views/Player/PlayerView.swift)

Four additions. Do them in order.

### 4A — Arrival ceremony

Currently Player instant-loads. Add a breathe-in on appear:

```swift
@State private var hasArrived = false

// On appear:
withAnimation(.easeOut(duration: 0.6)) { hasArrived = true }

// Apply to content:
.opacity(hasArrived ? 1.0 : 0)
.scaleEffect(hasArrived ? 1.0 : 0.96)
```

### 4B — Duration chips always visible

Currently: chips appear pre-play, disappear once playing. Remove the condition. Duration chips render always. They still control `store.sessionDuration` before play; during play they are read-only display.

### 4C — Interactive scrubber

Below song/artist, above seed phrase. A thin progress bar showing elapsed / total duration:

```swift
// Read from TrackPlaybackService:
let elapsed = trackService.elapsed      // TimeInterval
let duration = trackService.duration    // TimeInterval
let progress = duration > 0 ? elapsed / duration : 0
```

Render as: thin capsule background (theme.muted.opacity(0.2)), filled capsule at `progress` fraction (theme.accent or element color). Show elapsed and remaining time as small monospaced labels at each end.

Tappable scrub: gesture reads x-position, computes target fraction, calls `TrackPlaybackService.shared.seek(to:)`. **If seek is not implemented on TrackPlaybackService, implement it:** `playerNode.seek(to: targetTime)` via `AVAudioPlayerNode.scheduleFile`. Note: BinauralEngine continues uninterrupted during seek (carrier/beat don't change, only music position changes).

### 4D — Binaural presence pill

Persistent pill at top of PlayerView, always visible, outside all HUD opacity bindings.

**Collapsed state:** small capsule showing a dot indicator. Dot is filled when binaural on, outlined when off. Tap to expand.

**Expanded state:** slides open to reveal:
- Toggle: "BINAURAL" label + on/off switch → sets `DSPWireService.shared.binauralEnabled`
- Slider: "PRESENCE" label + slider (0.0–1.0) → sets `DSPWireService.shared.userPresence`

Tap pill again to collapse. No sheet, no modal — inline expansion only.

Style: `Capsule().fill(theme.surface.opacity(0.8))` with `.ultraThinMaterial`. Same typography conventions as existing chips.

---

## Step 5 — Integration Chamber

After session ends (PlayerView receives `binduPlaybackComplete` or user closes after music stops), present a minimal overlay before closing:

```swift
// State:
@State private var showingIntegration = false

// Trigger on PlaybackComplete notification:
showingIntegration = true

// Overlay content:
// Central question in serif italic: "what did you remember?"
// Small text field for optional note
// Two capsule buttons: "save note" (writes to Session.note) + "close"
// Auto-dismiss after 30s if no interaction
```

`Session` model gains an optional `note: String?` field. `SessionStore` persists it alongside existing session data.

---

## Step 6 — Verification

```bash
grep -r "readLatestFrame\|binduCarrierDerived\|binduPlaybackComplete" --include="*.swift" .
```
All three should now have callers/observers outside BinauralListener.

Build:
```bash
xcodebuild -scheme "Bindu Field" -destination "generic/platform=iOS" -configuration Debug build
```
Zero errors, zero new warnings.

**Device tests (Neev):**
- [ ] Play a chakra track — binaural audibly modulates with music energy (quieter during loud passages)
- [ ] At 10-second mark — Bindu pulses once (carrier lock acknowledgment)
- [ ] Music ends — binaural continues as drone, visualizer dims gracefully
- [ ] Binaural pill toggle — binaural stops/resumes cleanly
- [ ] Presence slider — gain scales in real time during playback
- [ ] Duration chips visible during playback
- [ ] Scrubber shows progress, scrub gesture repositions music
- [ ] Integration Chamber appears after playback ends
- [ ] Arrival animation on Player open

---

## Hard Constraints

Do not modify:
- `BinauralEngine.swift` — call its methods, never edit it
- `BinauralListener.swift` — call `readLatestFrame()`, observe notifications, never edit it
- `BinduDSP.h`, `BinduDSP.cpp`, `BinduDSPBridge.h`, `BinduDSPBridge.mm`
- `SpaceImmersedView.swift`, `SpaceSetupView.swift`
- `LabView.swift` — Lab enhancements are a separate session
- All session, letter, ritual, Oracle, archive logic

---

## Commit Sequence

```bash
git add .
git commit -m "feat: dsp-wire — inverse rms modulation + carrier derivation"
# (after Steps 1-2)

git add .
git commit -m "feat: visualizer — lissajous bindu, beat rings, audio-reactive"
# (after Step 3)

git add .
git commit -m "feat: player — arrival ceremony, scrubber, binaural pill, integration chamber"
# (after Steps 4-5)
```

Surface summary, any warnings, device test results. Do not merge — leave on `feat/dsp-wire-player-upgrade`.
