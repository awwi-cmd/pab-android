# DECISIONS — ARENA

A running log of choices and why they were made, so that later work doesn't
relitigate settled ground or accidentally undo something load-bearing.

**Add an entry whenever you choose between real alternatives** — a package, an
architectural split, a workaround, a tuning approach. Keep the format. Never
delete an entry; supersede it with a new one and mark the old one.

Format:

```
## D-000 — Short title
**Date:** YYYY-MM-DD · **Status:** Accepted | Superseded by D-0XX | Revisit after demo
**Context:** what forced a choice
**Decision:** what was chosen
**Because:** the reasoning
**Consequences:** what this now costs or enables
```

---

## D-001 — Flutter + Flame as the engine
**Date:** 2026-09-06 · **Status:** Accepted
**Context:** The game needs to ship as an Android APK. Candidates were Flutter +
Flame, Godot 4, and native Kotlin with a hand-rolled loop.
**Decision:** Flutter with the Flame game engine.
**Because:** The developer already has a working Flutter toolchain on this machine
(Flutter at `C:\src\flutter\bin\flutter.bat`, a Pixel_10 AVD, and proven
build/install batch scripts from a previous Flutter project). Flame supplies the
parts that are tedious to write by hand — component tree, sprite animations,
collision detection, a game loop — while Flutter handles the menus far better
than a game engine would. Godot would mean a new toolchain and rewritten scripts;
native Kotlin would mean building the engine before building the game.
**Consequences:** Menu screens are Flutter widgets and arena is a Flame
`GameWidget`, which is a clean split but means two rendering models in one app.
Performance ceiling is lower than a native engine — acceptable at the scale of a
few dozen sprites, and the 60 fps / 40 enemies budget in PRD §10 is the tripwire
if that assumption is wrong.

---

## D-002 — Dependency set kept minimal
**Date:** 2026-09-06 · **Status:** Accepted
**Context:** Flutter projects accrete packages fast, and a demo is exactly where
that starts.
**Decision:** `flame`, `flame_audio`, `shared_preferences`. Nothing else without a
new entry here. Explicitly **no** state-management library (Riverpod, Bloc,
Provider).
**Because:** The demo's state is a settings object and a round's counters. Flame
already owns the game loop's state; a state library would add ceremony around
nothing. Versions are resolved at `pub add` time rather than pinned here, since
pinning a version guessed in advance tends to be wrong.
**Consequences:** Record the resolved `flame` version below once the project is
created, so future work knows which API generation the code targets. If global
state genuinely appears later (progression, save files), revisit deliberately.

> **Resolved versions** — filled in at bootstrap (2026-09-06):
> `flame: 1.38.2` · `flame_audio: 2.12.2` · `shared_preferences: 2.5.5` ·
> `Flutter: 3.47.2` (stable) · `Dart: 3.13.2`

---

## D-003 — Demo scope is one character, whole flow
**Date:** 2026-09-06 · **Status:** Accepted
**Context:** The choice was between four characters with distinct stats, one
character with the full flow, or a grey-box flow with no art at all.
**Decision:** One fully playable character (The Apprentice), the complete flow
from main menu to death and back, and three locked slots on the select screen.
**Because:** The stated purpose of this demo is to have somewhere to develop
animations and skills. That needs a real character on screen with a real
animation state machine — grey boxes wouldn't serve it. But four characters
multiplies the art and balance work before anything is playable at all. One
character exercises every system; the other three are data rows proving the
select screen is general.
**Consequences:** The select screen must be built to handle N characters even
though N is 1. `CharacterDef` carries an `unlocked` flag from day one.

---

## D-004 — Auto-attack, player controls movement only
**Date:** 2026-09-06 · **Status:** Accepted
**Context:** Core interaction model.
**Decision:** The character fires automatically at the nearest enemy in range.
The player's only input is movement.
**Because:** It is the design pillar. One-thumb play, positioning as the entire
skill expression, and it keeps the control surface free for the skill system that
comes after the demo.
**Consequences:** Enemy design has to carry all the difficulty, since the player
cannot miss or misplay their attack. Targeting choice ("nearest") is a real design
lever and may need revisiting once there are multiple enemy types.

---

## D-005 — Projectiles only, no melee
**Date:** 2026-09-06 · **Status:** Revisit after demo
**Context:** Open question in the brief — "range maybe always projectiles?"
**Decision:** Projectiles only for the demo. Straight-line, constant speed, no
homing, no leading, one target per projectile.
**Because:** One attack implementation to build and one to tune. A melee or
area-of-effect character would need its own collision shape, timing model and
animation handling — that is a second system, and the demo does not need two.
**Consequences:** The Apprentice's INT-heavy stat block is built around ranged
combat, so a future melee character will need the derived-stat formulas revisited
(attack range and projectile speed mean nothing to a melee build).

---

## D-006 — Three control schemes, one input abstraction
**Date:** 2026-09-06 · **Status:** Accepted
**Context:** The brief asks for the control method to be selectable in Settings.
**Decision:** Floating joystick (default), fixed joystick, and drag-anywhere — all
behind a single `MovementInput` abstraction that emits a normalised `Vector2`.
**Because:** Which control scheme feels right is genuinely unknown until it is
played on a phone, so shipping all three and choosing later is cheaper than
guessing. The abstraction means game code never branches on scheme; adding a
fourth (tilt, D-pad) is one class.
**Consequences:** Three input paths to test every time the arena changes. The
scheme is read at arena entry rather than live-switched mid-round, to avoid
handling a control change while the player is being chased.

---

## D-007 — Fixed camera, world size equals screen size
**Date:** 2026-09-06 · **Status:** Accepted
**Context:** The brief specifies a fixed area the player cannot leave, sized to the
screen.
**Decision:** No camera scrolling. The arena is exactly the screen. The player is
clamped to the screen inset by 24 px plus system safe-area insets. Enemies are not
clamped — they spawn 64 px outside and walk in.
**Because:** It matches the brief literally, removes camera code entirely, and
makes off-screen spawning trivial to reason about. Every enemy is either visible or
about to be.
**Consequences:** No exploration or map design is possible without revisiting this.
Arena size varies with device aspect ratio, so spawn rate tuned on the Pixel_10
may feel different on a wider screen — hence the second-AVD check in TASKS 6.5.

---

## D-008 — All combat numbers derive from one file
**Date:** 2026-09-06 · **Status:** Accepted
**Context:** Stats need to visibly affect play, and the numbers will be re-tuned
many times.
**Decision:** `lib/core/stats.dart` holds `StatBlock` and every derived-stat
formula (PRD §5.1). No damage value, speed, HP number or fire rate may be typed
anywhere else in the codebase.
**Because:** Tuning is the majority of the work in a game like this, and a scattered
constant is a bug that only shows up as "it feels wrong". It also lets the character
select screen display genuinely derived numbers rather than a hand-maintained
description that drifts from reality.
**Consequences:** Formulas are unit-tested (TASKS 2.2). Slightly more indirection
for one-off values. Worth it.

---

## D-009 — No Retry button on the Round Over screen
**Date:** 2026-09-06 · **Status:** Revisit after demo
**Context:** The brief specifies death → a Main Menu button. A Retry button is the
obvious convenience.
**Decision:** Main Menu only, for the demo.
**Because:** Returning through the menu on every death is the harshest test of
state cleanup — it forces the full teardown and rebuild path to be exercised
constantly during development, which is exactly where leaked round state would
otherwise hide until much later.
**Consequences:** Slower to iterate by hand during play-testing. Add Retry in the
polish phase or the next milestone once the reset path is proven clean.

---

## D-010 — Round Over is a Flame overlay, not a route
**Date:** 2026-09-06 · **Status:** Accepted
**Context:** Where the death screen lives.
**Decision:** A Flame overlay rendered over the paused game, not a Flutter route
pushed on top.
**Because:** The death frame stays visible behind it, which reads as consequence
rather than as a screen transition. It also keeps the game instance alive so the
round's final statistics can be read directly rather than passed through
navigation arguments.
**Consequences:** The arena route must not be popped until the player chooses Main
Menu, so the game instance has to be disposed explicitly at that point. Watch this
in the memory check (TASKS 6.4).

---

## D-011 — Pixel art at 32×32, drawn at 2×, never smoothed
**Date:** 2026-09-06 · **Status:** Superseded by D-015
**Context:** Art direction and render settings, informed by the wizard reference
sheet.
**Decision:** Sprites authored at 32×32, rendered at 64 px on a 360×800 logical
design surface, nearest-neighbour filtering everywhere. One sheet per character,
one row per animation state, uniform cell size.
**Because:** Integer scaling keeps pixel art crisp; any smoothing or fractional
scale turns it to mush. A uniform grid means the sheet loader is a loop, not a
per-state coordinate table.
**Consequences:** All art must respect the 32×32 cell. Any sprite needing more room
(a large cast effect, a boss) needs its own decision about how it breaks the grid.

---

## D-012 — Animation states enumerated up front, built incrementally
**Date:** 2026-09-06 · **Status:** Accepted
**Context:** The reference sheet defines ~15 states; the demo needs 6.
**Decision:** `AnimState` lists every state on the sheet from day one — including
teleport, warp, fly, dash, charge, channel and cast, which have no implementation
yet. Only the six in PRD §8.1 are wired.
**Because:** The demo exists to be the substrate for the skills phase. If the state
vocabulary is complete on day one, adding a skill later is a data change and a
trigger; if it is added ad hoc, it is a refactor of the player component every
time.
**Consequences:** An enum with unused members, which analysis tools may flag.
Acceptable and deliberate — note it in the file.

---

## D-013 — Death animation gap accepted with a fallback
**Date:** 2026-09-06 · **Status:** Superseded by D-016
**Context:** The reference sheet has no death animation, and the `flash 1` /
`flash 2` cells are empty.
**Decision:** Ship a fade-and-shrink over 0.4 s for death, and a full-white tint
pass for the hurt flash instead of sprite frames.
**Because:** Death is the end of the round, so it is on screen for well under a
second and the overlay covers it immediately. It is the cheapest place to accept a
programmer-art fallback, and blocking the demo on one animation would be a poor
trade.
**Consequences:** A real death animation is an open art task. The hurt tint may
actually be preferable to frames — it is one shader path that works for every
character — in which case this becomes permanent rather than a fallback.

---

## D-014 — Project name and package id
**Date:** 2026-09-06 · **Status:** Accepted
**Context:** Needed before `flutter create`; the package id is painful to change
after an install exists.
**Decision:** Working title **ARENA**, Flutter project directory `arena/`, package
id `com.awwwi.arena`, matching the `com.awwwi.*` convention from the previous
project on this machine.
**Because:** A neutral working title that describes the demo without committing to
a brand. Consistent org prefix keeps the emulator's app list tidy.
**Consequences:** If the game is renamed later, the package id should change too,
which means a fresh install rather than an upgrade. Do that before anything ships
publicly, and never after.

---

## D-015 — Real character asset layout: one PNG per state, 16×24 cells
**Date:** 2026-09-06 · **Status:** Accepted · Supersedes D-011
**Context:** D-011 assumed one sheet per character with one row per animation
state, uniform 32×32 cells, based on the labelled reference mockup
(`docs/reference/character_states.png`). The developer then delivered the actual
production sheets under `assets/images/characters/main/`.
**Decision:** The real layout is **one PNG file per animation state**, named
`main-<state>.png`, frames laid out left-to-right with no padding, uniform
**16×24 px** cell (not 32×32). Frame count is read from each sheet's width
(`width / 16`), never hardcoded — PRD §8.1's frame-count column was a planning
placeholder, not a spec to match exactly (e.g. `main-run.png` ships 4 frames, not
the 6 the PRD guessed).
**Delivered:** `idle`(4) `run`(4) `dash`(4) `fly`(4) `hurt`(4) `die`(4)
`flash`(3) `spawn`(6) `warp`(11) `fire`(5). All PRD §8.1 demo-required states now
have real frames — no art gaps left for the demo's animation list.
**Because:** Build to the assets that actually exist rather than the assumed
layout. One-file-per-state is also simpler to load (`Image` → `SpriteAnimation`
per file) than slicing rows out of a mega-sheet.
**Consequences:** The Phase 5 sheet loader (TASKS 5.1/5.3) keys off filenames,
not row index. On-screen scale for a 16×24 source cell still needs a decision
(D-011's 32×32→2×→64px math no longer applies) — revisit at TASKS 5.1.

**Update 2026-09-06:** Projectile art delivered too, under
`assets/images/vfx/projectiles/`: `projectile-bolt.png` and
`projectile-spark.png`, both 64×16 (4 frames of 16×16 — smaller cell than the
character sheets, as expected for a projectile). Same naming/layout pattern,
registered in `pubspec.yaml`. Not wired to a component yet — that's
`ProjectileComponent` (TASKS 5.11), Phase 4/5.

---

## D-016 — Death animation gap closed
**Date:** 2026-09-06 · **Status:** Accepted · Supersedes D-013
**Context:** D-013 accepted a fade+shrink fallback because the reference mockup
had no death frames. The developer has since delivered `main-die.png`, a real
4-frame death animation, alongside the other `main-*` state sheets (D-015).
**Decision:** Wire `AnimState.death` to `main-die.png` when Phase 5 (art pass)
lands. The fade+shrink fallback from D-013 is kept in reserve only — used if the
death anim needs replacing later, not as the primary path.
**Because:** A real animation is strictly better than the programmer-art fallback
it was standing in for; no reason to ship the fallback now that the asset exists.
**Consequences:** TASKS 5.9 is no longer an "art gap" item — rename/repurpose it
to "wire the real death anim" when Phase 5 is reached.

---

## D-017 — Kotlin incremental compilation disabled (cross-drive build failure)
**Date:** 2026-09-06 · **Status:** Accepted
**Context:** `rebuildinstall.bat` / `flutter build apk --debug` failed with
`compileDebugKotlin` errors — first "Daemon compilation failed", then (after
stopping the daemon) `IllegalArgumentException: this and base files have
different roots`. Root cause: the repo lives on `L:\`, while the pub cache and
Gradle/Kotlin caches live on `C:\`. Kotlin's newer relocatable incremental-cache
support (`RelocatableFileToPathConverter`) computes a relative path between a
compiled source file and the project root to make its cache build-cache-portable;
`java.nio`/Kotlin's `relativeTo` cannot express a relative path across two
different Windows drive letters, so it throws mid-write and corrupts its own
`.tab` cache files, then fails every retry until the `build/` dir is cleared.
**Decision:** Set `kotlin.incremental=false` in `android/gradle.properties`.
**Because:** The alternative is moving the project or every cache to the same
drive, which is a machine-wide change outside this repo's control. Disabling
Kotlin's incremental compilation sidesteps the relocatable-cache code path
entirely; the plugin sources here are small (`shared_preferences_android`,
`audioplayers_android`), so the extra full-recompile cost per build is minor.
**Consequences:** Every build recompiles the Kotlin plugin glue from scratch —
slightly slower `rebuildinstall.bat` runs, not felt on Dart-only hot reload. If
the project or toolchain ever moves fully onto one drive, this can be reverted.

---

## D-018 — Movement input captured in Flutter, not Flame's gesture mixins
**Date:** 2026-09-06 · **Status:** Accepted
**Context:** Flame 1.38 offers a component-level gesture system
(`DragCallbacks`/`TapCallbacks` mixins on components or the `FlameGame`
itself) as its native way to read touch input. The alternative is a plain
Flutter `GestureDetector` layered on top of the `GameWidget`, feeding a
shared value the Flame side reads.
**Decision:** `MovementInput` (`game/input/movement_input.dart`) is a plain
Dart class holding a mutable `Vector2 direction`. All three control schemes
(`game/input/joystick_overlay.dart`) are ordinary `StatefulWidget`s using
`GestureDetector`/`LayoutBuilder`, stacked over the `GameWidget` in
`ArenaScreen`. `PlayerComponent` just reads `input.direction` every frame —
it has no idea a gesture even happened, let alone which scheme produced it.
**Because:** Joystick visuals (a base circle + a knob that follows the
thumb, appearing/disappearing, positioned per scheme) are exactly what
Flutter widgets are for, and CLAUDE.md §4.6 only requires that game
components stay scheme-agnostic behind a normalised `Vector2` — it doesn't
require the *capture* to happen inside Flame. Doing it in Flutter also
sidesteps Flame's gesture-mixin API entirely, which reduces surface area to
get wrong against a library version documented here for the first time.
**Consequences:** The movement overlay has to be hidden once the round ends
(`ArenaGame.roundOver`, a `ValueNotifier<bool>`) so it doesn't swallow taps
meant for the Round Over overlay underneath it — see
`ArenaScreen`'s `ValueListenableBuilder`. If a future control scheme needs
per-enemy or per-tile hit-testing against world objects, that scheme alone
may need to move into Flame's event system; the abstraction boundary
(`MovementInput.direction`) doesn't change either way.

---

## D-019 — Widget-test coverage stops before the `GameWidget` mounts
**Date:** 2026-09-06 · **Status:** Superseded 2026-09-07 (Phase 4) — see
below; original finding kept for the record.
**Context:** The Phase 3 full-flow widget test (`test/widget_test.dart`)
started timing out on `pumpAndSettle()` as soon as it navigated into
`ArenaScreen`. Root cause: `GameWidget` drives its own render ticker that
reschedules a new frame on every pump, independent of `ArenaGame.paused` —
so `pumpAndSettle`'s "pump until no more frames are scheduled" condition
never becomes true once a `GameWidget` is in the tree, paused or not.
**Original decision (Phase 3):** switch to a bounded frame-pump helper
(`_pumpFrames`) instead of `pumpAndSettle()` for any step after the
`GameWidget` mounts. This worked while `ArenaGame` had no real image assets
to load (Phase 3 was a colored placeholder box).

**Update 2026-09-07 (Phase 4):** Once `ArenaGame.onLoad()` started doing
real PNG decoding (`CharacterAnimations.load` + the two VFX sheets, all via
`Flame.images`/`instantiateImageCodec`), the widget test hung indefinitely
past `ENTER ARENA` — not a timeout, no exception, just `find.text('DIE
(debug)')` never appearing no matter how many frames were pumped or how
`tester.runAsync` was positioned around the pumps.

Root-caused by reproducing the exact `GameWidget` load sequence
(`onGameResize` → `game.load()` → `game.mount()` → `game.update(0)`) in an
isolated test wrapped in `tester.runAsync` — that version completed
instantly, with no error. So `ArenaGame`'s own logic is sound (this also
caught and fixed a real bug along the way: `resetRound()` was calling
`overlays.add('DebugDie')` during `onLoad()`, before `GameWidget` finishes
mounting and registers its overlay builders with the `OverlayManager` —
that assertion failure was being silently swallowed because no
`errorBuilder` was passed to `GameWidget`, which is why it looked like a
hang rather than a crash. Fixed: `resetRound()` no longer touches
`overlays` — the first `DebugDie` overlay comes from `GameWidget`'s
`initialActiveOverlays` instead, and `debugDie()`/`_endRound()` are the
only other call sites, both of which only ever run once the game is
already interactive).

Even after that real fix, the actual widget-test run (traced with print
statements) still stalled forever inside `CharacterAnimations.load` itself
— specifically when `ArenaGame.onLoad()` is invoked *by `GameWidget`'s own
internal `FutureBuilder`* during a normal `tester.pump()`, rather than
called directly. `GameWidget` kicks off loading from within the fake-async
test zone; the resulting image-decode `Future`s are then bound to that
zone too, and fake-async's clock doesn't drive the real engine callback
that completes `instantiateImageCodec`. Wrapping *later* test code in
`tester.runAsync` doesn't retroactively move an already-in-flight `Future`
into the real zone — only work that is *itself* invoked from inside
`runAsync` benefits from it.
**Decision:** Automated widget-test coverage stops at Character Select
(`test/widget_test.dart` no longer taps `ENTER ARENA`). Anything past that
— the arena, combat, animations — is a `flutter test` harness limitation to
decode real image assets through a `GameWidget`, not something worth
fighting further. This matches CLAUDE.md §5's existing line: don't write
tests for visual/gameplay feel; verify those on-device.
**Because:** Hours were already sunk chasing this exact interaction twice
(Phase 3's ticker issue, Phase 4's asset-decode issue) for a harness
limitation, not an app defect — both isolated reproductions proved the real
`ArenaGame` code path is correct. A third fight over the same boundary
isn't worth it.
**Consequences:** The arena's actual behavior (movement, combat, HP,
death/round-over) has **no automated regression coverage** — verify it by
running `rebuildinstall.bat` after any change that touches `game/`. If a
genuine `GameWidget`-hosting integration test is ever wanted, look at
Flutter's `integration_test` package (runs on a real device/emulator, real
engine, no fake-async) rather than retrying this under plain `flutter test`.

---

## D-020 — HP bar: fixed top bar, not floating above the player
**Date:** 2026-09-07 · **Status:** Accepted · Closes the "HP bar placement"
open question below
**Context:** Open question since D-011: floating above the player reads
better in a crowd, a fixed top bar is easier to see at a glance.
**Decision:** Fixed bar, top-left, 24px inset (`HpBarComponent`).
**Because:** PRD §6.4 explicitly accepts enemies stacking on the player with
no separation steering. A bar floating above the player's head would be
exactly what that stack of enemy sprites covers first — the "crowd"
scenario the open question worried about is the one case where floating
loses. World size equals screen size with no camera scroll (D-007), so a
fixed world position is already a fixed screen position — no HUD/viewport
component needed, it's just a `PositionComponent` at a constant `position`.
**Consequences:** None of the enemy-crowding readability risk; the bar
never has to reason about where the player currently is.

---

## D-021 — Player hurt reaction: main-hurt pose only, no tint
**Date:** 2026-09-07 · **Status:** Accepted
**Context:** Two candidate sheets both plausibly match PRD §8.1's `hurt
(flash)` state: `main-hurt.png` (4-frame recoil pose) and `main-flash.png`
(3-frame flash effect, D-015's update). D-013's fallback (assumed the flash
cells were empty) also offered a white-tint-pass option.
**Decision:** `AnimState.hurt` plays `main-hurt.png` only. `main-flash.png`
is loaded by nothing — reserved for a future effect (e.g. a cast/impact
flash) rather than the player's damage reaction, since
`projectile-spark.png` already covers the enemy-hit spark PRD §6.3 asks for.
**Because:** Developer's call when asked directly (asset-to-state mapping
was explicitly flagged as a question, not a default to silently pick).
**Consequences:** Separately, PRD §6.2's "sprite flashes white" during the
0.6s i-frame window is implemented as a plain opacity flicker on
`PlayerComponent` (`opacity` toggling via `HasPaint`) — not a colour tint,
not `main-flash.png`. This is a different mechanism answering a different
line in the PRD (the invulnerability indicator, not the hit-reaction pose)
and wasn't itself part of the question asked; flagged here in case the
developer wants it removed or reworked once it's seen on-device.

---

## D-022 — Three enemy skins, one stats profile
**Date:** 2026-09-07 · **Status:** Accepted
**Context:** Developer delivered 3 enemy sprite sets (`enemy-one`,
`enemy-two`, `enemy-three`, each with `run`/`die`, same 16×24 cell
convention as D-015) and asked for them to be "implemented... different
stats for enemies." That's a real scope expansion — PRD §9 explicitly keeps
"more than one enemy type" out of the demo, and TASKS' own Backlog says not
to start enemy variety pre-demo. Flagged and asked rather than building
past it silently (CLAUDE.md §6: "ask before scope").
**Decision:** Visual variety only. `ArenaGame.spawnEnemy` picks one of the
3 skins at random per spawn (`EnemyAnimations`, `game/anim/enemy_animations.
dart`); every enemy still reads its HP/speed/damage/cooldown/radius from
the single `EnemyStats` (PRD §6.4) regardless of skin. Still "one enemy
type" as far as the PRD is concerned — just not visually monotonous.
**Because:** Developer's explicit choice when asked. Keeps the demo inside
its documented scope while using the art that was actually delivered;
distinct per-type stats (the real "enemy variety" feature) stays in the
Backlog for after the demo, alongside ranged/fast/tanky/elite variants.
**Consequences:** `EnemyComponent` went from a placeholder `RectangleComponent`
to a `SpriteAnimationGroupComponent<EnemyAnim>` (run/death) — a real death
animation plays before the enemy is actually removed
(`ProjectileComponent` skips enemies mid-death-animation so a second
projectile can't "hit" an already-dead one). If per-skin stats are ever
wanted, `EnemySkin` already exists as the hook to key a stats table off of.

---

## D-023 — Real arena floor/border art
**Date:** 2026-09-07 · **Status:** Accepted
**Context:** `ArenaFloor` had been a flat colour fill + stroked border
(`Canvas.drawRect`) since Phase 3 — no tile art existed yet. Developer added
`assets/images/scenes/arena_floor_tiles.png` (3 32×32 variants, laid out
left-to-right like the character sheets, D-015) and
`arena_border_tile.png` (32×32, a single edge-line tile meant to be tiled
along the perimeter).
**Decision:** `ArenaFloor` now tiles the floor variants across the world at
a random-per-cell pattern (seeded once per arena entry, not per frame, so
it's stable for the round), and tiles the border sprite along all four
edges — rotated 90° for the left/right edges since the source art is drawn
as a horizontal line. Render scale is `kFloorTileRenderScale = 2` (32px
native → 64px on screen), a separate constant from the character/projectile
scales (D-015/this doc) since floor tiles, characters and VFX are all
different native cell sizes.
**Because:** Matches the delivered art directly — no reason to keep the
placeholder now that real tiles exist. Randomising per-cell (rather than a
single repeating variant) keeps a large flat floor from reading as an
obviously tiled grid, cheap for 3 variants.
**Consequences:** The floor's own `onLoad` does its own asset loading
(images + slicing into `Sprite`s), independent of `ArenaGame`'s onLoad —
components in this codebase are expected to self-load their own assets
rather than have `ArenaGame` do it for them, which keeps `ArenaGame.onLoad`
from growing every time a new component needs art (`PlayerComponent` is the
outlier here for historical reasons — its animations are loaded by
`ArenaGame` because they're also needed for the select-screen portrait).

---

## Open questions

Not decisions yet — things that need play-testing or a call from the developer
before they can be settled.

- ~~**HP bar placement**~~ — closed by D-020 (fixed top bar).
- **Enemy stacking** — with no separation steering, enemies will pile into a single
  column. Tolerable, or does it look broken enough to need steering in the demo?
  Answer after Phase 4 is playable.
- **Difficulty curve shape** — the −4 % spawn interval per 10 s is a guess. Needs
  ten real rounds before it means anything.
- **Whether stats should be visible as raw numbers at all**, or only as derived
  effects. The demo shows both; the select screen is where this gets judged.
- **Targeting rule** — "nearest enemy" is the demo rule. Nearest-in-front, or
  lowest-HP, may feel better once enemy variety exists.
