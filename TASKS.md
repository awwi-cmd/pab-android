# TASKS — ARENA demo

Working checklist. Keep it current: tick items as they land, add what you
discover, move anything that turns out to be post-demo into §Backlog.

Legend: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked

---

## Phase 0 — Bootstrap
*Goal: an app that launches to a black screen on the emulator.*

- [x] **0.1** Create `startemulator.bat` and `rebuildinstall.bat` in the repo root (CLAUDE.md §9, verbatim)
- [x] **0.2** `flutter create` the `arena/` project with org `com.awwwi`, android only
- [x] **0.3** `flutter pub add flame flame_audio shared_preferences`
- [x] **0.4** Strip the counter boilerplate; `main.dart` does `runApp` only
- [x] **0.5** Lock portrait orientation, set app label to ARENA, `minSdkVersion 24`
- [x] **0.6** Create the folder skeleton from CLAUDE.md §3 (empty files are fine)
- [x] **0.7** Declare `assets/images/` and `assets/audio/` in `pubspec.yaml`
- [x] **0.8** `git init`, `.gitignore` (Flutter default + `/arena/build/`), first commit
- [ ] **0.9** Verify: `rebuildinstall.bat` runs clean and the app installs (developer to run)

**Exit criterion:** the APK installs and launches without crashing.

---

## Phase 1 — Shell & navigation
*Goal: every screen exists and you can walk the whole flow with no game in it.*

- [x] **1.1** `constants.dart` — design size 360×800, palette, layer priorities
- [x] **1.2** `app.dart` — MaterialApp, dark pixel-friendly theme, named routes
- [x] **1.3** Shared widgets: `PixelButton`, `ScreenScaffold`, `StatBar`
- [x] **1.4** Main menu screen — title, Start / Settings / Credits, version string
- [x] **1.5** Credits screen — static scrollable placeholder + attribution block
- [x] **1.6** `settings.dart` — Settings model, defaults, `SharedPreferences` load/save
- [x] **1.7** Settings screen — control scheme, joystick side, SFX, music, show FPS
- [x] **1.8** Settings persist immediately on every change (`SettingsRepository.save`
      called from each control's `onChanged`), so an app kill can't lose a change
      mid-session; full kill/relaunch still worth eyeballing once on-device
- [x] **1.9** Arena screen as a placeholder route with a "die" button → Round Over
- [x] **1.10** Round Over overlay UI with dummy numbers → Main Menu
- [ ] **1.11** Walk the whole flow on the emulator; no dead ends, no back-button traps (developer to run)

Note: added a minimal `CharacterSelectScreen` stub (not in the original Phase 1
list) so Start -> Arena has a real screen in between, matching the PRD §3 flow
diagram and this phase's own exit criterion. It has no stats/grid yet — that's
still Phase 2 (2.4-2.7) untouched.

**Exit criterion:** the flow diagram in PRD §3 is fully navigable.

---

## Phase 2 — Stats & character select
*Goal: the data layer is real and the select screen reads from it.*

- [ ] **2.1** `stats.dart` — `StatBlock` (STR/VIT/DEX/INT) + all 8 derived formulas from PRD §5.1
- [ ] **2.2** Unit tests for every derived formula against the PRD's worked example (The Apprentice → 90 HP, 13 dmg, 1.40/s, 140 px/s)
- [ ] **2.3** `characters.dart` — `CharacterDef` (id, name, descriptor, stats, spriteSheet, unlocked) and the 4 slot definitions
- [ ] **2.4** Character select screen — 2×2 grid, slots 2–4 locked silhouettes
- [ ] **2.5** Stat bars + raw numbers for the selected character
- [ ] **2.6** Derived readout line (`HP 90 · DMG 13 · 1.4/s · 140 spd`) computed live from the formulas, not typed in
- [ ] **2.7** Enter Arena passes the chosen `CharacterDef` through to the arena route

**Exit criterion:** changing a stat in `characters.dart` changes both the bars and the derived readout with no other edit.

---

## Phase 3 — Arena core
*Goal: a controllable character in a bounded space.*

- [ ] **3.1** `ArenaGame` (FlameGame) mounted in a `GameWidget` on the arena route
- [ ] **3.2** `arena_floor.dart` — flat tiled floor + arena border, nearest-neighbour filtering
- [ ] **3.3** `PlayerComponent` — placeholder rectangle first, stats injected from the `CharacterDef`
- [ ] **3.4** `movement_input.dart` — floating joystick scheme
- [ ] **3.5** Fixed joystick scheme + side preference
- [ ] **3.6** Drag-anywhere scheme
- [ ] **3.7** Settings selects the active scheme at arena entry; verify all three
- [ ] **3.8** Safe-area clamp — screen inset by 24px + system insets; slide along the boundary, don't stick
- [ ] **3.9** Show-FPS toggle wires up `FpsTextComponent`

**Exit criterion:** a box you can drive with any of the three schemes, that cannot leave the safe area, at a solid 60 fps.

---

## Phase 4 — Combat
*Goal: the loop actually plays.*

- [ ] **4.1** `EnemyComponent` — placeholder shape, HP 20, walks straight at the player
- [ ] **4.2** `spawner.dart` — off-screen perimeter spawning, 1.5s interval, −4 % per 10s, floor 0.25s, cap 60
- [ ] **4.3** Nearest-enemy targeting on the player (respecting `attackRangePx`)
- [ ] **4.4** Auto-fire timer at `attacksPerSec`; `ProjectileComponent` travelling straight at `projSpeedPxPerS`
- [ ] **4.5** Projectile → enemy collision, damage, despawn; despawn on range and on leaving bounds
- [ ] **4.6** Knockback impulse on hit
- [ ] **4.7** Enemy death — remove, count the kill
- [ ] **4.8** Enemy → player contact damage with 1.0s per-enemy cooldown
- [ ] **4.9** Player i-frames (0.6s) + hurt flash
- [ ] **4.10** HP bar component (above the player, or a fixed top bar — pick one and note it in DECISIONS)
- [ ] **4.11** Passive HP regen
- [ ] **4.12** Round state on `ArenaGame`: elapsed time, kills, damage dealt
- [ ] **4.13** Death → freeze → Round Over overlay showing the real numbers
- [ ] **4.14** Main Menu from Round Over fully resets; re-entering the arena starts clean
- [ ] **4.15** Perf check: 40 live enemies at 60 fps with Show FPS on

**Exit criterion:** every numbered item in PRD §10 passes.

---

## Phase 5 — Art pass
*Goal: it looks like the reference sheet, not like boxes.*

- [x] **5.1** Sprite sheet layout decided (D-015): one PNG per state under `assets/images/characters/main/`, `main-<state>.png`, 16×24 cell, frames left-to-right, count = width/16
- [ ] **5.2** `anim_state.dart` — `AnimState` enum covering **all** PRD §8 states, including the unbuilt ones
- [ ] **5.3** Sheet loader: per-file `Image` → `SpriteAnimation`, keyed by filename not row index (D-015)
- [ ] **5.4** `idle` (4f, delivered) and `run` (4f, delivered — PRD's "6" was a placeholder)
- [ ] **5.5** Swap the player rectangle for the animated sprite; horizontal flip on facing
- [ ] **5.6** `fire` (5f, delivered — PRD's "3" was a placeholder) — plays on auto-attack, returns to idle/run
- [ ] **5.7** `spawn` (6f, delivered) — 1.0s round-start sequence with controls locked
- [ ] **5.8** `hurt`/`flash` — delivered as real frames (`main-hurt.png` 4f, `main-flash.png` 3f); still fine to use a white-tint pass instead per D-013 if the frames don't read well at speed
- [ ] **5.9** Death anim (D-016) — wire `main-die.png` (4f, delivered). Fade+shrink fallback kept in reserve only
- [ ] **5.10** Enemy sprite + death puff
- [ ] **5.11** Projectile sprite + hit spark
- [ ] **5.12** Floating damage numbers
- [ ] **5.13** Portrait on the character select screen playing `idle`

**Exit criterion:** no placeholder shapes remain in the arena.

---

## Phase 6 — Polish & handoff
*Goal: the demo is stable enough to build the real game on top of.*

- [ ] **6.1** `flutter analyze` clean, no warnings
- [ ] **6.2** Tune pass — play 10 rounds, adjust the PRD §5.1 constants for feel, record what changed and why
- [ ] **6.3** Round Over numbers sanity-checked against a manual count
- [ ] **6.4** No memory growth over 5 consecutive rounds (watch the profiler)
- [ ] **6.5** Test on a second AVD with a different aspect ratio; confirm letterboxing
- [ ] **6.6** Update PRD with anything the build proved wrong
- [ ] **6.7** Write `NEXT.md` — what the skills phase needs from this codebase

**Exit criterion:** the demo is done. Stop, play it, and only then plan the game.

---

## Backlog (post-demo — do not start)

Kept here so ideas have somewhere to go that isn't the current sprint.

- Skill system using the reserved animation states (teleport, dash, charge, channel, cast)
- Additional playable characters (slots 2–4) with distinct projectiles
- Enemy variety: ranged, fast/swarm, tanky, elite
- Structured waves and a boss
- Between-round upgrades / levelling
- Real audio: SFX bank + music, wired to the existing volume sliders
- Multiple arenas and backgrounds
- Camera larger than the screen, with scroll
- Enemy separation/steering so they stop stacking
- Object pooling if the perf budget gets tight
- Haptics on hit and death
- Play Store packaging, signing, release build config
