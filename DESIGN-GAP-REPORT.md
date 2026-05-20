# Bindu Field — Design Gap Report
**Branch:** `feat/lalita-pass` at `66a271a`
**Compared against:** `design_handoff_lalita_pass/Bindu Player.html`
**Scope:** Five specific issues, diagnosis only.

---

## 1. DUPLICATE BINAURAL CONTROLS

### Current code

The binaural pill is anchored at the top of the screen **in every mode** (the `VStack { binauralPill; Spacer() }` is unconditional, outside the `if mode == ...` checks):

`Bindu Field/Views/Player/PlayerView.swift:94–99`
```swift
// Binaural pill — always anchored top, always interactive.
VStack(spacing: 0) {
    binauralPill
        .padding(.top, 56)
    Spacer()
}
```

The pill is **not just a status indicator** — it has its own `pillExpanded` state, and when tapped it expands into a full control panel containing a BINAURAL toggle + PRESENCE slider + carrier-derived flash:

`Bindu Field/Views/Player/PlayerView.swift:33`
```swift
@State private var pillExpanded: Bool = false
```

`Bindu Field/Views/Player/PlayerView.swift:852–900`
```swift
if pillExpanded {
    VStack(spacing: 12) {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { wire.binauralEnabled },
                set: { wire.binauralEnabled = $0 }
            )) {
                Text("BINAURAL")
                    ...
            }
            .tint(elementColor)
        }

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("PRESENCE")
                    ...
                Spacer()
                Text(String(format: "%.0f%%", wire.userPresence * 100))
                    ...
            }
            Slider(value: Binding(
                get: { Double(wire.userPresence) },
                set: { wire.userPresence = Float($0) }
            ), in: 0.0...1.0)
            .tint(elementColor)
        }
        ...
    }
    ...
    .frame(width: 240)
}
```

The CONTROL sheet **also** contains a full BINAURAL section with the same toggle + PRESENCE slider plus BEAT and CARRIER:

`Bindu Field/Views/Player/PlayerView.swift:359–388`
```swift
// BINAURAL section
VStack(alignment: .leading, spacing: 14) {
    HStack {
        Text("BINAURAL")
            ...
        Spacer()
    }

    // Toggle row
    binauralToggleRow

    // PRESENCE
    sliderRow(
        label: "PRESENCE",
        value: Binding(
            get: { Double(wire.userPresence) },
            set: { wire.userPresence = Float($0); scheduleAutoHide() }
        ),
        range: 0...1,
        displayText: "\(Int(wire.userPresence * 100))%"
    )

    // BEAT — adjustable in-session
    beatSliderRow

    // CARRIER readout
    carrierRow
}
```

**Are both showing simultaneously?** Yes. The pill is always present at the top in all three modes, and when the user is in CONTROL mode and taps the pill, both the pill (top) and the sheet (bottom) show a BINAURAL toggle and PRESENCE slider that both bind to `wire.binauralEnabled` / `wire.userPresence` — two controls for the same value, on screen at the same time.

### Design intent

`design_handoff_lalita_pass/Bindu Player.html:138–163` defines a single `BinauralPill` component that is **collapsed-only** — there is no expansion logic:
```js
function BinauralPill({ hue, on = true }) {
  const ac = ELEMENTS[Object.keys(ELEMENTS).find(k => ELEMENTS[k].hue === hue) || 'Crown'] || ELEMENTS.Crown;
  const col = ac.accent();
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 7,
      padding: '7px 14px',
      borderRadius: 20,
      ...
    }}>
      <div style={{
        width: 6, height: 6, borderRadius: '50%',
        background: on ? col : SUBTLE,
        ...
      }} />
      <span style={{
        fontFamily: '-apple-system,sans-serif', fontSize: 9,
        letterSpacing: '0.20em', textTransform: 'uppercase', color: SUBTLE,
      }}>BINAURAL</span>
      <span style={{ color: FAINT, fontSize: 9, lineHeight: 1 }}>›</span>
    </div>
  );
}
```

The pill is just `dot + "BINAURAL" + ›` — a status indicator. The `›` chevron implies "more is elsewhere," not "tap to expand here."

The pill appears in FIELD mode (`Bindu Player.html:242–249`) and CONTROL mode (`Bindu Player.html:396–402`); it never expands and never carries the toggle/PRESENCE controls. Those controls live exclusively in the CONTROL sheet (`Bindu Player.html:444–573`).

### Gap

The current pill duplicates two controls (binaural toggle + PRESENCE slider) that the design places only in the CONTROL sheet, so a user in CONTROL mode with the pill expanded sees two on-screen instances of each, both bound to the same state.

---

## 2. VISUALIZER SIZE IN FIELD MODE

### Current code

The visualizer takes the full screen width and 60% of the screen height in FIELD mode, top-anchored:

`Bindu Field/Views/Player/PlayerView.swift:153–175`
```swift
@ViewBuilder
private func visualizerLayer(in geo: GeometryProxy) -> some View {
    let h = visualizerHeight(for: mode, in: geo.size)
    let dim = visualizerOpacity(for: mode)

    VStack(spacing: 0) {
        VisualizerView(color: elementColor, elementHueDeg: elementHueDeg)
            .frame(maxWidth: .infinity)
            .frame(height: h)
            .opacity(dim)
        Spacer(minLength: 0)
    }
    .allowsHitTesting(false)
    .animation(.spring(response: 0.55, dampingFraction: 0.82), value: mode)
}

private func visualizerHeight(for mode: PlayerMode, in size: CGSize) -> CGFloat {
    switch mode {
    case .field:   return size.height * 0.60
    case .control: return size.height * 0.45
    case .reading: return size.height * 0.20
    }
}
```

**Actual pixel area on a 6.7" screen (iPhone 14/15 Pro Max, 430×932 pt):**
- FIELD: `430 × (932 × 0.60) = 430 × 559.2 pt`

The FIELD content (verb, song, recognition, scrubber) is stacked **strictly below** the visualizer via a 60% spacer — there is no overlap, no fade gradient, no float-over:

`Bindu Field/Views/Player/PlayerView.swift:187–226`
```swift
@ViewBuilder
private func fieldContent(in geo: GeometryProxy) -> some View {
    VStack(spacing: 0) {
        Spacer()
            .frame(height: geo.size.height * 0.60)

        Text(track.verb)
            .font(.system(size: 62, weight: .ultraLight, design: .serif))
            .italic()
            ...

        Text("\(track.song) — \(track.artist)")
            ...

        if let rs = track.recognitionStatement, !rs.isEmpty {
            Text("\u{201C}\(rs)\u{201D}")
                ...
        }

        Spacer()

        slimScrubber
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
```

### Design intent

The design's reference frame is 393 × 720 pt. The Bindu visualization occupies the top 432 pt (= 60% of 720 — match in proportion), but the content block is positioned to **overlap the lower edge of the visualization** with a fade gradient between them:

`design_handoff_lalita_pass/Bindu Player.html:223–301`
```js
{/* ── Bindu visualization — top 60% ─────────────────────── */}
<div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 432 }}>
  <BinduViz ... />
</div>

{/* ── Top gradient for status bar legibility ─────────────── */}
<div style={{
  position: 'absolute', top: 0, left: 0, right: 0, height: 88,
  background: `linear-gradient(to bottom, ${BG}cc 0%, transparent 100%)`,
  pointerEvents: 'none',
}} />

{/* ── Bottom gradient — viz fades into content ─────────────  */}
<div style={{
  position: 'absolute', top: 348, left: 0, right: 0, height: 86,
  background: `linear-gradient(to bottom, transparent, ${BG})`,
  pointerEvents: 'none',
}} />

...

{/* ── Content block ─────────────────────────────────────────  */}
<div style={{
  position: 'absolute', top: 425, left: 0, right: 0, bottom: 0,
  display: 'flex', flexDirection: 'column',
  paddingBottom: 28,
}}>
  {/* Verb — the primary gesture */}
  <div style={{
    textAlign: 'center',
    fontStyle: 'italic', fontWeight: 300,
    fontSize: 62,
    color: col,
    textShadow: `0 0 48px ${colGlow}, 0 0 100px ${el.accent(0.10)}`,
    ...
  }}>
    {TRACK.verb}
  </div>
  ...
}
```

The content block starts at `top: 425` while the visualization ends at `y = 432` — a 7pt overlap zone — and the **bottom gradient at y = 348–434** softly fades the visualization into the content. The verb floats over the dissolving lower edge of the Bindu area.

### Gap

The visualizer's 60% height proportion matches the design, but the FIELD content sits below it on a hard line (a `Spacer().frame(height: geo.size.height * 0.60)` with no overlap and no fade gradient), missing the design's intended visual merge where the verb floats over the dissolving lower edge of the Bindu area.

---

## 3. FIELD MODE CONTENT BEFORE TAP

### Current code

The `mode` state defaults to `.field` so the Player starts in FIELD mode on every appearance:

`Bindu Field/Views/Player/PlayerView.swift:26`
```swift
@State private var mode: PlayerMode = .field
```

In FIELD mode, the visualizer is rendered at full size and full opacity, and the FIELD content (verb / song / recognition / scrubber) is rendered at full opacity:

`Bindu Field/Views/Player/PlayerView.swift:59–68`
```swift
// Mode-aware visualizer. Always rendered; size + position +
// opacity respond to mode transitions.
visualizerLayer(in: geo)

// FIELD content (verb / song / recognition / scrubber).
// Always laid out, opacity-faded in non-FIELD modes.
fieldContent(in: geo)
    .opacity(mode == .field ? 1.0 : 0)
    .animation(.easeInOut(duration: 0.32), value: mode)
    .allowsHitTesting(mode == .field)
```

`Bindu Field/Views/Player/PlayerView.swift:177–183`
```swift
private func visualizerOpacity(for mode: PlayerMode) -> Double {
    switch mode {
    case .field:   return 1.0
    case .control: return 0.55
    case .reading: return 0.32
    }
}
```

The background tap zone in FIELD mode is `Color.clear` — invisible — and only routes a tap to `enterControl()`, it doesn't cover or hide anything:

`Bindu Field/Views/Player/PlayerView.swift:276–280`
```swift
case .field:
    Color.clear
        .contentShape(Rectangle())
        .onTapGesture { enterControl() }
```

There is a one-time 0.6s arrival ceremony (opacity 0 → 1, scale 0.96 → 1) when the Player first appears (`PlayerView.swift:111–118`), but no tap is required for content to render — it animates in on `.onAppear` automatically.

### Design intent

The design's FIELD screen renders the Bindu visualization, the verb, the song · artist line, the recognition statement, and the scrubber unconditionally — there is no "tap to reveal" interaction, no overlay covering them. The screen is the resting state:

`design_handoff_lalita_pass/Bindu Player.html:209–303`
```js
function FieldScreen({ element, vizMode, speed }) {
  ...
  return (
    <div style={{
      width: 393, height: 720,
      ...
    }}>
      {/* ── Bindu visualization — top 60% ─────────────────────── */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 432 }}>
        <BinduViz vizMode={vizMode} hue={el.hue} ... />
      </div>
      ...
      {/* ── Content block ─────────────────────────────────────────  */}
      <div style={{
        position: 'absolute', top: 425, left: 0, right: 0, bottom: 0,
        ...
      }}>
        {/* Verb — the primary gesture */}
        <div style={{ ... fontSize: 62, color: col, ... }}>
          {TRACK.verb}
        </div>

        {/* Song + artist */}
        <div style={{ ... }}>
          {TRACK.song} — {TRACK.artist}
        </div>

        {/* Recognition statement */}
        <div style={{ ... }}>
          "{TRACK.recognition}"
        </div>

        <div style={{ flex: 1 }} />

        {/* Scrubber */}
        <Scrubber hue={el.hue} progress={0.30} />
      </div>
    </div>
  );
}
```

### Gap

No gap on visibility — the Bindu animation, verb, song · artist, recognition statement, and scrubber all render on entry without any tap (after the 0.6s arrival ceremony fades them in); the only caveat is that the loading view (`PlayerView.swift:925–936`) covers the canvas for the brief window while audio is fetching, which the design HTML doesn't model.

---

## 4. ENSEMBLE vs. SINGULAR LISSAJOUS TOGGLE

### Current code

There is no user-facing or developer-facing toggle for visualization mode anywhere in the codebase. `grep` confirms it:

```bash
$ grep -rn "vizMode\|singular\|Singular" "Bindu Field/Views/Player/"
# (no matches)
```

`VisualizerView` ships a single rendering pipeline — Cathedral Tier 1 (always) → Tier 2 (presence-gated) → Tier 3 (modulator-gated) → Tier 4 (climax-gated) → ensemble archetypes (Karishma/Ashrey/Neev) → Bindu Lissajous on top. The Bindu Lissajous draw is always rendered alongside the Cathedral tiers; it never appears in isolation.

`Bindu Field/Views/Player/VisualizerView.swift:65–113` (the Canvas body — abridged)
```swift
Canvas { ctx, size in
    let mod = performer.crescendoModulator
    let beat = performer.beatPulse
    let energy = performer.energy
    let gaiaPresence = performer.archetypePresence[.gaia] ?? 0

    // TIER 1 — continuous
    drawCathedralFloor(ctx: ctx, size: size, t: t, mod: mod, beat: beat)
    drawSidColumns(ctx: ctx, size: size, t: t, mod: mod)
    drawVaultCeiling(ctx: ctx, size: size, t: t, energy: energy, mod: mod)
    drawAtmosphericGrain(ctx: ctx, t: t)
    drawGaiaGround(ctx: ctx, size: size, t: t, gaia: gaiaPresence)

    // ENSEMBLE · Karishma
    let karishmaPresence = performer.archetypePresence[.karishma] ?? 0
    if karishmaPresence > 0.10 {
        drawKarishma(ctx: ctx, size: size, t: t, presence: karishmaPresence)
    }

    // TIER 2 — ensemble (presence-gated)
    let archPresence = performer.archetypePresence[.arch] ?? 0
    if archPresence > 0.1 {
        drawArchChant(ctx: ctx, size: size, t: t, presence: archPresence)
    }
    ...

    // BINDU — singular Lissajous on top
    drawBindu(ctx: ctx, size: size, t: t,
              energy: energy, beat: beat, mod: mod,
              bindu: bindu)
}
```

PlayerView has no UI surface for switching the visualizer mode. Settings has none either.

### Design intent

The design ships **two** Bindu visualization modes — `singular` (a bare Lissajous dot with trail, no Cathedral) and `ensemble` (the full Cathedral + archetype layers) — and routes between them through a `vizMode` prop:

`design_handoff_lalita_pass/Bindu Player.html:104–133`
```js
function BinduViz({ vizMode, hue, speed, dimmed, element, centered = false }) {
  // For ensemble in a non-720px container: center the 720px canvas
  const wrapStyle = centered
    ? { position: 'relative', overflow: 'hidden', width: '100%', height: '100%' }
    : { width: '100%', height: '100%' };

  if (vizMode === 'ensemble') {
    const innerStyle = centered
      ? { position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)', width: 393, height: 720 }
      : { width: '100%', height: '100%' };
    return (
      <div style={wrapStyle}>
        <div style={innerStyle}>
          <BinduEnsemble
            track={{ ...TRACK, element, carrier: TRACK.carrier, beat: TRACK.beat }}
            playing={false}
            toneOn={false}
            dimmed={dimmed}
          />
        </div>
      </div>
    );
  }

  return (
    <div style={wrapStyle}>
      <BinduLissajous hue={hue} speed={speed} beat={TRACK.beat} dimmed={dimmed} />
    </div>
  );
}
```

The mode selection lives in the tweaks panel:

`design_handoff_lalita_pass/Bindu Player.html:781–822`
```js
const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "element": "Crown",
  "vizMode": "ensemble",
  "speed": 1
}/*EDITMODE-END*/;

function BinduPlayerDesign() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  ...
  return (
    <DesignCanvas title="Bindu Player — Lalita Design Pass">
      ...
      <TweaksPanel>
        ...
        <TweakSection label="Bindu" />
        <TweakRadio
          label="Visualization"
          value={t.vizMode}
          options={['singular', 'ensemble']}
          onChange={v => setTweak('vizMode', v)}
        />
        <TweakSlider
          label="Speed"
          value={t.speed}
          min={0.25} max={2.5} step={0.05}
          unit="×"
          onChange={v => setTweak('speed', v)}
        />
      </TweaksPanel>
    </DesignCanvas>
  );
}
```

The `TweaksPanel` is design-canvas tooling (a developer/designer review tool exported from `design-canvas.jsx`), so the toggle is **dev-facing in the prototype**, not surfaced to a user — but it implies both visualizations are intended to ship as reachable options, and the toggle ought to be exposed somewhere in the app (likely Settings) for the user to choose between Cathedral-ensemble and singular-Lissajous.

### Gap

The app currently ships only the Cathedral-ensemble visualizer with no surface to switch to the singular Lissajous, while the design package defines two distinct modes (`vizMode: 'singular' | 'ensemble'`) and a toggle to route between them — meaning the singular Lissajous code path is not reachable from the app.

---

## 5. CONTROL SHEET LAYOUT

### Current code

The CONTROL sheet renders in this order: drag handle → 56pt play/pause circle → BINAURAL label → toggle row → PRESENCE → BEAT → CARRIER → READING + END SESSION buttons:

`Bindu Field/Views/Player/PlayerView.swift:329–423`
```swift
VStack(spacing: 0) {
    // Drag handle
    Capsule()
        .fill(Color.white.opacity(0.12))
        .frame(width: 34, height: 3)
        .padding(.top, 12)
        .padding(.bottom, 16)

    // Play/Pause circle
    Button(action: {
        trackPlayer.togglePlayPause()
        scheduleAutoHide()
    }) {
        ZStack {
            Circle()
                .fill(Color(hue: elementHueDeg / 360, saturation: 0.32, brightness: 0.12))
                .frame(width: 56, height: 56)
            Circle()
                .stroke(elementColor.opacity(0.42), lineWidth: 1)
                .frame(width: 56, height: 56)
            Image(systemName: trackPlayer.isPaused ? "play.fill" : "pause.fill")
                ...
        }
        ...
    }
    .padding(.bottom, 20)

    // BINAURAL section
    VStack(alignment: .leading, spacing: 14) {
        HStack {
            Text("BINAURAL")
                ...
        }

        // Toggle row
        binauralToggleRow

        // PRESENCE
        sliderRow(label: "PRESENCE", ...)

        // BEAT — adjustable in-session
        beatSliderRow

        // CARRIER readout
        carrierRow
    }
    .padding(.horizontal, 26)

    Spacer(minLength: 0)

    // Bottom buttons
    HStack(spacing: 10) {
        Button(action: { enterReading(); scheduleAutoHide() }) {
            Text("READING")
                ...
        }

        Button(action: { store.closePlayer() }) {
            Text("END SESSION")
                ...
        }
    }
    .padding(.horizontal, 26)
    .padding(.bottom, 28)
}
```

### Design intent

`design_handoff_lalita_pass/Bindu Player.html:404–596` (the CONTROL sheet — abridged structure)
```js
{/* ── Control surface ───────────────────────────────────────  */}
<div style={{ ... height: 414, ... }}>
    {/* Drag handle */}
    <div style={{ width: 34, height: 3, ... margin: '14px auto 16px' }} />

    {/* Play / Pause */}
    <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 20 }}>
        <div onClick={() => setPlaying(p => !p)}
            style={{ width: 56, height: 56, borderRadius: '50%', ... }}>
            <span>{playing ? '⏸' : '▶'}</span>
        </div>
    </div>

    {/* ── Binaural controls ──────────────────────────────────── */}
    <div style={{ ... }}>BINAURAL</div>

    {/* Toggle row */}
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
        <div onClick={() => setBinOn(v => !v)} style={{ width: 44, height: 24, ... }} />
        <span>{binOn ? 'ON' : 'OFF'}</span>
        {binOn && <div style={{ width: 6, height: 6, ... animation: 'breathePill 2s ...' }} />}
    </div>

    {/* PRESENCE slider */}
    <SliderRow label="PRESENCE" value={presence} ... />

    {/* BEAT slider with zone marks */}
    <div style={{ marginBottom: 12 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span>BEAT</span>
            <div style={{ flex: 1, ... }}>
                {/* track + fill + zone tick marks (Δ Θ α) + thumb + invisible range input */}
            </div>
            <span>{beatHz} Hz</span>
            <span>{bwState}</span>  {/* state badge */}
        </div>
        {/* Zone label strip below the slider */}
        <div style={{ ... marginLeft: 76, marginRight: 90 }}>
            {zones.map(z => <div>{z.label}</div>)}
        </div>
    </div>

    {/* CARRIER row */}
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 18 }}>
        <span>CARRIER</span>
        <span>{TRACK.carrier.toFixed(1)} Hz</span>
        <span>DERIVED</span>
    </div>

    <div style={{ flex: 1 }} />

    {/* Bottom capsule buttons */}
    <div style={{ display: 'flex', gap: 10 }}>
        <button>READING</button>
        <button>END SESSION</button>
    </div>
</div>
```

### Gap

No gap on the structural order — the current sheet matches the design's sequence exactly (drag handle → 56pt play/pause → BINAURAL label → toggle row → PRESENCE → BEAT with zone ticks + state badge + zone label strip → CARRIER with DERIVED chip → READING + END SESSION buttons); a minor semantic note is that the design's small 6pt dot in the toggle row breathes at 2s cycles **when binaural is on** (a "binaural is active" indicator), whereas the current code's equivalent dot at `PlayerView.swift:461–468` is tied to `wire.carrierLocked` — the 500 ms carrier-derivation pulse, not a continuous on-state breath.

---

## Summary

| # | Issue | Status |
|---|---|---|
| 1 | Duplicate binaural controls | **Gap** — pill carries an expansion with toggle + PRESENCE that the design places only in the sheet |
| 2 | Visualizer size in FIELD mode | **Gap** — 60% proportion matches but content lacks the design's gradient-faded overlap with the visualizer's lower edge |
| 3 | FIELD mode content before tap | **No gap** — Bindu, verb, song, recognition, scrubber all render on entry without a tap |
| 4 | Ensemble vs. singular toggle | **Gap** — singular Lissajous code path is not reachable; only Cathedral-ensemble ships |
| 5 | CONTROL sheet layout | **No structural gap** — order matches design; minor semantic difference in the toggle-row dot's animation source |
