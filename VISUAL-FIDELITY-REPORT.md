# Visual Fidelity Report — Lalita Pass

**Audit date:** 2026-05-19
**Branch:** `feat/lalita-pass` @ `efc8005`
**Sources compared:**
- `design_handoff_lalita_pass/Bindu Player.html` ↔ `Bindu Field/Views/Player/PlayerView.swift`
- `design_handoff_lalita_pass/Bindu Lab.html` ↔ `Bindu Field/Views/Tabs/LabView.swift`

This is a read-only audit. No code was changed. Differences are extracted
from the source of each file and grouped by area. "DESIGN" is the exact
value from the HTML reference; "CURRENT" is the exact value from the Swift
implementation.

---

## AREA 1 — FIELD MODE

### Layer order (bottom → top)

**DESIGN** (Bindu Player.html, lines 214–301):
1. `BG #020208` flat fill on the 393×720 frame
2. Visualizer — `position: absolute; top: 0; height: 432` (60% of 720)
3. Top gradient — `top: 0; height: 88` linear gradient
4. Bottom gradient — `top: 348; height: 86` linear gradient (sits *over* the bottom of the viz)
5. Binaural pill — `top: 52; zIndex: 20`
6. Content block — `top: 425; bottom: 0`
   - flexbox column with verb / song-artist / recognition / flex spacer / scrubber

**CURRENT** (PlayerView.swift, lines 60–138):
1. `theme.bg` + radial gradient (`elementColor.opacity(0.14) → bg`, center, radius 60–540) — *extra layer not in design*
2. Visualizer — 60% of height, full width, top-anchored ✓
3. Bottom fade gradient (FIELD only) — Spacer height 48% of screen, then `LinearGradient` 86pt
4. FIELD content (verb / song / recognition + bottom-pinned scrubber)
5. Mode tap zone
6. Top status-bar gradient
7. Binaural pill (`padding(.top, 56)`)
8. Loading view / Integration Chamber on top

---

### Visualizer frame

| Property | Design | Current |
|---|---|---|
| Height | `432` (60% of 720) | `geo.size.height * 0.60` ✓ |
| Width | `100%` of 393 | `maxWidth: .infinity` ✓ |
| Top anchor | `top: 0` ✓ | `VStack { viz; Spacer }` ✓ |

---

### Top status-bar gradient

PROPERTY: start color
DESIGN:   `#020208cc` (= `BG @ 0.80`)
CURRENT:  `theme.bg.opacity(0.80)` ≈ `#020208 @ 0.80`
IMPACT:   low — matches

PROPERTY: end color
DESIGN:   `transparent`
CURRENT:  `Color.clear` ✓
IMPACT:   low — matches

PROPERTY: height
DESIGN:   `88` pt
CURRENT:  `88` pt ✓
IMPACT:   low — matches

---

### Bottom fade gradient

PROPERTY: top anchor (absolute position)
DESIGN:   `top: 348` (= 48.3% of 720)
CURRENT:  `Spacer().frame(height: geo.size.height * 0.48)` then gradient → 48% of screen height ✓
IMPACT:   low — matches within 0.3%

PROPERTY: height
DESIGN:   `86` pt
CURRENT:  `86` pt ✓
IMPACT:   low — matches

PROPERTY: start → end
DESIGN:   `transparent → BG`
CURRENT:  `Color.clear → theme.bg` ✓
IMPACT:   low — matches

---

### Content block — vertical anchor / overlap into viz

PROPERTY: text block top anchor (absolute)
DESIGN:   `top: 425` (= **59.0%** of 720)
CURRENT:  `.padding(.top, geo.size.height * 0.56)` (= **56.0%** of height)
IMPACT:   **medium** — Swift verb sits **22 pt higher** than the design on a 720pt canvas. The viz ends at 432; design verb starts at 425 (–7 from viz bottom), Swift verb starts at 403 (–29 from viz bottom). Swift text overlaps significantly more of the visualizer.

PROPERTY: bottom padding for content
DESIGN:   `paddingBottom: 28`
CURRENT:  scrubber `.padding(.bottom, 28)` ✓
IMPACT:   low — matches (the scrubber pin position matches)

PROPERTY: scrubber relationship to text block
DESIGN:   text block + scrubber are siblings in one column; `flex: 1` spacer pushes scrubber to bottom of that column
CURRENT:  scrubber is a sibling **ZStack** layer pinned to bottom via `Spacer()` — text block does not "contain" the scrubber
IMPACT:   low — visual result is the same, structure differs

---

### Verb

PROPERTY: font size
DESIGN:   `62` pt
CURRENT:  `62` pt ✓
IMPACT:   low — matches

PROPERTY: font weight
DESIGN:   `fontWeight: 300` (light)
CURRENT:  `.ultraLight` (≈ 100)
IMPACT:   **medium** — `.ultraLight` in SwiftUI is significantly thinner than CSS `font-weight: 300`. The design wants a "Light" stroke, Swift renders "UltraLight".

PROPERTY: font design / italic
DESIGN:   `fontFamily: 'Lora, Georgia, serif'; fontStyle: italic`
CURRENT:  `design: .serif`, `.italic()` ✓
IMPACT:   low — matches

PROPERTY: color
DESIGN:   element color at full alpha (e.g. `hsla(50, 60%, 68%, 1)` for Light)
CURRENT:  `Color.bindu(element:)` at full alpha ✓
IMPACT:   low — matches (palette equivalencies are within tuning tolerance)

PROPERTY: text shadow — primary glow
DESIGN:   `0 0 48px ${colGlow}` where `colGlow = el.accent(0.28)`
CURRENT:  `.shadow(color: elementColor.opacity(0.5), radius: 22)`
IMPACT:   **high** — Swift glow alpha is **0.5** vs design **0.28** (almost 2× as bright); radius 22 ≈ 44pt blur vs design's 48pt blur. Verb appears noticeably hotter / blurrier than the design.

PROPERTY: text shadow — secondary halo
DESIGN:   `0 0 100px ${el.accent(0.10)}` — a wide, ultra-faint second shadow
CURRENT:  **missing** — only one `.shadow()` modifier
IMPACT:   **medium** — design's two-shadow stack (tight bright + wide faint) gives the verb a "presence" halo that single-shadow misses; verb feels flatter against the bg.

PROPERTY: letter spacing
DESIGN:   `letterSpacing: -0.01em` (slight negative tracking)
CURRENT:  no `.tracking()` modifier (default 0)
IMPACT:   low — barely perceptible on serif italic at 62pt

PROPERTY: line height
DESIGN:   `lineHeight: 1`
CURRENT:  default (varies by font)
IMPACT:   low

PROPERTY: padding around verb
DESIGN:   `paddingTop: 4; paddingBottom: 8`
CURRENT:  `.padding(.horizontal, 24)` + `.padding(.bottom, 8)` ✓ (bottom matches)
IMPACT:   low

---

### Song · artist

PROPERTY: font size
DESIGN:   `12` pt
CURRENT:  `12` pt ✓
IMPACT:   low

PROPERTY: color
DESIGN:   `SUBTLE` = `rgba(245,226,214,0.28)`
CURRENT:  `theme.subtle` = `text @ 0.28` ✓
IMPACT:   low — matches

PROPERTY: letter spacing
DESIGN:   `0.025em`
CURRENT:  none
IMPACT:   low

PROPERTY: bottom margin
DESIGN:   `marginBottom: 12`
CURRENT:  `.padding(.bottom, 12)` ✓
IMPACT:   low

---

### Recognition statement

PROPERTY: font size
DESIGN:   `13` pt
CURRENT:  `13` pt ✓
IMPACT:   low

PROPERTY: color
DESIGN:   `FAINT` = `rgba(245,226,214,0.12)` — almost a whisper
CURRENT:  `theme.text.opacity(0.65)` — ~5.4× brighter than design
IMPACT:   **HIGH** — Swift recognition is dramatically more visible than the design. Design treats this as an atmospheric whisper sitting at the edge of perception; Swift renders it as readable body copy. This is the most visually obvious legibility/hierarchy departure in FIELD mode.

PROPERTY: horizontal padding
DESIGN:   `padding: 0 38px`
CURRENT:  `.padding(.horizontal, 38)` ✓
IMPACT:   low

PROPERTY: line spacing
DESIGN:   `lineHeight: 1.6`
CURRENT:  `.lineSpacing(4)`
IMPACT:   low — close (4pt added between 13pt lines ≈ 1.31 effective line height; HTML's 1.6 with 13pt = 20.8pt line height, so design has ~8pt gap. Swift gap is half.) — minor.

---

### Scrubber

PROPERTY: track height
DESIGN:   `height: 2`
CURRENT:  `frame(height: 2)` ✓
IMPACT:   low

PROPERTY: track background
DESIGN:   `rgba(255,255,255,0.07)`
CURRENT:  `Color.white.opacity(0.07)` ✓
IMPACT:   low

PROPERTY: fill color
DESIGN:   element color full alpha
CURRENT:  `elementColor` ✓
IMPACT:   low

PROPERTY: fill shadow
DESIGN:   `boxShadow: 0 0 6px ${colFaint}` where `colFaint = el.accent(0.35)`
CURRENT:  `.shadow(color: elementColor.opacity(0.35), radius: 4)`
IMPACT:   low — alpha matches; radius 4 ≈ 8pt blur (design 6) — close

PROPERTY: thumb diameter
DESIGN:   `8 × 8`
CURRENT:  `frame(width: 8, height: 8)` ✓
IMPACT:   low

PROPERTY: thumb shadow
DESIGN:   `boxShadow: 0 0 10px ${col}` (full element-color glow)
CURRENT:  `.shadow(color: elementColor.opacity(0.55), radius: 5)`
IMPACT:   low — slightly more muted glow than design

PROPERTY: horizontal padding
DESIGN:   `0 28px`
CURRENT:  `.padding(.horizontal, 28)` ✓
IMPACT:   low

PROPERTY: "flowing" label
DESIGN:   `Lora,Georgia,serif italic` 10pt, color `SUBTLE`, letterSpacing `0.04em`
CURRENT:  `.system(size: 10, design: .serif).italic()`, `theme.subtle` ✓ — no tracking
IMPACT:   low

PROPERTY: % readout
DESIGN:   `-apple-system` 9pt, `letterSpacing: 0.12em` uppercase, color `FAINT` (0.12)
CURRENT:  `.system(size: 9, weight: .light, design: .monospaced).tracking(1.2)`, color `theme.subtle.opacity(0.55)` = ~0.154
IMPACT:   low — Swift uses monospaced where design uses sans; alpha slightly higher; close enough

PROPERTY: scrubber container `marginTop` from text block
DESIGN:   `marginTop: 9` between track and labels
CURRENT:  `VStack(spacing: 8)` between bar and label row
IMPACT:   low

---

### Binaural pill

PROPERTY: top anchor
DESIGN:   `top: 52` (within 720pt frame)
CURRENT:  `.padding(.top, 56)` (in a `.ignoresSafeArea()` ZStack)
IMPACT:   low — Swift effectively sits ~4pt lower than design before safe-area considerations; on a real device the safe area pushes it further. Marginal.

PROPERTY: padding (inner)
DESIGN:   `padding: 7px 14px`
CURRENT:  `.padding(.horizontal, 14)` + `.padding(.vertical, 7)` ✓
IMPACT:   low

PROPERTY: corner radius
DESIGN:   `borderRadius: 20`
CURRENT:  `Capsule()` → fully rounded
IMPACT:   low — both read as a pill

PROPERTY: background
DESIGN:   `rgba(255,255,255,0.055)` + `backdropFilter: blur(14px)`
CURRENT:  `.ultraThinMaterial`
IMPACT:   **medium** — `.ultraThinMaterial` is far more vibrant / lighter than the design's `0.055` white film. The design wants a near-invisible glass capsule; Swift renders a noticeably brighter blur surface.

PROPERTY: border
DESIGN:   `1px solid rgba(255,255,255,0.09)`
CURRENT:  `stroke(theme.muted.opacity(0.15), lineWidth: 1)` = `text @ 0.55 × 0.15` ≈ `(245,226,214) @ 0.083`
IMPACT:   low — tint differs (warm vs pure white) but alpha ≈ matches

PROPERTY: dot diameter
DESIGN:   `6 × 6`
CURRENT:  `frame(width: 6, height: 6)` ✓
IMPACT:   low

PROPERTY: dot fill (on)
DESIGN:   element color full alpha
CURRENT:  `elementColor` ✓
IMPACT:   low

PROPERTY: dot shadow
DESIGN:   `0 0 8px 2px ${ac.accent(0.45)}`
CURRENT:  `.shadow(color: elementColor.opacity(0.45), radius: 6)`
IMPACT:   low — alpha matches; design uses `8px blur + 2px spread`, Swift has no spread param so renders ~12pt total — close

PROPERTY: dot animation (FIELD pill)
DESIGN:   `breathePill 2.6s ease-in-out infinite` → scale `1.0 ↔ 1.25`, opacity `0.7 ↔ 1.0`
CURRENT:  `.easeInOut(duration: 1.3).repeatForever(autoreverses: true)` → scale `1.0 ↔ 1.25`, opacity `0.7 ↔ 1.0`
IMPACT:   low — autoreverses makes the 1.3s Swift duration cycle 2.6s ✓ matches

PROPERTY: BINAURAL label
DESIGN:   `-apple-system` 9pt, `letterSpacing: 0.20em` uppercase, color `SUBTLE` (0.28)
CURRENT:  `.system(size: 9, weight: .light).tracking(2.0)`, `theme.subtle` (0.28) ✓
IMPACT:   low

PROPERTY: chevron
DESIGN:   `›` at 9pt, color `FAINT` (0.12)
CURRENT:  `›` at 12pt, color `theme.subtle.opacity(0.55)` = ~0.154
IMPACT:   low — Swift chevron is larger (12 vs 9pt) and slightly brighter

---

### Background (FIELD mode)

PROPERTY: bg color
DESIGN:   `#020208` flat
CURRENT:  `theme.bg` = `#020208` + extra **`RadialGradient`** layer (`elementColor.opacity(0.14)` center → bg)
IMPACT:   **medium** — Swift adds a centered element-color radial gradient under the visualizer that the design does **not** have. The design relies entirely on the visualizer's own atmospheric layers (Cathedral / Gaia) to color the void. This makes the Swift FIELD background warmer/brighter than designed, especially around the bottom 30% where the verb sits.

---

## AREA 2 — CONTROL MODE

### Sheet geometry

PROPERTY: sheet height (% of screen)
DESIGN:   `height: 414` / 720 = **57.5%**
CURRENT:  `geo.size.height * 0.55` = **55.0%**
IMPACT:   low — 2.5% (~18pt) shorter sheet

PROPERTY: top corner radius
DESIGN:   `borderRadius: 32px 32px 47px 47px` (32 top, 47 bottom — matches device-frame corner)
CURRENT:  `UnevenRoundedRectangle(topLeading: 32, topTrailing: 32, ...other 0)`
IMPACT:   low — both round top corners to 32; bottom corners not relevant on device (sheet meets screen edge)

PROPERTY: sheet background
DESIGN:   `rgba(5,5,16,0.97)` + `backdropFilter: blur(28px)` — near-opaque dark indigo
CURRENT:  `.ultraThinMaterial` + overlay `Color.white.opacity(0.04)`
IMPACT:   **HIGH** — `.ultraThinMaterial` is dramatically more translucent (~50–60% transmission) than design's `0.97` opacity. Visualizer above bleeds through Swift sheet far more than designed. Sheet feels glassy where design feels solid with subtle depth.

PROPERTY: sheet border
DESIGN:   `1px solid rgba(255,255,255,0.07)` (top edge only, `borderBottom: none`)
CURRENT:  `stroke(Color.white.opacity(0.07), lineWidth: 1)` (full outline of `UnevenRoundedRectangle`)
IMPACT:   low — visually identical at top edge; Swift strokes sides + bottom that meet the screen edge so are not seen

PROPERTY: horizontal padding
DESIGN:   `padding: 0 26px`
CURRENT:  `.padding(.horizontal, 26)` ✓
IMPACT:   low

PROPERTY: bottom padding
DESIGN:   `padding: ... 30px` (bottom)
CURRENT:  `.padding(.bottom, 28)`
IMPACT:   low — 2pt difference

---

### Drag handle

PROPERTY: dimensions
DESIGN:   `34 × 3`
CURRENT:  `frame(width: 34, height: 3)` ✓
IMPACT:   low

PROPERTY: color
DESIGN:   `rgba(255,255,255,0.10)`
CURRENT:  `Color.white.opacity(0.12)`
IMPACT:   low — Swift is 2% brighter

PROPERTY: margin
DESIGN:   `margin: 14px auto 16px` (top 14, bottom 16)
CURRENT:  `.padding(.top, 12)` + `.padding(.bottom, 16)`
IMPACT:   low — top off by 2pt

---

### Play / Pause button

PROPERTY: diameter
DESIGN:   `56 × 56`
CURRENT:  `frame(width: 56, height: 56)` ✓
IMPACT:   low

PROPERTY: fill
DESIGN:   `hsl(${el.hue}, 32%, 12%)` — dark element-tinted
CURRENT:  `Color(hue: hueDeg/360, saturation: 0.32, brightness: 0.12)` ✓
IMPACT:   low — matches exactly

PROPERTY: border
DESIGN:   `1px solid ${colDim}` where `colDim = el.accent(0.45)`
CURRENT:  `stroke(elementColor.opacity(0.42), lineWidth: 1)`
IMPACT:   low — 0.03 alpha difference

PROPERTY: glow (primary)
DESIGN:   `boxShadow: 0 0 32px ${colGlow}` where `colGlow = el.accent(0.22)`
CURRENT:  `.shadow(color: elementColor.opacity(0.28), radius: 14)`
IMPACT:   medium — Swift alpha 0.28 vs design 0.22 (slightly hotter); radius 14 ≈ 28pt blur vs design 32pt — close on size, slightly stronger color

PROPERTY: glow (secondary halo)
DESIGN:   `0 0 60px ${el.accent(0.08)}` — second shadow for wide halo
CURRENT:  **missing** — only one `.shadow()`
IMPACT:   medium — design intent is dual-layer glow (tight ring + soft bloom); single shadow misses the soft outer ring

PROPERTY: icon size (play state)
DESIGN:   `▶` at fontSize `22`, `marginLeft: 3`
CURRENT:  `Image("play.fill")` at `font(.system(size: 18))`, `offset(x: 2)`
IMPACT:   medium — icon **4pt smaller** than design

PROPERTY: icon size (pause state)
DESIGN:   `⏸` at fontSize `17`
CURRENT:  `Image("pause.fill")` at `font(.system(size: 18))`
IMPACT:   low — 1pt off

PROPERTY: bottom margin
DESIGN:   `marginBottom: 20`
CURRENT:  `.padding(.bottom, 20)` ✓
IMPACT:   low

---

### BINAURAL label

PROPERTY: font size
DESIGN:   `9` pt
CURRENT:  `9` pt ✓
IMPACT:   low

PROPERTY: tracking
DESIGN:   `letterSpacing: 0.22em` → 1.98pt on 9pt text
CURRENT:  `.tracking(2.2)` ✓
IMPACT:   low — matches

PROPERTY: color
DESIGN:   `FAINT` = `rgba(245,226,214,0.12)`
CURRENT:  `theme.subtle.opacity(0.6)` = `(text @ 0.28) × 0.6` = ~`0.168`
IMPACT:   low — Swift is ~40% brighter than design; the design wants this label to nearly disappear

PROPERTY: bottom margin
DESIGN:   `marginBottom: 12`
CURRENT:  `VStack(spacing: 14)` ≈ 14pt
IMPACT:   low

---

### Toggle row

PROPERTY: toggle dimensions
DESIGN:   `44 × 24`
CURRENT:  `frame(width: 44, height: 24)` ✓
IMPACT:   low

PROPERTY: toggle fill (on)
DESIGN:   element color full alpha
CURRENT:  `elementColor` ✓
IMPACT:   low

PROPERTY: toggle fill (off)
DESIGN:   `rgba(255,255,255,0.10)`
CURRENT:  `Color.white.opacity(0.10)` ✓
IMPACT:   low

PROPERTY: toggle glow (on)
DESIGN:   `0 0 12px ${colGlow}` (0.22 alpha)
CURRENT:  `.shadow(color: elementColor.opacity(0.30), radius: 8)`
IMPACT:   low — Swift 0.30 vs design 0.22; radius 8 ≈ 16pt blur vs design 12pt — slightly hotter / blurrier

PROPERTY: thumb dimensions
DESIGN:   `20 × 20`
CURRENT:  `frame(width: 20, height: 20)` ✓
IMPACT:   low

PROPERTY: thumb color
DESIGN:   `rgba(5,5,16,0.95)` (matches sheet base color)
CURRENT:  `theme.bg` = `#020208` full alpha
IMPACT:   low — design has slight blue tint, Swift is pure-near-black. Sub-perceptible on the toggle.

PROPERTY: thumb transition
DESIGN:   `transition: left 0.28s cubic-bezier(0.4,0,0.2,1)`
CURRENT:  `.animation(.easeInOut(duration: 0.28))` on the whole toggle (via ZStack alignment)
IMPACT:   low — same duration, similar easing

PROPERTY: ON/OFF label
DESIGN:   `-apple-system` 10pt, `letterSpacing: 0.14em` uppercase, color `MUTED` when on / `SUBTLE` when off
CURRENT:  `.system(size: 10, weight: .regular).tracking(1.4)`, `theme.muted` / `theme.subtle` ✓
IMPACT:   low — matches

PROPERTY: row layout order
DESIGN:   `[toggle][label][dot]` — all in a 10px-gap flex row, dot immediately follows label
CURRENT:  `[toggle][label][Spacer()][dot]` — dot is pushed to the trailing edge
IMPACT:   **medium** — design puts the breathing dot adjacent to "ON" as a tight indicator triad; Swift pushes the dot to the far right, separating it visually from its label. Reads as a different control.

PROPERTY: breathing dot diameter
DESIGN:   `6 × 6`
CURRENT:  `frame(width: 6, height: 6)` ✓
IMPACT:   low

PROPERTY: breathing dot animation
DESIGN:   `breathePill 2s ease-in-out infinite` → scale `1.0 ↔ 1.25`, opacity `0.7 ↔ 1.0`
CURRENT:  `.easeInOut(duration: 2.0).repeatForever(autoreverses: true)` → scale `1.0 ↔ 1.15`, opacity `0.65 ↔ 1.0`
IMPACT:   medium — **two differences**: (1) Swift uses scale 1.15 vs design's 1.25 — visibly less "breathing"; (2) `autoreverses` doubles total cycle to 4s vs design's 2s — half the breath rate

---

### PRESENCE slider

PROPERTY: row layout
DESIGN:   `[label 68pt][slider flex 1][value 46pt right-aligned]`
CURRENT:  `[label 68pt][slider GeometryReader][value 46pt right-aligned]` ✓
IMPACT:   low — matches

PROPERTY: track color
DESIGN:   `rgba(255,255,255,0.13)`
CURRENT:  `Color.white.opacity(0.13)` ✓
IMPACT:   low

PROPERTY: track height
DESIGN:   `1` pt
CURRENT:  `frame(height: 1)` ✓
IMPACT:   low

PROPERTY: thumb diameter
DESIGN:   `13 × 13`
CURRENT:  `frame(width: 13, height: 13)` ✓
IMPACT:   low

PROPERTY: thumb shadow
DESIGN:   `0 0 10px ${colDim}, 0 0 22px ${el.accent(0.12)}` (two shadows)
CURRENT:  `.shadow(color: elementColor.opacity(0.45), radius: 6)` (one shadow)
IMPACT:   medium — Swift misses the wide secondary halo

PROPERTY: fill shadow
DESIGN:   `0 0 4px ${colDim}`
CURRENT:  `.shadow(color: elementColor.opacity(0.35), radius: 3)`
IMPACT:   low — close

PROPERTY: row bottom margin
DESIGN:   `marginBottom: 12`
CURRENT:  inside `VStack(alignment: .leading, spacing: 14)` — 14pt gap to next row
IMPACT:   low — 2pt difference

---

### BEAT slider

PROPERTY: zone marks (positions)
DESIGN:   3 marks at Δ (4Hz), Θ (8Hz), α (13Hz). `(hz - 0.5) / 29.5 * 100`
CURRENT:  same — 3 zones at 4, 8, 13 Hz with same percent math ✓
IMPACT:   low

PROPERTY: zone tick — width / height / color
DESIGN:   `1 × 5`, `rgba(255,255,255,0.14)`
CURRENT:  `Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1, height: 5)`
IMPACT:   low — Swift 0.18 vs design 0.14 — slightly brighter ticks

PROPERTY: zone label (Δ Θ α)
DESIGN:   `-apple-system` 8pt, `FAINT` (0.12)
CURRENT:  `.system(size: 8)` (no design) `theme.subtle.opacity(0.55)` ≈ 0.154
IMPACT:   low — Swift slightly brighter

PROPERTY: zone label strip layout
DESIGN:   `marginLeft: 76, marginRight: 90` over the slider track
CURRENT:  `Spacer().frame(width: 76)` + GeometryReader + `Spacer().frame(width: 96)`
IMPACT:   low — right offset 96 vs design 90; minor

PROPERTY: state badge — font
DESIGN:   `-apple-system` 8pt, `letterSpacing: 0.14em` uppercase
CURRENT:  `.system(size: 8, weight: .regular).tracking(1.4)` ✓
IMPACT:   low

PROPERTY: state badge — fill
DESIGN:   `hsl(${el.hue}, 38%, 13%)` + border `colDim` (0.45)
CURRENT:  `Color(hue: hueDeg/360, saturation: 0.38, brightness: 0.13)` + `stroke(elementColor.opacity(0.42))` ✓
IMPACT:   low — matches (0.42 vs 0.45)

PROPERTY: state badge — corner radius
DESIGN:   `borderRadius: 4`
CURRENT:  `RoundedRectangle(cornerRadius: 4)` ✓
IMPACT:   low

PROPERTY: Hz readout width
DESIGN:   `width: 38`
CURRENT:  `frame(width: 44)`
IMPACT:   low — 6pt wider, value still right-aligned

---

### CARRIER row

PROPERTY: label width
DESIGN:   `width: 68`
CURRENT:  `frame(width: 68)` ✓
IMPACT:   low

PROPERTY: value font / size
DESIGN:   `-apple-system` 13pt
CURRENT:  `.system(size: 12, design: .monospaced)`
IMPACT:   low — Swift uses monospaced where design uses sans; 1pt smaller

PROPERTY: value color
DESIGN:   `MUTED` (0.55)
CURRENT:  `theme.muted` (0.55) ✓
IMPACT:   low

PROPERTY: DERIVED badge style
DESIGN:   same as state badge — `hsl(el.hue, 38%, 13%)` bg, `colDim` border, 8pt uppercase, `letterSpacing: 0.14em`, padding `2px 8px`, `borderRadius: 4`
CURRENT:  matching `Color(hue, sat 0.38, b 0.13)` + `elementColor.opacity(0.42)` stroke, `.system(size: 8).tracking(1.4)`, `.padding(.horizontal, 8).padding(.vertical, 2)`, `cornerRadius: 4` ✓
IMPACT:   low — matches

PROPERTY: row bottom margin
DESIGN:   `marginBottom: 18`
CURRENT:  inside `VStack(spacing: 14)` — 14pt to next element (Spacer below)
IMPACT:   low

---

### READING / END SESSION buttons

PROPERTY: gap between buttons
DESIGN:   `gap: 10`
CURRENT:  `HStack(spacing: 10)` ✓
IMPACT:   low

PROPERTY: shape / radius
DESIGN:   `borderRadius: 24` — pill
CURRENT:  `Capsule()` — fully rounded
IMPACT:   low — both read as pills

PROPERTY: vertical padding
DESIGN:   `padding: 12px 0`
CURRENT:  `.padding(.vertical, 12)` ✓
IMPACT:   low

PROPERTY: READING border
DESIGN:   `1px solid rgba(255,255,255,0.22)`
CURRENT:  `Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1)` ✓
IMPACT:   low

PROPERTY: END SESSION border
DESIGN:   `1px solid rgba(255,255,255,0.10)`
CURRENT:  `Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)` ✓
IMPACT:   low

PROPERTY: font size / weight
DESIGN:   `-apple-system` 10pt
CURRENT:  `.system(size: 10, weight: .regular)` ✓
IMPACT:   low

PROPERTY: READING letter spacing
DESIGN:   `letterSpacing: 0.14em` → ~1.4pt at 10pt
CURRENT:  `.tracking(1.6)`
IMPACT:   low — 0.2pt off

PROPERTY: END SESSION letter spacing
DESIGN:   `letterSpacing: 0.12em` → ~1.2pt
CURRENT:  `.tracking(1.4)`
IMPACT:   low — 0.2pt off

PROPERTY: READING text color
DESIGN:   `MUTED` (0.55)
CURRENT:  `theme.muted` ✓
IMPACT:   low

PROPERTY: END SESSION text color
DESIGN:   `SUBTLE` (0.28)
CURRENT:  `theme.subtle` ✓
IMPACT:   low

---

## AREA 3 — READING MODE

### Sheet geometry

PROPERTY: sheet height (% of screen)
DESIGN:   `height: 592` / 720 = **82.2%**
CURRENT:  `geo.size.height * 0.80` = **80.0%**
IMPACT:   low — 2.2% (~16pt) shorter

PROPERTY: sheet background
DESIGN:   `rgba(5,5,15,0.98)` + `backdropFilter: blur(28px)` — near-opaque
CURRENT:  `.ultraThinMaterial` + `white.opacity(0.04)` overlay
IMPACT:   **HIGH** — same as CONTROL — `.ultraThinMaterial` is far more transparent than the design's `0.98` solid sheet. Visualizer above bleeds through too much; reading content reads against a flickering rather than calm background.

PROPERTY: top corner radius
DESIGN:   `32px` top
CURRENT:  `UnevenRoundedRectangle(topLeading: 32, topTrailing: 32)` ✓
IMPACT:   low

PROPERTY: border
DESIGN:   `1px solid rgba(255,255,255,0.07)` top edge only
CURRENT:  `stroke(Color.white.opacity(0.07))` ✓
IMPACT:   low

---

### Recognition header

PROPERTY: font size
DESIGN:   `17` pt
CURRENT:  `17` pt ✓
IMPACT:   low

PROPERTY: weight
DESIGN:   `fontWeight: 300`
CURRENT:  `weight: .light` ✓
IMPACT:   low

PROPERTY: color
DESIGN:   element color full alpha (e.g. `col`)
CURRENT:  `elementColor` ✓
IMPACT:   low

PROPERTY: shadow
DESIGN:   `0 0 28px ${colGlow}` (0.22 alpha)
CURRENT:  `.shadow(color: elementColor.opacity(0.35), radius: 18)`
IMPACT:   low — Swift slightly hotter (0.35 vs 0.22) but radius 18 ≈ 36pt blur vs design 28pt — close

PROPERTY: line height
DESIGN:   `lineHeight: 1.55`
CURRENT:  `.lineSpacing(4)`
IMPACT:   low — design 26.4pt line height (17 × 1.55), Swift 17 + 4 = 21pt — Swift lines pack tighter

PROPERTY: padding (top / bottom / sides)
DESIGN:   `padding: 16px 28px 18px` (top 16, sides 28, bottom 18)
CURRENT:  `.padding(.top, 14)` + `.padding(.horizontal, 28)` + `.padding(.bottom, 16)`
IMPACT:   low — top 14 vs 16, bottom 16 vs 18 — 2pt off on each

PROPERTY: bottom rule
DESIGN:   `borderBottom: 1px solid rgba(255,255,255,0.06)`
CURRENT:  **missing** — no horizontal divider between header and tabs
IMPACT:   medium — design has a hairline rule between recognition and tab bar that separates the two zones; Swift loses this anchoring

---

### Tab bar

PROPERTY: tab font size
DESIGN:   `9` pt
CURRENT:  `9` pt ✓
IMPACT:   low

PROPERTY: tracking
DESIGN:   `letterSpacing: 0.18em` ≈ 1.62pt
CURRENT:  `.tracking(1.8)`
IMPACT:   low

PROPERTY: tab padding
DESIGN:   `padding: 13px 2px`
CURRENT:  `.padding(.top, 8)` + `VStack(spacing: 10)`
IMPACT:   low — different stack but similar visual rhythm

PROPERTY: active color
DESIGN:   `TEXT` (#F5E2D6)
CURRENT:  `theme.text` ✓
IMPACT:   low

PROPERTY: inactive color
DESIGN:   `SUBTLE` (0.28)
CURRENT:  `theme.subtle` ✓
IMPACT:   low

PROPERTY: active underline height
DESIGN:   `borderBottom: 1.5px solid col`
CURRENT:  `Rectangle().frame(height: 1.5)` ✓
IMPACT:   low

PROPERTY: active underline color
DESIGN:   element color
CURRENT:  `elementColor` ✓
IMPACT:   low

PROPERTY: tab bar bottom rule
DESIGN:   `borderBottom: 1px solid rgba(255,255,255,0.06)`
CURRENT:  `Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)` ✓
IMPACT:   low

PROPERTY: horizontal padding
DESIGN:   `padding: 0 20px`
CURRENT:  `.padding(.horizontal, 20)` ✓
IMPACT:   low

---

### Content area

PROPERTY: content padding
DESIGN:   `padding: 24px 28px 36px`
CURRENT:  `.padding(.top, 24).padding(.horizontal, 28).padding(.bottom, 36)` ✓
IMPACT:   low — matches

PROPERTY: WORDS — line font size
DESIGN:   `15` pt serif italic 300
CURRENT:  `.system(size: 15, design: .serif).italic()` ✓
IMPACT:   low

PROPERTY: WORDS — non-last color
DESIGN:   `MUTED` (0.55)
CURRENT:  `theme.muted` ✓
IMPACT:   low

PROPERTY: WORDS — last paragraph color
DESIGN:   element color
CURRENT:  `elementColor` ✓
IMPACT:   low

PROPERTY: WORDS — line height
DESIGN:   `lineHeight: 1.82` (15 × 1.82 ≈ 27.3pt)
CURRENT:  `.lineSpacing(6)` (15 + 6 = 21pt)
IMPACT:   **medium** — Swift packs paragraph lines noticeably tighter than the design's airy 1.82 leading. The design's whitespace is part of its meditative rhythm; Swift reads denser.

PROPERTY: WORDS — paragraph spacing
DESIGN:   `marginBottom: 16` between non-last paragraphs; last paragraph `paddingTop: 18` + `borderTop: 1px solid rgba(255,255,255,0.05)`
CURRENT:  `VStack(spacing: 16)` between paragraphs (✓); last paragraph `.padding(.top, 18)` + overlay top `Rectangle().fill(white.opacity(0.05)).frame(height: 1)` ✓
IMPACT:   low — matches

PROPERTY: FREQUENCY — row padding
DESIGN:   `padding: 14px 0`
CURRENT:  `.padding(.vertical, 14)` ✓
IMPACT:   low

PROPERTY: FREQUENCY — row border
DESIGN:   `borderBottom: 1px solid rgba(255,255,255,0.05)`
CURRENT:  overlay `Rectangle().fill(white.opacity(0.05)).frame(height: 1)` ✓
IMPACT:   low

PROPERTY: FREQUENCY — label size
DESIGN:   `9.5` pt
CURRENT:  `.system(size: 9)`
IMPACT:   low — 0.5pt off

PROPERTY: FREQUENCY — label tracking
DESIGN:   `letterSpacing: 0.18em` ≈ 1.71pt
CURRENT:  `.tracking(1.8)`
IMPACT:   low

PROPERTY: FREQUENCY — label color
DESIGN:   `SUBTLE` (0.28)
CURRENT:  `theme.subtle` ✓
IMPACT:   low

PROPERTY: FREQUENCY — value size / color
DESIGN:   `13` pt `MUTED`
CURRENT:  `.system(size: 13)` `theme.muted` ✓
IMPACT:   low

PROPERTY: FREQUENCY — extra prose block (not in design)
DESIGN:   not present
CURRENT:  optional `track.frequencyReading` text at 14pt italic serif `theme.muted` below the rows
IMPACT:   low — additive; design's reference track has no frequencyReading body, so neither would render. Behaviour-only.

PROPERTY: VIDEO — empty state container height
DESIGN:   `height: 200`
CURRENT:  `frame(minHeight: 200)` ✓
IMPACT:   low

PROPERTY: VIDEO — empty state surface
DESIGN:   `background: SURFACE` (white 0.042), border `BORDER` (white 0.08), `borderRadius: 14`
CURRENT:  `theme.surface` + `theme.border` stroke + `cornerRadius: 14` ✓
IMPACT:   low — matches

PROPERTY: VIDEO — empty text wording
DESIGN:   "video arrives in a future session"
CURRENT:  "video arrives in a future session" ✓
IMPACT:   low — matches exactly

PROPERTY: VIDEO — empty text style
DESIGN:   `Lora,Georgia,serif italic` 13pt `SUBTLE`
CURRENT:  `.system(size: 13, design: .serif).italic()` `theme.subtle` ✓
IMPACT:   low

PROPERTY: LALITA — empty state — paragraph 1 wording
DESIGN:   `"The Lalita reading for this song is still forming. What you've brought to it is part of the reading."`
CURRENT:  `"the Lalita reading for this song is still forming. what you've brought to it is part of the reading."`
IMPACT:   low — Swift is **fully lowercased** ("the", "what"); design uses sentence case capitals on "The" / "What". The design lowercases most of the app but not these two sentences. Minor inconsistency with the rest of the design.

PROPERTY: LALITA — empty state — paragraph 1 style
DESIGN:   `serif italic 300, 15pt MUTED, lineHeight 1.82, marginBottom 24`
CURRENT:  `.system(size: 15, design: .serif).italic()`, `theme.muted`, `.lineSpacing(6)` — inside `VStack(spacing: 24)` ✓
IMPACT:   medium — same line-height issue as WORDS (6pt spacing vs design's 12.3pt effective)

PROPERTY: LALITA — empty state — paragraph 2 wording
DESIGN:   `"Return when the field calls you back."`
CURRENT:  `"return when the field calls you back."`
IMPACT:   low — same lowercase issue as paragraph 1

PROPERTY: LALITA — empty state — paragraph 2 style
DESIGN:   `serif italic 300, 14pt FAINT (0.12), lineHeight 1.82`
CURRENT:  `.system(size: 14, design: .serif).italic()`, `theme.subtle.opacity(0.6)` = `0.28 × 0.6` ≈ `0.168`
IMPACT:   low — Swift is ~40% brighter than design's `FAINT`; design wants this line to barely appear

---

### Ambient Bindu (top of READING)

PROPERTY: height of ambient strip
DESIGN:   `height: 144` (20% of 720)
CURRENT:  visualizer at `height: geo.size.height * 0.20` ✓ (20% of screen)
IMPACT:   low

PROPERTY: dimmed flag
DESIGN:   `dimmed: true` passed to viz
CURRENT:  visualizer opacity `0.32` for reading mode
IMPACT:   low — Swift uses opacity, design uses a flag the renderer interprets; visually similar

PROPERTY: top-to-content fade
DESIGN:   bottom fade `height: 64` `linear-gradient(transparent, rgba(5,5,15,0.98))` *over* the bottom of the ambient viz
CURRENT:  **missing** — no explicit fade between ambient viz and reading sheet top edge in this mode (the sheet itself sits on top, but there's no soft fade band between viz and sheet)
IMPACT:   medium — design fades the ambient viz softly into the sheet; Swift relies on the sheet's solid top to mask, but with `.ultraThinMaterial` translucency the unfaded viz edge can read as a hard line

---

## AREA 4 — ANIMATIONS AND TRANSITIONS

PROPERTY: FIELD → CONTROL transition
DESIGN:   not explicitly defined (the three screens are separate artboards); implied via design intent
CURRENT:  `.spring(response: 0.45, dampingFraction: 0.85)` driving `mode` change; CONTROL sheet uses `.move(edge: .bottom).combined(with: .opacity)`
IMPACT:   low — no spec to deviate from

PROPERTY: CONTROL → READING transition
DESIGN:   not explicitly defined
CURRENT:  same spring; READING sheet `.move(edge: .bottom).combined(with: .opacity)` stacks over CONTROL
IMPACT:   low

PROPERTY: visualizer height transition
DESIGN:   not explicitly defined per-mode in HTML (each screen is static); intent is "the field shrinks but never stops"
CURRENT:  `.spring(response: 0.55, dampingFraction: 0.82)` on viz `mode` change
IMPACT:   low

PROPERTY: arrival ceremony
DESIGN:   not specified in HTML
CURRENT:  opacity 0→1 + scale 0.96→1.0, `easeOut(0.6)`
IMPACT:   low — additive, no conflict

PROPERTY: auto-hide timer
DESIGN:   not specified in HTML (sheet sticks in design)
CURRENT:  4-second `Task.sleep` on inactivity in CONTROL mode → returns to FIELD
IMPACT:   low — additive

PROPERTY: FIELD pill dot breathing
DESIGN:   `breathePill 2.6s` cycle, scale `1.0 ↔ 1.25`, opacity `0.7 ↔ 1.0`
CURRENT:  `easeInOut(1.3).repeatForever(autoreverses: true)` cycle ≈ 2.6s, scale `1.0 ↔ 1.25`, opacity `0.7 ↔ 1.0` ✓
IMPACT:   low — matches

PROPERTY: CONTROL toggle row dot breathing
DESIGN:   `breathePill 2s`, scale `1.0 ↔ 1.25`, opacity `0.7 ↔ 1.0`
CURRENT:  `easeInOut(2.0).repeatForever(autoreverses: true)` cycle = 4s, scale `1.0 ↔ 1.15`, opacity `0.65 ↔ 1.0`
IMPACT:   **medium** — Swift's breath is **half the rate** of the design (4s vs 2s cycle) **and** the scale amplitude is smaller (1.15 vs 1.25). Reads as slower, subtler breathing than designed.

PROPERTY: toggle thumb slide
DESIGN:   `transition: left 0.28s cubic-bezier(0.4,0,0.2,1)`
CURRENT:  `.easeInOut(duration: 0.28)` applied to the ZStack alignment
IMPACT:   low — same duration, similar easing

PROPERTY: verb glow animation
DESIGN:   not animated (static shadow)
CURRENT:  not animated ✓
IMPACT:   low

PROPERTY: play / pause press feedback
DESIGN:   none specified (CSS `transition: box-shadow 0.3s`)
CURRENT:  default SwiftUI Button feedback only
IMPACT:   low

---

## AREA 5 — LAB

### Header

PROPERTY: top padding
DESIGN:   `padding: 52px 28px 0` (top 52)
CURRENT:  `.padding(.top, 18)` (inside `theme.bg.ignoresSafeArea()` ZStack but VStack respects safe area)
IMPACT:   **medium** — design wants 52pt of breathing room above the header dot; Swift uses 18pt. On a device with a ~47pt top safe area, Swift ends up at ~65pt total (close to design's 52pt) but on edge-to-edge contexts the spacing differs. The design intent of "the lab opens with quiet at the top" reads tighter in Swift.

PROPERTY: header dot diameter
DESIGN:   `5 × 5`
CURRENT:  `frame(width: 6, height: 6)`
IMPACT:   low — 1pt larger

PROPERTY: header dot active color
DESIGN:   element color
CURRENT:  `stateColor` (state-based, not element-based — Lab is state-driven) ✓ by intent
IMPACT:   low

PROPERTY: title "frequency lab"
DESIGN:   `Lora,Georgia,serif italic 300, 18pt, TEXT, letterSpacing 0.01em`
CURRENT:  `.system(size: 18, weight: .light, design: .serif).italic()`, `theme.text` ✓
IMPACT:   low

PROPERTY: caption "craft your own permission slip"
DESIGN:   `-apple-system 10pt, letterSpacing 0.16em uppercase, SUBTLE, padding-left 15`
CURRENT:  `.system(size: 10, weight: .light).tracking(1.6).textCase(.uppercase)`, `theme.subtle`, `.padding(.leading, 16)` ✓
IMPACT:   low — leading 16 vs design 15 — 1pt off

---

### Waveform

PROPERTY: height
DESIGN:   `120`
CURRENT:  `frame(height: 120)` ✓
IMPACT:   low

PROPERTY: top + bottom border
DESIGN:   `borderTop / borderBottom: 1px solid BORDER` (white 0.08)
CURRENT:  overlay top + bottom `Rectangle().fill(theme.border).frame(height: 1)` (`theme.border = white.opacity(0.08)`) ✓
IMPACT:   low — matches

PROPERTY: vertical margin around strip
DESIGN:   `margin: 16px 0`
CURRENT:  `.padding(.bottom, 14)` after the header (header itself has `.padding(.bottom, 16)`) so effective top gap 16, bottom 14
IMPACT:   low — 2pt off on bottom

---

### Carrier row

PROPERTY: label
DESIGN:   `9pt letterSpacing 0.22em uppercase SUBTLE`
CURRENT:  `.system(size: 9, weight: .light).tracking(2.2).textCase(.uppercase)`, `theme.subtle` ✓
IMPACT:   low

PROPERTY: editable value style
DESIGN:   `DM Mono` 14pt weight 300, color = state color (`hsl(stateHue, 58%, 68%)`), borderBottom `1px solid rgba(255,255,255,0.10)`, paddingBottom 2
CURRENT:  `Text("%.1f")` `.system(size: 14, weight: .light, design: .monospaced)`, `stateColor`, overlay `Rectangle().fill(Color.white.opacity(0.10)).frame(height: 1)` ✓
IMPACT:   low — matches

PROPERTY: inline "Hz" suffix style
DESIGN:   integrated in the `EditableNum` text (` Hz` appended)
CURRENT:  separate `Text("Hz")` at `.system(size: 11, design: .monospaced)`, `stateColor.opacity(0.7)`
IMPACT:   low — visually similar but Swift renders "Hz" at 11pt instead of design's 14pt (since it's a separate `Text`, not inline)

PROPERTY: sacred badge — overall
DESIGN:   pill `padding: 3px 10px`, `borderRadius: 12`, `bg hsl(stateHue, 38%, 12%)`, `border 1px solid col44` (~0.27 alpha)
CURRENT:  `Capsule().fill(Color(hue, 0.38, 0.12)).overlay(Capsule().stroke(stateColor.opacity(0.27)))`, `.padding(.horizontal, 10).padding(.vertical, 3)` ✓
IMPACT:   low — matches

PROPERTY: sacred badge — dot
DESIGN:   `5 × 5`, breathing 2s
CURRENT:  `frame(width: 5, height: 5)`, no breathing animation
IMPACT:   medium — design's sacred badge has its own breathePill animation; Swift's is static. Less "alive."

PROPERTY: sacred badge — name + note style
DESIGN:   name `-apple-system 8pt letterSpacing 0.14em uppercase col`; note `serif italic 9pt SUBTLE`
CURRENT:  name `.system(size: 8, weight: .regular).tracking(1.2).textCase(.uppercase)`, `stateColor`; note `.system(size: 9, design: .serif).italic()`, `theme.subtle` ✓
IMPACT:   low — tracking 1.2 vs design 1.4em — 0.2pt off

---

### Beat readout (76pt)

PROPERTY: font
DESIGN:   `DM Mono` weight 300, fontSize **76**, letterSpacing `-0.02em`
CURRENT:  `.system(size: 76, weight: .ultraLight, design: .monospaced)`
IMPACT:   low — `.ultraLight` (~100) is significantly lighter than design's weight 300 — same issue as FIELD verb

PROPERTY: color
DESIGN:   `hsl(stateHue, 58%, 68%)` (state color)
CURRENT:  `stateColor` ✓
IMPACT:   low

PROPERTY: editability
DESIGN:   tap to inline-edit via `EditableNum` (number input replaces text)
CURRENT:  tap to `TextField(.decimalPad)` ✓ — Swift uses decimal pad keyboard, design uses inline HTML number input
IMPACT:   low — same behaviour

PROPERTY: Hz suffix style
DESIGN:   `DM Mono 20pt weight 300`, color = stateColor at opacity 0.6, letterSpacing 0.04em, paddingBottom 12
CURRENT:  `.system(size: 20, weight: .light, design: .monospaced)`, `stateColor.opacity(0.6)`, `.padding(.bottom, 6)`
IMPACT:   low — Swift `padding(.bottom, 6)` vs design `paddingBottom: 12` — 6pt difference, baseline alignment may differ slightly

PROPERTY: randomize animation
DESIGN:   `animation: cycleNum 0.16s ease-in-out infinite` (opacity flickers 1.0↔0.4)
CURRENT:  `.opacity(randomizing ? 0.85 : 1.0)` static change (no flicker animation)
IMPACT:   medium — design's randomize flickers the number rapidly during cycling; Swift just dims it to 0.85. Cycling display values change (per the timer code in `letTheFieldChoose`) but without the flicker animation it feels less frantic/searching.

---

### State card

PROPERTY: dot
DESIGN:   `6 × 6`, shadow `0 0 8px 2px ${col}55` (0.33 alpha)
CURRENT:  `frame(width: 6, height: 6)`, `.shadow(color: stateColor.opacity(0.55), radius: 4)`
IMPACT:   low — Swift shadow alpha 0.55 vs design 0.33; design has 2px spread Swift doesn't

PROPERTY: state label
DESIGN:   `9pt letterSpacing 0.22em uppercase col`
CURRENT:  `.system(size: 9, weight: .light).tracking(2.2)`, `stateColor` ✓
IMPACT:   low

PROPERTY: essence
DESIGN:   `serif italic 11pt SUBTLE flex 1`
CURRENT:  `.system(size: 11, design: .serif).italic()`, `theme.subtle`, `.lineLimit(1)` ✓
IMPACT:   low

PROPERTY: chevron
DESIGN:   `∨` (unicode) 10pt, `FAINT`, rotating 180°
CURRENT:  SF Symbol `chevron.down` at 9pt weight medium, `theme.subtle.opacity(0.7)`, rotating 180°
IMPACT:   low — different glyph source; effect is the same

PROPERTY: expanded detail
DESIGN:   `serif italic 13pt MUTED lineHeight 1.75`
CURRENT:  `.system(size: 13, design: .serif).italic()`, `theme.muted`, `.lineSpacing(4)` (13 + 4 = 17pt vs design 22.75pt)
IMPACT:   medium — Swift packs the detail tighter; design wants airy reading rhythm

PROPERTY: range label (expanded)
DESIGN:   `9pt letterSpacing 0.16em uppercase FAINT`
CURRENT:  `.system(size: 9, weight: .light).tracking(1.6).textCase(.uppercase)`, `theme.subtle.opacity(0.7)` ≈ 0.196
IMPACT:   low — Swift slightly brighter than design's FAINT (0.12)

---

### Sliders (Lab)

PROPERTY: label width
DESIGN:   `width: 64`
CURRENT:  `frame(width: 60)`
IMPACT:   low — 4pt narrower

PROPERTY: thumb diameter
DESIGN:   `12 × 12`
CURRENT:  `frame(width: 12, height: 12)` ✓
IMPACT:   low

PROPERTY: thumb shadow
DESIGN:   `0 0 10px ${colDim}`
CURRENT:  `.shadow(color: stateColor.opacity(0.5), radius: 6)`
IMPACT:   low — close

PROPERTY: track height / color
DESIGN:   `1pt, rgba(255,255,255,0.12)`
CURRENT:  `1pt, Color.white.opacity(0.12)` ✓
IMPACT:   low

PROPERTY: right-side readout
DESIGN:   `EditableNum 14pt mono state-colored` (also editable here)
CURRENT:  `Text` `.system(size: 11, weight: .light, design: .monospaced)`, `stateColor.opacity(0.85)`, width 64 trailing — **non-editable** from slider row (only editable via the 76pt readout above)
IMPACT:   medium — design's slider-row readout is also tap-to-edit; Swift's is read-only. Functional + visual (14pt vs 11pt) difference.

---

### Sacred frequency map

PROPERTY: horizontal padding
DESIGN:   `padding: 0 28px`
CURRENT:  manual `28 + pct * W` x-offsets, `geo.size.width - 56` width ✓
IMPACT:   low

PROPERTY: track height / color
DESIGN:   `1pt rgba(255,255,255,0.07)`
CURRENT:  `Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)` ✓
IMPACT:   low

PROPERTY: sacred dot — non-hit
DESIGN:   `3 × 3`, `rgba(255,255,255,0.22)`
CURRENT:  `frame(width: 3, height: 3)`, `Color.white.opacity(0.22)` ✓
IMPACT:   low

PROPERTY: sacred dot — hit
DESIGN:   `6 × 6`, state color, `boxShadow: 0 0 10px 3px ${col}66` (0.40 alpha)
CURRENT:  `frame(width: 6, height: 6)`, `stateColor`, `.shadow(color: stateColor.opacity(0.55), radius: 5)`
IMPACT:   low — Swift alpha 0.55 vs design 0.40; close

PROPERTY: current-carrier cursor
DESIGN:   `10 × 10`, state color, `boxShadow: 0 0 12px 3px ${col}55` (0.33 alpha)
CURRENT:  `frame(width: 10, height: 10)`, `stateColor`, `.shadow(color: stateColor.opacity(0.55), radius: 6)`
IMPACT:   low — Swift alpha 0.55 vs design 0.33

PROPERTY: sacred label font / size
DESIGN:   `DM Mono 7pt letterSpacing 0.06em`
CURRENT:  `.system(size: 7, weight: .light, design: .monospaced).tracking(0.4)` ✓
IMPACT:   low — tracking 0.4 vs design 0.42 — within margin

PROPERTY: sacred label layout
DESIGN:   labels positioned **below** the track using `position: absolute; top: 16` per dot, with a 28pt margin-left offset (visually labels sit beneath their dots)
CURRENT:  per-dot `VStack { Circle; Text(entry.name) }`, dot at `y: 14`, label sits directly under each dot
IMPACT:   low — different layout method; visually similar (label-under-dot)

PROPERTY: sacred label — hit color
DESIGN:   state color when hit, `FAINT` (0.12) otherwise
CURRENT:  `stateColor` when hit, `theme.subtle.opacity(0.5)` = `0.14` otherwise
IMPACT:   low — close

PROPERTY: total height
DESIGN:   24pt track + ~4pt margin + label space
CURRENT:  `.frame(height: 28)`
IMPACT:   low

---

### Preset chips

PROPERTY: padding
DESIGN:   `padding: 7px 12px`
CURRENT:  `.padding(.horizontal, 12).padding(.vertical, 7)` ✓
IMPACT:   low

PROPERTY: corner radius
DESIGN:   `borderRadius: 20`
CURRENT:  `RoundedRectangle(cornerRadius: 18)`
IMPACT:   low — 2pt smaller, barely perceptible at chip scale

PROPERTY: inactive fill
DESIGN:   `SURFACE` = `rgba(255,255,255,0.042)`
CURRENT:  `theme.surface` = `white.opacity(0.042)` ✓
IMPACT:   low

PROPERTY: inactive border
DESIGN:   `1px solid BORDER` (white 0.08)
CURRENT:  `RoundedRectangle().stroke(theme.border)` (white 0.08) ✓
IMPACT:   low

PROPERTY: active fill
DESIGN:   `hsl(stateHue, 38%, 14%)`
CURRENT:  `Color(hue: stateHue/360, saturation: 0.38, brightness: 0.14)` ✓
IMPACT:   low

PROPERTY: active border
DESIGN:   `1px solid col + '55'` = state color @ ~0.33 alpha
CURRENT:  `stroke(stateColor.opacity(0.33))` ✓
IMPACT:   low

PROPERTY: name text
DESIGN:   `-apple-system 10pt letterSpacing 0.10em` (~1pt tracking), `col` when active else `MUTED`
CURRENT:  `.system(size: 10, weight: .light).tracking(0.8)`, `stateColor` when active else `theme.muted`
IMPACT:   low — tracking 0.8 vs design 1.0 — within margin

PROPERTY: tag text
DESIGN:   `serif italic 9pt SUBTLE marginTop 1`
CURRENT:  `.system(size: 9, design: .serif).italic()`, `theme.subtle` ✓
IMPACT:   low

PROPERTY: "+ save" chip
DESIGN:   same chip style, sans-serif 10pt `SUBTLE`
CURRENT:  matching chip style, `.system(size: 10, weight: .light)`, `theme.subtle` ✓
IMPACT:   low

---

### Action buttons

PROPERTY: gap
DESIGN:   `gap: 12`
CURRENT:  `HStack(spacing: 12)` ✓
IMPACT:   low

PROPERTY: shape / corner radius
DESIGN:   `borderRadius: 24` (pills)
CURRENT:  `Capsule()` ✓
IMPACT:   low

PROPERTY: vertical padding
DESIGN:   `padding: 13px 0`
CURRENT:  `.padding(.vertical, 13)` ✓
IMPACT:   low

PROPERTY: randomize — border
DESIGN:   `1px solid rgba(255,255,255,0.18)`
CURRENT:  `Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)` ✓
IMPACT:   low

PROPERTY: randomize — text style
DESIGN:   `Lora,Georgia,serif italic 13pt`, `MUTED` (or `FAINT` while randomizing)
CURRENT:  `.system(size: 13, design: .serif).italic()`, `theme.muted` (or `theme.subtle` while randomizing) ✓
IMPACT:   low — Swift "randomizing" state uses `theme.subtle` (0.28) where design uses `FAINT` (0.12); slightly brighter than designed

PROPERTY: activate — width ratio
DESIGN:   `flex: 1.2` (≈ 20% wider than randomize)
CURRENT:  `.layoutPriority(1.2)` on activate
IMPACT:   medium — `layoutPriority` in SwiftUI is **not** equivalent to flex-grow. It changes priority order but the resulting width depends on intrinsic content size. The design's "activate is 20% wider" intent is not reliably preserved.

PROPERTY: activate — inactive fill
DESIGN:   `TEXT` (#F5E2D6)
CURRENT:  `theme.text` ✓
IMPACT:   low

PROPERTY: activate — active fill
DESIGN:   state color (`col`)
CURRENT:  `stateColor` ✓
IMPACT:   low

PROPERTY: activate — text style
DESIGN:   `-apple-system 10pt letterSpacing 0.18em uppercase`, color `BG` (#020208)
CURRENT:  `.system(size: 10, weight: .regular).tracking(1.8)`, `theme.bg` ✓
IMPACT:   low

PROPERTY: activate — active glow
DESIGN:   `0 0 28px ${colGlow}` (0.22) + `0 0 60px ${col(0.10)}` — **two shadows**
CURRENT:  `.shadow(color: stateColor.opacity(0.22), radius: 28)` — **one shadow**
IMPACT:   medium — design's wide outer halo (60pt blur @ 0.10) is missing in Swift, just like the play/pause button. Active state feels less luminous than designed.

PROPERTY: activate — transition
DESIGN:   `transition: all 0.4s cubic-bezier(0.4,0,0.2,1)`
CURRENT:  `.animation(.easeOut(duration: 0.4), value: isPlaying)` ✓
IMPACT:   low

---

## Summary

**Total differences flagged: 119**

By impact tier:
- **HIGH:** 4 differences (sheet translucency × 2, recognition-text legibility, verb shadow alpha)
- **MEDIUM:** 16 differences
- **LOW:** 99 differences (small alpha/size/spacing nudges within tuning tolerance)

---

## HIGH-IMPACT FIX LIST

These four differences materially break the design's intent and should be addressed before the visual fidelity pass is declared complete.

### 1. FIELD mode — recognition statement is 5× too bright
- **Where:** `PlayerView.swift:239` (`fieldContent` view)
- **Design:** `FAINT` = `rgba(245,226,214,0.12)` — an atmospheric whisper at the edge of perception
- **Current:** `theme.text.opacity(0.65)` — fully readable body copy
- **Why it matters:** The design treats the recognition statement as ambient context that catches your eye only after the verb has landed. At 0.65 alpha it competes with the verb itself; at 0.12 it sits behind it.
- **Suggested fix:** `theme.text.opacity(0.12)` or `theme.subtle.opacity(0.43)` to land at ~0.12 effective.

### 2. CONTROL sheet — `.ultraThinMaterial` is too translucent
- **Where:** `PlayerView.swift:373` (`controlSheet` `fill(.ultraThinMaterial)`)
- **Design:** `rgba(5,5,16,0.97)` + `backdropFilter: blur(28px)` — near-opaque dark indigo with a soft blur
- **Current:** `.ultraThinMaterial` + `Color.white.opacity(0.04)` overlay
- **Why it matters:** The design wants the control surface to feel like a solid instrument panel that the visualizer cannot reach. `.ultraThinMaterial` lets the visualizer flicker through, undermining the "field continues above; controls are grounded" intent.
- **Suggested fix:** Replace `.ultraThinMaterial` fill with a solid color close to `Color(red: 5/255, green: 5/255, blue: 16/255).opacity(0.97)` and apply blur via `.background(.ultraThinMaterial.opacity(0.4))` underneath if a touch of glass texture is desired.

### 3. READING sheet — same translucency issue
- **Where:** `PlayerView.swift:717` (`readingSheet` `fill(.ultraThinMaterial)`)
- **Design:** `rgba(5,5,15,0.98)` + `backdropFilter: blur(28px)` — even more opaque than CONTROL
- **Current:** `.ultraThinMaterial` + `white.opacity(0.04)` overlay
- **Why it matters:** Reading is the "depth" mode — text needs a calm, almost-opaque ground. Flicker from the ambient viz above breaks reading flow.
- **Suggested fix:** Same as #2, with target alpha 0.98.

### 4. FIELD verb shadow is too hot
- **Where:** `PlayerView.swift:225` (`fieldContent` `.shadow(color: elementColor.opacity(0.5), radius: 22)`)
- **Design:** `textShadow: 0 0 48px ${col @ 0.28}, 0 0 100px ${col @ 0.10}` — two layered shadows, tight bright + wide faint
- **Current:** single `.shadow(elementColor.opacity(0.5), radius: 22)` — nearly 2× the design's primary alpha, and missing the wide outer halo
- **Why it matters:** The verb is the strongest single gesture in the app. The design's two-shadow stack gives it a "presence aura" the single shadow can't approximate. At 0.5 alpha the verb reads as glowy / new-age; at 0.28 + 0.10 it reads as luminous / settled.
- **Suggested fix:** Stack two `.shadow()` modifiers — first `elementColor.opacity(0.28), radius: 24`, then `elementColor.opacity(0.10), radius: 50`.

---

## Secondary observations (not flagged above but worth noting)

- The FIELD `background` adds a centered `RadialGradient` of `elementColor.opacity(0.14)` that the design does not have. The design relies entirely on the visualizer's own atmospheric layers to color the void. Removing the Swift radial may bring the FIELD background closer to the design's `BG` flat fill.
- The `.ultraLight` font weight used for the FIELD verb and the Lab 76pt readout is materially thinner than CSS `font-weight: 300`. Consider `.light` for closer match.
- The CONTROL toggle row layout puts the breathing dot at the trailing edge via `Spacer()`; the design clusters [toggle][ON][dot] together at the leading edge.
- LALITA empty-state copy in Swift is fully lowercased ("the Lalita reading…", "return when…"); the design uses sentence case for those two lines specifically, breaking the otherwise-lowercase pattern.
- Multiple "two-shadow" patterns in the design (verb, play/pause, slider thumb, activate button) all collapse to single shadows in Swift. Establishing a shared two-shadow pattern (e.g. a small `View` extension) would close most of the MEDIUM-impact glow differences in one pass.
- READING WORDS / LALITA paragraphs use `lineSpacing(6)` in Swift; design uses `lineHeight: 1.82` which is ~12pt of effective leading at 15pt size. The packed Swift rhythm reduces meditative whitespace.
