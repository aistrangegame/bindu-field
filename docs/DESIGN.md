# Design tokens

## Palette — `ThemeData.void` (the canonical dark theme) + `ThemeData.light`

Two palettes ship since `b9c2918`: the dark `void` below and a warm-paper `light` (`Theme` is a `struct`; `id == "light"` exposes `isLight`). `SettingsStore.themeMode` (`"system"`/`"light"`/`"dark"`) picks via `activeTheme(for:)`; `RootView` injects it into `\.binduTheme` and sets `preferredColorScheme`. **Immersive Canvas scenes (PlayerView vocabularies, breath/ritual immersed views) are pinned to `ThemeData.void` regardless of theme** so the element worlds stay dark. The token table below documents `void`; `light` mirrors its opacity structure with `surface`/`border` becoming dark-on-light.

| Token | Value (sRGB) | Notes |
|---|---|---|
| `bg` | `#020208` (very near-black with a hint of blue) | base background; `PlayerView` overrides with `vocab.bg` (per-element near-black) |
| `bg2` | `#05050F` | rarely used today — slight elevation |
| `text` | `#F5E2D6` (warm off-white, the "Bindu cream") | all primary text, button fill |
| `muted` | `text @ 0.68` | secondary text, button strokes (raised from 0.55 in the `b9c2918` contrast pass) |
| `subtle` | `text @ 0.40` | labels, tiny captions, hint copy (raised from 0.28 in the `b9c2918` contrast pass) |
| `accent` | `#D46453` (warm coral-red) | the Bindu red — selection, slider tint, active toggles, "Begin" buttons |
| `gold` | `#C4A862` (defined but rarely surfaced) | available for ceremonial accent |
| `border` | `white @ 0.08` | rarely used directly |
| `surface` | `white @ 0.042` | card / input field background |
| `cornerRadius` | 10 | reference; many surfaces use 12 / 14 / 16 / 18 / 32 directly |
| `hueShift` | 0 | reserved for a theme-shift future |
| **Bindu birth red** | `#E5524E` | hardcoded in `BinduBirthView` + `FieldView` central core; brighter than `accent` and reserved for the Bindu glyph itself |

## Element colors — `Color.bindu(element:)` (single source of truth in `Views/Components/ElementColors.swift`)

| Element | HSB (×360, 0–1, 0–1) | Roughly |
|---|---|---|
| Earth | `15 / 0.55 / 0.85` | terracotta |
| Water | `210 / 0.50 / 0.90` | azure |
| Fire | `25 / 0.65 / 0.95` | amber-orange |
| Air | `195 / 0.40 / 0.92` | pale teal |
| Light | `50 / 0.50 / 0.95` | warm yellow |
| Crown | `280 / 0.45 / 0.90` | lavender |
| Soul | `265 / 0.50 / 0.85` | violet |
| Dissolution | `190 / 0.40 / 0.85` | desaturated cyan |
| Meditate | greyscale `0.75` | neutral |
| Family | `330 / 0.35 / 0.88` | dusty rose |
| (unknown) | greyscale `0.75` | fallback |

`Color.binduHue(element:)` exposes the hue in degrees for callers that want to mix custom saturation/brightness (Oracle response glow, Loop reveal, badge surfaces). `Color(hex:)` is a simple "#RRGGBB" → `Color` init used throughout the design pass.

## Chakra colors — Map nodes via `ChakraRegistry.all[].hue` at `saturation 0.60, brightness 0.68`

Map node hues are authored in degrees on each `ChakraNode`, drawn directly via `Color(hue: node.hue/360, saturation: …, brightness: …)`. The 9 composed chakras share hues with the Track elements where they overlap (Muladhara 15 / Svadhisthana 210 / Manipura 25 / Anahata 195 / Vishuddha 185 / Ajna 50 / Sahasrara 280 / Aatma 265 / Maya 190).

## Typography

- **Display verbs / headlines** — `.font(.system(size: 62 / 32 / 28 / 24, weight: .ultraLight, design: .serif)).italic()`. The verb at 62pt in element color with element-color shadow `radius: 24 + 50` is the strongest single visual gesture in the app. Oracle's response verb is even larger (72pt).
- **Body / inline narration** — `.font(.system(size: 13–17, design: .serif)).italic()`. Almost everything emotional reads in italic serif: prompts, affirmations, "flowing", "fetching the field…", "speak from this state".
- **Section labels / chip captions** — `.font(.system(size: 7–11, weight: .light)).tracking(1.5–5).textCase(.uppercase)`. Tracking widens with importance — Map title goes to 5.0; binaural label 2.0; section headers 2.5.
- **Numerics** — `.font(.system(size: 9–76, design: .monospaced))`. Carrier, beat, elapsed, percentages.
- **Tabs / system UI** — Tab labels render as serif italic via `Text(...).font(.system(...))` injected into `Label.title` so the Bindu Canvas glyph sits next to typeset text rather than SF Symbol + system font.

## Glow vocabulary

`.binduGlow(color: tight: wide:)` is a two-layer shadow extension. The design's verbs / buttons never use a single shadow — they use a tight inner halo (radius 14, opacity 0.22) + a wider ambient bloom (radius 40, opacity 0.08). Calling `.shadow` twice in a row stacks them correctly. Default arguments match the design; callers override `tight`/`wide` to dim the glow for inactive states (Lab's ACTIVATE button uses 0 / 0 when stopped).

## Surface vocabulary

- **Capsule, filled** — primary action: `Capsule().fill(theme.text)` + `foregroundColor(theme.bg)` (i.e. the cream button with near-black text). Used for Begin / Save / ACTIVATE.
- **Capsule, stroked** — secondary: `Capsule().stroke(theme.muted.opacity(0.3), lineWidth: 1)` with `theme.muted` text. Used for stop / close / cancel.
- **Capsule, element-stroked** — Map CTAs, Loop close: `Capsule().stroke(elementColor.opacity(0.30))` with element-color text.
- **Capsule, ultraThinMaterial** — overlay surface: binaural pill, error/headphone banners (with `Color.black.opacity(0.92)` underlay).
- **RoundedRectangle, surface-filled** — card: `theme.surface` fill + `theme.muted.opacity(0.15–0.25)` stroke. Used for Settings sections, Oracle input (typing state), Integration Chamber input, ChakraTile, Letter recorder review.
- **UnevenRoundedRectangle (top corners 32)** — the Player CONTROL + READING sheets. Near-opaque dark panel + `ultraThinMaterial.opacity(0.20–0.25)` + 1pt cream-0.07 stroke.
- **Radial gradients** — element/chakra-color × 0.12–0.25 from center → `theme.bg`. SpaceImmersedView, LabView background, LetterRecordView recording.

## Motion vocabulary

| Duration | Easing | Used for |
|---|---|---|
| 0.10–0.20s | linear / easeInOut | breath ring scale, meter follows |
| 0.25–0.32s | easeInOut | state-info expand/collapse, preset-name field flip, mode transitions text crossfade |
| 0.30s | easeInOut | tab program-switch, countdown digit cross-fade |
| 0.40s | easeInOut / easeOut | chip selection, headphone-tip dismiss, audio-error banner |
| 0.45s | spring (response 0.45, damping 0.85) | Player mode transitions FIELD↔CONTROL↔READING |
| 0.60s | easeOut / easeInOut | Player arrival ceremony, recording-bg color follow, Bindu pulse |
| 0.18–0.25s | easeOut | carrier-lock 1.5× pulse |
| 1.0s ×∞ autoreverses | easeInOut | CONTROL toggle-row breathing dot (2s total cycle) |
| 1.3s ×∞ autoreverses | easeInOut | binaural pill breathing dot |
| ~10s (cycle) | linear | central Bindu breathing in Field (sin 0.628 Hz) |
| 5.5s | smoothstep | Loop pre-roll breath ring |
| 14s | sine | Oracle presence fog breath |
| seconds-scale | TimelineView .animation | Visualizer Lissajous, vocabulary draws, breath ring, constellation rotation, Map breath |

## Iconography

Tab bar: custom 28×28 Canvas glyphs — Map (3 concentric orbits + cardinals + dot) · Field (constellation) · Oracle (concentric whisper) · Space (crescent + dot) · Lab (oscilloscope) · Archive (stacked horizons) · Ritual (flame) · Letter (sealed envelope). All cream, active = full opacity, inactive = 0.40.

Other recurring icons: `chevron.up/down/left` for collapsibles · `xmark` for close (PlayerView top-right uses it inside a black-0.25 disc) · `stop.fill` / `play.fill` / `pause.fill` · `headphones` (tip) · `gearshape` (settings) · `arrow.clockwise` (refresh) · `square.and.arrow.up` (share) · `speaker.slash` (error banner) · `wifi.slash` (offline catalogue) · `scope` (carrier-derived).

## Voice

Lowercase serif italic prompts. "the constellation". "a body has thirty-three doors". "speak from this state". "find your own frequency". "weave a sequence". "breathe with the field". "the Oracle awaits a key". "what word has been waiting in you?". "I see you. You have always been here." Labels are usually a verb or a noun, never a sentence. Buttons say "Begin", "BEGIN THE LOOP", "ENTER THE FIELD", "ENTER THIS DANCE", "DANCE AGAIN" — capitalized + tracked, the rare break from lowercase.
