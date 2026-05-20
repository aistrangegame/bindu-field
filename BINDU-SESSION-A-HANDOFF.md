# Bindu Field — Session A Handoff
**Branch:** `feat/session-a` off main
**Scope:** Functional fixes · Visual fidelity · Element Vocabularies · Tab Icons
**Design references:** `design_handoff_lalita_pass/Bindu_Vocabularies.html` · `Bindu_Tab_Icons.html`

Read `CLAUDE.md` fully before starting. State your complete plan before touching any file.

---

## PHASE 0 — Prerequisites
```bash
git checkout main && git checkout -b feat/session-a
```

---

## PHASE 1 — Functional Regressions
**Commit:** `fix: functional regressions — lab sliders, player close`

### Fix 1A — Lab sliders not applying to engine

The LabView redesign (Lalita Pass Phase 1) built custom visual sliders. Diagnose whether the carrier and beat slider values are actually being applied to `BinauralEngine` during playback.

Test: With binaural playing in Lab (`store.isPlaying == true`), moving the carrier slider must audibly change the frequency. If it does not:

Find every `Slider` or custom slider gesture in `LabView.swift` that controls `store.carrier` or `store.beat`. Verify each has a `.onChange` or binding that calls:
```swift
if store.isPlaying {
    store.setCarrier(store.carrier)
    store.setBeat(store.beat)
}
```
If the custom visual slider thumb position is bound to a local `@State` variable instead of directly to `store.carrier`, the engine never hears changes. Fix the binding to go directly to the store property and trigger the engine call.

### Fix 1B — Player always-accessible close

In FIELD mode, there is no way to close the Player without first tapping to enter CONTROL mode. Add:

**Swipe-down gesture** on the FIELD mode area:
```swift
.gesture(
    DragGesture(minimumDistance: 40)
        .onEnded { value in
            if value.translation.height > 60 && mode == .field {
                store.closePlayer()
            }
        }
)
```

**Small close indicator** in FIELD mode — top trailing corner, outside binaural pill:
```swift
// In FIELD mode overlay, top-right:
VStack {
    HStack {
        Spacer()
        Button(action: { store.closePlayer() }) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(theme.subtle)
                .frame(width: 36, height: 36)
        }
        .padding(.top, 52)
        .padding(.trailing, 16)
    }
    Spacer()
}
```

This is visible in all three modes (FIELD/CONTROL/READING) — always an escape.

---

## PHASE 2 — Visual Fidelity Fixes
**Commit:** `fix: visual fidelity — sheets, verb, recognition, weights`

These are the HIGH and MEDIUM impact items from the fidelity report.

### Fix 2A — Sheet backgrounds (HIGH)

Both CONTROL and READING sheets use `.ultraThinMaterial` which is far too translucent. Design: near-opaque dark panels.

```swift
// CONTROL sheet background — replace current fill:
Color(red: 5/255, green: 5/255, blue: 16/255)
    .opacity(0.97)
    .background(.ultraThinMaterial.opacity(0.25))

// READING sheet background:
Color(red: 5/255, green: 5/255, blue: 15/255)
    .opacity(0.98)
    .background(.ultraThinMaterial.opacity(0.2))
```

### Fix 2B — Recognition statement (HIGH)

```swift
// Change from:
theme.text.opacity(0.65)
// To:
theme.text.opacity(0.12)
```

The recognition statement is an atmospheric whisper. At 0.12 it sits behind the verb. At 0.65 it competes with it.

### Fix 2C — Verb shadow (HIGH)

```swift
// Replace single shadow with two-layer stack:
Text(track.verb)
    .shadow(color: elementColor.opacity(0.28), radius: 24)
    .shadow(color: elementColor.opacity(0.10), radius: 50)
```

### Fix 2D — Remove background radial gradient (HIGH)

The FIELD mode adds `elementColor.opacity(0.14)` centered RadialGradient. Design has flat `#020208`. Remove it entirely. The vocabulary renderer provides all atmospheric color.

### Fix 2E — Font weights (MEDIUM)

```swift
// Verb: .ultraLight → .light
.font(.system(size: 62, weight: .light, design: .serif))

// Lab 76pt beat readout: .ultraLight → .light
.font(.system(size: 76, weight: .light, design: .monospaced))
```

CSS `font-weight: 300` is `.light` in SwiftUI, not `.ultraLight` (~100).

### Fix 2F — Content vertical position (MEDIUM)

```swift
// Change from 0.56 to 0.59:
.padding(.top, geo.size.height * 0.59)
```

### Fix 2G — Toggle row dot layout (MEDIUM)

```swift
// Remove Spacer() between ON label and dot:
HStack(spacing: 8) {
    // toggle
    // ON/OFF label
    // breathing dot — immediately after label, no spacer
}
// Spacer() after the whole group
```

### Fix 2H — Breathing dot animation rate (MEDIUM)

```swift
// Control sheet dot: was 2.0s autoreverses = 4s total cycle
// Design is 2s total. Fix:
.animation(
    .easeInOut(duration: 1.0)  // 1.0 * 2 (autoreverses) = 2s cycle
    .repeatForever(autoreverses: true),
    value: ctrlDotBreathePhase
)
// Also fix scale: 1.15 → 1.25
```

### Fix 2I — Reading line spacing (MEDIUM)

```swift
// WORDS and LALITA content: lineSpacing(6) → lineSpacing(12)
// Design lineHeight: 1.82 at 15pt ≈ 12pt effective gap
```

### Fix 2J — Reading hairline rule (MEDIUM)

```swift
// Between recognition statement and tab bar in reading sheet:
Rectangle()
    .fill(Color.white.opacity(0.06))
    .frame(height: 1)
```

### Fix 2K — LALITA empty state capitalisation

```swift
// "the Lalita reading..." → "The Lalita reading..."
// "return when the field..." → "Return when the field..."
```

### Fix 2L — Shared two-shadow extension

```swift
extension View {
    func binduGlow(color: Color, tight: CGFloat = 0.22,
                   wide: CGFloat = 0.08) -> some View {
        self
            .shadow(color: color.opacity(tight), radius: 14)
            .shadow(color: color.opacity(wide), radius: 40)
    }
}
// Apply to: play/pause circle button, ACTIVATE button in Lab
```

---

## PHASE 3 — Element Vocabulary Routing
**Commit:** `feat: element vocabularies — 9 visual languages`

This is the most important phase. The Cathedral currently renders for every song. It should only render for the Air element (Anahata / Sound of Silence). Every element gets its own visual world.

### 3A — VocabularyRenderer.swift (new: `Views/Player/VocabularyRenderer.swift`)

A SwiftUI Canvas that draws the vocabulary for the current element. Replaces the Cathedral-only VisualizerView for non-Air elements.

The draw functions are ported directly from `Bindu_Vocabularies.html`. Each takes the same parameters. The Canvas handles the `t` (time) parameter via TimelineView.

**Element → Vocabulary mapping:**
```swift
enum ElementVocabulary: String {
    case earth        // Muladhara — seismic cracks, dust, amber ground
    case water        // Svadhisthana — interference ripples, flow lines
    case fire         // Manipura — ember particles, solar rings
    case air          // Anahata — Cathedral (existing renderer)
    case ether        // Vishuddha — sound waves as geometry
    case constellation // Ajna — star field, clarity dot
    case crown        // Sahasrara — 12-petal lotus, ascending particles
    case soul         // Aatma — dual triangles, extreme stillness
    case dissolution  // Maya — veil cycle, form↔void
    case meditate     // non-chakra tracks — ambient minimal
    case family       // family tracks — warm minimal

    static func from(element: String) -> ElementVocabulary {
        switch element.lowercased() {
        case "earth": return .earth
        case "water": return .water
        case "fire":  return .fire
        case "air":   return .air
        case "light": return .constellation
        case "crown": return .crown
        case "soul":  return .soul
        case "dissolution": return .dissolution
        case "meditate": return .meditate
        case "family":   return .family
        default:         return .meditate
        }
    }

    // Note: Vishuddha (Sound of Silence) has element "Air" in Airtable
    // but the actual vocabulary is Ether (sine wave bands).
    // Track-level override: Track 27 uses .ether, other Air tracks use .air
    static func forTrack(_ track: Track) -> ElementVocabulary {
        if track.id == 27 { return .ether } // Sound of Silence → Vishuddha/Ether
        return from(element: track.element)
    }
}
```

**Intensity mapping:**
```swift
// In VocabularyRenderer, compute intensity from Performer:
var intensity: Float {
    let base = Float(performer.energy) * 0.4  // DSP energy as baseline
    let mod  = Float(performer.crescendoModulator) * 0.6  // score modulator on top
    return min(1.0, base + mod)
}
```

**Port each draw function from the HTML exactly.** The JavaScript Canvas API maps directly to SwiftUI Canvas `GraphicsContext`:

| JS | Swift |
|---|---|
| `ctx.fillRect(0,0,W,H)` | `gc.fill(Path(CGRect(x:0,y:0,width:size.width,height:size.height)), with: .color(...))` |
| `ctx.beginPath(); ctx.arc(cx,cy,r,0,Math.PI*2)` | `let path = Path(ellipseIn: CGRect(...)); gc.fill(path, with:...)` |
| `ctx.createRadialGradient(...)` | `gc.fill(path, with: .radialGradient(Gradient(stops:[...]), center:..., startRadius:..., endRadius:...))` |
| `ctx.createLinearGradient(...)` | `gc.fill(path, with: .linearGradient(Gradient(...), startPoint:..., endPoint:...))` |
| `ctx.globalCompositeOperation='screen'` | `gc.blendMode = .screen` |

**dn() deterministic noise function** — port this helper:
```swift
func dn(_ seed: Double) -> Double {
    let x = sin(seed * 127.1 + 311.7) * 43758.5453
    return x - floor(x)
}
func dn2(_ seed: Double) -> Double {
    let x = sin(seed * 269.5 + 183.3) * 43758.5453
    return x - floor(x)
}
```

**Draw Bindu** at the center of each vocabulary (ported from `drawBindu`):
```swift
func drawBindu(in gc: GraphicsContext, at point: CGPoint,
               hue: Double, t: Double, scale: Double = 1.0) {
    let b = 0.65 + 0.35 * sin(t * 1.15)
    let r = 5.5 * scale
    // Aura (radial glow)
    // Core dot (radial gradient: bright center → element color)
    // Inner shine (small white offset circle)
}
```

**Per-vocabulary background colors:**
```swift
let bgColors: [ElementVocabulary: Color] = [
    .earth:         Color(hex: "#080503"),
    .water:         Color(hex: "#020508"),
    .fire:          Color(hex: "#080300"),
    .air:           Color(hex: "#020208"),
    .ether:         Color(hex: "#030809"),
    .constellation: Color(hex: "#020202"),
    .crown:         Color(hex: "#060408"),
    .soul:          Color(hex: "#030408"),
    .dissolution:   Color(hex: "#040209"),
    .meditate:      Color(hex: "#020208"),
    .family:        Color(hex: "#020208"),
]
```

### 3B — Wire vocabulary into VisualizerView

`VisualizerView` currently always draws the Cathedral. Change it to route by vocabulary:

```swift
// In VisualizerView body, inside Canvas:
let vocab = ElementVocabulary.forTrack(currentTrack)

switch vocab {
case .air:
    // Existing Cathedral draw calls (all 4 tiers) — unchanged
    drawCathedralContinuous(...)
    drawCathedralEnsemble(...)
    if performer.crescendoModulator > 0 { drawCathedralCrescendo(...) }
    if performer.crescendoModulator > 0.25 { drawCathedralClimax(...) }
case .earth:
    drawEarth(gc: gc, size: size, t: t, intensity: intensity)
case .water:
    drawWater(gc: gc, size: size, t: t, intensity: intensity)
case .fire:
    drawFire(gc: gc, size: size, t: t, intensity: intensity)
case .ether:
    drawEther(gc: gc, size: size, t: t, intensity: intensity)
case .constellation:
    drawConstellation(gc: gc, size: size, t: t, intensity: intensity)
case .crown:
    drawCrown(gc: gc, size: size, t: t, intensity: intensity)
case .soul:
    drawSoul(gc: gc, size: size, t: t, intensity: intensity)
case .dissolution:
    drawDissolution(gc: gc, size: size, t: t, intensity: intensity)
default:
    drawAmbient(gc: gc, size: size, t: t) // minimal breathing void
}

// Bindu Lissajous dot always draws on top regardless of vocabulary
drawBinduLissajous(gc: gc, size: size, t: t)
```

**Background color** — set the canvas background to the vocabulary's bg color:
```swift
// In VisualizerView, before the Canvas:
bgColors[vocab]?.ignoresSafeArea()
```

### 3C — Update PlayerView background

The PlayerView background should match the vocabulary background color, not always use `theme.bg`. Add an animated transition when vocabulary changes.

### 3D — Ambient and meditate vocabularies

For tracks with no specific element vocabulary, draw a simple breathing void:
```swift
func drawAmbient(gc: GraphicsContext, size: CGSize, t: Double) {
    // Pure dark background
    // One slow radial breath: hsl(265, 20%, 20%) at 8% opacity
    // The Bindu dot on its Lissajous path is all that's needed
}
```

---

## PHASE 4 — Custom Tab Icons
**Commit:** `feat: tab icons — 7 custom bindu glyphs`

### 4A — BinduTabIcons.swift (new: `Views/Components/BinduTabIcons.swift`)

Seven icons. Each is a SwiftUI `View` rendering an SVG-equivalent path in a 28×28 frame. All use `currentColor` (passed as a parameter) at the specified opacities.

```swift
struct BinduTabIcon: View {
    enum Tab { case map, field, oracle, space, lab, archive, letter }
    let tab: Tab
    let active: Bool

    var color: Color { active ? Color(hex: "#F5E2D6") : Color(hex: "#F5E2D6").opacity(0.4) }

    var body: some View {
        switch tab {
        case .map:     MapIcon(active: active, color: color)
        case .field:   FieldIcon(active: active, color: color)
        case .oracle:  OracleIcon(active: active, color: color)
        case .space:   SpaceIcon(active: active, color: color)
        case .lab:     LabIcon(active: active, color: color)
        case .archive: ArchiveIcon(active: active, color: color)
        case .letter:  LetterIcon(active: active, color: color)
        }
    }
}
```

**MAP icon** — three concentric rings + cardinal ticks + center dot:
```swift
struct MapIcon: View {
    let active: Bool, color: Color
    var body: some View {
        Canvas { gc, size in
            let cx = size.width/2, cy = size.height/2
            // Ring 1: r=12.5
            gc.stroke(Path(ellipseIn: CGRect(x:cx-12.5,y:cy-12.5,width:25,height:25)),
                     with: .color(color.opacity(active ? 0.65 : 0.35)), lineWidth: 0.9)
            // Ring 2: r=7.5
            gc.stroke(Path(ellipseIn: CGRect(x:cx-7.5,y:cy-7.5,width:15,height:15)),
                     with: .color(color.opacity(active ? 0.50 : 0.28)), lineWidth: 0.8)
            // Ring 3: r=3.2
            gc.stroke(Path(ellipseIn: CGRect(x:cx-3.2,y:cy-3.2,width:6.4,height:6.4)),
                     with: .color(color.opacity(active ? 0.70 : 0.40)), lineWidth: 0.9)
            // Center dot: r=1.5
            gc.fill(Path(ellipseIn: CGRect(x:cx-1.5,y:cy-1.5,width:3,height:3)),
                   with: .color(color.opacity(active ? 1.0 : 0.6)))
            // 4 cardinal ticks at 12/3/6/9 on outer ring
            for angle in [0.0, 90.0, 180.0, 270.0] {
                let rad = angle * .pi / 180
                var p = Path()
                p.move(to: CGPoint(x: cx+11.8*cos(rad), y: cy+11.8*sin(rad)))
                p.addLine(to: CGPoint(x: cx+13.5*cos(rad), y: cy+13.5*sin(rad)))
                gc.stroke(p, with: .color(color.opacity(active ? 0.50 : 0.25)), lineWidth: 0.8)
            }
        }
        .frame(width: 28, height: 28)
    }
}
```

**FIELD icon** — 7 deterministic stars + constellation lines from center:
```swift
struct FieldIcon: View {
    let active: Bool, color: Color
    var body: some View {
        Canvas { gc, size in
            let stars: [(CGFloat,CGFloat)] = [(5,6),(22,5),(8,20),(21,19),(13,9),(6,14),(20,13)]
            let cx: CGFloat = 14, cy: CGFloat = 14
            stars.enumerated().forEach { (i, s) in
                let r: CGFloat = i == 4 ? 1.8 : 0.9
                let op = i == 4 ? (active ? 1.0 : 0.7) : (active ? 0.45 : 0.22)
                gc.fill(Path(ellipseIn: CGRect(x:s.0-r,y:s.1-r,width:r*2,height:r*2)),
                       with: .color(color.opacity(op)))
            }
            // Center node
            gc.fill(Path(ellipseIn: CGRect(x:cx-2.5,y:cy-2.5,width:5,height:5)),
                   with: .color(color.opacity(active ? 0.85 : 0.5)))
            // Lines from center to 3 stars
            for target in [(CGFloat(13),CGFloat(9)),(22,5),(8,20)] {
                var p = Path()
                p.move(to: CGPoint(x:cx,y:cy))
                p.addLine(to: CGPoint(x:target.0,y:target.1))
                gc.stroke(p, with: .color(color.opacity(active ? 0.25 : 0.12)), lineWidth: 0.5)
            }
        }
        .frame(width: 28, height: 28)
    }
}
```

**ORACLE icon** — outer ring open at top, inner ring, center dot:
```swift
// Outer ring with gap at 12 o'clock (approximately 340°→20° opening)
// Use Path.addArc from 20° to 340° (leaving ~40° open at top)
// Inner circle: r=6.5, complete
// Center dot: r=2.0
```

**SPACE icon** — breath ring (full circle, very thin), inner ring, 3 timing dots:
```swift
// Outer ring r=11.5, opacity 0.65/0.32
// Inner ring r=6.0, opacity 0.40/0.20
// 3 dots at angles 60°/180°/300°, on outer ring radius, r=0.9
// Center dot r=1.5
```

**LAB icon** — sine wave + center node:
```swift
// Path: M2,14 Q5,8 8,14 Q11,20 14,14 Q17,8 20,14 Q23,20 26,14
// Center circle r=2.5 (stroke only, with fill = bg color to "cut" wave)
// Inner dot r=1.0 fill
// Two vertical ticks above and below
```

**ARCHIVE icon** — layered stacked pages:
```swift
// Bottom rect: x:333→347, y:44→56, rx:1, opacity 0.30
// Top rect: x:336→350, y:42→54, rx:1, opacity 0.45
// Two horizontal lines in top rect for text simulation
```

**LETTER icon** — 3 outward arcs from source + receiving line:
```swift
// Arc 1 (inner): M8,14 Q14,6 20,14
// Arc 2 (mid): M5,14 Q14,3 23,14
// Arc 3 (outer): M3,14 Q14,0.5 25,14
// Source dot: r=2.2 at (14,14)
// Receiving line: (14,17)→(14,25)
// Ground dot: r=0.9 at (14,25.5)
```

### 4B — Wire into RootView.swift

Replace all `Image(systemName:)` calls in the `TabView` items with `BinduTabIcon`:

```swift
// In each .tabItem label:
Label {
    Text("MAP") // keep for VoiceOver
} icon: {
    BinduTabIcon(.map, active: selectedTab == 0)
}
```

**Add MAP as tab 0** — The Map tab is the new front door (implemented in Session B, but wire the tab item now with a placeholder view). Shift existing tabs by +1 if needed, or add Map as a new tab item. Check `NavigationStore.selectedTab` tag assignments.

---

## PHASE 5 — Self-Verification

### Build check
```bash
xcodebuild -scheme "Bindu Field" -destination "generic/platform=iOS" \
  -configuration Debug build 2>&1 | grep -E "error:|warning:|SUCCEEDED|FAILED"
```
Zero errors. Zero warnings.

### Functional checks
```bash
# Vocabulary routing
grep -n "ElementVocabulary\|forTrack\|drawEarth\|drawWater" \
  "Bindu Field/Views/Player/VisualizerView.swift"
# Expected: routing switch with all 9 vocabularies

# Tab icons
grep -rn "Image(systemName" "Bindu Field/Views/RootView.swift"
# Expected: zero hits (all replaced with BinduTabIcon)

# Lab sliders wired
grep -n "setCarrier\|setBeat" "Bindu Field/Views/Tabs/LabView.swift"
# Expected: called in slider onChange

# Player close
grep -n "closePlayer\|DragGesture" "Bindu Field/Views/Player/PlayerView.swift"
# Expected: both present in FIELD mode
```

### Device tests (Neev — run after install)
- [ ] Open Field tab — constellation shows, orbs have element colors
- [ ] Tap Iron (Earth) — visualizer shows amber/seismic vocabulary, NOT cathedral
- [ ] Tap Crystallize (Water) — shows ripple interference vocabulary
- [ ] Tap Sound of Silence (Air/Ether) — shows ether wave vocabulary
- [ ] Tap Experience (Constellation/Ajna) — shows star field
- [ ] Swipe down in FIELD mode → player closes
- [ ] X button in top-right → player closes
- [ ] Lab carrier slider → frequency changes audibly
- [ ] Lab beat slider → beat Hz changes audibly
- [ ] Control sheet feels solid (not glassy)
- [ ] Recognition statement is barely visible whisper behind the verb
- [ ] Verb glow is soft presence, not aggressive
- [ ] Tab bar shows custom icons for all 7 tabs

### Commit sequence
```bash
git commit -m "fix: functional regressions — lab sliders, player close"
git commit -m "fix: visual fidelity — sheets, verb, recognition, weights"
git commit -m "feat: element vocabularies — 9 visual languages"
git commit -m "feat: tab icons — 7 custom bindu glyphs"
```

Leave on `feat/session-a`. Do not merge. Report back with device test results.

---

## Design Principles to Honor

**The void is the ground.** Each vocabulary emerges from darkness. The background color sets the element. The Bindu dot always travels through it.

**Intensity is the session.** At 0 intensity, only the subtlest atmospheric elements show. As the music builds and the DSP energy rises, complexity emerges. At crescendo, the vocabulary peaks. The user's session intensity determines what they see.

**The dot is always present.** The Lissajous Bindu dot renders on top of every vocabulary. It is the constant across all nine worlds.

**The Cathedral belongs to one song.** Air vocabulary (Anahata) is for tracks with the Air element, not all tracks. Ether vocabulary (Vishuddha) is for Sound of Silence specifically. Each song has exactly one visual world.
