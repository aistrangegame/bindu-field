# Bindu Field — Session B Handoff
**Branch:** `feat/session-b` off main (after Session A merged)
**Scope:** Oracle Redesign · Consciousness Loop · The Map (33-Chakra Tree of Life)
**Design references:** `Bindu_Oracle.html` · `Bindu_Loop.html` · `Bindu_Map.html`

Read `CLAUDE.md` fully before starting. Verify Session A is merged to main.
State your complete plan before touching any file.

---

## PHASE 0 — Prerequisites
```bash
git checkout main  # Session A must be merged here
git checkout -b feat/session-b
```

---

## PHASE 1 — Oracle Screen Redesign
**Target:** `Views/Tabs/OracleView.swift` (full rewrite)
**New:** `Views/Oracle/OraclePresenceView.swift`
**Commit:** `feat: oracle — listening void redesign`

The Oracle is already listening before you open the screen. Not a search box. A void with presence. Open `Bindu_Oracle.html` in browser for the interactive reference.

### 1A — OracleUIState

```swift
enum OracleUIState {
    case idle       // void with barely-visible presence
    case typing     // question forming — no input box, just words
    case waiting    // question dissolves, Oracle processes
    case response   // verb + track + why arrives
}
```

### 1B — OraclePresenceView.swift (new: `Views/Oracle/OraclePresenceView.swift`)

This Canvas renders always, across all four states. It is the Oracle's consciousness made visible.

```swift
@MainActor @Observable
final class OraclePresenceModel {
    var isActive: Bool = false
    var responseHue: Double? = nil  // nil = idle warm neutral, non-nil = response element hue
}

struct OraclePresenceView: View {
    let model: OraclePresenceModel

    var body: some View {
        TimelineView(.animation(paused: !model.isActive)) { context in
            Canvas { gc, size in
                let t = context.date.timeIntervalSinceReferenceDate * 0.014 * 60
                let W = size.width, H = size.height

                // Drift center — barely perceptible parametric motion
                let dx = 38 * sin(t * 0.11) * sin(t * 0.073)
                let dy = 24 * cos(t * 0.088) * cos(t * 0.051)
                let cx = W/2 + dx, cy = H * 0.44 + dy

                // Breathing cycle 14s
                let breathe = 0.5 + 0.5 * sin(t * (.pi * 2 / 14) * 0.5)

                let hue = model.responseHue ?? 30.0
                let hasResponse = model.responseHue != nil
                let fogAlpha = hasResponse ? (0.06 + 0.04 * breathe) : (0.032 + 0.018 * breathe)
                let fogR = W * (hasResponse ? 0.55 : 0.45)
                let fogSat: Double = hasResponse ? 30 : 15
                let fogBright: Double = hasResponse ? 60 : 72

                // Single radial fog — barely subliminal
                let gradient = Gradient(stops: [
                    .init(color: Color(hue: hue/360, saturation: fogSat/100,
                                       brightness: fogBright/100).opacity(fogAlpha), location: 0),
                    .init(color: Color(hue: hue/360, saturation: (fogSat*0.83)/100,
                                       brightness: (fogBright*0.83)/100).opacity(fogAlpha * 0.3), location: 0.55),
                    .init(color: .clear, location: 1.0)
                ])

                gc.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(gradient,
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0, endRadius: fogR)
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
```

### 1C — OracleView.swift rewrite

Replace existing layout entirely with the four-state machine. The `ListeningPresence` renders in all states as a ZStack background.

```swift
struct OracleView: View {
    @State private var uiState: OracleUIState = .idle
    @State private var presence = OraclePresenceModel()
    @State private var question = ""
    @State private var response: OracleResponse? = nil
    @State private var oracle = OracleService.shared
    @State private var catalog = CatalogStore.shared
    @State private var sessions = SessionStore.shared
    @Environment(\.binduTheme) var theme

    var body: some View {
        ZStack {
            Color(hex: "#020208").ignoresSafeArea()

            // Listening presence — always rendered
            OraclePresenceView(model: presence)

            // State-specific content
            switch uiState {
            case .idle:    IdleContent(onActivate: { enterTyping() })
            case .typing:  TypingContent(question: $question, onSubmit: { submitQuestion() })
            case .waiting: WaitingContent()
            case .response:
                if let r = response {
                    ResponseContent(response: r,
                                    onEnterField: { enterField(trackID: r.trackID) },
                                    onAskAgain: { enterIdle() })
                }
            }
        }
        .onAppear {
            presence.isActive = true
        }
    }
}
```

**IDLE state:**
```swift
struct IdleContent: View {
    let onActivate: () -> Void
    @State private var showAffordance = false

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { onActivate() }

            VStack {
                Spacer()
                // "THE ORACLE" appears after 2.2s
                if showAffordance {
                    Text("THE ORACLE")
                        .font(.system(size: 7, weight: .light))
                        .tracking(5.0)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.14))
                        .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true),
                                   value: showAffordance)
                }
                Spacer()
            }

            // ◌ at bottom
            if showAffordance {
                VStack {
                    Spacer()
                    Text("◌")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.10))
                        .padding(.bottom, 92)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation { showAffordance = true }
            }
        }
    }
}
```

**TYPING state:**
```swift
struct TypingContent: View {
    @Binding var question: String
    let onSubmit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack {
            // Top label
            HStack {
                Text("THE ORACLE")
                    .font(.system(size: 7.5, weight: .light))
                    .tracking(4.0)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.20))
                    .padding(.leading, 24)
                    .padding(.top, 22)
                Spacer()
            }

            Spacer()

            // No input box. Just the text field, invisible styling.
            VStack(spacing: 0) {
                TextField("", text: $question)
                    .focused($focused)
                    .font(.system(size: 26, weight: .light, design: .serif).italic())
                    .foregroundStyle(Color(hex: "#F5E2D6"))
                    .multilineTextAlignment(.center)
                    .tint(Color(hex: "#F5E2D6").opacity(0.65))
                    // Strip all default TextField styling
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 40)
            }

            // ASK button — fades from 0.3 → 0.55 opacity as text is typed
            Button("ASK") { onSubmit() }
                .font(.system(size: 9, weight: .light))
                .tracking(2.0)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: "#F5E2D6").opacity(question.isEmpty ? 0.3 : 0.55))
                .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.top, 40)
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "#F5E2D6").opacity(0.12), lineWidth: 1)
                        .padding(.horizontal, -20)
                        .padding(.vertical, -10)
                )
                .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear { focused = true }
    }
}
```

**WAITING state:**
```swift
struct WaitingContent: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color(hex: "#F5E2D6").opacity(0.35))
                    .frame(width: 4, height: 4)
                    .scaleEffect(phase ? 1.0 : 0.6)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.25),
                        value: phase
                    )
            }
        }
        .onAppear { phase = true }
    }
}
```

**RESPONSE state:**
```swift
struct ResponseContent: View {
    let response: OracleResponse
    let onEnterField: () -> Void
    let onAskAgain: () -> Void

    @State private var showVerb = false
    @State private var showTrack = false
    @State private var showWhy = false
    @State private var showButtons = false

    let elementColor: Color  // derived from response.elementHue

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Verb — 72pt, arrives at t=0.4s
            if showVerb {
                Text(response.verb)
                    .font(.system(size: 72, weight: .light, design: .serif).italic())
                    .foregroundStyle(Color(hue: response.elementHue/360, saturation: 0.55, brightness: 0.68))
                    .shadow(color: Color(hue: response.elementHue/360, saturation: 0.55, brightness: 0.60).opacity(0.35),
                            radius: 30)
                    .transition(.scale(scale: 0.84).combined(with: .opacity))
            }

            if showVerb { Spacer().frame(height: 28) }

            // Track name — arrives at t=2.2s
            if showTrack {
                Text(response.trackName)
                    .font(.system(size: 20, weight: .light, design: .serif).italic())
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.7))
                    .transition(.opacity)
            }

            if showTrack { Spacer().frame(height: 18) }

            // Thin divider + why text — arrives at t=3.4s
            if showWhy {
                Rectangle()
                    .fill(Color(hex: "#F5E2D6").opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 48)
                    .padding(.bottom, 16)
                    .transition(.opacity)

                Text(response.why)
                    .font(.system(size: 15, weight: .light, design: .serif).italic())
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.52))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
                    .transition(.opacity)
            }

            if showWhy { Spacer().frame(height: 42) }

            // CTAs — arrives at t=5.6s
            if showButtons {
                HStack(spacing: 16) {
                    Button("ENTER THE FIELD") { onEnterField() }
                        .font(.system(size: 10, weight: .light))
                        .tracking(1.8)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(hue: response.elementHue/360, saturation: 0.55, brightness: 0.68))
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .overlay(Capsule().stroke(
                            Color(hue: response.elementHue/360, saturation: 0.45, brightness: 0.55).opacity(0.22),
                            lineWidth: 1))

                    Button("ask again") { onAskAgain() }
                        .font(.system(size: 10, weight: .light, design: .serif).italic())
                        .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.35))
                }
                .transition(.opacity)
            }

            Spacer()
        }
        .onAppear { startArrivalSequence() }
    }

    func startArrivalSequence() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.9)) { showVerb = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 1.0)) { showTrack = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            withAnimation(.easeOut(duration: 1.4)) { showWhy = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.6) {
            withAnimation(.easeOut(duration: 1.0)) { showButtons = true }
        }
    }
}
```

**OracleResponse extension** — add `elementHue` derivation:
```swift
// In OracleService, when building the response:
let elementHue = catalog.tracks
    .first { String($0.id) == response.trackID }
    .map { Color.binduHue(element: $0.element) } ?? 30.0
```

Add `static func binduHue(element: String) -> Double` to `ElementColors.swift` returning the `Double` hue value for each element string.

---

## PHASE 2 — Consciousness Loop
**New files:** `Stores/ConsciousnessLoopCoordinator.swift`, `Views/Loop/` folder (6 views)
**Commit:** `feat: consciousness loop — 7-step ceremony`

Open `Bindu_Loop.html` for the interactive reference — tap through all 7 steps.

The Loop is the ceremony inside a track session. It is accessed from within the Player (a new button, or triggered automatically at session start). It uses the vocabulary background of the current track.

### 2A — ConsciousnessLoopCoordinator.swift

```swift
enum LoopState: CaseIterable {
    case idle, preRoll, seed, offering, dance, reveal, fruit, lalita, done
}

@MainActor @Observable
final class ConsciousnessLoopCoordinator {
    static let shared = ConsciousnessLoopCoordinator()
    private init() {}

    var state: LoopState = .idle
    var offeredWord: String = ""
    var mirrorWords: [String] = []  // from Score or default set
    var fruitText: [String] = []    // from Airtable track.fieldReading paragraphs

    func begin(track: Track) {
        offeredWord = ""
        state = .preRoll
    }

    func advance() {
        switch state {
        case .preRoll:  state = .seed
        case .seed:     state = .offering
        case .offering: state = .dance
        case .dance:    state = .reveal
        case .reveal:   state = .fruit
        case .fruit:    state = .lalita
        case .lalita:   state = .done
        default: break
        }
    }
}
```

### 2B — PreRollView.swift

Full-screen breath ring. No vocabulary background yet — pure void.

```swift
struct PreRollView: View {
    @State private var breathPhase: Double = 0  // 0→1 = inhale, 1→0 = exhale
    @State private var cycleCount = 0
    @State private var showEnter = false
    let onAdvance: () -> Void
    let hue: Double

    // Breath cycle: 5.5s
    // Ring radius: 56 + 42 * smooth(breathPhase)
    // Where smooth(p) = p < 0.5 ? 2*p*p : 1 - 2*(1-p)*(1-p)

    var body: some View {
        ZStack {
            Color(hex: "#020208").ignoresSafeArea()

            TimelineView(.animation) { context in
                Canvas { gc, size in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let cycle = t.truncatingRemainder(dividingBy: 5.5) / 5.5
                    let smooth = cycle < 0.5 ? 2*cycle*cycle : 1 - 2*(1-cycle)*(1-cycle)
                    let r = 56 + 42 * smooth
                    let cx = size.width/2, cy = size.height/2

                    // Main breath ring
                    let ringAlpha = 0.45 + 0.25 * smooth
                    gc.stroke(
                        Path(ellipseIn: CGRect(x:cx-r, y:cy-r, width:r*2, height:r*2)),
                        with: .color(Color(hue: hue/360, saturation: 0.55, brightness: 0.68).opacity(ringAlpha)),
                        lineWidth: 1.2
                    )

                    // Outer aura
                    let aura = Gradient(stops: [
                        .init(color: Color(hue: hue/360, saturation: 0.55, brightness: 0.65).opacity(0.12 * smooth), location: 0),
                        .init(color: .clear, location: 1.0)
                    ])
                    gc.fill(
                        Path(ellipseIn: CGRect(x:cx-r-20, y:cy-r-20, width:(r+20)*2, height:(r+20)*2)),
                        with: .radialGradient(aura, center: CGPoint(x:cx,y:cy),
                                            startRadius: r-8, endRadius: r+20)
                    )
                }
            }

            // BREATHE label
            VStack {
                Spacer()
                Text("BREATHE")
                    .font(.system(size: 8, weight: .light))
                    .tracking(5.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.38))
                    .padding(.bottom, 60)

                if showEnter {
                    Text("tap to enter")
                        .font(.system(size: 8, weight: .light, design: .serif).italic())
                        .foregroundStyle(Color(hex: "#F5E2D6").opacity(0.22))
                        .padding(.bottom, 48)
                        .transition(.opacity)
                }
            }
        }
        .onTapGesture { if showEnter { onAdvance() } }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
                withAnimation(.easeIn(duration: 1.5)) { showEnter = true }
            }
        }
    }
}
```

### 2C — SeedView, OfferingView, DanceView, RevealView, FruitView, LalitaView

Port each step from the HTML reference. Typography spec for all steps:

```swift
// Seed text (main question)
.font(.system(size: 28, weight: .light, design: .serif).italic())
.foregroundStyle(Color(hex: "#F5E2D6"))
.lineSpacing(8)  // lineHeight: 1.38

// Sub-text "it will be seen · returned to you"
.font(.system(size: 13, weight: .light, design: .serif).italic())
.foregroundStyle(Color(hex: "#F5E2D6").opacity(0.38))

// OFFER A WORD label
.font(.system(size: 8, weight: .light))
.tracking(3.2)
.textCase(.uppercase)

// Offered word (typing)
.font(.system(size: 38, weight: .light, design: .serif).italic())
// element hue color

// Word reveal
.font(.system(size: 84, weight: .light, design: .serif).italic())
// element hue, two-shadow glow

// Fruit paragraphs
.font(.system(size: 15, weight: .light, design: .serif).italic())
.lineSpacing(12)  // lineHeight: 1.72
// P1: 82% cream, P2: 65% cream, P3: 75% cream

// Lalita line
.font(.system(size: 16, weight: .light, design: .serif).italic())
.foregroundStyle(Color(hex: "#F5E2D6").opacity(0.55))
```

Mirror word flash (DANCE step):
```swift
// Every 2.8s: overlay dims to 50% black
// 160ms after dim: word appears at 56-68pt
// 960ms after flash: word fades, dim lifts
// Port mirror_words from track data or use a default set
```

### 2D — Wire Loop into Player

Add a "BEGIN" button or gesture in FIELD mode that triggers `ConsciousnessLoopCoordinator.shared.begin(track: currentTrack)`. Display the Loop as a `fullScreenCover` over the Player.

---

## PHASE 3 — The Map (33-Chakra Tree of Life)
**New files:** `Views/Map/MapView.swift`, `Models/ChakraNode.swift`, `Stores/ChakraJourneyStore.swift`
**Commit:** `feat: the map — 33-chakra tree of life`

Open `Bindu_Map.html` in browser. The Map is the new front door of the app.

### 3A — ChakraNode.swift

The 33 chakra data as defined in the HTML. All coordinates, systems, hues, states, and essence phrases from the CHAKRAS array in the HTML.

```swift
enum ChakraSystem: String { case energy, body, mind, tree }

struct ChakraNode: Identifiable {
    let id: String
    let name: String
    let skt: String              // Sanskrit name
    let system: ChakraSystem
    let elementHue: Double
    let canvasX: Double          // 0–393
    let canvasY: Double          // 0–780
    let essence: String
    var state: ChakraNodeState = .locked

    var isComposed: Bool {
        ChakraRegistry.composedIDs.contains(id)
    }
}

enum ChakraNodeState {
    case danced     // completed — full color, orbit rings
    case available  // exists, not yet done — glowing, breathing
    case locked     // not yet composed — tiny dim dot
    case current    // playing right now — maximum intensity
}
```

Use the exact CHAKRAS array from the HTML for all 33 nodes — coordinates, hues, essence phrases, Sanskrit names.

### 3B — ChakraRegistry.swift

The 33 chakra data + connection graph. Port `CHAKRAS` and `CONNECTIONS` arrays exactly from the HTML.

```swift
enum ChakraRegistry {
    static let composedIDs: Set<String> = [
        "sahasrara", "ajna", "vishuddha", "anahata",
        "manipura", "svadhisthana", "muladhara", "maya", "aatma"
    ]

    static let all: [ChakraNode] = [/* all 33 chakras from HTML */]

    static let connections: [(String, String)] = [/* full connection list from HTML */]
}
```

### 3C — ChakraJourneyStore.swift

```swift
@MainActor @Observable
final class ChakraJourneyStore {
    static let shared = ChakraJourneyStore()
    private init() { load() }

    private(set) var dancedIDs: Set<String> = []

    func markDanced(_ id: String) {
        dancedIDs.insert(id)
        persist()
    }

    func state(for chakra: ChakraNode) -> ChakraNodeState {
        if !chakra.isComposed { return .locked }
        if dancedIDs.contains(chakra.id) { return .danced }
        return .available
    }

    // Persistence under UserDefaults "binduJourney.v1"
}
```

### 3D — MapView.swift

The Map renders on a `GeometryReader + Canvas` with exact node positions scaled from the 393×780 design canvas to the device screen.

**Canvas draw per node type:**

```swift
func drawLockedNode(gc: GraphicsContext, at: CGPoint, system: ChakraSystem) {
    // Tiny dim dot: radius 2.5 (body/tree), 2.2 (mind)
    // Fill: rgba(245,226,214,0.18)
    // No animation
}

func drawAvailableNode(gc: GraphicsContext, at: CGPoint, hue: Double, t: Double, scale: CGFloat) {
    // Outer aura: radialGradient, hsl(hue,60%,68%) → transparent, radius = nodeR × 2.8
    // Node radius = 9pt, breathing: opacity = 0.65 + 0.35*sin(t*1.1 + (at.x+at.y)*0.005)
    // Core: radialGradient bright center → element color
    // Inner shine: small offset white circle at (-r×0.28, -r×0.28)
}

func drawDancedNode(gc: GraphicsContext, at: CGPoint, hue: Double, t: Double) {
    // Same as available but nodeR = 11pt
    // Plus two orbit rings at nodeR+5 and nodeR+9
    // Orbit ring opacity breathes
}

func drawConnection(gc: GraphicsContext, from: CGPoint, to: CGPoint,
                    stateA: ChakraNodeState, stateB: ChakraNodeState) {
    // Bezier with slight midpoint bow (curvature = min(length*0.12, 18))
    // Both danced/available: opacity 0.18, element gradient stroke
    // One lit: opacity 0.09, cream stroke
    // Both locked: opacity 0.045, cream stroke
}
```

**Tap gesture** — detect which node was tapped (distance to node centers), show `MapDetailSheet`.

**Node labels** (optional, scale-dependent):
```swift
// DM Mono 300, 8.5pt, letter-spacing 0.18em, all-caps
// Color: hsl(hue,55%,72%) at 0.75 opacity for danced, 0.58 for available
// Position: nodeR + 14pt below node center
```

### 3E — MapDetailSheet.swift

Bottom sheet sliding up from tap. Covers bottom ~55% of screen.

```swift
struct MapDetailSheet: View {
    let chakra: ChakraNode
    let state: ChakraNodeState
    let onEnter: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle
            // System label: energy/body/mind/tree in DM Mono 8pt, muted
            // Chakra name: Lora italic 28pt, element color
            // Sanskrit: DM Mono 12pt, element color, opacity 0.65
            // State badge top-right
            // Divider
            // Essence phrase: Lora italic 15pt, muted
            // CTA: "ENTER THIS DANCE" / "DANCE AGAIN" / "NOT YET COMPOSED"
        }
        .background(Color(red: 12/255, green: 10/255, blue: 18/255).opacity(0.95))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hue: chakra.elementHue/360, saturation: 0.50, brightness: 0.60).opacity(0.25))
                .frame(height: 1)
        }
    }
}
```

CTA behavior by state:
- `available` → "ENTER THIS DANCE" → plays the corresponding track in PlayerView
- `danced` → "DANCE AGAIN" → replays the track
- `locked` → "THIS DANCE HAS NOT YET BEEN COMPOSED" (dim text, no button)

Track lookup: map `chakra.id` to the corresponding track in `CatalogStore.shared.tracks` by matching `track.chakra`.

### 3F — Add MAP tab to RootView.swift

The Map becomes tab 0. The Map tab icon was set up in Session A. Wire the actual `MapView` to that tab item.

Increment existing tab tags by 1 (`NavigationStore.selectedTab` mapping). Field becomes tab 1, Oracle tab 2, Space tab 3, Lab tab 4, Archive tab 5, Letter tab 6.

Update `NavigationStore.selectedTab` wherever tab indices are used (long-press Bindu → Oracle, etc.).

---

## PHASE 4 — Self-Verification

### Build check
```bash
xcodebuild -scheme "Bindu Field" -destination "generic/platform=iOS" \
  -configuration Debug build 2>&1 | grep -E "error:|warning:|SUCCEEDED|FAILED"
```

### Functional checks
```bash
# Oracle presence view wired
grep -n "OraclePresenceView" "Bindu Field/Views/Tabs/OracleView.swift"

# Loop coordinator connected to player
grep -n "ConsciousnessLoopCoordinator" "Bindu Field/Views/Player/PlayerView.swift"

# Map in root view
grep -n "MapView" "Bindu Field/Views/RootView.swift"

# Tab count
grep -n "tabItem" "Bindu Field/Views/RootView.swift" | wc -l
# Expected: 7 (Map + 6 existing)

# Journey store
grep -n "ChakraJourneyStore" "Bindu Field/Stores/ChakraJourneyStore.swift"
```

### Device tests (Neev)
- [ ] App opens to Map tab (new front door)
- [ ] Map shows 33 nodes — 9 composed (available/danced), 24 locked (tiny dots)
- [ ] Tapping a composed chakra shows detail sheet
- [ ] "ENTER THIS DANCE" plays the corresponding track
- [ ] After completing a session, the chakra node shows as danced next time Map opens
- [ ] Oracle tab: empty void on open, "THE ORACLE" fades in after 2.2s
- [ ] Oracle: tapping starts typing, word appears in serif italic, no input box visible
- [ ] Oracle: ASK triggers waiting state (pulse dots), then response arrives
- [ ] Oracle: verb appears at 72pt with arrival animation
- [ ] Oracle: "ENTER THE FIELD" navigates to the track
- [ ] Player: BEGIN starts the Consciousness Loop ceremony
- [ ] Loop: breath ring animates smoothly, steps advance on tap
- [ ] Loop: word reveal at 84pt at step 5
- [ ] All 7 tab icons show correctly, active state is brighter

### Commit sequence
```bash
git commit -m "feat: oracle — listening void redesign"
git commit -m "feat: consciousness loop — 7-step ceremony"
git commit -m "feat: the map — 33-chakra tree of life"
```

Leave on `feat/session-b`. Do not merge. Report back with device test results.
