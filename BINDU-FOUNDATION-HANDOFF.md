# Bindu Field — Foundation Handoff
**Branch:** `feat/foundation-cleanup`
**Depends on:** `feat/dsp-wire-player-upgrade` merged to main

Read `CLAUDE.md`. Then read `ARCHITECTURE-AUDIT.md`.

`ARCHITECTURE-AUDIT.md` is your complete work order. Fix every item in it — all 18 bugs, all 25 opportunities, all 24 gaps. Nothing is deferred.

---

## Permissions

For this session only, you may modify `BinauralEngine.swift` and `BinauralListener.swift` — but only for the specific fixes named in the audit (B2, B3, B4, B7). Make the minimum viable change for each. Do not refactor the engine architecture.

All other existing constraints are lifted for this session. The audit is authoritative.

---

## Design Decisions — Pre-made

These require context beyond the code. Use them as-is:

**G13 — Carrier source of truth:**
Airtable `carrierHz` is the initial hint set at play time. The DSP-derived carrier (at 10s) overrides it when available. DSP wins. This is already the behavior — document it clearly in code comments so it's unambiguous.

**G7 — Unused themes:**
Delete `ThemeData.dusk` and `ThemeData.mist`. The app is committed to the void theme. If a theme picker is ever added, it starts fresh.

**G8 — youtubeID:**
Keep the field. It is intentionally retained for a future "watch on YouTube" affordance in the Player. Do not remove it.

**G6 — defaultSessionDuration:**
Do not delete. Wire it as the default duration for Space and Lab sessions — they should read `SettingsStore.shared.defaultSessionDuration` rather than hardcoding their own defaults. The Settings UI row stays.

**B1 — AudioSessionCoordinator:**
Implement it. A single `AudioSessionCoordinator` owns all `AVAudioSession` category transitions. `BinauralEngine`, `BinauralListener`, and `RecorderService` request through it — they do not call `setCategory` directly. `NowPlayingService` configures once at launch through it. The coordinator serializes all requests.

**O1 — Theme environment:**
Implement `@Environment(\.binduTheme)` with `ThemeData.void` as the default. Remove the per-view `private let theme = ThemeData.void` declarations. This is the correct SwiftUI pattern.

**O14 / G9 — Remote commands:**
`pause` and `togglePlayPause` should invoke `BinauralEngine.updateGain(0)` — a soft mute, not a stop. `play` should restore gain. `stop` remains a full stop. This gives the lock screen a real pause affordance without requiring true seek/resume on `BinauralListener`.

**O25 — Keychain access:**
Set `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` on all Keychain writes. This enables background reads after the device has been unlocked once.

---

## Approach

Work through items in this sequence. Commit at each boundary.

**Pass 1 — Critical bugs** (B1–B18)
All bugs in the audit. Start with the highest-severity items. Each fix is self-contained.

**Pass 2 — Opportunities** (O1–O25)
Code quality, performance, robustness, UX polish. O1 (theme environment) touches many files — do it last within this pass so other opportunity fixes can use the simple pattern while it exists, and O1 migrates them all at once.

**Pass 3 — Gaps** (G1–G24)
Dead code removal, unfinished wiring, missing UI surfaces. G11 (Session.note in Archive) is the most user-visible — prioritize it within this pass.

---

## Self-Verification Protocol

After all three passes, before reporting back, conduct your own verification sweep. Do not skip this.

**Step 1 — Build**
```bash
xcodebuild -scheme "Bindu Field" -destination "generic/platform=iOS" -configuration Debug build
```
Zero errors. Zero warnings. If any warnings, fix them before proceeding.

**Step 2 — Audit cross-check**
For every item in `ARCHITECTURE-AUDIT.md`, write a one-line entry in your report: what you did, or why the item is now resolved. Nothing should be unaddressed.

**Step 3 — Grep verification**
Run these checks and confirm the expected outcomes:

```bash
# B5: PlayerStore should not double-stop
grep -n "BinauralEngine.shared.stop\|TrackPlaybackService.shared.stop" "Bindu Field/Stores/PlayerStore.swift"
# Expected: only one stop path, not both

# G3: dead carrierDerivationTimer property gone
grep -rn "carrierDerivationTimer" "Bindu Field/"
# Expected: zero hits

# G5: purgeAll wired to Settings or removed
grep -rn "purgeAll" "Bindu Field/"
# Expected: either a caller exists, or zero hits

# G7: dusk/mist deleted
grep -rn "ThemeData.dusk\|ThemeData.mist" "Bindu Field/"
# Expected: zero hits

# O1: no more per-view theme declarations
grep -rn "let theme = ThemeData" "Bindu Field/"
# Expected: zero hits (environment key is the only declaration)

# O14: stop handler no longer handles pause/togglePlayPause
grep -A3 "pauseCommand\|togglePlayPauseCommand" "Bindu Field/Stores/NowPlayingService.swift"
# Expected: separate, non-stop handlers

# B4: userStoppedFlag in BinauralListener
grep -n "userStopped\|userStop" "Bindu Field/BinauralListener.swift"
# Expected: flag exists and is checked before posting .binduPlaybackComplete

# B11: timer in .common run-loop mode
grep -n "RunLoop\|forMode" "Bindu Field/Stores/DSPWireService.swift"
# Expected: .common mode

# B13: empty fetch guard in CatalogStore
grep -A5 "fetched.isEmpty\|records.isEmpty" "Bindu Field/Stores/CatalogStore.swift"
# Expected: guard that prevents overwriting cache on empty response

# G17: updateElapsed called somewhere
grep -rn "updateElapsed" "Bindu Field/"
# Expected: a caller exists

# G11: Session.note displayed in ArchiveView
grep -n "note" "Bindu Field/Views/Tabs/ArchiveView.swift"
# Expected: note field referenced in SessionRow or detail view
```

**Step 4 — Fix anything the verification sweep finds**
If any check fails unexpectedly, fix it before reporting.

**Step 5 — Final build**
One more clean build confirming zero errors and zero warnings.

---

## Report Format

When done, report back with exactly this structure:

**FIXED** — list every audit item addressed with a one-line description of what was done.

**DESIGN CHOICES MADE** — any item where you made a judgment call beyond the pre-made decisions above. Name the choice clearly so it can be reviewed.

**NEEDS HUMAN DECISION** — any item that requires information only Ashrey can provide (content, visual direction, feature intent).

**COULD NOT FIX** — any item that proved impossible without external dependencies or out-of-scope architectural changes. Be specific about why.

**VERIFICATION RESULTS** — the output of each grep check and whether it passed.

**BUILD STATUS** — final build result.

Do not merge. Leave on `feat/foundation-cleanup`.
