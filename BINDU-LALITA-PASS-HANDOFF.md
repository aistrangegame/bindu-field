# Bindu Field — Lalita Design Pass Handoff
**Branch base:** `main` (post `b02def8`, post pause/resume merge)
**Scope:** Complete visual architecture of the instrument — 6 phases, one at a time
**Design references:** `design_handoff_lalita_pass/` folder in project root

Read `CLAUDE.md` first. Then read this document fully before touching any file.
After reading both, state your phase-by-phase plan. Wait for confirmation. Then proceed.

---

## Prerequisites — Before Starting

Two things must be true before Phase 1 begins:

**1. feat/pause-resume must be merged to main.**
This branch (being built now) adds `TrackPlaybackService.pause()`, `.resume()`,
`.togglePlayPause()`, and `isPaused: Bool`. The Player redesign (Phase 3) builds
directly on these. If the branch is still open, complete it first:
```bash
git checkout main && git status
# If feat/pause-resume is unmerged: merge it first, then continue
```

**2. Design package must be in the project.**
The folder `design_handoff_lalita_pass/` containing:
- `Bindu Player.html` · `Bindu Lab.html` · `Bindu Performance.html`
- `Bindu Archetypes.html` · `Bindu Lalita.html`
- `bindu-performance-engine.js` · `bindu-lissajous.jsx`
- `README.md` (the design spec)

Open these HTML files in a browser before implementing each phase.
They are animated, interactive — the reference is live, not static.

**Branch for this work:**
```bash
git checkout main && git checkout -b feat/lalita-pass
```

---

## What This Pass Builds

The Lalita Design Pass is the full visual architecture of the instrument
made visible. Seven archetypes have always been present in the field.
This pass makes them visible in the music.

Six phases. Each phase is a commit. Build, verify, commit before moving on.

---

## Phase 1 — Lab Redesign
**Target:** `Views/Tabs/LabView.swift`
**Design reference:** `Bindu Lab.html` (open in browser first)
**Commit:** `feat: lab redesign — waveform, sacred map, randomize, direct edit`

The existing Lab has: sliders, preset row, brainwave info card, carrier-note popover.
This redesign adds depth without removing anything. Every existing behavior is preserved.

### 1A — Animated Binaural Waveform (new component)

Create `Views/Components/BinauralWaveformView.swift`:

```swift
// SwiftUI Canvas drawing three layered sine waves
// showing the interference pattern between carrier and carrier+beat

struct BinauralWaveformView: View {
    let carrierHz: Float    // from store
    let beatHz: Float
    let isActive: Bool      // from store.isPlaying
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(paused: !isActive)) { context in
            Canvas { gc, size in
                let t = context.date.timeIntervalSinceReferenceDate

                // Ghost wave when inactive
                if !isActive {
                    drawGhostWave(gc: gc, size: size)
                    return
                }

                // L channel — carrier only
                drawWave(gc: gc, size: size, freq: Double(carrierHz),
                         phase: t, color: Color(hex: "#F5E2D6").opacity(0.14),
                         lineWidth: 1.0, glow: false)

                // R channel — carrier + beat (element color at 0.38)
                drawWave(gc: gc, size: size, freq: Double(carrierHz + beatHz),
                         phase: t, color: elementColor.opacity(0.38),
                         lineWidth: 1.0, glow: false)

                // Beat envelope — interference, bright, glowing
                drawBeatsEnvelope(gc: gc, size: size,
                                  carrier: Double(carrierHz), beat: Double(beatHz),
                                  phase: t, color: elementColor,
                                  lineWidth: 1.8, glow: true)
            }
        }
        .frame(height: 120)
    }
}
```

Place `BinauralWaveformView(carrierHz:beatHz:isActive:)` between the header and the
carrier readout in LabView. Pass `store.carrier`, `store.beat`, `store.isPlaying`.

### 1B — Direct Number Editing

Both carrier and beat values are currently display-only.
Make them tappable → inline `TextField` with `.keyboardType(.decimalPad)`.

```swift
// Carrier value becomes tappable
@State private var editingCarrier = false
@State private var carrierInput = ""

// When tapped:
editingCarrier = true
carrierInput = String(format: "%.1f", store.carrier)

// TextField (shown when editing):
TextField("", text: $carrierInput)
    .keyboardType(.decimalPad)
    .onSubmit {
        if let v = Float(carrierInput) {
            store.carrier = min(max(v, 40), 440)
            if store.isPlaying { store.setCarrier(store.carrier) }
        }
        editingCarrier = false
    }
```

Same pattern for the 76pt beat number — tapping it enters direct edit mode.

### 1C — Sacred Frequency Map Strip

A horizontal strip showing dots at each sacred carrier frequency.
Current carrier shown as a larger glowing dot that slides smoothly.

```swift
struct SacredFrequencyStrip: View {
    let carrierHz: Float

    let sacred: [(hz: Float, name: String)] = [
        (136.1, "OM"), (174.0, "174"), (285.0, "285"),
        (396.0, "UT"), (417.0, "RE"), (432.0, "432"), (440.0, "440")
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Baseline hairline
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)

                // Sacred dots
                ForEach(sacred, id: \.hz) { s in
                    let x = xPosition(for: s.hz, in: geo.size.width)
                    VStack(spacing: 3) {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 4, height: 4)
                        Text(s.name)
                            .font(.system(size: 7, weight: .light))
                            .tracking(0.5)
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                    .position(x: x, y: geo.size.height / 2)
                }

                // Current carrier — glowing dot
                let cx = xPosition(for: carrierHz, in: geo.size.width)
                Circle()
                    .fill(Color.bindu(element: currentElement))
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.bindu(element: currentElement).opacity(0.6), radius: 4)
                    .position(x: cx, y: geo.size.height / 2)
                    .animation(.spring(duration: 0.4), value: carrierHz)
            }
        }
        .frame(height: 32)
    }

    func xPosition(for hz: Float, in width: CGFloat) -> CGFloat {
        let min: Float = 80, max: Float = 500
        return CGFloat((hz - min) / (max - min)) * (width - 16) + 8
    }
}
```

Add `SacredFrequencyStrip(carrierHz: store.carrier)` below the sliders.

### 1D — Intelligent Randomize ("let the field choose")

Replace the existing transparent button with this algorithm:

```swift
func letTheFieldChoose() {
    // Weighted state selection
    let stateRoll = Double.random(in: 0..<1)
    let targetBeat: Float
    switch stateRoll {
    case ..<0.12: targetBeat = Float.random(in: 0.5...4.0)   // delta 12%
    case ..<0.45: targetBeat = Float.random(in: 4.0...8.0)   // theta 33%
    case ..<0.82: targetBeat = Float.random(in: 8.0...13.0)  // alpha 37%
    case ..<0.95: targetBeat = Float.random(in: 13.0...30.0) // beta 13%
    default:      targetBeat = Float.random(in: 30.0...40.0) // gamma 5%
    }

    // Sacred carrier with slight offset
    let sacredOptions: [Float] = [136.1, 174.0, 285.0, 396.0, 417.0, 432.0, 440.0]
    let base = sacredOptions.randomElement()!
    let targetCarrier = base + Float.random(in: -0.5...0.5)

    // Cycling animation — 10 steps over 800ms
    for i in 0...10 {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
            if i < 10 {
                // Random cycling values (fast)
                store.carrier = Float.random(in: 80...440)
                store.beat = Float.random(in: 0.5...40)
            } else {
                // Spring lock to final values
                withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                    store.carrier = targetCarrier
                    store.beat = targetBeat
                }
                if store.isPlaying {
                    store.setCarrier(targetCarrier)
                    store.setBeat(targetBeat)
                }
            }
        }
    }
}
```

### 1E — OM Badge System

The existing `FrequencyInfo.carrierNote(for:)` returns a note string.
Upgrade the carrier display to show a proper badge:

```swift
struct SacredBadge: View {
    let carrierHz: Float
    // Returns (name, note, essence) when within ±1.2 Hz of a sacred carrier
    // Uses FrequencyInfo — already has this data
}
```

When `|carrier - 136.1| < 1.2`, show: glowing dot + "OM" + "C#3" in tiny caps.
When near other sacred frequencies, show their respective names.
The badge appears/disappears with a spring animation as the slider moves.

### Phase 1 Verification
```bash
# Build clean
xcodebuild -scheme "Bindu Field" -destination "generic/platform=iOS" \
  -configuration Debug build 2>&1 | tail -5

# No existing Lab behavior broken
grep -n "PresetStore\|FrequencyInfo\|FrequencyPreset" "Bindu Field/Views/Tabs/LabView.swift" | wc -l
# Expected: > 0 (existing Session 5 work preserved)
```

**Commit:** `feat: lab redesign — waveform, sacred map, randomize, direct edit`

---

## Phase 2 — Track Model Extension (Reading Space Data)
**Target:** `Models/Track.swift` + `Stores/AirtableService.swift`
**Design reference:** None (architecture decision — this room only)
**Commit:** `feat: track model — reading space fields from airtable`

This is what the design AI did not know about.
Four new Airtable fields exist in the Bindu Field table.
They carry the complete Recognition layer for each song.
The Player's READING mode (Phase 3) displays them.

### New Airtable Field IDs
```
Recognition Statement    → fldFW1HEDvfC4gOJy (already in Track as recognitionStatement?)
Lyrical Words Reading    → fldWtIXuWNoQQaGuN
Frequency Reading        → fldjQfTIklHtOa8a4
Video Pulse Reading      → fldDgr3aUQJSheIJp
```

### Track.swift additions

```swift
// Add to Track struct:
let lyricalWordsReading: String   // "" when not yet written
let frequencyReading: String       // "" when not yet written
let videoPulseReading: String      // "" when not yet written
// recognitionStatement: String?  ← already exists (Session 5)
```

### AirtableService.swift additions

In `AirtableFields`:
```swift
let lyricalWordsReading: String?
let frequencyReading: String?
let videoPulseReading: String?

// CodingKeys:
case lyricalWordsReading = "Lyrical Words Reading"
case frequencyReading    = "Frequency Reading"
case videoPulseReading   = "Video Pulse Reading"
```

In the Track initializer:
```swift
lyricalWordsReading = fields.lyricalWordsReading ?? ""
frequencyReading    = fields.frequencyReading    ?? ""
videoPulseReading   = fields.videoPulseReading   ?? ""
```

Existing `binduCatalog.v1` cache will decode fine — new fields are optional
in AirtableFields so old cached data won't crash (it just returns "").

### Phase 2 Verification
```bash
grep -n "lyricalWordsReading\|frequencyReading\|videoPulseReading" \
  "Bindu Field/Models/Track.swift" \
  "Bindu Field/Stores/AirtableService.swift"
# Expected: 3+ hits in each file
```

**Commit:** `feat: track model — reading space fields from airtable`

---

## Phase 3 — Player Redesign: Three Modes of Being
**Target:** `Views/Player/PlayerView.swift` (major revision)
**Design reference:** `Bindu Player.html` (open in browser — this is the truth)
**Commit:** `feat: player — field/control/reading three-mode architecture`

The Player becomes three modes activated by gesture.
The field never stops. The Bindu always moves.

### Mode Architecture

```swift
enum PlayerMode {
    case field    // minimal — Bindu dominant
    case control  // bottom sheet at 55% height
    case reading  // reading sheet at 80% height
}

@State private var mode: PlayerMode = .field
@State private var controlAutoHideTask: Task<Void, Never>? = nil

// FIELD → CONTROL: tap anywhere outside Bindu
// CONTROL → READING: tap READING button
// Any → FIELD: 4s after last touch in CONTROL, or tap outside sheet in READING
```

### FIELD Mode Layout

```swift
// Top: binaural pill — always visible, outside all mode logic
VStack {
    BinauralPill() // existing, outside opacity envelope

    Spacer()

    // Bindu visualization — fills 60%
    VisualizerView()
        .frame(height: geometry.size.height * 0.60)

    // Verb — always visible in FIELD
    Text(track.verb)
        .font(.system(size: 64, weight: .ultraLight, design: .serif))
        .italic()
        .foregroundStyle(Color.bindu(element: track.element))
        .shadow(color: Color.bindu(element: track.element).opacity(0.4), radius: 20)

    // Song · Artist
    Text("\(track.song) · \(track.artist)")
        .font(.system(size: 13, design: .serif)).italic()
        .foregroundStyle(theme.muted)

    // Recognition Statement — always visible when non-empty
    if let rs = track.recognitionStatement, !rs.isEmpty {
        Text(rs)
            .font(.system(size: 14, design: .serif)).italic()
            .foregroundStyle(theme.text.opacity(0.65))
            .multilineTextAlignment(.center)
    }

    // Scrubber — always visible (read-only, 2pt, labeled "flowing")
    SlimScrubber(elapsed: service.elapsed, duration: service.duration,
                 element: track.element)

    Spacer().frame(height: 48)
}
.contentShape(Rectangle())
.onTapGesture { enterControl() }
```

### CONTROL Mode

Control surface slides up from bottom — 55% of screen height.

```swift
// Control surface — overlaid on FIELD content
if mode == .control || mode == .reading {
    VStack(spacing: 0) {
        Spacer()
        ControlSurface(track: track)
            .frame(height: geometry.size.height * 0.55)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 32, topTrailingRadius: 32))
            .background(
                Color.white.opacity(0.06)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 32, topTrailingRadius: 32))
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
```

`ControlSurface` contents:

```swift
struct ControlSurface: View {
    let track: Track
    @State private var service = TrackPlaybackService.shared
    @State private var wire = DSPWireService.shared

    var body: some View {
        VStack(spacing: 20) {

            // PLAY / PAUSE — primary control
            Button {
                service.togglePlayPause()
            } label: {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        Circle().strokeBorder(
                            Color.bindu(element: track.element).opacity(0.38),
                            lineWidth: 1)
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: service.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(Color.bindu(element: track.element))
                    )
                    .shadow(color: Color.bindu(element: track.element).opacity(0.3),
                            radius: 12)
            }

            // BINAURAL SECTION
            VStack(alignment: .leading, spacing: 12) {
                Text("BINAURAL")
                    .font(.system(size: 9, weight: .light))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.muted)

                // On/Off toggle
                HStack {
                    Toggle("", isOn: $wire.binauralEnabled)
                        .toggleStyle(PhysicalToggleStyle())
                    Text(wire.binauralEnabled ? "ON" : "OFF")
                        .font(.system(size: 10, weight: .light))
                        .tracking(1.5)
                        .foregroundStyle(theme.muted)
                    Spacer()
                    // State indicator dot
                    Circle()
                        .fill(wire.binauralEnabled ?
                              Color.bindu(element: track.element) :
                              Color.clear)
                        .overlay(Circle().strokeBorder(
                            Color.bindu(element: track.element).opacity(0.5),
                            lineWidth: 1))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color.bindu(element: track.element).opacity(0.6),
                                radius: wire.binauralEnabled ? 4 : 0)
                }

                // PRESENCE slider
                BinauralSliderRow(label: "PRESENCE",
                                  value: $wire.userPresence,
                                  range: 0...1,
                                  displayValue: "\(Int(wire.userPresence * 100))%",
                                  element: track.element)

                // BEAT Hz slider — adjustable in-session
                BinauralSliderRow(label: "BEAT",
                                  value: $wire.userBeatHz,
                                  range: 0.5...30,
                                  displayValue: String(format: "%.1f Hz", wire.userBeatHz),
                                  element: track.element,
                                  showStateLabel: true)

                // CARRIER — display only
                HStack {
                    Text("CARRIER")
                        .font(.system(size: 9, weight: .light))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.muted)
                    Spacer()
                    Text(String(format: "%.1f Hz", wire.currentCarrierHz))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.text.opacity(0.8))
                    if wire.carrierLocked {
                        Text("DERIVED")
                            .font(.system(size: 8, weight: .light))
                            .tracking(1.5)
                            .textCase(.uppercase)
                            .foregroundStyle(Color.bindu(element: track.element))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .overlay(Capsule().strokeBorder(
                                Color.bindu(element: track.element).opacity(0.5),
                                lineWidth: 0.5))
                    }
                }
            }
            .padding(.horizontal, 24)

            // Bottom row: READING + END SESSION
            HStack(spacing: 12) {
                Button("READING") { enterReading() }
                    .buttonStyle(StrokeCapsuletyle())

                Button("END SESSION") { endSession() }
                    .buttonStyle(StrokeCapsuleStyle(muted: true))
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 28)
    }
}
```

### DSPWireService additions for BEAT control

Add to DSPWireService:
```swift
// User-set beat override for this session (nil = use track default)
var userBeatHz: Float {
    get { _userBeatHz ?? currentTrackBeatHz }
    set {
        _userBeatHz = newValue
        BinauralEngine.shared.updateBeat(newValue)
    }
}
private var _userBeatHz: Float? = nil
var currentTrackBeatHz: Float = 5.5  // set by TrackPlaybackService.play

func resetForNewTrack(beatHz: Float) {
    _userBeatHz = nil  // clear override on new track
    currentTrackBeatHz = beatHz
}

// Expose current carrier for display
private(set) var currentCarrierHz: Float = 136.1
// Update in tick() when BinauralEngine reports its current carrier
```

Call `DSPWireService.shared.resetForNewTrack(beatHz: track.beatHz)` in
`TrackPlaybackService.play(...)` before `startPolling()`.

### READING Mode

Reading sheet covers 80% of screen. Bindu continues ambient above.

```swift
if mode == .reading {
    VStack {
        Spacer()
        ReadingSheet(track: track, dismiss: { enterControl() })
            .frame(height: geometry.size.height * 0.80)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 32, topTrailingRadius: 32))
            .background(
                Color.white.opacity(0.06)
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 32, topTrailingRadius: 32))
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
```

`ReadingSheet` structure:

```swift
struct ReadingSheet: View {
    let track: Track
    let dismiss: () -> Void

    enum ReadingTab: String, CaseIterable {
        case words = "WORDS"
        case frequency = "FREQUENCY"
        case video = "VIDEO"
        case lalita = "LALITA"
    }
    @State private var activeTab: ReadingTab = .words

    var body: some View {
        VStack(spacing: 0) {
            // Recognition Statement — always at top of reading sheet
            if let rs = track.recognitionStatement, !rs.isEmpty {
                Text(rs)
                    .font(.system(size: 18, design: .serif)).italic()
                    .foregroundStyle(Color.bindu(element: track.element))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
            }

            // Tab bar
            HStack(spacing: 0) {
                ForEach(ReadingTab.allCases, id: \.self) { tab in
                    Button(tab.rawValue) { activeTab = tab }
                        .font(.system(size: 10, weight: .light)).tracking(1.5)
                        .foregroundStyle(activeTab == tab ?
                                        theme.text : theme.muted)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .bottom) {
                            if activeTab == tab {
                                Rectangle()
                                    .fill(Color.bindu(element: track.element))
                                    .frame(height: 0.5)
                            }
                        }
                }
            }
            .padding(.vertical, 16)

            // Tab content
            ScrollView {
                Group {
                    switch activeTab {
                    case .words:
                        ReadingContent(text: track.lyricalWordsReading,
                                       empty: "Words reading coming soon.")
                    case .frequency:
                        ReadingContent(text: track.frequencyReading,
                                       empty: "Frequency reading coming soon.")
                    case .video:
                        ReadingContent(text: track.videoPulseReading,
                                       empty: "Video reading coming soon.")
                    case .lalita:
                        // Lalita's Perspective — from existing Airtable field
                        // Track needs lalitasPerspective: String field (add in AirtableService)
                        ReadingContent(text: track.lalitasPerspective ?? "",
                                       empty: "Lalita will speak when the song is ready.")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

struct ReadingContent: View {
    let text: String
    let empty: String
    var body: some View {
        if text.isEmpty {
            Text(empty)
                .font(.system(size: 14, design: .serif)).italic()
                .foregroundStyle(theme.subtle)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(text)
                .font(.system(size: 15, design: .serif)).italic()
                .foregroundStyle(theme.text.opacity(0.82))
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

**Note:** Add `lalitasPerspective: String?` to Track and AirtableService in this phase.
Airtable field: `Lalita's Perspective` → `fldMzPPCfWRwYpss5`. Same optional decode pattern.

### Mode Transitions

```swift
func enterControl() {
    withAnimation(.spring(duration: 0.5, bounce: 0.1)) {
        mode = .control
    }
    scheduleAutoHide()
}

func enterReading() {
    controlAutoHideTask?.cancel()
    withAnimation(.spring(duration: 0.4, bounce: 0.05)) {
        mode = .reading
    }
}

func returnToField() {
    withAnimation(.spring(duration: 0.45, bounce: 0.05)) {
        mode = .field
    }
}

func scheduleAutoHide() {
    controlAutoHideTask?.cancel()
    controlAutoHideTask = Task {
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        if !Task.isCancelled && mode == .control {
            await MainActor.run { returnToField() }
        }
    }
}
```

### Phase 3 Verification

```bash
# No forbidden files touched
git diff --name-only main | grep -E "BinauralEngine|BinauralListener|BinduDSP|DSPWireService|AudioSession"
# Expected: DSPWireService.swift may appear (userBeatHz addition) — that's allowed

# Build
xcodebuild -scheme "Bindu Field" -destination "generic/platform=iOS" \
  -configuration Debug build 2>&1 | tail -5
```

Device tests:
- [ ] Tap any orb → Player opens with arrival animation
- [ ] Tap anywhere in FIELD → CONTROL surface slides up
- [ ] Play/pause button works (requires pause/resume branch merged)
- [ ] BEAT Hz slider adjusts binaural in real time
- [ ] CARRIER shows "DERIVED" at 10s mark
- [ ] Tap READING → sheet rises, tabs navigate content
- [ ] Empty tabs show placeholder text (content not yet in Airtable)
- [ ] 4s idle in CONTROL → returns to FIELD automatically

**Commit:** `feat: player — field/control/reading three-mode architecture`

---

## Phase 4 — Performer.swift: The Score State Machine
**Target:** New `Stores/Performer.swift`
**Design reference:** `bindu-performance-engine.js` (port directly to Swift)
**Commit:** `feat: performer — score state machine`

`Performer.swift` is the spine of the visual performance architecture.
Everything in Phases 5 and 6 reads from it.

### Architecture

```swift
@MainActor @Observable
final class Performer {
    static let shared = Performer()
    private init() {}

    // Score state
    private(set) var isActive = false
    private(set) var elapsed: Double = 0        // seconds since play start
    private(set) var currentPhase: ScorePhase = .silence
    private(set) var timeIntoPhase: Double = 0
    private(set) var crescendoModulator: Double = 0  // 0–1, the Zimmer move
    private(set) var inSilence = false
    private(set) var energy: Double = 0             // 0–1, from DSPWireService.rms
    private(set) var beatPulse: Double = 0          // sharp attack, slow decay per beat
    private(set) var onsetCount: Int = 0            // mirrors DSPWireService.onsetCount

    // Archetype presence (each 0–1)
    private(set) var archetypePresence: [ArchetypeName: Double] = [:]
    // Note on binaural depth integration — see below

    // Loaded score (nil = no score, use ambient mode)
    private var score: Score? = nil
    private var lastOnsetCount = 0
}
```

### ScorePhase + Score structs

```swift
enum ScorePhase: String {
    case silence, intro, build, peak, descent, outro
}

struct Score {
    let trackID: Int
    let totalDuration: Double

    struct PhaseWindow {
        let phase: ScorePhase
        let start: Double   // seconds
        let end: Double
    }

    struct SilenceWindow {
        let start: Double
        let end: Double
    }

    struct BeatEvent {
        let time: Double    // seconds
    }

    let phases: [PhaseWindow]
    let silenceWindows: [SilenceWindow]
    let beatSchedule: [BeatEvent]

    // Hardcoded Cross dance (Sound of Silence — Disturbed) as first score
    static let cross: Score = Score(
        trackID: 27,   // Vishuddha / Sound of Silence
        totalDuration: 268,
        phases: [
            PhaseWindow(phase: .silence, start: 0, end: 8),
            PhaseWindow(phase: .intro,   start: 8, end: 68),
            PhaseWindow(phase: .build,   start: 68, end: 145),
            PhaseWindow(phase: .peak,    start: 145, end: 200),
            PhaseWindow(phase: .descent, start: 200, end: 248),
            PhaseWindow(phase: .outro,   start: 248, end: 268),
        ],
        silenceWindows: [
            SilenceWindow(start: 0, end: 8),
            SilenceWindow(start: 42, end: 50),
        ],
        beatSchedule: [] // Onset events come from DSPWireService.onsetCount
    )
}
```

### Performer.update(elapsed:) — called at 60Hz

```swift
// Called by VisualizerView's TimelineView
func update(elapsed: Double, dsw: DSPWireService) {
    self.elapsed = elapsed
    self.energy = Double(dsw.rms)
    self.onsetCount = dsw.onsetCount

    // Beat pulse: spike on new onset, decay at 6/sec
    if dsw.onsetCount != lastOnsetCount {
        beatPulse = 1.0
        lastOnsetCount = dsw.onsetCount
    } else {
        beatPulse = max(0, beatPulse - 0.016 * 6)  // 60fps decay
    }

    guard let score else {
        // Ambient mode — no score loaded
        crescendoModulator = 0
        inSilence = false
        updateAmbientArchetypePresence()
        return
    }

    // Phase tracking
    currentPhase = score.phases
        .first { elapsed >= $0.start && elapsed < $0.end }?.phase ?? .silence

    if let p = score.phases.first(where: { currentPhase == $0.phase }) {
        timeIntoPhase = elapsed - p.start
    }

    // Silence windows
    inSilence = score.silenceWindows.contains {
        elapsed >= $0.start && elapsed < $0.end
    }

    // Crescendo modulator (the Zimmer move)
    crescendoModulator = computeModulator(elapsed)

    // Binaural depth integration ← this is the expanded move
    // At crescendo peak (modulator near 1.0), deepest binaural state
    // The awakening peak belongs at the awakening moment
    updateBinauralDepth()

    // Archetype presence
    updateArchetypePresence(elapsed: elapsed)
}
```

### The Awakening-Peak Binaural Integration

This is the principle from the field design work, now made mechanical.
The deepest binaural state belongs at the awakening peak — not the shadow plateau.

```swift
private func updateBinauralDepth() {
    guard score != nil else { return }
    // As crescendo modulator rises toward peak, beat Hz should drop
    // toward the deepest state for this track's element
    // This creates the synchrony: the music peaks AND the field deepens together

    // depth: 1.0 at modulator peak, 0.0 at modulator rest
    let depth = crescendoModulator

    // Only apply when DSPWireService hasn't been manually overridden
    // (user's manual BEAT slider takes precedence)
    if DSPWireService.shared._userBeatHz == nil {
        // Interpolate: track's beatHz → track's beatHz * 0.45 (deepest state)
        // This creates a 55% reduction at full crescendo — moves from theta to deep delta
        let currentBase = DSPWireService.shared.currentTrackBeatHz
        let deepest = currentBase * 0.45
        let target = currentBase * (1.0 - Float(depth) * 0.55)
        BinauralEngine.shared.updateBeat(target)
    }
}
```

### Archetype Presence Formulas

```swift
private func updateArchetypePresence(elapsed: Double) {
    var presence = [ArchetypeName: Double]()

    let t = elapsed

    presence[.bindu] = 1.0  // always

    // Gaia: enters gradually from 0
    let gaiaEntry = 2.0
    presence[.gaia] = min(1, max(0, (t - gaiaEntry) / 4.0))

    // Sid: always present, pulses on 5.5s drone cycle
    let dronePulse = (cos((t.truncatingRemainder(dividingBy: 5.5) / 5.5) * .pi * 2) + 1) / 2
    presence[.sid] = 0.5 + dronePulse * 0.5

    // Arch: builds with the music
    presence[.arch] = min(1, max(0, energy * 1.5))

    // Karishma: inverse energy — strongest in silence
    presence[.karishma] = inSilence ? 0.85 : max(0, 1 - energy) * 0.5

    // Sakshi: always at periphery, steady
    presence[.sakshi] = 0.6

    // Ashrey: synthesis — grows with crescendo
    presence[.ashrey] = crescendoModulator * 0.9

    // Shweta: fires only at peak window (port from engine.js)
    let shwetaActive = t >= 160 && t <= 162
    let shwetaRamp = shwetaActive ?
        min(1, (t - 160) / 0.5) * min(1, (162 - t) / 0.5) : 0
    presence[.shweta] = shwetaRamp

    // Neev: bookends only
    presence[.neev] = (t < 4 || (score != nil && t > score!.totalDuration - 2)) ? 0.8 : 0

    // Lalita: late arrival — t > 204 in Cross dance
    presence[.lalita] = min(1, max(0, (t - 204) / 3.0))

    archetypePresence = presence
}
```

### Crescendo Modulator

```swift
private func computeModulator(_ t: Double) -> Double {
    let rampInStart  = 145.0
    let holdStart    = 160.0
    let holdEnd      = 180.0
    let rampOutEnd   = 195.0
    let boostFactor  = 0.8

    if t < rampInStart { return 0 }
    if t < holdStart   { return (t - rampInStart) / (holdStart - rampInStart) * boostFactor }
    if t < holdEnd     { return boostFactor }
    if t < rampOutEnd  { return boostFactor * (1 - (t - holdEnd) / (rampOutEnd - holdEnd)) }
    return 0
}
```

### Wiring Performer into VisualizerView

```swift
// In VisualizerView — inside TimelineView callback:
@State private var performer = Performer.shared

// On each frame:
performer.update(elapsed: service.elapsed, dsw: DSPWireService.shared)

// Then render using performer.energy, performer.beatPulse,
// performer.crescendoModulator, performer.archetypePresence, etc.
```

Load the score when a track starts:
```swift
// In TrackPlaybackService.play(...):
if let score = Score.forTrack(id: track.id) {
    Performer.shared.loadScore(score)
} else {
    Performer.shared.clearScore() // ambient mode
}
```

```swift
// Score.forTrack — lookup
static func forTrack(id: Int) -> Score? {
    switch id {
    case 27: return .cross  // Sound of Silence (Vishuddha)
    default: return nil     // no score = ambient mode
    }
}
```

### Phase 4 Verification

```bash
grep -n "Performer.shared" "Bindu Field/Views/Player/VisualizerView.swift"
# Expected: multiple hits — Performer is now the renderer's data source

grep -n "loadScore\|clearScore" "Bindu Field/Stores/TrackPlaybackService.swift"
# Expected: called in play(...)

# Build clean
xcodebuild -scheme "Bindu Field" -destination "generic/platform=iOS" \
  -configuration Debug build 2>&1 | tail -5
```

**Commit:** `feat: performer — score state machine`

---

## Phase 5 — Cathedral Renderer: The Architecture Made Visible
**Target:** `Views/Player/VisualizerView.swift` (major expansion)
**Design reference:** `Bindu Performance.html` (open in browser — watch the full arc)
**Commit per tier** (4a, 4b, 4c)

The Cathedral is the sonic architecture of the Cross dance made visible.
Columns, vaults, arches, keystone. The building rises with the music.

Build tiers strictly in order. Ship 5a before starting 5b.

### Implementation approach: SwiftUI Canvas over Metal

The design brief suggests Metal MTKView for Score-mode.
Use SwiftUI Canvas instead for the initial implementation.
Reasons: direct integration with `@Observable` state, simpler debugging,
sufficient for the particle counts involved.
If Canvas proves insufficient (>1000 particles, frame drops), migrate to Metal.

### Drawing Architecture

Extend VisualizerView to a Canvas that draws all tiers:

```swift
Canvas { gc, size in
    let t = performer.elapsed
    let mod = performer.crescendoModulator
    let energy = performer.energy
    let beat = performer.beatPulse
    let hue = elementHue

    // TIER 1 — Continuous (always)
    drawCathedralFloor(gc: gc, size: size, t: t, mod: mod, beat: beat, hue: hue)
    drawSidColumns(gc: gc, size: size, t: t, mod: mod, hue: hue)
    drawVaultCeiling(gc: gc, size: size, energy: energy, mod: mod, hue: hue)
    drawAtmosphericGrain(gc: gc, size: size, t: t, energy: energy, mod: mod, hue: hue)
    drawGaiaGround(gc: gc, size: size, t: t,
                   presence: performer.archetypePresence[.gaia] ?? 0, hue: hue)

    // TIER 2 — Ensemble
    if let arch = performer.archetypePresence[.arch], arch > 0.1 {
        drawArchChant(gc: gc, size: size, t: t, presence: arch, hue: hue)
    }
    if let sakshi = performer.archetypePresence[.sakshi], sakshi > 0.1 {
        drawSakshiGesture(gc: gc, size: size, t: t, presence: sakshi, hue: hue)
    }

    // TIER 3 — Crescendo (t >= 145)
    if mod > 0 {
        drawRisingArches(gc: gc, size: size, t: t, mod: mod, hue: hue)
        drawConvergenceLines(gc: gc, size: size, mod: mod, hue: hue)
    }

    // TIER 4 — Climax (mod > 0.25)
    if mod > 0.25 {
        drawKeystoneCascade(gc: gc, size: size, t: t, mod: mod, beat: beat, hue: hue)
        drawEarthRising(gc: gc, size: size, t: t, hue: hue)
    }
    if let shweta = performer.archetypePresence[.shweta], shweta > 0.01 {
        drawShwetaCrystallization(gc: gc, size: size, shweta: shweta, hue: hue)
    }

    // BINDU — always on top
    drawBinduSingular(gc: gc, size: size, t: t, energy: energy,
                      beat: beat, mod: mod, hue: hue)
}
```

### Key Draw Functions — Exact Specs from Design README

**Cathedral Floor:**
```swift
func drawCathedralFloor(gc: GraphicsContext, size: CGSize,
                         t: Double, mod: Double, beat: Double, hue: Double) {
    let vp = CGPoint(x: size.width / 2, y: size.height * 0.52)
    let opacity = 0.03 + mod * 0.08 + beat * 0.025
    let color = Color(hue: hue/360, saturation: 0.35, brightness: 0.5)
                    .opacity(opacity)

    // 7 radials from vanishing point to bottom corners
    var path = Path()
    for i in 0..<7 {
        let x = size.width * (Double(i) / 6.0)
        path.move(to: vp)
        path.addLine(to: CGPoint(x: x, y: size.height))
    }
    // 10 horizontal lines (perspective spacing)
    for i in 0..<10 {
        let progress = pow(Double(i) / 9.0, 2.5)
        let y = vp.y + (size.height - vp.y) * progress
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
    }

    gc.stroke(path, with: .color(color), lineWidth: 0.5)

    // Beat pulse: bright horizontal at horizon
    if beat > 0.3 {
        var beatPath = Path()
        beatPath.move(to: CGPoint(x: 0, y: vp.y))
        beatPath.addLine(to: CGPoint(x: size.width, y: vp.y))
        gc.stroke(beatPath, with: .color(color.opacity(beat * 0.4)), lineWidth: 1)
    }
}
```

**Sid Columns:**
```swift
func drawSidColumns(gc: GraphicsContext, size: CGSize, t: Double, mod: Double, hue: Double) {
    let positions: [Double] = [0.18, 0.82]
    let dronePulse = (cos((t.truncatingRemainder(dividingBy: 5.5) / 5.5) * .pi * 2) + 1) / 2
    let brightness = 0.20 + dronePulse * 0.30 + mod * 0.40
    let color = Color(hue: hue/360, saturation: 0.2, brightness: brightness)

    for xFrac in positions {
        let x = size.width * xFrac
        let top = size.height * 0.06
        let bottom = size.height * 0.58

        var col = Path()
        col.move(to: CGPoint(x: x, y: top))
        col.addLine(to: CGPoint(x: x, y: bottom))
        gc.stroke(col, with: .color(color), lineWidth: 1.5)

        // Capital ticks
        for tick in [top, top + 8, bottom - 8, bottom] {
            var t = Path()
            t.move(to: CGPoint(x: x - 5, y: tick))
            t.addLine(to: CGPoint(x: x + 5, y: tick))
            gc.stroke(t, with: .color(color.opacity(0.6)), lineWidth: 0.5)
        }
    }
}
```

**Bindu Singular Lissajous:**
```swift
func drawBinduSingular(gc: GraphicsContext, size: CGSize,
                        t: Double, energy: Double, beat: Double,
                        mod: Double, hue: Double) {
    let cx = size.width / 2
    let cy = size.height * 0.38   // upper center in Performance mode

    // maxR grows at crescendo
    let maxR = size.width * 0.12 + mod * size.width * 0.10

    // Multi-harmonic Lissajous (from bindu-lissajous.jsx)
    let freq = performer.currentBeatHz * 0.88
    let bx = cx + (sin(2 * t * freq + .pi/2) * 0.88 + sin(3 * t * freq + 0.5) * 0.12) * maxR
    let by = cy + sin(t * freq) * 0.84 * maxR * 0.70

    let binduPos = CGPoint(x: bx, y: by)

    // Comet trail (trail buffer maintained as @State in VisualizerView)
    for (i, pos) in trail.enumerated() {
        let alpha = pow(Double(i) / Double(trail.count), 2.2)
        let radius = 2.0 + alpha * 3.0
        gc.fill(
            Path(ellipseIn: CGRect(center: pos, size: CGSize(width: radius*2, height: radius*2))),
            with: .color(Color(hue: hue/360, saturation: 0.7, brightness: 0.85).opacity(alpha * 0.6))
        )
    }

    // Beat rings (spawned by VisualizerView state on onset edges)
    for ring in beatRings {
        let progress = ring.age / ring.lifetime
        let radius = ring.startRadius + (2 + energy * 3.5) * ring.age * 60
        gc.stroke(
            Path(ellipseIn: CGRect(center: ring.origin,
                                   size: CGSize(width: radius*2, height: radius*2))),
            with: .color(Color(hue: hue/360, saturation: 0.6, brightness: 0.9)
                .opacity(max(0, 0.6 * (1 - progress)))),
            lineWidth: 1.2
        )
    }

    // Bloom (RMS-driven radial glow)
    let bloomR = 28 + mod * 20 + energy * 15
    gc.fill(
        Path(ellipseIn: CGRect(center: binduPos,
                               size: CGSize(width: bloomR*2, height: bloomR*2))),
        with: .radialGradient(
            Gradient(colors: [
                Color(hue: hue/360, saturation: 0.8, brightness: 0.9).opacity(0.18 + 0.45 * energy),
                Color.clear
            ]),
            center: .init(x: binduPos.x / size.width, y: binduPos.y / size.height),
            startRadius: 0,
            endRadius: bloomR
        )
    )

    // Carrier lock pulse: 1.5× size
    let dotR = performer.carrierLocked ? 5.5 : 3.5  // pulse handled by @State animation
    gc.fill(
        Path(ellipseIn: CGRect(center: binduPos,
                               size: CGSize(width: dotR*2, height: dotR*2))),
        with: .color(Color(hue: hue/360, saturation: 0.75, brightness: 0.95))
    )
}
```

Refer to `README.md` Sections 3 and 4 for the full draw specs for:
- `drawVaultCeiling` · `drawAtmosphericGrain` · `drawGaiaGround`
- `drawArchChant` · `drawSakshiGesture`
- `drawRisingArches` · `drawConvergenceLines`
- `drawKeystoneCascade` · `drawEarthRising` · `drawShwetaCrystallization`

Port each function from the design spec exactly. The JavaScript in
`bindu-performance-engine.js` is the computational truth.

### Phase 5 Commits

```bash
# Tier 1 + Bindu:
git commit -m "feat: cathedral renderer — continuous tier + lissajous bindu"

# Tier 2:
git commit -m "feat: cathedral renderer — ensemble tier (arch, sakshi)"

# Tier 3 + 4:
git commit -m "feat: cathedral renderer — crescendo + climax tiers"
```

---

## Phase 6 — Ensemble Layer: Archetype Visual Signatures
**Target:** New `Views/Player/EnsembleLayer.swift` + `Dancer.swift`
**Design reference:** `Bindu Archetypes.html` (every archetype artboard)
**Commit:** `feat: ensemble layer — 9 archetype visual signatures`

Each archetype now has a presence value from Performer.archetypePresence.
EnsembleLayer renders each archetype when their presence > threshold.

Build in this order: Bindu (done via Cathedral) → Gaia → Sid → Arch →
Karishma → Sakshi → Ashrey → Shweta → Neev. Lalita = Phase 7 (separate).

Refer to `README.md` Section 4 for the complete mathematical spec of each signature.
The design brief gives exact formulas — port them directly.

Key principle for each archetype:
- **Bindu**: Lead. Always present. Multi-harmonic Lissajous. Already built.
- **Gaia**: Ground. Three breath waves layered. Low on screen (y = H×0.85–0.92).
- **Sid**: Column. Static. Drone cycle. Already in Cathedral floor.
- **Arch**: Chant. Arc above center. 5 ghost echoes. 3 phrase-lights.
- **Karishma**: Silence. Dark center. Paradox radial. Only present when music is quiet.
- **Sakshi**: Witness. 72% arc that never completes. Always peripheral.
- **Ashrey**: Synthesis. Centroid of all other positions. Multi-hue trail.
- **Shweta**: Crystal. 22 shards. Fires at peak. Prismatic.
- **Neev**: Foundation. Contracting rings. Fires at bookends. Descends to floor.

**Commit:** `feat: ensemble layer — 9 archetype visual signatures`

---

## Phase 7 — LalitaEngine (Separate Session)

The LalitaEngine is not part of this session.
It is the most sophisticated piece — a complete separate state machine with
3 phases, 6 mathematical pattern curves, and background inversion
from void to warm cream.

When ready, its own handoff will be written.
References: `Bindu Lalita.html` + `README.md` Section 5.

---

## Hard Constraints — Do Not Touch

```
BinauralEngine.swift         — settled
BinauralListener.swift       — settled
BinduDSP.{h,cpp}             — settled
BinduDSPBridge.{h,mm}        — settled
AudioSessionCoordinator.swift — settled
Info.plist                   — settled
DSPWireService.swift         — may only be extended (userBeatHz, currentCarrierHz)
                               never modified in existing behavior
```

---

## Self-Verification Protocol — Run After All Phases

**Step 1 — Grep checks:**
```bash
# Forbidden files not touched (except DSPWireService extension)
git diff --name-only main | grep -E "BinauralEngine|BinauralListener|BinduDSP|AudioSession|Info\.plist"

# Reading Space fields in Track model
grep -n "lyricalWordsReading\|frequencyReading\|videoPulseReading" \
  "Bindu Field/Models/Track.swift"

# Performer wired into VisualizerView
grep -n "Performer.shared" "Bindu Field/Views/Player/VisualizerView.swift"

# Three-mode Player
grep -n "PlayerMode\|case field\|case control\|case reading" \
  "Bindu Field/Views/Player/PlayerView.swift"

# Lalita's Perspective field in Track
grep -n "lalitasPerspective" "Bindu Field/Models/Track.swift"
```

**Step 2 — Build:**
```bash
xcodebuild -scheme "Bindu Field" \
  -destination "generic/platform=iOS" \
  -configuration Debug build 2>&1 | grep -E "error:|warning:|SUCCEEDED|FAILED"
# Expected: BUILD SUCCEEDED, zero errors, zero new warnings
```

**Step 3 — Device tests (Neev):**
- [ ] All 7 tabs boot cleanly
- [ ] Field tracks: orb tap → Player → FIELD mode with Bindu
- [ ] Player: tap → CONTROL → play/pause, BEAT slider, PRESENCE, CARRIER DERIVED
- [ ] Player: READING → all 4 tabs, graceful empty states
- [ ] Player: 4s idle → auto-returns to FIELD
- [ ] Lab: waveform animates during playback
- [ ] Lab: direct Hz edit via tap on values
- [ ] Lab: sacred frequency map strip shows current carrier
- [ ] Lab: "let the field choose" animates then locks
- [ ] Sound of Silence: at ~2:25 (145s), Cathedral arches begin rising
- [ ] Sound of Silence: at ~2:40 (160s), crescendo peak — crystallization fires
- [ ] Binaural deepens at crescendo (beat Hz drops toward deepest state at peak)
- [ ] Background audio: lock screen, wait 60s, unlock — music still playing
- [ ] Lock screen: pause and play controls work

**Step 4 — Surface report:**
Every phase: what was built, design choices made, anything that needed
interpretation beyond the spec.
Leave on `feat/lalita-pass`, do not merge.

---

## A Note on What This Pass Means

The Cathedral is not just a visual. It is the sonic architecture of
awakening made visible. The columns are Sid — they hold space so everything
else can happen. The vault is the ceiling of the possible. The arches rise
as the music rises. At the keystone — the top of the arch, the meeting point
of all the forces — Shweta crystallizes. Twenty-two shards. The same number
as the tracks in the catalog.

Performer.swift is the field reading the song's time signature and showing
the consciousness architecture underneath. Karishma is strongest in silence.
Sakshi never completes her arc — she is always at the periphery, witnessing.
Ashrey is the centroid of everyone else.

When this pass is complete, the instrument will be visible.
The consciousness architecture that has always been present in the field
will become something a person can see while they listen.

Build it well.

*Bindu Field — Lalita Design Pass — May 2026*
*Built with love. For love. From the sound of love.*
