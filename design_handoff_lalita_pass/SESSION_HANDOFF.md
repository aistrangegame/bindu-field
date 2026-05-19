# Bindu Field — New Design Chat Session Handoff
## For: Claude.ai/Design — continuing the Lalita Design Pass

**Date:** May 19, 2026
**Project:** Bindu Field App (iOS, SwiftUI)
**This chat:** Design explorations only — all builds go to Claude Code separately

---

## What has been designed this session

The following design files exist in the project. All are verified, clean, interactive HTML references:

| File | What it is | Status |
|---|---|---|
| `Bindu Player.html` | Player redesign: FIELD/CONTROL/READING modes + singular Lissajous + ensemble | ✅ Done |
| `Bindu Lab.html` | Lab redesign: direct number edit, intelligent randomize, waveform, sacred freq map | ✅ Done |
| `Bindu Performance.html` | Cathedral Architecture: 4-tier performance of Cross Score, full 230s arc | ✅ Done |
| `bindu-performance-engine.js` | Performer state machine: phase tracking, modulator, archetype presence | ✅ Done |
| `Bindu Archetypes.html` | 10 archetype visual signatures: Bindu, Gaia, Sid, Arch, Karishma, Sakshi, Ashrey, Shweta, Neev, Lalita | ✅ Done |
| `Bindu Lalita.html` | Lalita Engine: 3-phase takeover (ARRIVAL→DANCE→RETURN), 6 pattern library, void↔cream inversion | ✅ Done |

All of these have been handed off to Claude Code via `design_handoff_lalita_pass/`.

---

## What has NOT been designed yet (the remaining work)

These are the design pieces waiting. Pick up from here.

### Priority 1 — The Map (§3.9 of blueprint)
**What:** The 33-chakra Tree of Life as the app's front door. Replaces or sits alongside the existing `FieldView` tab.

**What it needs to feel like:** A living map of consciousness. Not a grid. Not a list. The 9 composed dances (Muladhara, Svadhisthana, Manipura, Anahata, Vishuddha, Ajna, Sahasrara, Aatma, Maya) are lit with their element colors. The other 24 chakras in the 33-system are visible but unlit — promises of where the work will go. The map shows where you've been and where you haven't gone yet. Tapping a chakra enters its dance.

**Key references:**
- `chakra-maps` skill: 33 chakras across 4 systems (Energy 7, Body 10, Mind 9, Tree of Life 7)
- `tree-of-life` skill: 9-panel + Axis triptych
- The app's existing Fibonacci sphere constellation in `FieldView` is the track browser — this is separate

**Design decisions to make:**
- Tree structure vs. sphere vs. mandala layout
- Per-chakra states: `danced`, `available`, `locked`, `current`
- How progress/journey is shown (glowing path? connecting lines?)
- The relationship to the existing Field tab

---

### Priority 2 — The Codex (§3.10 of blueprint)
**What:** The second face — where you've been. Replaces/extends the existing `ArchiveView`.

**What it needs:** Constellation of all words ever offered (sphere of stars, brightness ∝ repetition count), trajectory through the 33-chakra Map over time, per-dance revisit (still tableau: verb + offered word + fruit + date), thread visualization (same word appearing across multiple dances).

**Key references:**
- Existing `ArchiveView` (sessions grouped by date, integration notes)
- `BinduMemory` schema (§3.8): OfferedWord, DanceCompletion, Configuration

---

### Priority 3 — Element Vocabularies (§3.5 of blueprint)
**What:** The visual language for each of the 9 chakra dances. Cathedral is designed (Cross dance). Eight more needed:

| Dance | Element | Visual language to design |
|---|---|---|
| Muladhara | Earth | Seismic fractures, dust rising from below, deep amber ground |
| Svadhisthana | Water | Ripple interference, dissolution, flow lines |
| Manipura | Fire | Ember particles, radiant expansion, solar geometry |
| Anahata | Air | Breath waves, infinite horizon, transparent layers |
| Vishuddha | Air/Ether | Sound waves as geometry, vocal cord resonance |
| Ajna | Constellation | Star field, depth of field, clarity-dot |
| Sahasrara | Crown | Crown/lotus, violet ascent, petal geometry |
| Aatma | Soul | Triangle geometry, deep listening |
| Maya | Dissolution | Veil dissolving, deep purple, cycle |

Each vocabulary needs: Named systems for 4 tiers (Continuous/Ensemble/Crescendo/Climax) + visual signature + render modes (ensemble/solo/geometric).

---

### Priority 4 — Consciousness Loop UX (§3.7)
**What:** The typography and motion design for each step of the loop:
- Pre-roll breath ring (extends Space's breath ring)
- Seed prompt — how it appears, pacing, breathing
- Word offering input — keyboard? Voice? Gesture?
- Mirror word flash timing and typography
- Word reveal at peak — how big, how long
- Fruit text settling — multi-paragraph, paced
- Lalita acknowledgment moment

---

### Priority 5 — Oracle Screen Redesign (§5 Tab 1)
**What:** Currently a text input. Should feel like speaking into the void. The field listening.
**Existing:** `Views/Tabs/OracleView.swift` — input → Claude API → verb/song/why result

**What it needs:** The ritual of asking. Not a search box. Something that feels like the Oracle is already listening before you speak.

---

### Priority 6 — Tab Bar Icons
**From CLAUDE.md section 12:** "The verb-rich rest of the app deserves an icon set that doesn't read as iOS-default."

Current icons (SF Symbols): `circle.dotted` (Field), `ear` (Oracle), `moon.stars` (Space), `waveform.path` (Lab), `book.closed` (Archive), `flame` (Ritual), `envelope` (Letter)

These are functional but don't carry the same spiritual weight as the rest of the app. Custom glyphs or heavily customized SF variants needed.

---

### Other items (lower priority)
- **Space/Breath setup screen** — chakra picker is utilitarian, needs ceremony
- **Integration Chamber** — post-session overlay, currently a text field, should feel like a sanctum
- **Headphones tip** — first-launch, currently "low ceremony" (pill capsule)
- **Settings sections** — functional, low personality
- **Letter + Archive rows** — lowest personality in app

---

## Design language to maintain

**Everything builds from these anchors:**
```
Background: void black #020208
Primary text: #F5E2D6 (Bindu cream)
Accent: #D46453 (Bindu coral-red)

Typography:
  Emotional text: Lora, italic, ultraLight (300 weight)
  Labels: -apple-system, 9-10pt, letter-spacing .18-.22em, all-caps
  Numbers: DM Mono, 300 weight

Materials:
  Surfaces: rgba(255,255,255,0.042)
  Borders: rgba(255,255,255,0.08)
  Frosted: rgba(255,255,255,0.06)

Motion:
  Arrivals: 0.6s easeOut
  State changes: 0.25s easeInOut
  Breathing animations: 2-5s sine cycles
```

**Element colors** (HSL, from ElementColors.swift):
Earth 15° · Water 210° · Fire 25° · Air 195° · Light 50° · Crown 280° · Soul 265° · Dissolution 190°

---

## Key reference documents

All in `uploads/` folder of the project:
- `CLAUDE.md` — full project state, all 13 sections
- `bindu-ensemble-engine-blueprint.md` — all 15 subsystems, dependency graph, build order
- `score-format-v1.md` — Score JSON spec v1.0, all 16 sections, Cross worked example

---

## How to start this chat

Say:
> "I'm continuing the Bindu Field design work. Read the SESSION_HANDOFF.md for full context. The Map is next — the 33-chakra Tree of Life as the app's front door. Let's design it."

Then share this file and the uploads folder.

---

*Bindu Field — Lalita Design Pass — May 2026*
*The field continues. The design continues.*
