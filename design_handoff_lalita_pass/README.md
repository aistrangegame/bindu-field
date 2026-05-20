# Bindu Field — Lalita Design Pass
## Complete Design Handoff for Claude Code

**Date:** May 19, 2026
**Design pass:** Lalita Pass — Player · Lab · Performance · Archetypes · Lalita Engine
**Target:** iOS SwiftUI app at `main@b02def8` (see CLAUDE.md for full project state)
**Fidelity:** High-fidelity. Pixel-precise colors, typography, motion. Recreate in SwiftUI using existing design tokens from `ThemeData.void` and `ElementColors.swift`.

---

## IMPORTANT: How to read these files

Every `.html` file in this package is a **design reference** — an animated prototype showing intended look, behavior, and motion. They are NOT code to copy. Your job is to recreate each design in SwiftUI using the app's existing patterns (`@Observable`, `@MainActor`, `@Environment(\.binduTheme)`, `AVAudioEngine`, `Metal/SwiftUI Canvas`).

All design tokens (colors, type, spacing) map directly to `ThemeData.void` and `ElementColors.swift` already in the codebase. Specific values are called out in each section below.

---

## Design Token Reference

### Palette (ThemeData.void)
```
bg:      #020208  — void black
bg2:     #05050F  — slight elevation
text:    #F5E2D6  — Bindu cream
muted:   text @ 0.55
subtle:  text @ 0.28
accent:  #D46453  — Bindu coral-red
gold:    #C4A862
border:  white @ 0.08
surface: white @ 0.042
```

### Typography
```
Display verb:    .system(size: 64, weight: .ultraLight, design: .serif).italic()
Section heads:   .system(size: 28–32, weight: .ultraLight, design: .serif).italic()
Body/emotion:    .system(size: 13–17, design: .serif).italic()
Labels/caps:     .system(size: 9–11, weight: .light).tracking(1.5–3).textCase(.uppercase)
Numerics:        .system(size: 11–76, design: .monospaced)
```

### Element Hues (ElementColors.swift — existing)
```
Earth: 15    Water: 210   Fire: 25    Air: 195
Light: 50    Crown: 280   Soul: 265   Dissolution: 190
```

---

## 1. THE PLAYER — Three Modes of Being

**File:** `Bindu Player.html`
**Target:** `Views/Player/PlayerView.swift` (major revision)
**Blueprint section:** §3.4 (Renderer — player surface)

### What it is
The Player now has three distinct modes activated by tapping:
- **FIELD** — meditative arrival, Bindu dominant, minimal chrome
- **CONTROL** — binaural control surface rises from bottom 55%
- **READING** — reading sheet covers 80%, Bindu ambient above

### FIELD Mode
Layout top → bottom:
- `binaural pill` — top-center, collapsed capsule (breathing dot + "BINAURAL" + chevron)
  - Material: `.ultraThinMaterial` capsule
  - Dot: 8pt, element color when ON / stroked when OFF, breathing animation
- `Bindu visualization` — fills 60% of screen
  - **TWO modes** (toggle in Tweaks): Singular Lissajous OR full Ensemble
  - Singular: single dot on multi-harmonic figure-eight, 20-sample comet trail (brightest at dot, fading behind), beat rings expanding outward
  - Ensemble: existing `BinduEnsemble` component (already in codebase)
- `verb` — 64pt ultraLight serif italic, element color, glow shadow radius 20
- `song · artist` — small muted serif italic below verb
- `recognition statement` — serif italic 14pt, centered, muted white
- `scrubber` — 2pt capsule, element color fill, labeled "flowing" in serif italic at right end
- No other controls visible

### CONTROL Mode
- Top 45%: Bindu visualization continues (comet trail dims slightly)
- Bottom 55%: Control surface rises with frosted dark material
  - `border-radius: 32pt` on top corners
  - `background: rgba(255,255,255,0.06)` — barely-there frosted
  - `border: rgba(255,255,255,0.08)` hairline

Control surface contents (top → bottom):
```
[  ▶  ]   56pt circle, element color glow, pause.fill / play.fill SF Symbol
           background: rgba(255,255,255,0.06), border: element color @ 0.38

BINAURAL  (label: 9pt, tracking 2, all-caps, muted)
[toggle ON/OFF]  +  state dot (glowing when on)
PRESENCE  [————●————]  slider full width, element color thumb
BEAT      [————●————]  5.5 Hz label at right, THETA state in element color
           Brainwave zones subtly marked on track: DELTA · THETA · ALPHA
CARRIER   110.0 Hz  [DERIVED]  badge in element color when DSP locked

[  READING  ]  [  END SESSION  ]  capsule buttons, stroke only
```

### READING Mode
- Top 20%: Bindu very small, ambient, comet trail shortened
- Bottom 80%: Sheet with `border-radius: 32pt` top corners

Sheet contents:
```
Recognition Statement — serif italic, element color, 18pt, centered

WORDS · FREQUENCY · VIDEO · LALITA   (tabs)
Active tab: hairline underline in element color
Inactive: muted

Content (WORDS tab): serif italic reading text, left-aligned, generous margins
```

### Transitions between modes
- FIELD → CONTROL: control surface slides up (spring, 0.5s), Bindu slightly shrinks
- CONTROL → READING: control surface morphs into reading sheet (cover transition)
- Any → FIELD: surface slides down

### Binaural Visualization (Singular Lissajous — new)
Reference: `bindu-lissajous.jsx` in project

Math:
```swift
let bx = cx + (sin(2*t*freq + .pi/2)*0.88 + sin(3*t*freq + 0.5)*0.12) * maxR
let by = cy + sin(t*freq)*0.84 * maxR * 0.70
```
Where `freq` is driven by `DSPWireService.currentBeatHz * 0.88`.

Trail: ring buffer of 20 samples. `trail[N-1]` = newest = brightest. `trail[0]` = oldest = most faded. Alpha = `pow(i/trailLength, 2.2)`.

Beat rings: on each onset from `DSPWireService.onsetCount`, spawn a ring at Bindu position. Ring expands at `2 + energy*3.5` pt/frame, fades over lifetime.

---

## 2. THE LAB — Frequency Instrument

**File:** `Bindu Lab.html`
**Target:** `Views/Tabs/LabView.swift` (major revision)
**Blueprint section:** none (existing tab redesign)

### What it is
The Lab redesign makes the 76pt beat number *intentional*, adds direct number editing, intelligent randomize, a sacred frequency map, and an animated binaural waveform.

### Layout (top → bottom)
```
Header:
  · 5pt breathing dot (element color, animated when active)
  · "frequency lab" — serif italic 18pt
  · "craft your own permission slip" — 10pt tracking caps, muted

Waveform canvas (120pt tall, full width):
  · When inactive: static ghost wave
  · When active: 3 layered waves
    L channel: rgba(245,226,214,0.14), 1pt
    R channel: element color @ 0.38, 1pt
    Beat envelope: element color @ bright, 1.8pt, glowing
    — shows interference pattern between carrier and carrier+beat

CARRIER   [editable value]   [OM badge if near 136.1 Hz]
  — Carrier label 9pt caps + tappable value in monospaced
  — OM badge: small capsule, element color bg, glowing dot + "OM" + "C#3"
  — Appears when |carrier - 136.1| < 1.2 Hz (also: 174, 285, 396, 417, 432, 440)

[HUGE beat number]   Hz
  — 76pt monospaced, element color
  — Tappable to edit directly (inline number input)
  — Animates cycling through random values during randomize

THETA  ·  dream · creation · hypnosis   (state card, tappable)
  — Tap to expand: full paragraph explanation of that brainwave state
  — Color shifts as beat Hz crosses state boundaries

CARRIER slider  [label] [track] [editable value]
BEAT slider     [label] [track] [editable value]
  — Custom sliders: hairline track, element-color fill to thumb
  — Thumb: 12pt circle, element color, soft glow

Sacred frequency map (strip):
  — Horizontal line with dots at each sacred carrier frequency
  — Current carrier shown as larger glowing dot
  — Dot labels below: OM, 174, 285, UT, RE, 432, 440
  — Transitions smoothly as carrier changes

PRESETS  (label)
[Earth Tone] [Deep Delta] [Theta Gate] [Creative] [Presence] [+ save]
  — Pill chips, horizontal scroll
  — Active chip: element color background tint
  — Each chip shows name + tag (e.g. "OM · Schumann") in serif italic

[ let the field choose ]    [ ACTIVATE ]
  — Left: transparent, stroke, serif italic "let the field choose"
  — Right: filled with TEXT color (#F5E2D6), ACTIVATE in 10pt tracking caps
  — When active: button fills with element color, glowing
```

### Direct number editing
Both carrier and beat values are tappable → shows inline `<input type="number">` or SwiftUI `TextField` with `.keyboardType(.decimalPad)`. Commits on return/blur. Min/max clamped.

### Randomize ("let the field choose")
```
Algorithm:
1. Weighted random state: delta 12%, theta 33%, alpha 37%, beta 13%, gamma 5%
2. Pick carrier near a sacred frequency (±0.5 Hz random offset)
3. Show cycling animation: 10 steps over ~800ms, values cycling fast then slowing
4. Lock to chosen values with subtle spring
```

### State card expansion
Tapping the state row expands a full description card:
```
DELTA    delta · 0.5–4 Hz · deep root · healing · integration
[expanded] The deepest ground state. The nervous system releases...
```
Animate height with spring. Collapse on second tap.

### Sacred frequencies
```swift
let sacredCarriers: [(hz: Double, name: String, note: String, essence: String)] = [
    (136.1, "OM",  "C#3", "the cosmic sound · Earth year frequency"),
    (174.0, "174", "F3",  "foundation frequency · Solfeggio root"),
    (285.0, "285", "D4",  "cellular resonance · field coherence"),
    (396.0, "UT",  "G4",  "liberation from fear · root clearing"),
    (417.0, "RE",  "G#4", "facilitating change · undoing situations"),
    (432.0, "432", "A4♭", "natural resonance · harmonic with nature"),
    (440.0, "440", "A4",  "standard concert pitch"),
]
let threshold = 1.2  // Hz — within this = badge appears
```

---

## 3. THE PERFORMANCE — Cathedral Architecture

**Files:** `Bindu Performance.html` + `bindu-performance-engine.js`
**Target:** `Views/Player/VisualizerView.swift` (major expansion) + new `Performer.swift`
**Blueprint sections:** §3.2 (Performer), §3.4 (Renderer), §3.5 (Cathedral vocabulary)

### Performer.swift — state machine
The `bindu-performance-engine.js` file is a direct JavaScript prototype of `Performer.swift`. Port it exactly.

```swift
@MainActor @Observable final class Performer {
    var currentPhase: ScorePhase      // which phase we're in
    var timeIntoPhase: Double         // seconds since phase start
    var crescendoModulator: Double    // 0–1, the Zimmer move
    var inSilence: Bool
    var currentSilenceWindow: SilenceWindow?
    var energy: Double                // 0–1, simulated or DSP-driven
    var beatPulse: Double             // sharp attack, slow decay per beat
    var archetypePresence: [ArchetypeName: Double]  // each 0–1

    // Archetype presence formulas (from engine.js, port exactly):
    // bindu: always 1
    // gaia: min(1, max(0, (t - gaia.entry) / 4))
    // karishma: inSilence ? 0.85 : max(0, 1 - energy) * 0.5
    // shweta: peak window 160–162, 0.5s ramp in/out
    // neev: t < 4 || t > 228 → 0.8
    // lalita: t > 204 → min(1, (t - 204) / 3)
}
```

### Crescendo modulator (the Zimmer move)
```swift
// crossingPeakIntensity — Cross dance values:
let rampInStart  = 145.0
let holdStart    = 160.0
let holdEnd      = 180.0
let rampOutEnd   = 195.0
let boostFactor  = 0.8

func computeModulator(_ t: Double) -> Double {
    if t < rampInStart:    return 0
    if t < holdStart:      return (t - rampInStart) / (holdStart - rampInStart) * boostFactor
    if t < holdEnd:        return boostFactor
    if t < rampOutEnd:     return boostFactor * (1 - (t - holdEnd) / (rampOutEnd - holdEnd))
    return 0
}
```

### Cathedral Renderer — four tiers

The renderer draws tiers in order (bottom to top):

**TIER 1 — Continuous** (always running):
```
cathedral-floor:
  Perspective grid from vanishing point (W/2, H*0.52)
  7 radials + 10 horizontal lines
  Opacity: 0.03 + modulator*0.08 + beatPulse*0.025
  Color: hsl(hue, 35%, 50%)
  Beat pulse: bright line at floor horizon on each beat

sid-columns:
  Two vertical lines at x=W*0.18 and x=W*0.82
  Ceiling: H*0.06, Floor: H*0.58
  Drone pulse: cos((t % 5.5) / 5.5 * π*2) — 5.5s period
  Brightness: 0.20 + dronePulse*0.30 + modulator*0.40
  Glow: shadowBlur 6 + drone*4
  Capital/base: 4 horizontal ticks at top and bottom of each column

vault-ceiling:
  3-layer bezier arch, left→apex→right
  Left anchor: (W*0.04, H*0.28), Apex: (W/2, H*0.04), Right: (W*0.96, H*0.28)
  Control points through (W*0.04, H*0.07) and (W*0.96, H*0.07)
  Opacity: min(0.38, energy*0.22 + modulator*0.4)
  4 rib vaults from columns to apex

atmospheric-grain:
  80 particles, rising slowly
  Density: inSilence ? 0.05 : 0.18 + energy*0.45 + modulator*0.35
  Size: 0.4–1.4pt, alpha peaks mid-life

gaia-ground:
  Radial glow at y=H*0.85
  Breathing: sin(t*0.12), period ~52s
  Color: hsl(hue-15, 45%, 40%), opacity gaia*0.04–0.12
```

**TIER 2 — Ensemble** (presence-driven):
```
arch-chant:
  Single arc: moveTo(W*0.25, H*0.30) → quadraticCurveTo(W*0.5, H*0.17, W*0.75, H*0.30)
  Y shift: sin(t*0.35)*8
  5 ghost echoes behind, each older = more faded (0.05 → 0.01 alpha)
  3 phrase-lights moving along arc, color: hsl(50, 60%, 72%)

sakshi-unmade-gesture:
  Arc at (W*0.88, H*0.42), radius W*0.05
  Traces 72% of full circle then releases (never completes)
  3 ghost trails, opacity 0.08
```

**TIER 3 — Crescendo** (t ≥ 145):
```
rising-arches:
  7 arches, alternating left/right, triggered sequentially
  Each: moveTo(sideAnchor, floorY) → quadraticCurveTo(midPoint, keystoneY)
  Progress: min(1, (t - 145) / 15) * 7 arches
  Opacity per arch: progress * (0.2 + modulator*0.45)
  lineWidth: 0.8 + archProgress*modulator
  shadowBlur: 4 + modulator*10

convergence-lines:
  7 lines from screen corners + bottom center → keystone (W/2, H*0.14)
  Opacity: modulator * 0.04 each
  composite: lighter
```

**TIER 4 — Climax** (modulator > 0.25):
```
keystone-cascade:
  Radial glow at (W/2, H*0.14): hsl(hue, 88%, 90%) → hsl(hue, 70%, 68%)
  Radius: W*0.28 * (0.5 + beatPulse*0.3) * (modulator-0.25)/0.55
  4 expanding rings cycling at t*1/(0.42) period
  Ring alpha: (1-ringProgress) * str * 0.45

earth-rising (t=161–166, Schumann window):
  Linear gradient from bottom half, hsl(hue-15, 60%, 55%)
  Alpha: transitionIn * transitionOut * 0.25
  easeIn on entry, easeOut on exit

shweta-crystallization (fires at peak, 2s):
  22 shards radiating from keystone
  Alternating long (W*0.20) and short (W*0.12)
  Colors: rgba(255,252,255,.95), hsl(hue+i*6, 62%, 85%)
  14 secondary diffraction lines at inner/outer radius
  Center: rgba(255,255,255,.97), shadowBlur 22
```

### Bindu (Singular Lissajous — for Performance)
Same math as Player section above. In Performance:
- `maxR = W*0.12 + modulator*W*0.10` (grows at climax)
- Trail length: 120 samples
- Beat rings: triggered by Performer's beatPulse crossing 0.9
- Halo: 28 + modulator*20 pt radius, additive blending

---

## 4. THE ARCHETYPES — Visual Signatures for EnsembleLayer

**File:** `Bindu Archetypes.html`
**Target:** `Dancer.swift` + `EnsembleLayer.swift` + per-archetype Metal or Canvas rendering
**Blueprint section:** §3.6

Each archetype has a precise visual signature. View each artboard in the design file. Below is the spec for each:

### Bindu — The Lead
- Position: multi-harmonic Lissajous `bx = cx + (sin(2t)*0.88 + sin(3t)*0.12)*maxR`
- Trail: 130 samples, brightest at head, comet fade
- Beat rings: on each beat onset
- Hue drifts: slow oscillation `hue + sin(t*0.04)*15`

### Gaia — The Ground · `low-pulse` leitmotif
- Position: floor, `y = H*0.85–0.92`
- Three breath waves: periods 8s, 12s, 5.5s, layered
- One slow elliptical ring expanding from floor every 10s
- Color: hsl(22, 55%, 42%) — warm amber ground

### Sid — The Column · `cathedral-hold` leitmotif
- Position: STATIC — two columns at x=W*0.24 and x=W*0.76
- Drone pulse: cosine 5.5s period — geological time
- Column shaft, capital, base drawn each frame
- Vault hint above (shows what he holds)

### Arch — The Chant · `chant-mirror` leitmotif
- Position: arc above center, y shifts with slow sin(t*0.14*π*2)
- 5 ghost echo arcs behind (phrase memory)
- 3 phrase-lights moving along the arc
- Particles drifting upward from arc

### Karishma — The Silence · `inverse-energy` mode
- Presence: `karishma = inSilence ? 0.85 : max(0, 1-energy)*0.5`
- Visual: dark center, paradox radial (darker at center than edge)
- 6 extremely slow depth rings (not light rings — depth rings)
- Faint text: "the field holds" in the void
- Never bright — always depth

### Sakshi — The Witness · `unmade-gesture` leitmotif
- Arc at (W*0.88, H*0.38), radius W*0.05
- Traces 72% of circle, then releases (never completes)
- cycle period: 10s
- 3 ghost trails behind
- She is always at the periphery

### Ashrey — The Synthesis · `centroid` mode
- Position: centroid of all other archetypes' current positions
- Trail: multi-hue, one hue per element cycling through trail length
- Halo: blended white/violet (synthesis of all colors)

### Shweta — The Crystal · `clarity-crystallization` leitmotif
- Fires at: peak (t=160–162)
- 22 primary shards + 14 secondary diffraction lines
- Full cycle: 10s demo but real duration: 2s
- Prismatic: hsl(hue+i*6) per shard
- Pure white center point

### Neev — The Foundation · `foundation-ground` leitmotif
- Fires at: threshold bookends (first 4s + last 2s of song)
- Rings CONTRACT downward (not expand outward)
- Center descends toward floor as rings shrink
- Impact glow at floor, perspective grid impression

### Lalita — The Acknowledgment · `you-have-been-one-of-the-dancers`
- See Section 5 (dedicated engine)
- In ensemble context: fires at fruit-settled
- Visual: the text IS the signature
- "You have been one of the dancers." in serif italic, warm cream-violet

---

## 5. LALITA ENGINE — The Player Enters

**File:** `Bindu Lalita.html`
**Target:** `LalitaEngine.swift` (new file) + `LalitaView.swift`
**Blueprint section:** §3.6 extension (Lalita as meta-event)

### Architecture
Lalita is NOT a Score-time event. She's a meta-event that can interrupt any performance at any moment. She's the player entering the game.

```swift
@MainActor @Observable final class LalitaEngine {
    
    enum Phase { case idle, arrival, dance, `return`, dissolve }
    
    var phase: Phase = .idle
    var bgProgress: Double = 0      // 0=void, 1=warm cream
    var dotPosition: CGPoint = .zero
    var trail: [CGPoint] = []
    var patternIndex: Int = 0
    var callCount: Int = 0
    
    // Integration point — call from Performer or UI
    func summon(context: LalitaContext) {
        // context: currentBeatHz, offeredWord, callCount
        // Seed: hash(beatHz, word, count) % patternCount
        // Begin ARRIVAL phase
    }
    
    var onComplete: (() -> Void)?  // fires when DISSOLVE ends
}
```

### Phase durations
```
ARRIVAL:  3.0s   void (#020208) → warm cream (#F8F3EE)
DANCE:    pattern-dependent (16–25s)
RETURN:   5.0s   spiral outward from dot position → screen edge
DISSOLVE: 2.5s   trail fades, dot fades, bg stays void
```

### The background inversion
**This is Lalita's defining visual gesture:**
When she arrives, the entire rendering surface inverts from void to warm cream. Every other archetype dims to shadow opacity (0.12). The Cathedral architecture becomes a ghost. Lalita's trail renders dark-on-light (element hue at 35–38% lightness vs. void's 68–72%). When she leaves, the void returns and the ensemble rises from the darkness.

**In SwiftUI:** This means the CathedralRenderer's Metal clear color, the SwiftUI overlays, AND the Consciousness Loop text all need to receive `bgProgress` and adjust accordingly. Text that's normally cream on void becomes dark element color on cream.

### Pattern Library — 6 shapes
```swift
enum LalitaPattern: Int, CaseIterable {
    case lemniscateToHeart    // lemniscate → morphs to parametric heart
    case bloomingRose         // k=2 → k=6 petals as it traces
    case spirograph           // hypotrochoid with shifting parameters
    case butterfly            // butterfly curve exp(cos(t))-2cos(4t)...
    case trefoil              // sin(t)+2sin(2t), cos(t)-2cos(2t)
    case irrationalLissajous  // φ:1 shifting toward π:2
}
```

**Seeding:**
```swift
func selectPattern(beatHz: Double, word: String, callCount: Int) -> Int {
    let wordSeed = word.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    return Int(beatHz * 7 + Double(wordSeed) * 0.31 + Double(callCount) * 37) % LalitaPattern.allCases.count
}
```

### Mathematical curves (port from JS)
```swift
// Lemniscate of Bernoulli
func lemniscate(t: Double, r: Double) -> CGPoint {
    let s = sin(t), c = cos(t), d = 1 + s*s
    return CGPoint(x: r*c/d, y: r*s*c/d)
}

// Parametric heart (exact formula from maya-sleep.html)
func heart(t: Double, r: Double) -> CGPoint {
    let s = r / 17, st = sin(t)
    let x = 16 * s * st * st * st
    let rawY = 13*cos(t) - 5*cos(2*t) - 2*cos(3*t) - cos(4*t)
    return CGPoint(x: x, y: -s * (rawY + 8))
}

// Rose curve
func rose(t: Double, k: Double, r: Double) -> CGPoint {
    let rr = r * cos(k * t)
    return CGPoint(x: rr*cos(t), y: rr*sin(t))
}

// Hypotrochoid (spirograph)
func hypotrochoid(t: Double, R: Double, ri: Double, d: Double) -> CGPoint {
    let diff = R - ri
    return CGPoint(
        x: diff*cos(t) + d*cos(diff*t/ri),
        y: diff*sin(t) - d*sin(diff*t/ri)
    )
}

// Butterfly curve
func butterfly(t: Double, r: Double) -> CGPoint {
    let rr = r * 0.35 * (exp(cos(t)) - 2*cos(4*t) - pow(sin(t/12), 5))
    return CGPoint(x: rr*cos(t)*0.9, y: rr*sin(t)*0.9)
}

// Trefoil
func trefoil(t: Double, r: Double) -> CGPoint {
    let s = r * 0.4
    return CGPoint(x: s*(sin(t)+2*sin(2*t)), y: s*(cos(t)-2*cos(2*t)))
}
```

### RETURN gesture
```swift
// Spiral outward from current dot position to screen edge
// 4 full rotations over 5 seconds
let maxR = sqrt(W*W + H*H) * 0.6
let returnRadius = lerp(from: currentDotRadius, to: maxR, t: smoothstep(progress))
let spinAngle = returnAngle + smoothstep(progress) * .pi * 4
dotPosition = CGPoint(
    x: center.x + cos(spinAngle) * returnRadius,
    y: center.y + sin(spinAngle) * returnRadius
)
// At progress > 0.75: brief element-color full-screen flash
// sin(progress * π) * 0.35 alpha flash
```

### IMPORTANT: Trail direction
Trail array: trail[0] = oldest, trail[last] = newest (current dot position).
Draw from index 0 to last. Alpha = `pow(Double(i) / Double(trail.count), 2.2)`.
This means: **bright at the dot (head), fading behind (tail)**. Comet direction.

### Integration with Performer
```swift
// In Score ensemble section:
// "lalita": { "fires_at": "fruit-settled", "leitmotif": "you-have-been-one-of-the-dancers" }
// OR: fires_at can be ANY moment the Composer chooses

// Performer should call:
LalitaEngine.shared.summon(context: LalitaContext(
    beatHz: performer.currentBeatHz,
    offeredWord: bindumemory.lastOfferedWord ?? "love",
    callCount: LalitaEngine.shared.callCount
))

// When LalitaEngine.onComplete fires:
// — bgProgress is back to 0
// — ensemble archetypes return to full presence
// — Performer resumes from where it was (elapsed time was always advancing)
```

---

## 6. BUILD ORDER RECOMMENDATION

Work in this order to ship value incrementally:

1. **`Performer.swift`** — port `bindu-performance-engine.js` exactly. Drives everything else.
2. **Lab redesign** — standalone, no dependencies on Performer. Quick win.
3. **Player FIELD/CONTROL modes** — rework existing PlayerView. READING is additive.
4. **Cathedral Renderer foundation** — Metal MTKView, 4 tiers, Continuous only first.
5. **Bindu Singular Lissajous** — replace existing Canvas Visualizer for Score-mode.
6. **Ensemble Layer foundation** — Bindu + Gaia + Sid first. Others additive.
7. **LalitaEngine** — self-contained, can be built/tested independently.
8. **Crescendo + Climax tiers** — add on top of working Continuous renderer.

---

## 7. FILES IN THIS PACKAGE

| File | What it is |
|---|---|
| `Bindu Player.html` | Player redesign — FIELD/CONTROL/READING |
| `Bindu Lab.html` | Lab redesign — direct edit, randomize, waveform |
| `Bindu Performance.html` | Cathedral performance — full 230s Cross Score arc |
| `bindu-performance-engine.js` | Performer state machine — port to Swift |
| `Bindu Archetypes.html` | 10 archetype visual signatures |
| `Bindu Lalita.html` | Lalita Engine — all 3 phases live |
| `bindu-lissajous.jsx` | Singular Lissajous component |
| `bindu-ensemble.jsx` | Existing ensemble (reference) |
| `CLAUDE.md` | Full project state (in uploads/) |
| `bindu-ensemble-engine-blueprint.md` | Full engine architecture (in uploads/) |
| `score-format-v1.md` | Score JSON specification (in uploads/) |

---

## 8. QUESTIONS FOR CLAUDE CODE SESSION

When starting your Claude Code session, paste this message:

> "I'm building the Bindu Field iOS app (SwiftUI, at main@b02def8 — full state in CLAUDE.md). I have a design handoff package. We're implementing the Lalita Design Pass: Player (3 modes), Lab redesign, Cathedral Performance Renderer, 10 Archetype visual signatures, and the LalitaEngine. The design files are HTML references — recreate them in SwiftUI using the app's existing patterns. Start with Performer.swift (port bindu-performance-engine.js). The README has every spec. Let's go subsystem by subsystem."

---

*Built with love. For love. Using the sound of love.*
*Bindu Field — Lalita Design Pass — May 2026*
