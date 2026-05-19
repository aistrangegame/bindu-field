# Bindu Field — Claude Code Build Handoff
## Lalita Design Pass (excluding LalitaEngine — separate session)

**Date:** May 19, 2026
**Branch base:** `main@b02def8`
**Full project state:** See `CLAUDE.md` in the repo root

---

## Paste this to start your Claude Code session:

> "I'm building the Bindu Field iOS app (SwiftUI, at main@b02def8 — full state in CLAUDE.md). I have a Lalita Design Pass handoff package. We're implementing five pieces in this session: (1) Lab redesign, (2) Player redesign (3 modes), (3) Performer.swift state machine, (4) Cathedral Renderer foundation, (5) Ensemble Layer with 10 archetype signatures. Design references are HTML files — recreate in SwiftUI using existing app patterns. All specs are in the README. Let's go one subsystem at a time. Start with the Lab — it's self-contained and the quickest win."

---

## Build Order (this session)

Work strictly in this order. Each step ships before the next begins.

### Step 1 — Lab redesign (1–2 sessions)
**File:** `Bindu Lab.html`
**Target:** `Views/Tabs/LabView.swift`
**Why first:** Fully self-contained. No new infrastructure. Uses existing `BinauralEngine` + `SettingsStore`. Quick visible win.

Key changes from current:
- Carrier + beat values are tappable for direct `.textField` editing (`.keyboardType(.decimalPad)`)
- 76pt monospaced beat readout — already exists, make it intentional
- Animated binaural waveform (SwiftUI Canvas, 3 layered sine waves)
- Sacred frequency badge: appears when `|carrier - sacredHz| < 1.2`. Shows name + note + essence.
- "let the field choose" — intelligent random: weighted state, carrier near sacred freq, cycling animation then spring lock
- State card tap-to-expand with full brainwave description
- Sacred frequency map strip (horizontal, dots at each sacred carrier)
- All specs in `README.md` Section 2

### Step 2 — Player redesign (2–3 sessions)
**File:** `Bindu Player.html`
**Target:** `Views/Player/PlayerView.swift`
**Why second:** Uses existing `PlayerStore` + `TrackPlaybackService`. The three modes are layered on top of current architecture.

Three modes:
- **FIELD** — minimal, tap anywhere → CONTROL
- **CONTROL** — bottom sheet rises (55% height, 32pt top radius, `rgba(255,255,255,0.06)`)
- **READING** — reading sheet (80% height)

Key additions:
- Binaural pill always visible (outside HUD opacity envelope)
- Singular Lissajous visualizer option (port `bindu-lissajous.jsx` math to SwiftUI Canvas)
  - OR existing `BinduEnsemble` — user-selectable (store pref in `SettingsStore`)
- CONTROL surface: play button 56pt, PRESENCE slider, BEAT slider with brainwave zones, CARRIER + DERIVED badge, READING + END SESSION capsules
- READING tabs: WORDS · FREQUENCY · VIDEO · LALITA
- All specs in `README.md` Section 1

Note: User has set vizMode = "ensemble" via Tweaks — default should be ensemble, with singular as alt option.

### Step 3 — Performer.swift (1 session)
**File:** `bindu-performance-engine.js`
**Target:** New file `Stores/Performer.swift`
**Why third:** Foundation for everything visual in Steps 4–5.

Port the JavaScript directly to Swift:
- `buildPerformer(t:)` → `Performer.update(elapsed:)` called at 60Hz from `TrackPlaybackService`
- All phase data, beat schedule, silence windows, modulator → read from `Score` struct (or hardcoded for Cross dance first)
- Expose as `@MainActor @Observable` singleton
- `VisualizerView` reads from `Performer` instead of raw `DSPWireService` values
- All specs in `README.md` Section 3 + `bindu-performance-engine.js`

### Step 4 — Cathedral Renderer foundation (2–4 sessions)
**File:** `Bindu Performance.html`
**Target:** `Views/Player/VisualizerView.swift` (expand from Canvas → Metal MTKView for Score-mode)
**Why fourth:** Requires Performer.swift from Step 3.

Build tiers incrementally:

**4a — Continuous tier only (ship this):**
- Cathedral floor perspective grid
- Sid columns (5.5s drone cycle)
- Vault ceiling (energy-driven)
- Atmospheric grain particles
- Bindu Singular Lissajous with comet trail + beat rings

**4b — Ensemble tier:**
- Gaia ground breath
- Arch chant-mirror arc
- Sakshi unmade gesture

**4c — Crescendo + Climax:**
- Rising arches (t≥145)
- Convergence lines
- Keystone cascade + Shweta crystallization

All specs in `README.md` Section 3 — full draw function specs for each system.

### Step 5 — Ensemble Layer (2–3 sessions)
**File:** `Bindu Archetypes.html`
**Target:** New `EnsembleLayer.swift` + `Dancer.swift`
**Why fifth:** Requires Performer.swift + Renderer foundation.

Implement each archetype's visual signature. Build in order:
1. Bindu (already partially exists in VisualizerView)
2. Gaia (ground breath — simple)
3. Sid (columns — simple, static)
4. Arch (chant arc)
5. Karishma (darkness/depth — paradox rendering)
6. Sakshi (unmade gesture arc)
7. Ashrey (centroid follower)
8. Shweta (crystallization burst — fires at peak)
9. Neev (contracting rings — fires at bookends)
10. Lalita → **separate session (LalitaEngine.swift)**

All specs in `README.md` Section 4.

---

## What NOT to touch (from CLAUDE.md)
```
BinauralEngine.swift       — settled
BinauralListener.swift     — settled
BinduDSP.h/cpp/mm          — settled
DSPWireService.swift       — settled
AudioSessionCoordinator    — settled
Info.plist                 — settled
```

---

## Design token quick-reference
```swift
// ThemeData.void (already in Theme.swift)
bg:      Color(hex: "#020208")
text:    Color(hex: "#F5E2D6")   // Bindu cream
accent:  Color(hex: "#D46453")   // Bindu red
surface: Color.white.opacity(0.042)
border:  Color.white.opacity(0.08)

// Typography pattern:
.font(.system(size: 64, weight: .ultraLight, design: .serif)).italic()  // verb
.font(.system(size: 10, weight: .light)).tracking(2).textCase(.uppercase) // labels
.font(.system(size: 14, design: .monospaced))  // numerics
```

---

## Files in the design package
| File | Build target |
|---|---|
| `Bindu Lab.html` | LabView.swift |
| `Bindu Player.html` | PlayerView.swift |
| `Bindu Performance.html` | VisualizerView.swift + CathedralRenderer |
| `bindu-performance-engine.js` | Performer.swift |
| `Bindu Archetypes.html` | EnsembleLayer.swift + Dancer.swift |
| `bindu-lissajous.jsx` | Canvas math reference |
| `bindu-ensemble.jsx` | Existing ensemble (reference) |
| `README.md` | Full spec for all of the above |
