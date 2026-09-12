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
**Date:** 2026-09-06 · **Status:** Superseded by D-040 (2026-09-09, Phase 9 —
roaming world, camera follows the player, no bounds). Record of the demo's
original design, kept for history — was correct and binding through
Phase 8.
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

## D-024 — Skeleton hardening: per-character sprite prefix, AttackBehavior, pure game rules
**Date:** 2026-09-07 · **Status:** Accepted
**Context:** Developer asked what to do "skeleton wise" to make the demo
easier to build the real game on top of. Review turned up three real
latent gaps rather than speculative ones:
1. `CharacterAnimations` hardcoded the `main-` filename prefix — invisible
   because the one unlocked character's folder happens to be named
   `main`, but would break or force an awkward naming convention the
   moment a second character got real sprites.
2. Auto-attack (nearest-target search, projectile spawn) lived directly in
   `ArenaGame._tryFire`, reading `character.stats` inline. D-005 already
   flagged that a melee character's stats "mean nothing" to this path —
   there was no seam to add one without editing `ArenaGame` itself.
3. Gameplay math (targeting, spawn-interval decay, knockback distance) was
   inline inside component `update()` methods, which — per D-019 — means
   it can never be unit-tested, since a `GameWidget` can't run under
   `flutter test`.
**Decision:**
- `CharacterDef` gained `spritePrefix` (replaces the hardcoded `'main'` in
  `CharacterAnimations.load` and the select-screen portrait).
- `CharacterDef` gained `attackBehavior: AttackBehavior`
  (`game/attack_behavior.dart`). `ArenaGame` now only owns the cooldown
  timer and calls `character.attackBehavior.perform(this)`; the demo's one
  implementation, `ProjectileAttack`, holds the old `_tryFire` logic
  verbatim. Behaviors are stateless/`const` so they can't leak state
  between rounds by being accidentally shared (CLAUDE.md §4.5).
- `core/game_rules.dart`: pure functions with no Flame `Component`/`Game`
  dependency — `nearestWithinRange`, `nextSpawnInterval`,
  `knockbackDistance` — called from `ProjectileAttack`, `Spawner`, and
  `EnemyComponent` respectively. Unit-tested in
  `test/core/game_rules_test.dart` the same way `stats.dart` is.
**Because:** All three were "pay a little now or pay a lot later"
situations — the fixes are small today and expensive after a second
character or a skill system exists and something built on the old
assumption has to be unwound. Full reasoning and what each hook is *for*
is written up in `NEXT.md` (TASKS 6.7, written ahead of schedule since the
question came up directly).
**Consequences:** `data/characters.dart` now imports `game/attack_behavior.
dart` — a data-layer file reaching into the game layer. Accepted rather
than adding an interface purely to avoid it; `NEXT.md` notes the narrowing
fix (an `AttackContext` interface instead of the full `ArenaGame`) if this
ever actually causes a problem. No behavior change for the Apprentice —
`ProjectileAttack.perform` is the old `_tryFire` body moved, not rewritten.

---

## D-025 — In-round leveling, direct stat bonuses, and a 3-way pause architecture
**Date:** 2026-09-07 · **Status:** Accepted
**Context:** First real post-demo feature, built at the developer's explicit
request right after calling the demo done. Spec, verbatim intent: kills
grant XP directly (no drops), levelling pauses the round and offers 1-of-3
placeholder upgrades (VIT→HP, DEX→speed, STR→half of each, INT→projectile
damage), a way to review picks without losing the choice screen, levelling
shouldn't feel fast, plus a top-right pause button (Resume/Settings/Main
Menu) whose Settings screen gets a debug section (god mode, grant a free
level-up that plays out once the menu closes) that the main-menu Settings
never shows.
**Decisions, in order:**
1. **In-round only, not persistent.** Resolves the open question left after
   the last planning pass. `ArenaGame.level`/`xp`/`upgrades` reset in
   `resetRound()` exactly like `kills`/`damageDealt` already did — no new
   save-data layer needed. Revisit if a later ask wants progress to survive
   between rounds.
2. **Direct additive stat bonuses, not `StatBlock` re-derivation.** The spec
   says "VIT increases HP," not "increases the VIT attribute" — so
   `PlayerUpgrades` (`core/progression.dart`) is a flat bonus layer
   (`bonusMaxHp`/`bonusMoveSpeed`/`bonusDamage`) added on top of
   `CharacterDef.stats` at the point of use (`PlayerComponent.
   effectiveMaxHp`/`effectiveMoveSpeed`, `ProjectileAttack.perform`'s damage
   calc) rather than mutating or re-running the derived formulas. Simpler,
   and matches the "for now just placeholder stats" framing — swapping in a
   real formula later touches one file.
3. **XP curve tuned deliberately slow.** `kBaseXpToNextLevel = 150`,
   `kXpGrowthFactor = 1.3`, `kXpPerKill = 10` — first level costs 15 kills,
   every level after costs more. Direct response to "make it not feel so
   fast"; all three are named constants in `core/progression.dart`, one
   edit to retune.
4. **Three pause reasons, one coordinator.** Round Over, the level-up
   popup, and the manual pause menu can all stop the engine, and they can
   interact (a level-up can be earned/granted while the pause menu is
   open). `ArenaGame` owns a single `_pendingLevelUps` counter and
   `_maybeShowNextLevelUp()` gate: it won't show the popup while
   `PauseMenu` is active, so anything queued during a pause (debug-granted
   or otherwise) plays out immediately after `closePauseMenu()`, still
   paused, rather than resuming first — matches the spec's "given once you
   close pause menu" exactly. `menuOpen` (a `ValueNotifier<bool>`, same
   pattern as the existing `roundOver`) mirrors "is *any* menu/popup
   showing" for the Flutter side.
5. **`DebugDie` and the new pause button stopped being Flame overlays.**
   They're plain Flutter widgets in `ArenaScreen`'s `Stack` now, visibility
   gated by `roundOver`/`menuOpen` the same way the movement-input overlay
   already was — one fewer thing that has to be registered with
   `GameWidget`'s `overlayBuilderMap` before it can be touched (the exact
   class of bug D-024's predecessor hit). `RoundOver`/`LevelUp`/`PauseMenu`
   stay real Flame overlays since they need to sit above everything,
   `ArenaGame`-triggered.
6. **Debug tools live in `SettingsScreen`, gated by route arguments, not a
   separate screen.** `SettingsScreenArgs(debugGame: ...)` — non-null only
   when Settings is reached from the Pause Menu. Reuses the existing
   screen/persistence code entirely; the debug section is just conditional
   widgets at the bottom.
**Because:** each of these mirrors a pattern already established in this
codebase (D-019/D-024's pure-logic extraction, `roundOver`'s
Flutter/Flame bridging, `SettingsScreenArgs` following D-024's data→game
layering precedent) rather than inventing a new one — consistent with the
"skeleton hardening" pass from the same day.
**Consequences:** `EnemyStats` doesn't scale with the new `level` yet — the
player gets stronger, enemies don't, which is only half of the developer's
original stated vision. That's the immediate next open question (see
below), not an oversight.

---

## D-026 — Enemy scaling: linear HP/damage multiplier by player level, baked in at spawn
**Date:** 2026-09-08 · **Status:** Accepted · Closes the "Enemy scaling
mechanism" open question below
**Context:** D-025 shipped the player-side half of progression; enemies
stayed flat. Three real options on the table: scale `EnemyStats` by a
level-derived factor, speed up spawns via `Spawner` instead/as well, or
unlock distinct tougher `EnemySkin` tiers (real enemy-variety scope,
Backlog territory). Asked the developer directly rather than guessing
(CLAUDE.md §6).
**Decision:** Scale `EnemyStats` only. `core/game_rules.dart` gained
`enemyStatMultiplier(int playerLevel)` — linear, `1 + (level-1) * 0.12`
(`kEnemyScalePerLevel`), pure and unit-tested
(`test/core/game_rules_test.dart`) same as every other rule in that file.
`ArenaGame.spawnEnemy` reads `game.level` at spawn time and passes the
multiplier into `EnemyComponent`'s new `statMultiplier` constructor param,
which scales `hp` (already a mutable field) and a new `contactDamage`
field — `EnemyStats.maxHp`/`contactDamage` stay the level-1 baseline
constants, unscaled. `moveSpeedPxPerS` is deliberately left unscaled.
`ArenaGame.onEnemyContact` now takes the `EnemyComponent` that touched the
player and reads its (possibly scaled) `contactDamage`, instead of the old
flat `EnemyStats.contactDamage` call.
**Because:** Stat scaling is the smallest, purely-numeric option — no new
content, one pure function, fits the existing `game_rules.dart` pattern
(spawn-interval decay is the same shape of problem: a number that changes
over the round). Leaving move speed alone keeps positioning/kiting — the
game's one skill expression (D-004) — viable at every level; only the
cost of getting hit or facetanking goes up, not whether you can outrun a
grunt at all. Baking the multiplier in at spawn (not re-applied live) means
an enemy that spawned early in the round doesn't retroactively get
tougher just because the player leveled up since — matches "never carry
state across rounds" in spirit (CLAUDE.md §4.5): each enemy's stats are
fixed at the moment it's created, not floating with current round state.
**Consequences:** `0.12`/level is a first guess, not playtested — 7.10-style
on-device verification should include a run past level 5-6 to see whether
it actually reads as "getting harder" or needs retuning (one constant to
change). Faster spawns and skin-tiered enemy types remain open for later if
stat scaling alone doesn't carry the difficulty curve far enough — not
ruled out, just not built now.

---

## D-027 — Aura: first skill-type upgrade, weighted roll, capped stacks
**Date:** 2026-09-08 · **Status:** Accepted
**Context:** Developer asked for a 5th level-up option that's a real skill
rather than a flat stat bump — a damaging aura built from the existing
`projectile-spark.png` sheet (a left-to-right flash, not natively circular),
mixed into the same random level-up roll as the 4 placeholder stat
upgrades, with placeholder weights (real tuning deferred to config later),
and capped at 3 stacks unlike the uncapped stat upgrades.
**Decisions:**
1. **Ring built from copies of the linear sheet, not new art.** `AuraComponent`
   (`game/components/aura.dart`) places `_sparkCount = 6` child
   `SpriteAnimationComponent`s evenly around a circle of
   `UpgradeAmounts.auraRadiusPx` (70px) and rotates the whole group via its
   own `angle`, rather than needing a genuinely circular sprite. Same
   sheet as the existing hit-spark VFX, loaded a second time with
   `loop: true` (`ArenaGame._auraSparkAnimation`) since the hit-spark's
   existing load is deliberately non-looping (one-off burst per projectile
   hit).
2. **Spawned once, read every tick, not rebuilt per pick.** `ArenaGame._aura`
   is created on the first Aura pick (`_syncAura()`, called from
   `resolveLevelUpChoice`) and left alone after that — `AuraComponent`
   reads `upgrades.pickCounts[UpgradeKind.aura]` itself each damage tick
   to look up the current tier's damage
   (`UpgradeAmounts.auraDamagePerTick`), so a 2nd/3rd pick is just a
   number going up, not a respawn. Ticks every
   `auraTickIntervalSec` (0.5s), hitting every non-dying enemy within
   radius via the new pure `allWithinRange` (`core/game_rules.dart`) —
   `nearestWithinRange` only returns one target, which doesn't fit an
   area-effect skill.
3. **Damage-only scaling, capped at 3 stacks, radius/tick-rate fixed.**
   `UpgradeAmounts.auraDamagePerTick(stacks)` is a 3-entry tier table
   (`[4, 8, 14]`), clamped so an out-of-range stack count can't index past
   the table. Matches "damage scaling... max 3 levels like the other
   upgrades" — radius and tick interval deliberately don't scale, so the
   skill's *reach* stays predictable even as its damage grows.
4. **Weighted, capped roll — a real mechanism change to `rollUpgradeChoices`,
   not a special case bolted onto it.** `core/progression.dart` gained
   `kUpgradeWeights` (placeholder, all `1` — the developer's explicit "we'll
   decide weights later in config", this just wires the knob) and
   `kUpgradeMaxPicks` (`null` = unlimited for the original 4,
   `UpgradeAmounts.auraMaxStacks` for Aura). `rollUpgradeChoices` now
   filters out anything at its cap, then samples the rest without
   replacement using the Efraimidis-Spirakis key trick
   (`random()^(1/weight)`, keep the top N keys) instead of a plain shuffle
   — the standard way to do weighted sampling without replacement, and
   still a pure function of the `Random` passed in (deterministic for a
   seed, same as before). `pickCounts` is an optional named param
   (defaults to `{}`, i.e. unrestricted) so the existing uniform-roll
   tests didn't need rewriting.
**Because:** Each piece follows an existing pattern in this codebase rather
than inventing a new one — `game_rules.dart`'s pure-function style
(`allWithinRange` sits right next to `nearestWithinRange`), `ArenaGame`
owning round state and components reading it live rather than being
handed values (D-025's `PauseMenu`/level-up gating does the same thing),
and `UpgradeAmounts` as the one place a level-up number lives (CLAUDE.md
§4.3 extended to skills, not just stats).
**Consequences:** `0.12`-style tuning question again: `_sparkCount`,
`auraRadiusPx`, `auraTickIntervalSec`, and the `[4, 8, 14]` damage tiers
are first guesses, not playtested — one file (`core/progression.dart`) to
retune once it's been seen on-device. `kUpgradeWeights` being all-equal
means the roll behaves like the old uniform shuffle for now; real weight
values are an explicit follow-up, not forgotten. `UpgradeKind.aura` being
capped while the other 4 aren't is the first upgrade with a real
`kUpgradeMaxPicks` entry — worth remembering if a 6th upgrade needs its
own cap later, the mechanism already generalizes.

**Update 2026-09-08 (first on-device pass):** Developer reported damage
reading as absent or negligible. Code review found no wiring bug — hit
detection, damage application, and `damageDealt`/floating-number feedback
all route through the same `enemy.takeDamage` + `game.onProjectileHit`
path the projectile already uses (`ProjectileComponent`), and the checked
radius and the rendered ring were always the same `_radiusPx` value, just
with nothing on screen actually marking where that boundary was. Two
changes:
1. **A visible ring, not just the orbiting sparks.** `AuraComponent` now
   also adds a stroked `CircleComponent` at exactly `_radiusPx` — directly
   answers "check hitbox location" by making the real damage boundary
   visible on-device instead of inferred from where the decorative sparks
   happen to sit.
2. **Numbers bumped ~25-50%** — `auraRadiusPx` 70→85, `auraTickIntervalSec`
   0.5→0.4s, damage tiers `[4,8,14]`→`[6,12,20]`. The original numbers
   were plausible on paper (tier-1 was already ~half the Apprentice's base
   attack DPS) but evidently didn't read as "working" in practice — most
   likely too tight a radius for how little time enemies spend near the
   player while being knocked back/chased, not a logic bug. Still a
   guess, now a better-informed one; the ring should make the next
   on-device pass diagnostic rather than a guess either way.

**Update 2026-09-08 (second on-device pass):** Developer reported the
opposite-sounding but consistent symptom: damage lands on the outside of
the ring, not inside it. Re-verified `allWithinRange`'s check
(`distance <= maxRange`) line by line — it's an inclusive full disk from
the center outward, not a boundary/ring-only test, and there's only one
definition of it in the codebase (no shadowing). The likely real cause:
the only *visible* feedback the aura had was the 6 sparks and the debug
ring, both of which sit permanently at exactly `_radiusPx` and nowhere
else — so nothing ever rendered to show the interior was live, and a hit
on an enemy stacked close to the player (small, easy to lose against the
player's own sprite) was far less noticeable than one further out on open
floor. Fix: replaced the static debug ring with `_AuraPulseComponent` — a
filled, fast-fading flash across the *entire* disk, spawned by
`_dealDamage()` itself on every tick that actually connects (not a
standalone decoration). This is the requested "disable the visible
hitbox" (the static outline is gone) plus a positive answer to "deal
damage inside the radius as well": the whole disk visibly lights up on
every real hit, edge to center, every 0.4s, so there's no more room for
the ring-only impression. No gameplay-math change — `_dealDamage` is
otherwise identical.

**Update 2026-09-08 (confirmed working, flash removed):** Developer
confirmed the disk-wide coverage was correct all along — it was purely
the missing interior feedback, not a damage bug. `_AuraPulseComponent`
removed now that its diagnostic job is done; `AuraComponent` ships with
just the orbiting sparks (no ring, no pulse). `_dealDamage`'s actual hit
logic never changed across any of this — three rounds of on-device
feedback, zero changes to the range check itself.

---

## D-028 — Slots 2-4 unlocked with real assets, sharing the Apprentice's bolt
**Date:** 2026-09-08 · **Status:** Accepted
**Context:** Developer delivered full sprite sheets (`black`/`third`/`fourth`
prefixes, 10 states each — same set as `main`, plus `dash`/`flash`/`fly`/`warp`
left unwired same as `main`'s) for the Bruiser, Skirmisher, and Warden slots.
CLAUDE.md §6 ("ask before scope") applied because unlocking them and giving
each a distinct kit are two different asks.
**Decision:** Wire all 3 new slots as fully unlocked (no progression gate
yet — that's a separate future feature) using their real sprite folders, but
give every one of them `ProjectileAttack()` — the same bolt the Apprentice
uses — as a deliberate placeholder. `CharacterDef.unlocked` no longer singles
out the Apprentice; it's just `true` everywhere until real unlock-by-progress
is built.
**Because:** The developer explicitly asked for "same main ability for now,
we'll change it later" and "unlockable from the beginning ... we'll unlock
them all with progression later, for now all unlocked" — both are staged,
not final. `AttackBehavior` (D-024) already supports a per-character kit with
zero `ArenaGame` changes, so nothing here blocks that follow-up; it's a data
edit on `CharacterDef.attackBehavior`, tracked as TASKS Phase 8 items.
**Consequences:** All 4 characters currently play identically except for
stats/sprite — visual variety without mechanical variety yet. `_idleFrameCount`
in `character_select_screen.dart`'s portrait widget stays hardcoded at 4
(confirmed via PNG `IHDR` dims: all four `*-idle.png` sheets are 64×24, i.e.
4 frames at the shared 16×24 cell) — still needs a manual bump if a future
character ships an idle sheet with a different frame count. Progression-gated
unlocking (locking 2-4 again, then re-opening them via in-game milestones) is
new scope, tracked in TASKS Phase 8, not started.

---

## D-029 — Bruiser kit: piercing spinning knife, clean→bloody sprite swap
**Date:** 2026-09-08 · **Status:** Accepted
**Context:** TASKS 8.3 asks for a distinct `AttackBehavior` per new character
instead of every slot sharing the Apprentice's bolt. Developer supplied two
static 32×32 images (`knife_clean.png`/`knife_bloody.png`, not a sheet) and
specified the mechanic directly: thrown at the nearest target, spins in
flight, pierces through enemies instead of stopping at the first one, and
switches from the clean sprite to the bloody one the instant it draws blood.
**Decision:** New `KnifeAttack` (`game/attack_behavior.dart`) + new
`KnifeProjectileComponent` (`game/components/knife_projectile.dart`),
targeting/cooldown/damage/knockback/range formulas copied verbatim from
`ProjectileAttack` — pierce and the sprite swap are the only differences for
now, real balance is a later pass same as everywhere else in Phase 7/8.
Piercing means each enemy the knife touches can only be hit once per throw
(a `Set<EnemyComponent>` on the component), otherwise standing in its path
for multiple frames would tick damage every frame; it otherwise flies exactly
like `ProjectileComponent` (constant velocity, despawns on max range or
leaving bounds) except it never despawns on hit. `sprite` flips to bloody the
first time `touching` is non-empty in `update()` and stays flipped for the
rest of that knife's flight — a fresh throw always starts clean again since
each `KnifeProjectileComponent` is a new instance.
**Because:** `SpriteComponent` (not `SpriteAnimationComponent`) is the right
fit for two static single-frame images — no sheet, no animation, just a
sprite reference that gets swapped once. `kKnifeRenderScale = 1`
(`core/constants.dart`) renders the 32×32 native knife at the same on-screen
footprint as the bolt (16×16 cell × `kProjectileRenderScale` 2 = 32×32) so
it doesn't read oversized next to the 48×72 player.
**Consequences:** The Bruiser is now the first character with a real,
distinct kit (closes half of TASKS 8.3) — the Skirmisher and Warden still
use `ProjectileAttack` as a placeholder. On-device feel (does pierce read
clearly, does the bloody swap show up at the size/speed it flies) is
unverified — needs a pass same as every other combat-feel item in this file.

---

## D-030 — Knife: no max-range despawn, -30% attack speed, +25%/+15% range tunes
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** On-device pass on the Bruiser's knife (D-029) found it despawning
mid-flight after a hit, before it left the screen — the shared
`stats.attackRangePx * 1.5` max-travel-range it inherited from
`ProjectileAttack`/`ProjectileComponent` was cutting it off well short of the
arena edge. Developer also asked for slower attack speed and a bigger
targeting range on top.
**Decision:** `KnifeProjectileComponent` drops the max-range despawn
entirely — `maxRangePx` param removed, `_traveled` tracking removed, the only
despawn condition left is `_outOfBounds()` (already existed, checks against
`game.size` — CLAUDE.md/D-007's fixed camera means world size *is* screen
size, so "despawn at the world edge" already meant "despawn off-screen", it
just wasn't the *only* condition before). `KnifeAttack.cooldownSeconds`
divides the shared `1/attacksPerSec` formula by a new `_attackSpeedMultiplier`
(0.7, i.e. -30% attack speed → longer cooldown) instead of reusing it as-is.
Targeting range for the initial nearest-enemy lookup gets its own
`_rangeMultiplier` (1.15, +15%) applied on top of `stats.attackRangePx`
— separate from the removed travel-range multiplier, this one only affects
which enemy the throw picks as its target. Render scale (`kKnifeRenderScale`)
went through two on-device size tunes this session, +25% then +20% more,
landing at 1.5 total (was 1, see D-029).
**Because:** All 4 were explicit developer asks after seeing the knife
in motion; none is inferred. Removing the travel-range cap rather than just
raising it matches the literal ask ("must not despawn until it gets out of
screen") and removes a tuning knob (`maxRangePx`) that no longer does
anything for this projectile instead of leaving it dead in the constructor.
**Consequences:** The knife can now cross most of the arena on a single
throw, piercing anything in its path the whole way — a much longer effective
threat range than the bolt. `_rangeMultiplier` only gates targeting (does the
Bruiser bother throwing at that enemy at all), not how far the thrown knife
can travel once released, which is now unlimited (screen-bound only) — those
are two independently tunable numbers now, not one shared value.

## D-031 — Knife Mastery: first character-locked upgrade
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer asked for a knife-specific upgrade line in the
level-up popup, available "only if you have this character" (the Bruiser) —
the first upgrade that isn't offered to everyone. Existing `rollUpgradeChoices`
(D-025) drew from the full `UpgradeKind.values` unconditionally; nothing in
`core/progression.dart` knew what character was playing. Level 1's effect
wasn't specified by the developer; asked and got "damage buff, still 1 knife"
as the answer (recommended option), reserving the multi-knife jump for
levels 2/3 as specified.
**Decision:** New `UpgradeKind.knifeMastery`, 3-stack-capped like Aura
(`UpgradeAmounts.knifeMasteryMaxStacks`). Level 1: `KnifeAttack` multiplies
its damage by `knifeMasteryTier1DamageMultiplier` (1.2, i.e. +20%, partially
offsetting D-029's -30% pierce nerf) — still one knife. Level 2: throws a
second knife straight behind the player (180° from the throw direction).
Level 3: throws 4 at once, at 0°/90°/180°/-90° from the throw direction (one
to every side) — this replaces level 2's pattern rather than adding to it.
All the extra knives come from the one existing nearest-enemy lookup; they're
geometric offsets (`KnifeAttack._rotated`, plain cos/sin, no Flame
`Vector2.rotate` — not on the type) off that single forward direction, not
separate target searches. Character-gating is a new `core/progression.dart`
pair: `kCharacterLockedUpgrades` (a `UpgradeKind -> CharacterDef.id` map,
just `knifeMastery -> 'bruiser'` for now) and `upgradeKindsFor(characterId)`
(everything minus another character's locks), which `ArenaGame` passes as
`rollUpgradeChoices`'s new `candidates` param (defaults to
`UpgradeKind.values`, so every existing call site/test is unaffected).
Like Aura, `PlayerUpgrades.apply(knifeMastery)` adds no flat stat bonus —
`KnifeAttack` reads `pickCounts[UpgradeKind.knifeMastery]` itself every
throw, same "component reads its own stack count" pattern NEXT.md documents
for Aura.
**Because:** A map + a filter function is the minimal shape that generalizes
to more character-locked upgrades later without touching
`rollUpgradeChoices`'s sampling logic — adding a second locked upgrade for
another character is one more map entry, not new branching. Reusing the
existing single target lookup for all the extra knives (rather than each
knife re-running `nearestWithinRange`) keeps every knife in one throw aimed
at a consistent formation instead of each one potentially picking a
different nearest enemy.
**Consequences:** `rollUpgradeChoices` callers that care about
character-gating must remember to pass `candidates` — the Apprentice/
Skirmisher/Warden all currently get identical pools since only one upgrade
is locked; this is the seam for the Skirmisher/Warden's own future kits
(TASKS 8.3) to hang their own locked upgrades off. Level 1's exact number
(+20%) and the level-3 exact offsets (cardinal, not diagonal) are first
guesses, unverified on-device — same caveat as every other placeholder
number in this file.

---

## D-032 — Aura visual swap: orbiting sparks → `effect_electric-shield.png`
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** D-027 built the Aura's visual from 6 copies of the existing
`projectile-spark.png` hit-spark placed around a circle and rotated as a
group, because no dedicated asset existed yet. Developer supplied a real
shield-ring asset (`assets/images/vfx/vfx/effect_electric-shield.png`) and
asked for the swap, with two hard constraints: keep the radius/damage logic
exactly as-is, and don't let the new visual read bigger than the actual
damage area.
**Decision:** `effect_electric-shield.png` turned out to be a 2385×1855 grid
sheet — 265×265 cells, 9 per row × 7 rows, 60 real animation frames padded
into a 63-cell rectangle (confirmed by checking each cell's alpha channel:
rows 0-5 are all populated, row 6 has frames 0-5 and blank alpha at 6-8).
That's a multi-row layout, which `loadSheetAnimation` (`game/anim/
sheet_loader.dart`, D-015) didn't support — every other sheet in this
project is a single left-to-right strip. Extended it with optional
`frameCount`/`amountPerRow` params (both `null` by default, preserving the
exact old single-row behavior for every existing caller) rather than
writing a one-off loader just for this asset. `AuraComponent` now adds one
centered `SpriteAnimationComponent` playing that sheet instead of building
6 orbiting spark children + a manual per-frame rotation of the whole group
— the sheet's own frames already animate the spin, so the extra rotation
code was removed rather than compounded on top. Sized to
`Vector2.all(_radiusPx * 2)` — the damage diameter exactly, not a pixel
more; because the source art has its own inset padding around the ring
inside each frame, the actual visible ring ends up a little *inside* the
hit circle rather than exactly on its edge, which satisfies "never bigger
than the damage area" with margin to spare rather than by exact coincidence.
`_dealDamage()`/`_tickTimer`/the `allWithinRange` radius check are all
byte-for-byte untouched — this was a rendering-layer swap only.
**Because:** A generalized sheet loader is the CLAUDE.md §4.3-consistent
choice — the alternative (a bespoke loader for one asset) would fork the
"how do I read a sprite sheet" logic in two places for no reason. Exact
diameter (not e.g. 1.5× or a fudge factor) is the simplest way to guarantee
the "not bigger" constraint without needing to hand-measure the ring's
actual radius inside its frame padding.
**Consequences:** Aura's `SpriteAnimation` field/param name changed
(`_auraSparkAnimation`→`_auraShieldAnimation`,
`sparkAnimation`→`shieldAnimation`) — anything referencing the old names
(NEXT.md's Aura writeup) needs the same update, done alongside this entry.
`stepTime` (0.03s/frame × 60 frames ≈ 1.8s per full loop) is a first guess
for how fast the ring should spin, unverified on-device — same caveat as
every other placeholder timing number in this file. The old
orbiting-sparks approach (multiple children + manual group rotation) is
gone, not kept behind a flag — if a future skill wants that "several small
sprites around a circle" look again, D-027's original `aura.dart` history
in git is the reference, not dead code left in this file.

**2026-09-09 update:** first on-device look at the ring read "too bright,
in your face" — added `_opacity`/`_contrast`, both 0.8 (-20% each), on the
`SpriteAnimationComponent`'s `paint`. Opacity via `Paint.color`'s alpha
(`Color.fromRGBO(255, 255, 255, _opacity)`); contrast via a standard
scale-toward-grey `ColorFilter.matrix` (`AuraComponent._contrastMatrix`) —
the two compose independently in Flutter's paint pipeline (alpha controls
overall opacity, `colorFilter` transforms the sampled color before that
alpha is applied), so stacking both doesn't fight itself. `_dealDamage`/
radius/sizing untouched — purely a paint-layer tune on top of D-032's swap.

---

## D-033 — Player hit feedback: `effect_blood-impact`, randomized on-body position
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer delivered `assets/images/vfx/vfx/effect_blood-impact.png`
(discovered to be the same 9-cols×7-rows grid convention as D-032's shield —
60×63 native cell, 48 real frames padded into 63) and asked for it to play
"on the character's body" whenever any character takes damage (not tied to a
specific character), sized 25% smaller than a natural first pass, and at a
different spot each time rather than a fixed decal.
**Decision:** `ArenaGame.spawnBloodImpact()`, called from
`PlayerComponent.takeDamage()` right after the guard clauses (god mode,
i-frames, already dead) so it only fires when damage actually lands. Reuses
the existing `spawnEffect()` one-shot helper (new — a generalization of what
`onProjectileHit`'s hit-spark spawn was already doing inline, now shared by
every one-shot VFX added this session). Position: `player.position` plus a
random offset within ±30% of the player's width/height on each axis
(`ArenaGame._random`, already existed). Size: `player.size.x *
kBloodImpactWidthFactor` (0.45) — landed there directly rather than in two
tuning passes like the knife: 0.6x width would have been the "natural" first
guess, developer asked for -25% smaller before it ever shipped, so the
constant documents that derivation instead of pretending there were two
separate commits.
**Because:** Randomizing per-hit rather than a fixed offset was the explicit
ask ("not always in the same place") — a static position would read as a
sticker, not a hit reaction. Deriving size from `player.size.x` at call time
(not a duplicated hardcoded pixel value) means it can't drift out of sync if
`kCharacterRenderScale` ever changes.
**Consequences:** Every character shows the same blood-impact regardless of
its own visual theme (no per-character skin for this VFX) — matches the ask
("all characters not specific"). Unverified on-device (TASKS 8.7) — same
caveat as every other placeholder VFX size/position in this project.

## D-034 — Skirmisher kit: Spiral Fire (twin orbiting projectiles + cast/hit/kill VFX)
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** TASKS 8.3's Skirmisher slot was still on the `ProjectileAttack`
placeholder. Developer specified a full kit in one message: a cast flourish
(`effect_sparkles-constelation`, on the caster's body, 35% opacity, behind
the character) as "part of" the skill, with the other part being "2
effect_pixel-fire projectiles shot together that are spinning like yin and
yang in a spiral towards their target" — plus `effect_impact` on a non-lethal
hit and `effect_explosion` (delivered as `effect_explosion2.png`,
consolidating what were two separate GIFs before D-032's PNG re-delivery) on
a kill from this skill specifically.
**Decision:** `SpiralFireAttack` (`game/attack_behavior.dart`) — same
targeting/cooldown formula as `ProjectileAttack`, but launches two
`SpiralFireProjectileComponent`s per cast (`game/components/
spiral_fire_projectile.dart`) at orbit phases 0 and pi (opposite sides of a
shared advancing center point), plus one call to the new
`ArenaGame.spawnCastSparkle()`. Each projectile's position each frame is
`start + direction*(traveled + radius*sin(angle)) +
perpendicular*(radius*cos(angle))` — a genuine circular orbit around the
straight-line path to `targetPoint` (captured once at launch, not homing —
matches D-005), with `radius` shrinking linearly to 0 as `traveled`
approaches the total distance, so the pair visually converges exactly on
arrival instead of still circling on impact. Built via the existing
`_scratch`-vector-reuse pattern (no per-frame `Vector2` allocation, CLAUDE.md
§4.4) rather than `Vector2`'s `+`/`*` operators, which each allocate.
Single-target hit per projectile (not piercing, unlike the knife) — on hit,
`EnemyComponent.isDying` is checked immediately after `takeDamage()` (it's
set synchronously when hp drops to 0) to pick `spawnExplosionEffect` (kill)
vs. `spawnImpactEffect` (non-lethal), **in addition to** the existing shared
`onProjectileHit` call (damage number, damage-dealt bookkeeping, the generic
hit-spark) — this skill's flourishes are additive on top of that shared
feedback, not a replacement for it, so damage totals/round bookkeeping stay
identical across every kit. `TrackingSpriteEffect`
(`game/components/tracking_effect.dart`) is new shared infrastructure for
the cast sparkle: a VFX that follows a still-alive component (the caster)
every frame and self-removes once that component leaves the tree — needed
because the player isn't movement-locked during a cast (only `hurt` blocks
movement, `fire` doesn't), so a fixed-position sparkle would drift off the
body mid-animation.
**Because:** Two full-price shots is the literal spec ("2 ... projectiles
... shot together") — not halving each one's damage the way the knife's
pierce got a compensating nerf, since nobody's asked for that tuning pass on
this kit yet and guessing a number pre-feedback (rather than shipping the
straightforward reading and tuning from an actual on-device reaction) is
exactly the pattern D-029→D-030 showed doesn't save a round trip anyway.
Orbiting via true circular motion (not just a perpendicular wobble) is what
actually reads as "spiral"/"yin-yang" instead of a shaky straight line.
**Consequences:** `SpiralFireAttack` is meaningfully stronger per-cast than
`ProjectileAttack`/`KnifeAttack` (two full hits vs. one) — expected to need
a balance pass same as everything else once it's seen in motion (TASKS
8.3's new on-device item). `ArenaGame` picked up 5 new `SpriteAnimation`
fields and 4 new small `spawn*` helper methods this session (D-033's
`spawnBloodImpact`/shared `spawnEffect`, plus this entry's
`spawnCastSparkle`/`spawnImpactEffect`/`spawnExplosionEffect`) — still all
one-line wrappers, but worth noting `arena_game.dart` is trending toward
CLAUDE.md §5's ~300-line guideline; not over it yet, next VFX addition
should check.

## D-035 — Elite enemies: visual-only fire glow, no stat change yet
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer asked for "some enemies" to be "elite" with an
`effect_dithered-fire` glow under them, explicitly capped at "not bigger or
wider than the enemy." The Backlog already lists full elite/enemy-variety
(distinct stats) as out-of-scope-for-now (D-022) — this ask was visual only,
no stat/behavior change requested, so it's treated as a first slice of that
Backlog item rather than the whole thing (CLAUDE.md §6, "ask before scope" —
here the ask was narrow enough not to need clarifying).
**Decision:** `rollIsElite(Random)` + `kEliteChance` (0.15, `core/
game_rules.dart` — pure and unit-tested, including a statistical check over
20,000 trials) rolled independently per spawn in `ArenaGame.spawnEnemy`. No
new field on `EnemyComponent` — the roll only decides whether to also attach
a `TrackingSpriteEffect` (same component D-034 introduced) as a **top-level
sibling** of the enemy, not a child of it: Flame's `Component.renderTree`
renders a component's own `render()` first and its children afterward, so a
child would always paint on top of its parent regardless of the child's own
`priority` — the opposite of "fire under them." A sibling at
`ArenaPriority.groundEffects` (5, below `enemy`'s 10) sorts correctly instead,
with the tracking behavior gluing it to the enemy's position every frame and
self-removing once the enemy leaves the tree (dies/despawns). Sized to
`enemy.size.x` exactly (never wider, per the ask), offset down by 30% of the
enemy's height so it reads as under its feet rather than centered through
its torso.
**Because:** Deriving glow width from `enemy.size.x` at spawn time (not a
duplicated constant) can't drift out of sync with `kCharacterRenderScale`.
Keeping this visual-only (no `EnemyComponent` changes at all) is the
narrowest change that satisfies the literal ask without pre-building the
Backlog's full "distinct stats" feature nobody asked for yet.
**Consequences:** "Elite" currently means nothing mechanically — it's a
coin flip on whether an enemy gets a fire glow, full stop. If/when real
elite stats (tankier, more damage) get built, this is the hook to extend
(`rollIsElite`'s result already threading through `spawnEnemy` is the
obvious place), but that's new scope to ask about, not assume. Unverified
on-device (TASKS 8.7): does 15% read as "some," does the glow's position/
size actually look like it's under the enemy rather than through it.

---

## D-036 — Elite fire on top + fades on death; cast sparkle made persistent
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** First on-device-adjacent feedback on D-034/D-035: elite fire
should render **on top of** the enemy (not behind it as D-035 shipped), and
should start fading the instant the enemy dies rather than staying at full
brightness through the whole death animation and then vanishing the frame
it's removed. Separately, the cast sparkle had a real bug: `spawnCastSparkle`
was called once per `SpiralFireAttack.perform()` as a one-shot flash — the
developer wants it "visible at all times," not just for the ~0.5s after a
cast.
**Decision:** Three changes. (1) New `ArenaPriority.enemyOverlay` (12, between
`enemy` 10 and `player` 15) — elite fire now renders at this priority instead
of `groundEffects` (5), so it reads on top of the enemy sprite. (2)
`TrackingSpriteEffect` gained `fadeOutWhen`/`fadeOutDurationSec` — a poll
function checked every frame once `target` is still mounted; the first time
it returns true, opacity ramps to 0 over `fadeOutDurationSec` (0.4s,
`kEliteFireFadeOutSec`) and the component removes itself at the end of the
ramp instead of waiting for `target.isMounted` to flip. The elite spawn in
`ArenaGame.spawnEnemy` passes `fadeOutWhen: () => enemy.isDying` —
`EnemyComponent.isDying` flips synchronously the moment `takeDamage` reduces
hp to 0, well before the death animation finishes and the enemy is actually
removed, so the glow starts dying with the enemy instead of after it. (3)
The cast sparkle moved off the per-cast path entirely: `_sparkleAnimation`
now loads with `loop: true` (was one-shot), and a new `AttackBehavior.
onEquipped(ArenaGame)` lifecycle hook — called once from `ArenaGame.
resetRound()` right after the player is created, default no-op — is where
`SpiralFireAttack` now spawns one persistent `TrackingSpriteEffect` on the
player for the whole round. `spawnCastSparkle`/the per-cast call in `perform()`
are gone.
**Because:** `onEquipped` rather than an `if (character.attackBehavior is
SpiralFireAttack)` branch in `ArenaGame` is CLAUDE.md §4.12 — character/kit-
specific behavior is a strategy-object method, not a type-check in the
generic owner. `fadeOutWhen` as a poll closure (not a one-off event/callback)
keeps `TrackingSpriteEffect` decoupled from knowing anything about
`EnemyComponent` specifically — it can fade-trigger off any boolean
condition a future caller wants, elite death is just the first one.
**Consequences:** Every `AttackBehavior` now has 3 lifecycle touchpoints
(`cooldownSeconds`, `perform`, `onEquipped`) instead of 2 — `ProjectileAttack`/
`KnifeAttack` don't override the new one, no change to them. The sparkle's
opacity also went 0.35 → 0.5 (`kSparkleOpacity`) per "a little more visible"
in the same round of feedback — bundled into this entry rather than a
separate one since it's the same constant/same conversation.

## D-037 — Spiral Fire retune: +40% range, -30% spin speed, -40% damage
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** First feedback pass on `SpiralFireAttack` (D-034): targeting
range should be bigger, the orbiting spin should be slower, and per-hit
damage should come down — same "ship it plain, then tune from a real
reaction" pattern as the knife (D-029→D-030) and the Aura ring (D-027 update).
**Decision:** `SpiralFireAttack` gained its own `_rangeMultiplier` (1.4,
+40% vs. the shared `stats.attackRangePx` formula, applied only to the
initial target lookup — same role `KnifeAttack._rangeMultiplier` plays) and
`_damageMultiplier` (0.6, -40% vs. the shared per-hit formula, same role as
`KnifeAttack._damageMultiplier`). `SpiralFireProjectileComponent
._spinSpeedRadPerSec` (the orbit's angular speed, not the forward travel
speed — "spiral" reads as the orbiting wobble, not how fast the pair
advances toward the target) dropped from 10.0 to 7.0 (-30%).
**Because:** Naming these per-kit tuning fields the same way `KnifeAttack`'s
already are keeps the pattern recognizable — anyone tuning a kit later knows
to look for a `_rangeMultiplier`/`_damageMultiplier`/similar rather than
hunting for where a formula got inlined differently per class. Reading
"speed" in "make projectiles spiral with 30% less speed" as the orbit's
angular speed (not `speedPxPerS`, the forward travel speed already driven by
`stats.projSpeedPxPerS` like every other kit) matches what "spiral" actually
refers to — the wobble, not the advance.
**Consequences:** Two full-damage shots at 0.6x each is still more total
per-cast damage than a single `ProjectileAttack`/`KnifeAttack` hit at 1x
(1.2x combined) — intentionally not brought all the way down to parity,
since two-projectiles-that-can-both-connect is the kit's whole identity;
further tuning is expected same as everywhere else in this file.

## D-038 — Fixed real bug: Spiral Fire projectiles despawning short of their target
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer reported the projectiles' effective range read shorter
than the targeting range that picked them a target, and that they sometimes
despawned before visibly reaching it — worse after D-037's +40% range put
targets further out, closer to the arena edges.
**Decision:** `SpiralFireProjectileComponent._outOfBounds()` (a straight
`0 <= position <= game.size` check, copied from `ProjectileComponent`/
`KnifeProjectileComponent`) is removed. `_traveled >= _totalDistance` is now
the only despawn condition.
**Because:** The bug was the orbit itself: actual on-screen `position` each
frame is the straight-line path point *plus* a sideways wobble of up to
`_orbitRadiusPx` (24px) that only shrinks to 0 near the very end of the
flight (D-034's convergence design). Near a screen edge, that wobble could
push `position` outside `game.size` while `_traveled` was still well short
of `_totalDistance` — an early, wrong despawn. `ProjectileComponent`/
`KnifeProjectileComponent` need an out-of-bounds backstop because they don't
have a tight, exact natural endpoint (the bolt has a generous `maxRangePx`
multiplier; the knife has none at all after D-030). `SpiralFireProjectileComponent`
already has one — `_totalDistance` is computed directly from the real
distance to `targetPoint` at launch, so `_traveled` alone guarantees
termination in finite time at exactly the right place, regardless of what
the wobble does to on-screen position along the way. The bounds check was
redundant at best and actively wrong near an edge.
**Consequences:** A shot aimed at the extreme edge of the (now +40%) range
can render briefly outside the visible screen for a frame or two before its
final convergence — harmless (nothing draws outside the canvas clip, no
crash), and correct: it still lands exactly on `targetPoint` on schedule.

## D-039 — Spiral Fire projectiles fly to the screen edge, matching the knife
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer asked for two more things on the same kit: confirm
that firing again doesn't despawn an already-flying shot (nothing in the
code ever could — each `SpiralFireProjectileComponent` is a fully
independent instance with no shared/static state and no cross-references to
other projectiles; this was almost certainly the same symptom as D-038's
bug, now fixed), and that projectiles keep flying until they actually leave
the screen instead of stopping once they reach `targetPoint` — the same
"don't despawn on its own, only on a hit or leaving the arena" rule D-030
gave the Bruiser's knife.
**Decision:** Removed the `_traveled >= _totalDistance` despawn entirely.
`progress` (which drives the orbit radius shrinking to 0) is now
`(_traveled / _totalDistance).clamp(0, 1)` instead of an unclamped ratio —
the spiral still converges to a straight line exactly at `targetPoint`, but
then *stays* a straight line (radius pinned at 0) for as long as the
projectile keeps flying past it, rather than the ratio continuing to grow
past 1 (which the old despawn-at-1 branch never let happen, but the removed
branch was the only thing stopping it). D-038's `_outOfBounds()` comes back
as the sole despawn condition (hit-or-leaves-the-arena, same shape as the
knife) — but this time with a `_boundsMargin` equal to `_orbitRadiusPx`
padded onto every edge, so the orbit's own sideways wobble can never trip a
false "it's gone" near the true edge the way the unmargined version did
before D-038 removed it. Only once the projectile is genuinely past the
edge by more than the wobble's own amplitude does it actually despawn.
**Because:** A margin sized to the wobble amplitude is the minimal fix that
lets the bounds check come back safely — smaller than that risks
reintroducing D-038's bug, bigger just delays the despawn for no reason.
**Consequences:** Spiral Fire projectiles now behave exactly like the
knife's travel rule post-D-030: fly straight through/past their original
target, hit whatever they touch along the way (still single-target,
non-piercing — they despawn on the *first* hit same as always), and only
give up at the arena edge. `_totalDistance` is still computed and still
drives the orbit-convergence math; it's just no longer a despawn trigger by
itself.

---

## D-040 — Roaming world, Phase 9: camera follows the player, no bounds
**Date:** 2026-09-09 · **Status:** Accepted (Phase 9 started, not complete)
**Context:** Developer wants to move the game from a fixed-camera walled
arena (D-007, the whole demo through Phase 8) toward a Vampire-Survivors-
style roaming world: no bounds, the player can walk any direction
indefinitely, camera follows them ("kind of like parallax"). Given the size
of this change — it touches the camera, floor rendering, enemy spawning,
and the safe-area clamp all at once — asked the developer two things before
starting (CLAUDE.md §6, "ask before scope," this being explicitly a Backlog
item: "Camera larger than the screen, with scroll"): world size, and build
order. Answers: **effectively infinite** world (not a large-but-finite
map), built **one slice at a time** rather than all at once. This entry
covers slice 1 only: the camera and free movement. Two known, deliberately
deferred follow-ups are called out below and in TASKS.md Phase 9 — endless
floor tiling and re-centering enemy spawns on the player, not the world
origin.
**Decision:** `FlameGame` (which `ArenaGame` already extends) ships a
`World`/`CameraComponent` pair by default — before this, `ArenaGame` never
actually used them: every `add(x)` call added `x` as a **sibling** of the
default camera/world (both auto-added in `FlameGame`'s own constructor),
not a child of `world`, so nothing was ever subject to the camera's
transform at all. That's what let `game.size` (== `camera.viewport.
virtualSize`) silently double as "the world's bounds" throughout the
codebase (D-007) — screen space and world space were the same space by
accident, not by any explicit design. Two new `ArenaGame` methods,
`addToWorld(Component)`/`addToHud(Component)`, replace every direct
`add(...)`/`game.add(...)` call site across the codebase (floor, player,
enemies, projectiles, VFX, the Aura ring → `addToWorld`; the HP bar and FPS
counter, the only two components that must stay screen-fixed → `addToHud`,
i.e. `camera.viewport`, which is screen-space by construction). `resetRound`
now clears `world.children`/`camera.viewport.children` instead of `children`
(which would also try to remove `world`/`camera` themselves — they're
permanent, only their contents reset per round) and calls `camera.
follow(player, snap: true)` right after creating the new player each round
(`snap` so the camera jumps straight to them instead of panning in from
wherever it was left). `PlayerComponent._clampToSafeArea` and `ArenaGame.
safeAreaBounds`/`kSafeAreaInset` are gone outright — no bounds means nothing
left to clamp against.
**Because this forced a real bug fix, not just new scope:** every
projectile's `_outOfBounds()` (`ProjectileComponent`, `KnifeProjectileComponent`,
`SpiralFireProjectileComponent`) checked `position` against a literal
`0..game.size` rectangle — i.e. "the original screen-sized patch at the
world origin," which was indistinguishable from "off camera" only because
the camera never moved (D-007). The instant the camera can be anywhere,
that check means "more than one screen-width from world (0,0)" — true for
almost any shot fired after the player has walked away from spawn, which
would have made every ranged attack stop working within seconds of moving.
Fixed by checking against `game.camera.visibleWorldRect` (the camera's
actual current view) instead — a correctness fix this change *required*,
not an optional add-on, so it's included here rather than deferred.
**Consequences (the two known, deliberately deferred gaps — not bugs,
not forgotten):** `ArenaFloor` still only tiles the original `game.size`
patch at the world origin — walking past its edge currently reveals the
plain background colour instead of more floor. `Spawner._randomPerimeterPoint`
still spawns around that same origin rect, not around the player's current
position — enemies stop appearing once the player wanders far enough away.
Both are flagged in-code and in TASKS.md Phase 9 as the next two slices,
per the developer's own chosen build order; fixing either now would have
been scope beyond what was asked for this pass. `HpBarComponent`/
`ArenaFloor`'s doc comments updated to drop the D-007 assumption they were
written against.

## D-041 — Phase 9.3/9.4: endless floor, camera-relative spawning, straggler culling
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** On-device pass on 9.1 surfaced 4 issues, screenshotted:
(1) the old bounded arena's border tiles were still visible as a stray line
partway across the screen once the camera scrolled past where that patch
used to end; (2) the floor genuinely only ever covered the original
patch — walking past it showed empty background, exactly the gap D-040
flagged; (3) enemies could spawn inside the visible view instead of outside
it; (4) far enough from the start, enemies stopped spawning at all. This
entry closes TASKS 9.3 and 9.4 together, since (3) and (4) turned out to
share one root cause.
**Decision:** `ArenaFloor` rewritten to render every frame from
`game.camera.visibleWorldRect` directly — no more fixed `size`/
`onGameResize`-driven pattern grid, no more border tiles at all (an
infinite world has no edge to draw one on, which is what fixes (1) for
free). Tile variant per cell is a deterministic hash of `(col, row)` plus a
per-round random seed, not `Random()` per frame — the same cell always
renders the same tile if you leave and come back, only the seed differs
round to round. `Spawner._randomPerimeterPoint` now builds its perimeter
from `visibleWorldRect` inflated by `_visibleMarginFactor` (0.15, the
developer's literal "maybe 15% further" ask) instead of a fixed rect at the
origin — spawns always land just outside whatever the player can currently
see, wherever that is.
That alone would have re-broken (4) in a new shape: `EnemyStats.
moveSpeedPxPerS` (70) is slower than every playable character's
`moveSpeedPxPerS` (120+), so in an unbounded world an enemy that spawns
behind a player moving mostly one direction can fall behind and never
catch up — previously impossible, since world-equals-screen (D-007) meant
every live enemy was already always near the player. Left alone, those
enemies never die, permanently occupying slots under `Spawner.
_maxLiveEnemies` (60) until nothing new can spawn — the actual mechanism
behind the reported "stops spawning far from start" bug. Fixed with
`Spawner._cullStragglers`, ticking once a second: any enemy farther than
`_cullDistanceFactor` (3.0) times the visible view's larger dimension from
the player is removed via a new `ArenaGame.cullEnemy` — same removal as a
normal kill, minus the kill count/XP grant, so it doesn't misreport round
stats. 3.0x is well beyond the spawn margin specifically so normal chasing
(an enemy temporarily behind mid-pursuit) is never mistaken for stragglers.
**Because:** Deriving both the floor's tile range and the spawn ring from
`visibleWorldRect` (rather than reintroducing a second "where is the player
now" concept) means both automatically track whatever the camera is
actually doing — including any future zoom/viewport changes — without
needing their own separate camera-following logic. Culling was not
explicitly requested but is required for (4) to be *actually* fixed rather
than just moved: recentering spawns alone does not stop already-unreachable
enemies (or ones created by an unlucky chase) from permanently eating the
population cap.
**Consequences:** `TrackingSpriteEffect`-based effects (an elite's fire
glow) clean themselves up for free on a cull the same way they do on a
real death, since they already key off the target leaving the tree, not
off `onEnemyKilled` specifically. No stat/UI changes — culled enemies are
invisible to the player by construction (they're always far outside the
view when it happens). TASKS 9.5 (revisit anything else that assumed a
bounded arena) is still open.

## D-042 — The boss: spawns at levels 3/6/9, ranged, teleports away up close
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer delivered `boss_map1.png` and asked for a real boss
fight: spawns at player levels 3/6/9 (~20% stronger each time), idle/walk/
fire/death animations "all in the same spritesheet in this order," fires a
bolt recoloured "bright green, like green screen green," teleports to the
other side of the map when the player gets close (playing `effect_anima` at
both ends, one-shot, self-cleaning), and every hit on it plays
`effect_impact`.
**Decision:** `boss_map1.png` turned out to be one 4-cols × 8-rows sheet
(256×192 native cell) — inspecting each cell's actual alpha content (not
just eyeballing the thumbnail, which reads confusingly since some
"empty" cells render as solid black in this pipeline rather than
transparent) found idle=6 frames (rows 0-1), walk=3 (row 2), fire=5
(rows 3-4), death=10 (rows 5-7) — 24 real frames total, in exactly the
stated reading order. `loadSheetAnimation` (`sheet_loader.dart`) gained a
`texturePosition` param to pull each of those 4 slices out of the one
shared sheet — must be a whole-row pixel origin (`x: 0`, `y` a multiple of
cell height); the frame-index math wraps correctly onto the next row down
from there, confirmed by hand for each of the 4 ranges before trusting it.
New `BossComponent` (`game/components/boss.dart`) — `implements Damageable`
rather than `extends EnemyComponent`: the two share no behavior worth
inheriting (different animation states, different movement rule, firing
and teleporting `EnemyComponent` has no hook for), but both need to be
hittable by the exact same attack code. `Damageable` (`game/components/
damageable.dart`) is a new minimal interface (`isDying`/`position`/`size`/
`applyKnockback`/`takeDamage`) — `EnemyComponent` already satisfies it with
zero code changes, since every member already existed with a matching
signature. Every attack's hit-detection loop (`ProjectileComponent`,
`KnifeProjectileComponent`, `SpiralFireProjectileComponent`, `AuraComponent`)
now iterates `ArenaGame.damageableTargets` (`[...enemies, ?_boss]`) instead
of `enemies` directly.
The boss's own state machine: idle/fire while the player is within
`BossStats.fireRangePx` (holds position, fires on a cooldown instead of
closing to melee — a caster, not a brawler), walk to close the distance
when further than that, and an immediate teleport (no walk/fire check that
frame) the instant the player gets within `BossStats.teleportTriggerDistancePx`.
The teleport target is the literal mirror of the boss's current position
across the player (`playerPos + (playerPos - bossPos)`) — "the other side"
of wherever the player actually is, not a random point, since "the map" no
longer has fixed bounds to define "other side" against (D-040). The green
bolt reuses `ProjectileComponent` itself (not a new component) via a new
optional `tint` constructor param — `ColorFilter.mode(color,
BlendMode.srcIn)` recolours the existing bolt animation to a flat solid
colour, which is exactly "green screen green" (pure `0xFF00FF00`) rather
than a tint that would need the sprite's own shading preserved.
`BossComponent.takeDamage` owns the impact-vs-explosion choice itself
(impact on a non-lethal hit, explosion + its SFX, D-044, on the kill) so
"hits on this boss play effect_impact" holds for every attack kit
uniformly, not just the ones (Spiral Fire) that already had their own
hit-flourish logic — accepting that Spiral Fire specifically hitting the
boss now shows that flourish twice in the same frame, an invisible overlap,
not worth special-casing around.
Boss spawn/kill bookkeeping lives in `ArenaGame`: `_checkBossSpawnThreshold`
runs on every level-up (real or debug-granted) and queues a spawn per
threshold crossed rather than checking `level == 3` exactly, so a multi-
level jump (debug-granting several at once) queues all of them; only one
boss is ever alive at a time, a queued spawn waits for `onBossKilled`.
Boss kills grant `kBossXpReward` (10x a grunt, `core/progression.dart`) and
`kBossCoinMultiplier`x coins (D-043) — meant to feel like a milestone, not
just another kill.
**Because:** `Damageable` as a structural interface (not a base class) is
the minimal-footprint way to let two components with nothing else in
common share one set of attack code — the alternative (a duplicated
per-attack-file boss-specific hit loop) would have meant four files each
carrying two near-identical collision loops instead of one generic one.
Reusing `ProjectileComponent` for the green bolt rather than writing
`BossProjectileComponent` avoids a whole new component for what's really
just a recolour.
**Consequences:** `randomPerimeterPoint` (`core/game_rules.dart`) is now
shared by `Spawner` (grunts) and the boss's own spawn point — extracted
from what was `Spawner._randomPerimeterPoint` into a pure, tested function
so both stay in sync and neither duplicates the ring math. Every stat
(`BossStats`, `core/stats.dart`), the frame-range mapping, the render size
(`kBossWidthPx`), and the tint colour are first-guess placeholders — none
of this is tuned on-device yet.

## D-043 — Economy: gems (drop), potions (drop, heal), money (round-over only)
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer delivered `gems.png`/`money.png`/`potions.png` (all
80×N, 5 columns of rarity tiers left-to-right, each column its own vertical
animation strip — the opposite layout from every other multi-frame sheet in
this project, which reads frames left-to-right along a row) and specified
three related but distinct systems: gems drop from kills at a chance that
grows with level and sit in the world until walked over; money isn't a
world object at all — it accrues silently per kill and reveals itself only
at round-over, in a specific counting-up-with-flying-coins animation the
developer described in detail; potions spawn randomly on the map, float in
place, and heal on touch ("we will add more logic later" — healing is
deliberately the whole mechanic for now).
**Decision:** One shared model, `core/economy.dart` — `ItemRarity` (5
values), `kRarityWeights` (a placeholder weighted table, common far more
likely than legendary), `rollRarity`, and three per-resource value tables
keyed off the same roll: `kCoinValueByRarity` (money), `kPotionHealByRarity`
(potions) — gems have no value table since nothing reads a gem's rarity
yet beyond which icon it shows. `gemDropChance(level)` is `0.8 +
0.01*(level-1)`, clamped at 1.0 (developer's literal "80% and growing" ask).
New `loadColumnAnimation` (`sheet_loader.dart`) reads one vertical strip
out of a column-per-type sheet — a `texturePosition` offset couldn't do
this (that trick only wraps onto the *next row down* from a whole-row
origin, not sideways into a different column's frames), so it needed its
own loader rather than a variant of the row-major one.
`GemComponent`/`PotionComponent` are both simple world pickups: loop their
own 16×16 column animation, self-collect (call back into `ArenaGame`, then
`removeFromParent()`) once the player is within `kItemPickupRadiusPx` — no
central "check all pickups" loop, each pickup checks its own distance to
the player every frame, same pattern `EnemyComponent` already uses for
contact damage. `PotionComponent` layers a sine offset on `position.y`
(`kPotionFloatAmplitudePx`/`kPotionFloatPeriodSec`) on top of its sprite
animation for the float — a second, independent animation dimension, not
baked into the sprite sheet. Gems spawn from `ArenaGame.onEnemyKilled`
(rolls `rollGemDrop`, then `rollRarity` for which icon); potions spawn from
a new periodic `PotionSpawner` component, picking a random point in a
generous rect around the camera's current view (not just its perimeter,
unlike enemies — potions are meant to be walked toward, not to appear like
a threat) capped at `_maxLivePotions` (5) live at once.
Money never becomes a component: every kill rolls `rollCoinValue` (a
rarity roll → `kCoinValueByRarity`) straight into `ArenaGame.coinsEarned`,
a plain running total, no world presence at all. It surfaces once, at
round-over, via a new `_CoinCounter` Flutter widget (`arena_screen.dart` —
Round Over is a Flutter overlay, D-010, so this is Flutter animation code,
not a Flame component): an `AnimationController`-driven `IntTween` counts
the number from 0 to the real total next to `ui/currency-counter.png` (the
"big red coin"), while up to 10 small coins (capped regardless of the real
total — animating hundreds of individual sprites would be absurd) fly in
from outside the widget on staggered `Interval`s, shrinking and fading to
nothing exactly as they arrive — the developer's literal spec. The flying
coins use a new small `_SpriteCell` widget (crops one cell out of a sheet
via `OverflowBox` + `ClipRect` + `Alignment` math) so they show the actual
`money.png` art rather than a placeholder shape.
**Because:** One rarity model for three resources is what "same value
logic" literally asked for — three separate weight tables would drift out
of sync with each other for no reason. Column-strip pickups reading their
own distance to the player (rather than `ArenaGame` polling a pickup list
every frame) keeps the "how do I get collected" logic next to the thing
being collected, consistent with how contact damage already works.
**Consequences:** Every number here — the rarity weights, the coin/heal
values per tier, the level-scaling rate, the flying-coin count/timing — is
a first-guess placeholder, unverified on-device, same caveat as everything
else shipped this way in this project. Gems currently do nothing but
accumulate a visible count at round-over; no economy sink exists yet (nor
was one asked for).

## D-044 — SFX: explosion + death, quiet by default
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** `flame_audio` has been a declared dependency since D-002 with
nothing ever playing through it (NEXT.md flagged this explicitly as
deliberately deferred, not forgotten). Developer delivered
`assets/audio/core/sfx-explosion.wav`/`sfx-you-died.wav` and asked for them
wired to "when we kill boss, when any explosion effect is played" and "when
we die" respectively, both quiet.
**Decision:** One new private helper, `ArenaGame._playSfx(String file)` —
`FlameAudio.play(file, volume: (settings.sfxVolume/100) * kSfxVolumeCap)`.
Two call sites: `spawnExplosionEffect` (already the single place both a
Spiral Fire kill *and* now a boss kill trigger the explosion visual, so
hooking the sound there satisfies both halves of "when we kill boss, when
any explosion effect is played" with one line, not two) and
`onPlayerDied` (guarded to fire once, same as the `_roundEndDelay ??=` it
sits next to — `debugDie()` bypasses this method entirely, so the debug
kill button doesn't play a death sound for what isn't a real death).
**Because:** Deriving the played volume from the user's own `sfxVolume`
slider (already a real, working setting, just never consumed until now)
rather than a flat constant means turning SFX off in Settings actually
turns these off too — `kSfxVolumeCap` (0.35) is layered on top specifically
because the developer asked for quieter-than-the-slider-might-suggest, not
instead of respecting the slider.
**Consequences:** Music (the other half of `flame_audio`'s intended use,
per D-002/NEXT.md) is still entirely unwired — this closes the SFX half
only. First real audio in the project; no other sound effects exist yet.

## D-045 — `arena_game.dart` is now ~800 lines; a split is overdue
**Date:** 2026-09-09 · **Status:** Accepted (flagged, not acted on)
**Context:** D-034's own consequences section already flagged this file
"trending toward CLAUDE.md §5's ~300-line guideline" after the VFX work.
This session's boss/economy/SFX additions pushed it to ~820 lines without
pausing to split it first — a deliberate call under the circumstances (see
Because), not an oversight.
**Decision:** Ship the features now, log this entry, and put a real split
at the top of TASKS as the next priority before anything else piles onto
this file. The shape of the split is already visible from how the file
reads today: a `VfxLibrary`/`AssetLibrary`-type class to hold the ~20
`SpriteAnimation`/`Sprite` fields and the entire loading block currently in
`onLoad()` (the single biggest contributor to the line count), leaving
`ArenaGame` itself holding round state, spawn/kill bookkeeping, and the
`addToWorld`/`addToHud` split — much closer to CLAUDE.md §5 afterward.
**Because:** This message asked for three substantial, independent
features in one go (a boss, SFX, a full loot economy) — stopping mid-task
to refactor the file they all needed to touch would have meant redoing
that refactor's touch points against a moving target three separate times
instead of once, for a rule about maintainability, not correctness. Explicit
technical debt, called out rather than silently accumulated, is the
project's established way of handling exactly this trade-off (see D-007→
D-040/D-041's gap-then-fix pattern) — this is the same move, logged instead
of deferred silently.
**Consequences:** The next arena_game.dart change of any real size should
do the split first. Nothing about today's features depends on the current
file shape — the split is pure reorganization once it happens, not a
behavior change.

## D-046 — Two real bugs from the first on-device Phase 10 pass, plus a gem-rate cut
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer's first real play session against the boss reported
"boss does not get to attack? He does the animation but I never get to see
his projectile. Also, the character projectile seems to ignore him, does
not shoot towards him at all" — plus gems dropping so densely they were
spawning on top of each other.
**Decision:** Three fixes, all in code the boss/economy work (D-042/D-043)
already touched:
1. **Boss self-hit.** `ProjectileComponent`'s hit-loop reads
   `game.damageableTargets`, which includes the boss itself (D-042) — the
   boss's own bolt starts at `position.clone()` (its own position), so the
   very first `update()` after spawn found it "touching" its own spawn
   point at distance ≈0 and destroyed itself before ever traveling
   anywhere. Added an `excludeSelf` param to `ProjectileComponent`,
   `BossComponent._fire` passes `excludeSelf: this`.
2. **Player attacks never targeting the boss.** `ProjectileAttack`/
   `KnifeAttack`/`SpiralFireAttack` all built their targeting list from
   `game.enemies` directly — a leftover from before the boss existed — so
   `nearestWithinRange` could never return the boss as a candidate no
   matter how close it was. All three now target off
   `game.damageableTargets` (the same list the hit-detection loops already
   used), matching that getter's own doc comment ("every attack's
   hit-detection loop reads this instead of `enemies` directly" — the
   *targeting* half just hadn't been updated to match).
3. **Gem rate cut 80%** (`kGemBaseDropChance` 0.8→0.16, `kGemDropChancePerLevel`
   0.01→0.002) — "spawn near one another," too dense at the original
   numbers.
**Because:** (1) and (2) are the same root cause from two directions — the
boss was added to the *can-be-hit* list (`damageableTargets`) without a
matching audit of every place that used to enumerate `game.enemies` for a
different purpose (picking a target vs. checking for a hit). (3) is a
straight tuning response to on-device feedback, same as every other
first-guess number in this project.
**Consequences:** Any *future* Damageable (if one is ever added) needs the
same audit — grep for `game.enemies` in attack code, not just
`game.damageableTargets`, before assuming it's covered.

## D-047 — Persistent meta-progression: SHOP + UPGRADES from character select
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer's spec verbatim: room for SHOP & UPGRADES on the
character-select screen before pressing start. SHOP buys items/powers
("nothing yet, empty, just a back button"). UPGRADES raises STR/VIT/DEX/
INT/CORRUPTION, each 10 levels, increasing cost, spent from coins earned
finishing rounds. CORRUPTION specifically: "increases your enemy spawn
rate/enemy HP/enemy damage but increases rewards per level bought."
**Decision:** New `core/meta_progression.dart` — `MetaStat` enum (str/vit/
dex/intellect/corruption), `MetaProgression` (wallet + 5 levels, `.buy()`
does the afford/cap check and deducts atomically), `metaUpgradeCost`
(same exponential-growth shape as `progression.dart`'s XP curve — steep on
purpose, not a first-session buy), `MetaProgressionRepository`
(`SharedPreferences`, same load/save shape as `SettingsRepository`). Three
new corruption multiplier functions live in `game_rules.dart` instead
(gameplay math, not shop data) — `corruptionSpawnIntervalMultiplier`,
`corruptionEnemyStatMultiplier`, `corruptionRewardMultiplier`, all linear
per level, first-guess numbers.
Wired in:
- `ArenaGame` gains `meta` (loaded once at arena entry, same as `settings`)
  and `effectiveStats` — `character.stats` plus `meta.bonusStr/Vit/Dex/
  Intellect` (a flat +1 attribute point per level, landing directly on
  `StatBlock`'s own integer scale so it flows through every derived combat
  formula for free). Every place that used to read `character.stats` or
  `game.character.stats` for combat math now reads `game.effectiveStats`
  instead — `PlayerComponent` takes a resolved `StatBlock stats` in its
  constructor (needed before `game` is reachable, since HP is set in the
  initializer list) rather than reaching for `character.stats` itself.
- `Spawner` multiplies its scheduled interval by
  `corruptionSpawnIntervalMultiplier(game.meta.corruptionLevel)`.
- `ArenaGame.spawnEnemy` multiplies the existing level-based
  `enemyStatMultiplier` by `corruptionEnemyStatMultiplier` (layered on top,
  not instead of).
- Coin rewards (`onEnemyKilled`/`onBossKilled`) route through a shared
  `_rollCoins()` that applies `corruptionRewardMultiplier`.
- `ArenaGame._endRound` credits the round's `coinsEarned` into the
  persistent wallet exactly once
  (`MetaProgressionRepository().addCoins(...)`, fire-and-forget) — a
  *different* counter from `coinsEarned` itself, which stays the
  round-scoped number the RoundOver overlay displays.
Two new screens (`UpgradesScreen`, `ShopScreen`), two new routes, two new
buttons + a wallet readout on `CharacterSelectScreen` (reloaded every time
either route is popped, since either can spend the wallet).
**Because:** +1 attribute point per shop-level was chosen over a separate
bonus-tracking layer (the way `PlayerUpgrades`, the in-round system,
works) specifically because it's *cross-round* — folding it into
`StatBlock` itself means it's inert dead-simple to reason about (it's
exactly as if the character's base stats were higher) and costs zero new
derived-formula code. `ShopScreen` shipped as a literal empty placeholder
because that's exactly what was asked for — a home for a future feature,
not a guess at its contents.
**Consequences:** The Upgrades shop is reachable from character select
only, never mid-round, so `ArenaGame.meta` is safe to treat as immutable
for a whole round. Corruption has no upper guardrail beyond its own
10-level cap and the spawn-interval multiplier's 0.2 floor — needs a real
playtest to see whether level 10 corruption is "hard but rewarding" or
"unplayable." Same first-guess-numbers caveat as every other tuning value
in this project.

---

## D-048 — `arena_game.dart` split: `GameAssets` holds every loaded asset
**Date:** 2026-09-09 · **Status:** Accepted · Closes D-045/TASKS 10.7
**Context:** D-045 flagged `arena_game.dart` at ~820 lines, well past
CLAUDE.md §5's ~300-line guideline, and NEXT.md/TASKS 10.7 both said the
next non-trivial touch to this file should be the split, not another
feature on top. The 4 new skills (D-049, same session) were exactly that
next touch, so the split came first.
**Decision:** New `game/game_assets.dart`, a `GameAssets` class holding
every `SpriteAnimation`/`Sprite` field (~20 of them) plus a `static
Future<GameAssets> load(CharacterDef character)` that's the verbatim body
of the old `ArenaGame.onLoad()` loading block. `ArenaGame.onLoad()` is now
three lines: `await super.onLoad(); gameAssets = await
GameAssets.load(character); resetRound();`. The field on `ArenaGame` is
named `gameAssets`, not `assets` — `Game` (Flame's own base class) already
declares a member called `assets` (an `AssetsCache`), so the obvious name
was already taken and `flutter analyze` caught it immediately as an invalid
override. `ArenaGame` keeps its existing public getters
(`boltAnimation`/`knifeCleanSprite`/`pixelFireAnimation`/etc.) exactly as
they were, just delegating to `gameAssets.X` instead of a bare field — every
external call site (`AttackBehavior`s in `attack_behavior.dart`,
`BossComponent`, `AuraComponent`) needed zero changes.
**Because:** Matches NEXT.md's own plan exactly (pull the fields + loading
block into a class `ArenaGame` holds an instance of) — the getter-delegation
trick was the one addition, chosen specifically to make this a pure
extraction with no ripple into every file that reads `game.boltAnimation`
today. `ArenaGame` itself dropped from ~820 lines to a few hundred; round
state, spawn/kill bookkeeping, and `addToWorld`/`addToHud` are what's left,
matching CLAUDE.md §4.5's "ArenaGame owns round state" scoped down to
actually fit the file-size guideline in §5.
**Consequences:** A future asset (a 5th skill, a new enemy skin) is now a
new field + load call in `game_assets.dart`, not another few lines inline
in `ArenaGame.onLoad()` — keeps the split from silently regressing the same
way it grew the first time. `assets` as a field name is now permanently
off-limits on any `FlameGame` subclass in this codebase — worth remembering
before reaching for the "obvious" name again.

---

## D-049 — Four new powers: Ultimate Mirror, Projectile Ray, Projectile Thunder, Defence Crystal
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer delivered 4 new VFX sheets
(`vfx/projectiles/{ultimate-mirror,projectile-ray-beam,projectile-thunder,
defence-crystal}.png`) and specced 4 new level-up skills directly:
1. **Ultimate Mirror** — spawns away from the player, animated, shoots
   bolts from both sides at a fast pace; levels increase how many mirrors
   can be up at once; mirrors only spawn on screen, where the player can
   see them.
2. **Projectile Ray** — fires once every 3 seconds, pierces, high damage;
   levels increase attack speed.
3. **Projectile Thunder** — strikes down on random enemies the player can
   see, damage, must render on top of the enemy sprite, not behind; levels
   increase damage and how many enemies get hit at once; cooldown decreases
   from 4 seconds down to 1.
4. **Defence Crystal** — orbits the player in a figure-8 shape; picking it
   grants higher damage resistance and a low HP regen.
None of the 4 were specced with exact numbers (damage, cooldowns, stack
caps) — every number below is a first-guess placeholder, the same
established pattern as Aura (D-027) and every other tuning value in this
project, not a literal developer spec.
**Decision, grid dimensions first:** Each sheet's actual layout was
confirmed by decoding its PNG rows/columns for content bands (same method
D-042's boss sheet used, not the visual thumbnail) rather than guessed:
- `ultimate-mirror.png` — single **column** of 5 frames, 128×128 each.
- `projectile-ray-beam.png` — single **column** of 6 real frames (a 7th
  grid row is blank), 256×64 each — a wide, short beam texture, stretched
  to the shot's actual range at the call site rather than being a fixed
  size.
- `projectile-thunder.png` — single **row** of 4 frames, 128×256 each.
- `defence-crystal.png` — single **row** of 6 frames, 128×128 each.

**Decision, per skill:**
1. **Ultimate Mirror** (`UpgradeKind.ultimateMirror`,
   `game/components/mirror.dart`'s `MirrorComponent`) — a stationary turret,
   not a companion: doesn't move or track the player past its spawn point.
   Spawn point comes from a new pure function, `randomVisiblePoint`
   (`core/game_rules.dart`) — a point *inside* `camera.visibleWorldRect`,
   inset by a margin, the literal opposite of `randomPerimeterPoint`
   (enemies/the boss spawn just *outside* what's visible; this spawns
   *inside* it, per the "only on screen" ask). Fires a bolt directly left
   and directly right every 0.5s (fixed, not aimed at a target — the one
   attack in this project that doesn't target anything, matching "both
   sides" literally) using the existing bolt sprite/`ProjectileComponent`.
   Capped at 3 stacks; `ArenaGame._syncMirrors` adds the difference on each
   new pick and never removes one — a stack count can't decrease mid-round.
   A single mirror's own damage/pace never scales; only the count does,
   matching the spec's "levels increase number of mirrors" and nothing
   else.
2. **Projectile Ray** (`UpgradeKind.projectileRay`) — a second,
   independently-cooling attack owned directly by `ArenaGame` (its own
   `_rayActive`/`_rayCooldownTimer` fields, ticked in `update()` next to the
   existing `character.attackBehavior` cooldown), not a `CharacterDef.
   attackBehavior` — every character can pick this regardless of kit, unlike
   `knifeMastery` (D-031). A new pure function, `alongLineWithinRange`
   (`core/game_rules.dart`), finds every target within a half-width of the
   line from the player toward the nearest target in range (not just the
   nearest one — "pierces"), so a full row of enemies standing in the beam's
   path all take damage in one shot. `ArenaGame._syncRay` starts the timer
   on the first pick only (`_rayActive`), same "sync once, read the current
   stack count live on every trigger" shape as Aura's `_syncAura`/`_aura`.
   Base cooldown 3s, capped at 3 stacks; both cooldown (shrinks) and damage
   (grows) are tier tables keyed by stack count
   (`UpgradeAmounts.rayCooldownSec`/`rayDamage`) — the spec only asked for
   faster attack speed per level, but a faster ray dealing the *same*
   per-hit damage as a slower one would make higher levels strictly better
   with no tradeoff, so damage rises too rather than staying flat.
   Visual: `game/components/ray_beam.dart`'s `RayBeamEffectComponent` —
   pure decoration, no hit-test of its own (that already happened in
   `ArenaGame._fireRayBeam` before this spawns) — stretched to the shot's
   actual range and rotated to face it via `Anchor.centerLeft` + `angle:
   atan2(direction.y, direction.x)`.
3. **Projectile Thunder** (`UpgradeKind.projectileThunder`) — same
   sync-once-timer shape as Projectile Ray
   (`ArenaGame._syncThunder`/`_thunderActive`/`_thunderCooldownTimer`).
   Strikes `UpgradeAmounts.thunderTargetCount(stacks)` random living targets
   (grunts or the boss, via `damageableTargets`) per trigger, each with
   `spawnEffect` at `ArenaPriority.hitEffects` — deliberately *not*
   `ArenaPriority.enemy`/`enemyOverlay`, since `hitEffects` (25) is already
   well above `enemy` (10), which is what actually answers "make sure the
   lightning appears on top of the enemies asset not behind" (every other
   one-shot hit VFX in this project — sparks, impact, explosion — already
   uses this same priority for the same reason). Capped at **4** stacks,
   not the usual 3 — the one deliberate exception, because the spec gives 4
   literal cooldown values (4s → 3s → 2s → 1s, "reaching 1"), so 4 tiers is
   the number the spec actually specified, not a guess. Damage and target
   count both rise across the same 4 tiers.
4. **Defence Crystal** (`UpgradeKind.defenceCrystal`,
   `game/components/defence_crystal.dart`'s `DefenceCrystalComponent`) —
   the one skill capped at **1** stack, not 3: the spec never says "levels
   increase" anything for this one ("if the user picks this power, he has
   higher damage resistance and low hp regen" — a single flat effect, not a
   scaling one), so it's modeled as a single-pick passive rather than
   extrapolating a tier table the developer never asked for. The visual
   orbits the player on a lemniscate (figure-8) path — `x = sin(t)`,
   `y = sin(2t)/2` — the literal "orbits ... in a kind of 8 shape" ask,
   picked over a true parametric lemniscate for how much simpler it is to
   tune independently on each axis (`defenceCrystalOrbitRadiusXPx`/`Y`). The
   actual resistance/regen bonus is **not** read live off the component the
   way the 3 skills above read their stack count — it's a flat additive pair
   on `PlayerUpgrades` (`damageResistance`, `bonusHpRegenPerSec`), applied
   once in `PlayerUpgrades.apply()` the same way vit/dex/str/intellect
   already are (D-025 #2's "direct additive stat bonuses, not `StatBlock`
   re-derivation" pattern, extended to a multiplier and a second regen
   source rather than just HP/speed/damage). `PlayerComponent.takeDamage`
   multiplies incoming damage by `(1 - damageResistance).clamp(0, 1)` before
   applying it (the clamp guards against a future stacking bug ever
   inverting it into bonus damage); the regen line adds
   `bonusHpRegenPerSec` next to the existing `stats.hpRegenPerSec`.

**Because:** Every mechanism reuses an existing pattern rather than
inventing a new one — Aura's "sync once, read the current stack count
live" shape covers 3 of the 4 skills directly (a live component for Mirror,
a bare timer for Ray/Thunder, since there's nothing to render between
triggers); Defence Crystal reuses D-025's original flat-bonus layer instead,
since its own spec is a flat effect, not a live-scaling one. The 2 new pure
functions in `core/game_rules.dart` (`randomVisiblePoint`,
`alongLineWithinRange`) follow the file's own rule (CLAUDE.md rule 3/11):
targeting/placement math with no `Component`/`Game` dependency, unit-tested
directly rather than only verifiable on-device.
**Consequences:** All 4 numbers (damage, cooldowns, stack caps, orbit
radii) are first-guess placeholders like every other tuning value in this
project — a real balance pass is a later, separate step once they've been
seen on-device. `flutter analyze` clean, `flutter test` 85/85 (14 new: 7 in
`game_rules_test.dart` for the 2 new pure functions, 7 in
`progression_test.dart` for the new tier tables/`PlayerUpgrades` fields),
`flutter build apk --debug` succeeds, and the debug APK installs and
launches on the emulator without a crash (the highest-risk part —
`GameAssets.load()` loading all 4 new sheets with the grid dimensions
above, since a wrong `amount`/`amountPerRow` pairing throws an assertion at
load time the same way D-042's boss sheet once did). Full on-device play
(seeing each skill actually fire/render, TASKS 12.7) wasn't completed this
session — the emulator got stuck in a repeating "System UI isn't
responding" loop on every touch, an environment/host-performance issue
unrelated to this change, not a code defect.

---

## D-050 — Four powers, first on-device-facing tune pass (pre-verification)
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer asked for 4 specific tweaks to D-049's skills before
committing, ahead of TASKS 12.7's on-device pass (the emulator session that
would have driven that check got derailed — see D-049's closing note — and
the developer asked to stop testing on the device and do it themselves;
CLAUDE.md §2 gained an explicit "never drive the emulator to test" rule as
a result). All 4 are asked-for numbers, not guesses:
1. **Projectile Thunder +40% size, +20% brightness.** `kThunderWidthPx`
   48→48×1.4 (`core/constants.dart`). Brightness needed a new capability —
   `spawnEffect` (`ArenaGame`) gained an optional `brightness` param, a
   pure-multiply color matrix (`_brightnessMatrix`, no translate term,
   unlike `AuraComponent`'s existing contrast matrix which pulls toward
   grey) layered onto the same `Paint` the existing `opacity` tint already
   uses — one shared method instead of a thunder-only copy, since a future
   VFX wanting the same treatment now has the knob. `_strikeThunder` passes
   `brightness: 1.2`.
2. **Ultimate Mirror: cycle instead of a permanent turret.** The original
   D-049 mirror never went away once spawned — developer's framing ("Mirror
   never de-spawns") flagged that as the thing to fix, not confirm.
   `MirrorComponent` now runs a 2-phase timer: active (visible, firing
   both ways every 0.5s) for `UpgradeAmounts.mirrorActiveDurationSec` (3s),
   then hidden (invisible via `opacity = 0`, doesn't fire) for
   `mirrorCooldownDurationSec` (3s) — "that's the cooldown," developer's
   exact words, so the two numbers are named and equal rather than one
   cooldown constant algebraically implying the other. Toggling opacity
   rather than removing/re-adding the component keeps `ArenaGame._mirrors`
   bookkeeping untouched — the component still lives for the whole round,
   only its visibility/firing flips. Every time it goes active again it
   also re-picks its position (`randomVisiblePoint`, same function D-049
   already added) — "make it come" read as a fresh appearance each cycle,
   not a fade-in at the same spot.
3. **Defence Crystal: bigger figure-8, front/behind depth cycling.**
   `defenceCrystalOrbitRadiusXPx`/`Y` 50/30 → 80/48 (+60%, "make the 8 ...
   bigger" — no exact target given, same first-guess-tune convention as
   every other number in this project). The depth effect reuses the orbit
   math already being computed rather than adding a second curve: the
   figure-8's own `x = sin(t)` term already tells the two lobes apart (it
   crosses zero exactly at the crossing point in the middle), so
   `DefenceCrystalComponent.priority` just flips between
   `ArenaPriority.player - 1` (behind) and `player + 1` (front) on that
   same sign — Flame's `Component.priority` setter re-sorts siblings on
   change (confirmed in `flame-1.38.2`'s `component.dart`, cheap here since
   it only actually re-enqueues on the two sign flips per loop, not every
   frame).
4. **Projectile Ray beam +40% thickness.** `kRayBeamThicknessPx` 28→28×1.4
   — visual only, deliberately not touching `rayHalfWidthPx` (the hit-test
   half-width): the ask was "too thin" to look at, not that it's missing
   hits, and the two were already close enough (28 vs. a 36px hit-width)
   that changing only the render size doesn't create a visible mismatch.
**Because:** Each fix reuses an existing mechanism rather than adding a new
one — brightness rides the same `Paint`/color-matrix path opacity and
`AuraComponent`'s contrast tune already use; the mirror's cycle is a timer
state machine, the same shape as every other D-049 skill's cooldown timer,
just with a visibility flag added; the crystal's depth swap reads a value
already being computed every frame instead of introducing a parallel one.
**Consequences:** All 4 are still first-pass numbers (the mirror's 3s/3s
split, the crystal's 60% orbit bump, the two 40% size bumps) — genuine
on-device feel is still TASKS 12.7, now explicitly the developer's to run,
not something a future session should try to drive itself.

---

## D-051 — Fixed: boss bolt never damaged the player
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer reported the boss's projectile does the fire
animation and travels but never damages the player. Real bug, not a
misconfigured number: `ProjectileComponent`'s hit-test loop only ever
checks `game.damageableTargets` — "everything a *player* attack can hit"
(grunts + the boss, DECISIONS D-042's own doc comment on that getter). The
player was never in that list, because it was never meant to answer "what
can an enemy attack hit" — nothing needed that question before the boss
existed. So the boss's own bolt (`BossComponent._fire`, also built from
`ProjectileComponent`) was scanning a target list that structurally could
never contain the thing it was actually supposed to hit. This is a
different bug from D-046 (the boss self-hitting its own bolt at spawn,
already fixed) — that one was about the *wrong entry* being in the list
this loop checks; this one is about the *wrong list* being checked at all,
and had been there since the boss shipped (D-042), silently never caught
because on-device passes noticed the bolt visually firing and travelling
and read that as "it's working."
**Decision:** `ProjectileComponent` gained a `targetsPlayer` param (default
`false`, matching every existing player-owned use — `ProjectileAttack`,
Ultimate Mirror). `true` skips `game.damageableTargets` entirely and checks
`game.player` instead, calling `player.takeDamage(damage)` directly with no
knockback (`PlayerComponent` isn't `Damageable` and nothing in this project
knocks the player back — enemy contact damage doesn't either,
`ArenaGame.onEnemyContact` calls `player.takeDamage` the same bare way).
`BossComponent._fire` now passes `targetsPlayer: true` instead of
`excludeSelf: this` — the self-hit guard is dead code now (it only ever
mattered for the `damageableTargets` loop this bolt no longer runs; the
field stays on `ProjectileComponent` for any future player-owned projectile
that might need it, just unused today).
**Because:** A second, parallel branch (`_checkPlayerHit` next to the
renamed `_checkDamageableHit`) rather than trying to unify the player and
`Damageable` under one interface — `PlayerComponent` has real differences
(no knockback, a different alive-check, i-frames handled inside
`takeDamage` itself) that would make a forced-fit interface more confusing
than two short, clearly-named methods on the one component that already
knows how to travel and range-check itself.
**Consequences:** Any *future* enemy-side projectile (a second boss, a
ranged grunt) reuses `targetsPlayer: true` for free. `flutter analyze`
clean, `flutter test` 85/85, `flutter build apk --debug` succeeds — the
actual hit lands only visible on-device (TASKS 10.8), not something this
session drove itself (developer's standing instruction, D-050).

---

## D-052 — Boss bolt: 3-shot burst, bounces off the visible edge, +30% speed
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer's spec, verbatim: fire 3 in quick succession at the
player's current location instead of 1; the bolt can bounce off "the wall"
3 times; +30% bolt speed. This project has had no fixed arena wall since
D-040 (roaming world, no bounds) — read as the edge of
`camera.visibleWorldRect`, the existing stand-in for "off-screen"
everywhere else a projectile checks its own bounds in this codebase
(`ProjectileComponent._outOfBounds`, `KnifeProjectileComponent`,
`SpiralFireProjectileComponent`), not a literal wall that doesn't exist.
**Decision:**
1. **Burst, not a faster cooldown.** `BossComponent` gained
   `_burstShotsRemaining`/`_burstTimer`, checked first in `update()` (ahead
   of the walk/hold-and-fire branch, same precedence tier as the teleport
   check above it). `BossStats.fireCooldownSec` still gates the *whole*
   burst starting, not individual shots inside it —
   `BossStats.boltBurstIntervalSec` (0.12s) is the new, separate number for
   spacing between the 3 shots. Each shot re-aims fresh at
   `player.position - position` at the instant it actually fires, not the
   `toPlayer` vector captured once at the top of that frame's `update()` —
   "current location" means current at each shot, not current when the
   burst started.
2. **Bounce is a generic `ProjectileComponent` capability, not a
   boss-only fork.** `maxBounces` (default `0`, every existing call site
   unaffected) reflects the direction vector off whichever axis of
   `camera.visibleWorldRect` was crossed instead of despawning, clamping
   position back inside so a fast bolt can't re-trigger a second bounce
   next frame while still technically outside. Kept on the shared component
   (like `targetsPlayer`/`tint`/`excludeSelf` before it) rather than a new
   `BouncingProjectileComponent`, since nothing else about the boss's bolt
   differs from the base shape — one more optional param was simpler than
   a parallel class. `BossComponent._fire` passes
   `maxBounces: BossStats.boltBounceCount` (3); every other caller keeps
   the default (no behavior change for the Apprentice/Warden's bolt or
   Ultimate Mirror's).
3. **+30% speed is a straight multiply on the existing constant** —
   `BossStats.boltSpeedPxPerS` `220 * 1.3`, not a new number typed inline
   (CLAUDE.md §4.3).
**Because:** Both new boss-only numbers (burst interval, bounce count) live
on `BossStats` alongside the boss's other bolt constants — same file,
same reasoning as `boltDamage`/`boltKnockback` already being there, not a
new constants class. The burst-precedence placement (checked before the
walk/fire decision, same tier as the teleport check) means a player closing
to melee mid-burst still teleports the boss away correctly — the burst
doesn't have to know about teleporting, it just gets pre-empted by the
existing check the same way normal firing always was.
**Consequences:** A burst interrupted by a teleport (player rushes in
mid-burst) resumes from the boss's new position next frame rather than
being cancelled outright — not asked to cancel it, and cancelling would
need extra state to track "was this shot skipped," so left as the simpler
behavior. Bounced bolts can now stay alive well past
`BossStats.fireRangePx * 2`'s original travel budget (each bounce is a free
reset of position/direction, not distance) — `maxRangePx` is unchanged and
still the hard stop once `_traveled` catches up, so this can't accidentally
create an immortal bolt. `flutter analyze` clean, `flutter test` 85/85,
`flutter build apk --debug` succeeds — on-device feel (does the burst read
as 3 shots or a blur, does the bounce look intentional or glitchy off a
camera edge that's itself moving) is the developer's to check (CLAUDE.md
§2), not driven by this session.

---

## D-053 — Boss bolt lifetime/cap, and a shared "poof" despawn for every projectile
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer's spec: the boss's bolt should last 5 seconds
longer, cap at 9 of the boss's own bolts alive at once, and every
projectile in the game (not just the boss's — asked and confirmed via
`AskUserQuestion` rather than guessed, since it materially changed scope)
should despawn with a 100%→0% size shrink drifting downward — a "poof" —
instead of just vanishing.
**Decision:**
1. **+5s lifetime as extra distance, not a second despawn clock.**
   Nothing in this codebase despawns a projectile on a timer — every one
   (`ProjectileComponent`, the knife, Spiral Fire) despawns on distance
   traveled or leaving the screen. Added `BossStats.boltExtraLifetimeSec`
   (5.0) and a derived `BossStats.boltMaxRangePx` getter (`fireRangePx * 2
   + boltSpeedPxPerS * boltExtraLifetimeSec`) instead of a parallel
   time-based mechanism just for this one bolt — "5 seconds longer"
   converts cleanly to "however far it travels in 5 more seconds at its
   own (post-D-052) speed," reusing the existing distance model rather
   than adding a second one next to it.
2. **9-bolt cap is the boss's own bookkeeping, not `ProjectileComponent`'s.**
   `BossComponent._liveBolts` (a `List<ProjectileComponent>`) is pruned of
   anything no longer mounted, then checked, before each individual burst
   shot — a shot skipped for being over the cap still consumes its slot in
   the 3-shot burst (the burst always finishes on schedule, it just may
   fire fewer than 3 bolts onto an already-crowded screen), rather than
   stalling the whole burst waiting for room. `ProjectileComponent` itself
   needed no changes — `isMounted` (a plain Flame `Component` property) is
   already enough signal that an earlier bolt is gone, whether it hit
   something, ran out of range, or expired.
3. **`ProjectilePoofComponent` (`game/components/projectile_poof.dart`) is
   shared, not boss-only** — confirmed with the developer rather than
   assumed, since "every projectile" is a materially bigger change than
   "just the boss's bolt." Takes exactly one of `animation`/`sprite`
   (asserted) so it can shrink whatever the expiring projectile was
   actually showing — the bolt/Mirror/boss bolt and Spiral Fire pass their
   `SpriteAnimation`, the knife passes its current `Sprite` (clean or
   bloody, whichever it had drawn blood into by the time it left the
   screen) — rather than needing a second component class per visual type.
   Wired into the "expires without hitting anything" path only, in all
   three projectile classes (`ProjectileComponent._expire`,
   `KnifeProjectileComponent._expire`, `SpiralFireProjectileComponent
   ._expire`) — **not** the hit path, which already has its own feedback
   (`ArenaGame.onProjectileHit`'s spark + damage number, or Spiral Fire's
   impact/explosion flourish) and would just look cluttered with a poof
   layered on top. Carries over the expiring projectile's current `angle`
   too, so a spinning knife's poof doesn't snap to a flat orientation right
   before it shrinks away.
**Because:** All three follow the same rule this project already leans on
— reuse the existing mechanism (distance-based despawn, `isMounted` as the
liveness signal, the projectile's own current visual state) rather than
adding a parallel one, and ask rather than guess when a request's scope is
genuinely ambiguous (CLAUDE.md §6).
**Consequences:** `boltMaxRangePx` being a getter (not a `const`) is a
small, deliberate exception to this file's usual all-`const` `BossStats` —
it's derived from two other constants in the same class, and CLAUDE.md §4.3
asks for the formula to live in `core/`, not be duplicated at the
`BossComponent._fire` call site. `flutter analyze` clean, `flutter test`
85/85, `flutter build apk --debug` succeeds — on-device feel (does 9 bolts
read as "a lot" or "cluttered," does the poof read as intentional at 0.35s)
is the developer's to check (CLAUDE.md §2).

---

## D-054 — Death SFX moved to fire with the Round Over overlay, not on HP hitting 0
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer's spec: "make the death sound play as soon as the
dark overlay after you die appears." `ArenaGame.onPlayerDied()` was firing
`sfx-you-died.wav` immediately when HP hit 0 — under the ~0.6s death
animation (`_roundEndDelaySec`, PRD §6.5) and well before `_endRound()`
actually shows the dark `RoundOver` overlay.
**Decision:** The SFX call moved from `onPlayerDied()` into `_endRound()`,
gated by a new `_realDeath` bool (set only by `onPlayerDied()`, reset every
round) instead of the old `_roundEndDelay == null` guard — `debugDie()`
still never triggers it, same "a debug kill isn't a real death" rule as
before, just carried by an explicit flag instead of an incidental null
check.
**Because:** A dedicated bool reads directly as what it's for ("was this a
real death") rather than reusing a timer's null-ness as a stand-in signal
for it, which was only ever true by construction (both paths happened to
set `_roundEndDelay` around the same time) — worth making explicit now that
the SFX call is moving to a different method than the one that sets that
timer.
**Consequences:** `flutter analyze` clean. No test coverage needed (D-019 —
this is exactly the "does it feel right" category, not arithmetic that can
drift) — on-device confirmation the sound now lines up with the dark
overlay is the developer's to check.

---

## D-055 — Character unlocks, swipe-carousel select screen, chest economy
**Date:** 2026-09-09 · **Status:** Accepted
**Context:** Developer's spec, in one message, three related asks:
1. Real progression-gated character unlocking (TASKS 8.4 had explicitly
   flagged this as "ask before picking the unlock condition/mechanism,
   don't guess" — asked via `AskUserQuestion` rather than guessed this
   time) plus a "locked panel asset" for it.
2. The 2x2 character-select grid has all 4 characters idle-animating at
   once — "looks fucking silly" — fix via a swipe carousel bringing up one
   character and its stats at a time. (SHOP was also asked for as a
   "placeholder... completely empty, only back button" — already exists,
   shipped exactly that way in D-047; nothing to build.)
3. 12 chest sprites (`consumables/chest_01.png`..`chest_12.png`, delivered
   pre-session) need to spawn in the world, run an opening sequence
   ("anima + explosion before chest opens"), give gems, and those gems
   (plus the existing coin total) need to persist into a spendable wallet
   — with "a fancy chest opening pop-up and reveal of gems & gem count."
Three more real decisions were asked and confirmed rather than guessed
(`AskUserQuestion`, all three "Recommended" options chosen): the unlock
metric is **total lifetime kills** (not coins spent, rounds played, or
best single-round level); the carousel is a **full replacement** of the
grid, not a "freeze the unselected tiles" patch; chest gems become a
**separate persistent gem wallet**, not folded into the coin total.

**Decision, unlock logic:**
- `CharacterDef.unlockKillThreshold` (`int?`, `null` = always unlocked)
  replaces the old flat `unlocked: true` placeholder bool from D-028 —
  Apprentice `null`, Bruiser 50, Skirmisher 150, Warden 300 (steeper per
  slot, first-guess numbers like everything else in this project).
  `CharacterDef.isUnlockedFor(int lifetimeKills)` is the actual gate, unit
  tested (`test/data/characters_test.dart`).
- `MetaProgression`/`MetaProgressionRepository` gained `lifetimeKills` +
  `addLifetimeKills`, same read-modify-write shape as `addCoins` (D-047),
  called once from `ArenaGame._endRound` with that round's `kills`.
- The `bar-empty.png`/`bar-filling.png`/`star-empty.png`/`star-full.png`
  assets delivered alongside this ask turned out to already be exactly
  "the locked panel asset" — a progress bar (bar-empty background,
  bar-filling clipped to `lifetimeKills / threshold`) plus a star-empty
  badge, both read directly off existing files with no new art needed.

**Decision, character select redesign:**
- `CharacterSelectScreen` rewritten around a `PageView.builder` — one
  `_CharacterPage` per `CharacterDef`, swipe left/right, a `_PageDots` row
  replacing the grid's implicit "which tile is selected" readout. Only the
  current page's portrait is ever animating, which is what actually answers
  "looks silly" — not a new animation mechanism, just one on screen instead
  of four.
- A locked page's `_CharacterPage` still shows real stats (not hidden) —
  dimmed to 35% opacity instead — with `_LockedPanel` (the bar/star combo
  above) in place of the `ENTER ARENA` button. Wallet readout
  (`_WalletRow`) now shows gems next to coins (`star-full.png` icon, the
  filled/complete half of the same star pair used for the locked badge).
- Wallet + SHOP/UPGRADES stay pinned above the carousel, outside the
  `PageView`, unaffected by swiping — `ShopScreen` itself needed no
  changes (already the literal "empty, back button only" placeholder
  D-047 asked for).

**Decision, chest economy:**
- `game/anim/sheet_loader.dart` gained `loadFileSequenceAnimation` — a
  fourth loader alongside `loadSheetAnimation`/`loadColumnAnimation`, for
  the one case neither fits: 12 *separate whole-image files* forming one
  animation, not cells sliced out of a single sheet.
- `ChestComponent` (`game/components/chest.dart`) sits closed
  (`chest_01.png` alone, looping as a 1-frame "animation") until the player
  walks within `kChestPickupRadiusPx`, then runs a fixed beat: `ArenaGame.
  animaAnimation` first, `ArenaGame.spawnExplosionEffect` (and its SFX, for
  free) `_explosionDelaySec` (0.35s) later, swapping to the real
  `chest_01`-`chest_12` opening sequence at the same moment — "anima +
  explosion before chest opens," read as a 1-2-3 beat rather than everything
  landing on one frame. `ChestSpawner` is `PotionSpawner` (D-043) with the
  serial numbers changed — same random-point-in-a-view-sized-rect shape,
  rarer interval (40s vs. 15s) and lower live cap (2 vs. 5), since a chest
  is a bigger, rarer payout than a potion.
- Gems from a chest (`rollChestGems` — 3-6 independent `rollRarity` rolls,
  `core/economy.dart`, same weighted scale every other drop already uses)
  fold into the exact same round-scoped `ArenaGame.gemsCollected` Round
  Over already displays — chests and enemy drops aren't tracked
  separately, matching how coins already work (one total, multiple
  sources). `MetaProgressionRepository.addGems` credits that whole round
  total into the new persistent wallet at `_endRound`, same call site as
  `addCoins`/`addLifetimeKills`.
- **ChestReveal** is a 4th Flame overlay, same shape as `LevelUp`/
  `PauseMenu`/`RoundOver` (registered in `ArenaScreen`'s
  `overlayBuilderMap` — CLAUDE.md §4.2's registration-order rule) — the
  "fancy popup" ask, genuinely pausing the round rather than a floating
  text. `ArenaGame._afterMenuClosed()` generalizes the level-up chaining
  logic (D-025's `_pendingLevelUps` gate) into a 3-way priority: a pending
  level-up first, then a pending chest reveal, only then does the round
  actually resume — so a chest finishing its open sequence while the Pause
  Menu or a level-up popup already owns the screen doesn't fight either
  for it, it just waits its turn.
**Because:** Every mechanism reuses a shape this project already has —
`PotionSpawner`'s random-drop pattern for `ChestSpawner`, `addCoins`'s
read-modify-write shape for `addGems`/`addLifetimeKills`, `LevelUp`'s
overlay-plus-pending-queue shape for `ChestReveal`, `rollRarity`'s shared
weighted scale for chest gems — rather than inventing a parallel one for
each new feature, consistent with this file's own running theme. The three
real open decisions (unlock metric, carousel scope, gem-wallet-vs-coins)
were asked rather than guessed, per CLAUDE.md §6 and TASKS 8.4's own
standing instruction on the unlock question specifically.
**Consequences:** All numeric first-guesses (kill thresholds, chest
spawn interval/cap, gem count range, explosion-delay beat timing) are
placeholders like every other tuning value in this project — a real
balance pass needs on-device time. `CharacterDef.unlocked` no longer
exists as a field (superseded by `unlockKillThreshold`/`isUnlockedFor`) —
any future code reaching for `.unlocked` needs updating to the new
mechanism, there's no compatibility shim. `flutter analyze` clean,
`flutter test` 92/92 (7 new: `characters_test.dart`'s 4, `economy_test.
dart`'s 3 `rollChestGems` cases), `flutter build apk --debug` succeeds.
On-device verification (the whole feature is genuinely untested past the
build/widget-test line — D-019 stops automated coverage at Character
Select, and this session was also asked to stop driving the emulator
itself, D-050) is the developer's to run.

---

## D-056 — Warden's own kit: melee AoE "Ground Slam", no new art

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** TASKS 8.3's last open sub-item — the Warden had been sharing
`ProjectileAttack` as a placeholder since D-028, flagged again as the one
real remaining code task in this session's "what's next" survey. Developer
asked to start it "with what assets we have already" — no new sprites, no
new VFX sheets.

**Decision:** `WardenSlamAttack` (`game/attack_behavior.dart`) — not a
projectile at all, unlike every other kit. A short-range AoE burst centered
on the player: `allWithinRange` (the same targeting helper `AuraComponent`'s
tick already uses) finds every `Damageable` inside `attackRangePx * 0.35`,
each one takes damage and gets knocked radially outward from the player.
Visual is entirely existing assets — `fire` (already loaded for every
character via `CharacterAnimations`, D-024, since `fourth-fire.png` was
already part of the Warden's original sheet delivery, D-028) for the swing,
and `gameAssets.explosionAnimation` (`vfx/vfx/effect_explosion2.png`,
already loaded for the Skirmisher's kill flourish, D-034) for the shockwave
— sized to `radiusPx * 2` directly rather than a new fixed-width constant,
so the VFX can't drift out of sync with the actual hitbox (same reasoning
`AuraComponent` already uses for its own ring).

Tuning multipliers on top of the shared per-hit formula, same "own
multiplier on the shared base" pattern `KnifeAttack`/`SpiralFireAttack`
already use: -35% range (melee, not ranged — this is the actual
differentiator), -25% attack speed (tankier: hits less often), -15% damage
per hit (offsetting it landing on every target in the radius per swing
instead of just the nearest one), +50% knockback (the "shove a cluster
back" flavor a VIT-heavy tank should have). All first-guess numbers, same as
every other kit's tuning — expect a follow-up pass once it's seen on-device.

**Because:** Fits the Warden's stat line (`kCharacters`: 9 VIT, the highest
in the roster) without needing a design pass on brand-new art mid-session.
Reusing `allWithinRange` and `spawnEffect` rather than adding new machinery
keeps this consistent with how Aura's own AoE already works, and closes the
last CLAUDE.md §4.12 placeholder — every character now has a distinct
`AttackBehavior`, no more shared `ProjectileAttack()` fallback.

**Consequences:** No new `core/` gameplay math (the AoE loop is
component-level, same category as the Bruiser's pierce, D-029) — no new
unit tests needed, same reasoning D-029/D-034 already used for their own
kits. `flutter analyze` clean, `flutter test` 92/92 (unchanged — no new
tests), `flutter build apk --debug` succeeds. On-device feel (does the swing
read right, does the explosion VFX actually line up with the real hit
radius, does the slower cadence feel intentional rather than just weaker)
is the developer's to check, same standing rule as every other on-device
item since D-050.

---

## D-057 — Debug end-round button, and chests pay out via a playing-card draw

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** Developer's spec, one message, two asks: (1) "Create a end
round debug button make sure it takes the points/kills/score etc." and (2)
replace the chest reveal's gem-rarity payout with the newly-delivered
`assets/images/cards` deck (4 suits x 13 ranks + 2 Jokers + card backs) —
"add them instead of the reward when we open chests... make them change
really fast randomly, stop on one at the end, make each of them reward a
specific amount depending on the card."

**Decision, debug end-round:**
- `ArenaGame.debugEndRound()` is a thin wrapper over the existing
  `debugDie()` — both just set `_roundEndDelay = 0`, which `update()`
  already reads to call `_endRound()`. No new round-ending machinery: the
  existing `_endRound()` unconditionally banks `coinsEarned`/
  `gemsCollected`/`kills` into the persistent wallet regardless of how the
  round ended (real death or debug), so reusing that exact path is what
  makes "carries the points/kills/score" true, rather than something to
  re-verify by hand.
- Placed in Settings' DEBUG section (reached via the Pause Menu), not as a
  second always-on-screen button next to the existing DIE (debug) one — the
  existing "queued, plays out once you close the pause menu" shape
  `debugGrantLevelUp` already uses fits it exactly: `debugEndRound()` is
  called while the engine may still be paused (Settings doesn't resume it),
  so `update()` — and therefore `_endRound()` — genuinely can't fire until
  the player actually backs out and closes the pause menu.

**Decision, chest cards:**
- `core/economy.dart`: `kChestDeck` is a real 54-card deck built once
  (`ChestCard(assetPath, label, gemReward)` per entry) — 4 suits x 13 ranks
  from `kCardRanks`/`CardSuit`, plus the 2 Jokers. `rollChestCard(Random)`
  draws one uniformly. Drawing uniformly from a real deck gives the reward
  its odds for free (a Joker: 2/54 ≈ 3.7%, an Ace: 4/54 ≈ 7.4%, any given
  number card: 4/54) — no separate weight table needed the way
  `kRarityWeights` has one for the gem/coin/potion economy.
- Reward table (`kCardRankGemValue`, first-guess placeholder like every
  other number in this project): number cards pay face value (2-10),
  Jack/Queen/King step up (15/20/25), Ace is the best non-Joker card (35);
  `kJokerGemValue` (75) is the jackpot, on the deck's rarest draw. Suit is
  purely cosmetic — value is keyed on rank alone.
- `ChestComponent._finishOpening` now calls `rollChestCard` instead of
  `rollChestGems` and hands the single `ChestCard` to
  `ArenaGame.onChestOpened`, which credits `card.gemReward` into
  `gemsCollected` immediately, same "banked the moment the chest finishes
  opening, revealed after" ordering D-055 already used. The reveal overlay
  is purely cosmetic playback of an already-decided result — the spin never
  has a chance to land on anything but the pre-rolled card, so there's no
  risk of the animation and the actual payout disagreeing.
- `_ChestRevealOverlay` (`arena_screen.dart`) is now a `StatefulWidget`: 22
  flicker steps through a random `kChestDeck` card each, `Timer`-driven,
  per-step delay ramping 45ms → 260ms (`_minStepMs`/`_maxStepMs`, an
  ease-out quadratic) so it reads as a slot-reel genuinely decelerating into
  its stop rather than just cutting off — "change really fast randomly,
  stop on one at the end," the developer's literal spec. The real card is
  never shown until the very last step. CONTINUE is disabled
  (`onPressed: null`) until the spin finishes, so the popup can't be
  dismissed before the payout is actually visible.
- `pubspec.yaml` gained one `assets/` entry per suit folder plus `Joker/`
  and `Back Cards/` (the literal folder name, space included — Flutter's
  asset declarations handle it fine) — `Back Cards/` isn't actually used by
  the reveal (cards render face-up throughout, no flip), declared anyway
  since it shipped with the rest and costs nothing idle.

**Because:** Reusing `debugDie()`'s exact path for the new button is the
only way "make sure it takes the points/kills/score" is actually
guaranteed rather than asserted — new code duplicating that bookkeeping
would be a second place for it to drift out of sync with a real death. A
real deck (vs. inventing a new N-tier reward table) gives natural,
legible odds for free and reuses art delivered specifically for this.

**Consequences:** `rollChestGems`/`kChestMinGems`/`kChestMaxGems` are gone
— chests no longer roll a *group* of gems, they roll one card. Any future
code wanting chest odds/payouts reaches for `kChestDeck`/`rollChestCard`,
not the old function. `flutter analyze` clean, `flutter test` 95/95 (3 new,
replacing the 3 old `rollChestGems` cases — `economy_test.dart`'s
`kChestDeck`/`rollChestCard` groups), `flutter build apk --debug` succeeds.
On-device verification (does the debug button actually end the round with
correct numbers, does the spin read as intentional and not just chaotic
flicker, does the final card match the payout) is the developer's to run,
same standing rule since D-050.

---

## D-058 — Chest reveal: fixed an overflow, added a shuffle lead-in and a landing bounce

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** Feedback on D-057's chest reveal, three related asks: (1) a
real layout bug — "when the chest opened, it says bottom overflowed by 4.0
pixels"; (2) "make card, when draw is finished, do a jump and land
animation"; (3) "add another animation before the current one, that goes
between back cards, and after that transition to this one."

**Decision:**
- **Overflow (bug, not a tune):** `_ChestRevealOverlay`'s `Center(child:
  Padding(child: Column(...)))` had no scroll fallback — on a short enough
  viewport the fixed-height reward slot pushed the total past the available
  height. Wrapped in `SingleChildScrollView` (`Center(child:
  SingleChildScrollView(...))`, same idiom `_CharacterPage` already uses) —
  centers normally whenever it fits, scrolls instead of overflowing when it
  doesn't, on any screen size.
- **Shuffle lead-in:** a new phase before the existing spin — `_shuffling`,
  flickering through the 2 card backs (`assets/images/cards/Back Cards/`)
  at a flat 70ms rate for 8 steps (no ease-out; it's a lead-in beat, not the
  landing), then flips to the existing face-card spin logic unchanged —
  "transition to this one" is simply continuing straight into the spin that
  already existed, not a new second mechanism.
- **Jump/land:** an `AnimationController` (`_landController`,
  `SingleTickerProviderStateMixin`) fires once the spin's last step lands on
  the real card — a `TweenSequence` hopping up (`0 → -22px`, `Curves.
  easeOut`, 35% of the 520ms duration) then bouncing back down (`-22 → 0`,
  `Curves.bounceOut`, the remaining 65%), applied via `Transform.translate`
  around the card image. Asymmetric on purpose — a jump that eases out but
  bounces on the way down reads as landing; a symmetric tween wouldn't.
- `_ChestCardFace` renamed `_PlayingCardImage` and now takes a raw
  `assetPath` `String` instead of a `ChestCard`, so the same widget renders
  both the shuffle phase's backs and the spin phase's faces.

**Because:** The overflow is a real bug regardless of screen size — fixing
it with a scroll fallback is more robust than trimming padding/font sizes to
fit one specific device. The shuffle-then-spin sequencing and the landing
bounce are both purely additive to the existing state machine (`_shuffling`
gates before `_spinning` already did, the landing animation fires off the
existing "spin just finished" `setState`) — no change to the actual roll
(`ArenaGame.pendingChestCard`) or payout logic from D-057.

**Consequences:** `flutter analyze` clean, `flutter test` 95/95 (unchanged
— this is all UI/animation, no new `core/` logic), `flutter build apk
--debug` succeeds. On-device verification (does the shuffle read as a
distinct lead-in and not just more flicker, does the jump/land actually
read as landing rather than a jitter, is the overflow actually gone on the
real device/AVD it was reported on) is the developer's to run.

---

## D-059 — Debug currency tools, gem drop -25%, gem float, boss anima -40%, aura -25%/-20% bright, mirror desync + axis + immortal bolts

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** Six unrelated tuning/feature asks in one message, batched here
rather than split into six decisions since none is individually more than a
couple of lines: (4) "add more useful debug in main menu settings that can
affect currency as well"; (5) "reduce by 25% the amount of gems that drop";
(6) "add gems float animation, make it like the potion one"; (7) "make the
anima effect less in size by 40% on the boss when he teleports"; (8) "make
aura shield 25% smaller, less bright by 20%"; (9) "make magic mirrors spawn
not in sync, by 0.5 seconds delay, and can also spawn shooting from up to
down"; (10) "make magic mirrors projectile not expire and not despawn."

**Decision:**
- **Currency debug (4):** `MetaProgressionRepository` gained
  `debugAdjustCoins`/`debugAdjustGems` (any delta including negative,
  clamped at 0 — unlike `addCoins`/`addGems`, which ignore non-positive
  amounts since those exist for round-over credits) and `debugResetWallet`
  (zeroes coins/gems only — `lifetimeKills` and the bought MetaStat levels
  are progress, not currency, and stay untouched). `SettingsScreen` now
  loads a `MetaProgression` unconditionally (not gated on
  `SettingsScreenArgs.debugGame`) and shows a DEBUG section with the
  current coins/gems plus ±100 coins/±50 gems/reset buttons from **either**
  entry point — main menu Settings (no live `ArenaGame`) or the arena's
  Pause Menu. The existing `ArenaGame`-only debug tools (god mode, grant
  level up, end round) still require `debugGame != null` and now render
  under the same DEBUG header instead of a second one.
- **Gem drop -25% (5):** `kGemBaseDropChance`/`kGemDropChancePerLevel`
  (`core/economy.dart`) each multiplied by 0.75 on top of D-046's existing
  -80% tune (0.16→0.12, 0.002→0.0015).
- **Gem float (6):** `GemComponent` gained the exact same sine-bob
  `PotionComponent` already has. The two constants driving it
  (`kPotionFloatAmplitudePx`/`kPotionFloatPeriodSec`) are renamed
  `kItemFloatAmplitudePx`/`kItemFloatPeriodSec` and now shared by both,
  rather than a second identical pair — "make it like the potion one" is
  literal reuse, not a lookalike.
- **Boss anima -40% (7):** new `kBossAnimaWidthPx = kAnimaWidthPx * 0.6`
  (`core/constants.dart`), used at both `BossComponent._teleportAwayFrom`
  call sites (departure and arrival — "when he teleports" covers the whole
  teleport). `kAnimaWidthPx` itself is untouched since `ChestComponent`
  also plays `effect_anima` for its own opening beat and wasn't asked to
  change — a shared constant would have shrunk the chest's flourish too.
- **Aura -25%/-20% bright (8):** `UpgradeAmounts.auraRadiusPx`
  (`core/progression.dart`) *0.75 (85→63.75) — this is the shield's damage
  radius too, not just its render size (`AuraComponent` sizes its visual to
  it exactly by design, D-027), so the hitbox shrinks along with the art,
  deliberately. `AuraComponent` gained a `_brightness = 0.8` constant,
  folded into the existing contrast color matrix as a single combined
  `_colorMatrix(contrast, brightness)` (`Paint.colorFilter` can only hold
  one matrix, so this composes both effects into one rather than trying to
  chain two) — brightness is a flat post-contrast multiply, a different
  knob than contrast's pull-toward-grey.
- **Mirror desync (9a):** `MirrorComponent` gained a `staggerDelaySec`
  constructor param, added once to its initial `_phaseTimer` — since every
  mirror runs identical active/cooldown durations, one one-time offset per
  spawn order keeps them permanently out of phase, not just staggered at
  the start. New `UpgradeAmounts.mirrorStaggerDelaySec = 0.5`;
  `ArenaGame._syncMirrors` passes `_mirrors.length *
  mirrorStaggerDelaySec` to each newly spawned one.
- **Mirror fire axis (9b):** `MirrorComponent` gained `_horizontalAxis`
  (bool), rolled randomly at spawn and re-rolled every time it reactivates
  (`randomVisiblePoint` re-teleport branch) — `_fire()` picks
  `[Vector2(1,0), Vector2(-1,0)]` or `[Vector2(0,1), Vector2(0,-1)]`
  depending on it, instead of always the horizontal pair.
- **Mirror bolts never expire (10):** `ProjectileComponent` gained
  `neverExpire` (bool, default `false`) — when set, `update()` skips both
  the `maxRangePx` and `_outOfBounds`/bounce checks entirely, so the
  projectile only ever ends via actually hitting something. `MirrorComponent._fire`
  is the only caller passing `true`; every other projectile in the project
  (Apprentice/Warden bolt, boss bolt, knife, spiral fire) is unaffected.

**Because:** Currency debug tools that only exist behind a live `ArenaGame`
can't help test the character-unlock/wallet flow *before* a round even
starts, which is exactly where "does the right character unlock" needs
checking — main-menu reachability was the actual ask, not a nice-to-have.
Reusing the potion's float constants for gems (rather than a parallel
identical pair) and reusing `ProjectileComponent`'s existing despawn
checks (rather than a Mirror-specific projectile subclass) both keep this
project's "one shared mechanism, not a lookalike per caller" pattern intact
the same way D-052/D-053's bounce/poof work already did.

**Consequences:** Mirror bolts that never expire are a deliberate, scoped
exception to this project's "no unbounded per-frame growth" instinct
(CLAUDE.md §4.4) — they still can't accumulate indefinitely since
`resetRound()` clears the whole world every round, but *within* a long
round, enough active mirrors firing long enough could leave a growing
number of bolts alive simultaneously (each one only removed by actually
hitting something) — worth watching on-device if a very long round ever
gets played through. `flutter analyze` clean, `flutter test` 95/95
(unchanged — every change here is a tuning constant or component-level
behavior, no new `core/` formula), `flutter build apk --debug` succeeds.
On-device verification (does the currency debug UI actually work from both
entry points, do gems now visibly bob, does the boss's teleport flourish
read smaller without looking wrong, does the aura ring read smaller/dimmer
without disappearing, do multiple mirrors visibly desync and sometimes fire
vertically, do mirror bolts really never poof) is the developer's to run.

---

## D-060 — Chest reveal: the *real* overflow; boss teleport reworked into a telegraphed, delayed, longer jump

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** Two reports. (1) "Still occurs 'BOTTOM OVERFLOWED BY 4.0
PIXELS'" — D-058's `SingleChildScrollView` fix didn't actually touch the
real cause. (2) A full rework of the boss's D-042/D-052 teleport: "make
boss anima appear only where he will teleport 0.5 seconds before, so
automatically make him teleport with a delay," "add a boss animation when
he teleports, he must size down and size up where he appears," and "make
boss teleport a longer distance."

**Decision, the overflow (bug, not a re-tune):**
- The actual `RenderFlex` overflowing was never the outer `Column` D-058's
  scroll wrapper targeted — it was the *inner* one, a fixed
  `SizedBox(height: 46)` clipping a 2-line reward text (label + "+N gems")
  that's a few pixels taller than 46px once real font line-height is
  accounted for. The outer scroll fix was real and stays (protects against
  a short *screen*), but it can't fix a *hard-clipped fixed-height child*
  further down the same tree — two independent overflow sources, only one
  of which D-058 actually addressed.
- Fixed by replacing the fixed height with `ConstrainedBox(constraints:
  BoxConstraints(minHeight: 46))` — a minimum can only make the box grow to
  fit real content, never clip it, so it can't overflow again regardless of
  future copy/font changes. `Center` keeps the "..." placeholder vertically
  centered at that minimum height exactly as before.

**Decision, boss teleport rework (supersedes D-042's instant version):**
- `BossComponent._beginTeleport` computes the destination up front (mirror
  point across the player, `BossStats.teleportDistanceMultiplier` = 1.6
  past it — the "longer distance" ask) and plays `effect_anima` **there**
  immediately, not at the boss's current position the way D-042 did —
  "appear only where he will teleport."
  `_teleportPending`/`_teleportDelayTimer` (`BossStats.teleportDelaySec` =
  0.5) then freeze the boss entirely (no walk/fire/contact damage,
  `current = BossAnim.idle`) for that half-second before
  `_completeTeleport` actually repositions it — "automatically... with a
  delay," a committed wind-up the player can see coming but the boss can't
  be baited out of once it starts.
- On arrival, `_completeTeleport` starts a `_popScale` bounce — a sine dip
  (`1 - sin(t·π) · 0.4` over 0.28s) that starts and ends at 1 and bottoms
  out at 60% size at its midpoint, ticked every frame by `_tickTeleportPop`
  — "size down and size up where he appears." Since `BossComponent` already
  used `scale.x` for horizontal facing (±1, D-042), facing was pulled out
  into its own `_facingSign` field so the two can't stomp each other;
  `scale.setValues(_facingSign * _popScale, _popScale)` combines them once
  per frame instead.

**Because:** A `minHeight` constraint is the correct fix for "content that
might be taller than my placeholder guess" — a fixed height is only ever
safe when the content's exact size is actually known, which two lines of
real rendered text never reliably are across font/locale/accessibility
settings. The teleport rework keeps every existing mechanic (mirror-point
math, `effect_anima`, `ArenaGame.spawnEffect`) and only changes *when* and
*where* they fire, rather than introducing a parallel teleport system.

**Consequences:** `BossComponent._teleportAwayFrom` (D-042) is gone,
replaced by `_beginTeleport`/`_completeTeleport`. The boss is now
uninterruptible-but-freezeable for `teleportDelaySec` once a teleport
starts — still damageable/knockback-able during the wind-up (neither is
gated on `_teleportPending`), just AI-frozen. `flutter analyze` clean,
`flutter test` 95/95 (unchanged — no new `core/` formula, both changes are
UI layout and component-level behavior), `flutter build apk --debug`
succeeds. On-device verification (does the overflow warning actually stop
appearing now, does the destination telegraph read as a clear warning
before the boss arrives, does the freeze read as intentional wind-up rather
than a bug/hang, does the size-down-then-up bounce read as landing, does
the longer jump distance feel meaningfully different from the old exact
mirror point) is the developer's to run.

---

## D-061 — Chest reveal confetti, and every projectile despawns further off-screen

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** Two asks. (1) "Throw some confetti from outside the screen,
from left and right, landing in front and in the back of the card when we
land it." (2) "Make all projectiles shot by character in general despawn
when way out outside of screen, for example right now knifes spawn [the
poof] right when they hit the outside border" — a real visual bug across
every projectile type, not knife-specific despite the example.

**Decision, confetti:** `_ChestRevealOverlayState` (now
`TickerProviderStateMixin`, plural — a second `AnimationController`
alongside the existing landing-bounce one needs its own ticker) gained a
`_confettiController` started the instant the spin lands, same moment as
the jump/land bounce. ~26 `_ConfettiParticle`s (color/size/rotation/arc,
generated once in `initState`) are painted by two `_ConfettiLayer`
(`CustomPainter`)s sandwiching the actual card/text content in a `Stack` —
one painted before it (`front: false`, lands behind the card) and one after
(`front: true`, lands in front) — rather than one layer with z-order
baked into per-particle draw order, since Flutter's paint order is
determined by widget tree position, not a z-index property. Each particle's
`startAlign` uses an `Alignment` x beyond ±1 (`Alignment` resolves values
past the unit box to positions genuinely outside it) so half start
off-screen left, half off-screen right, arcing (`sin(π·flightT)`) toward a
scattered landing point near the card, easing out via `Curves.easeOut` over
the first 60% of the controller, then fading over the last 30%. No new
package (CLAUDE.md §4.9 — the intended dependency set is `flame`/
`flame_audio`/`shared_preferences` and nothing else) and no new art —
plain rotated rectangles drawn straight to the canvas are enough for a
one-shot decorative burst. Both confetti layers sit outside the existing
`SingleChildScrollView` (in the overlay's own `Stack`, not inside the
scrollable content `Column`) since particles starting genuinely off-screen
would otherwise get clipped by the scroll view's own viewport — and both
are wrapped in `IgnorePointer` so a layer painted on top of the CONTINUE
button can never swallow its taps.

**Decision, projectile despawn margin:** every projectile's zero-bounce
despawn check now waits until it's cleared the visible edge by
`size.x * kProjectileDespawnMarginFactor` (new constant, `1.0` — a full
extra sprite-width of clearance), not just until its center crosses the
bare edge:
- `ProjectileComponent` (the shared bolt — Apprentice/Warden/Ultimate
  Mirror/boss): split the single `_outOfBounds()` check into two. The bare
  edge (`_outOfBounds`) still triggers a bounce for anything with
  `maxBounces` left (DECISIONS D-052 — that edge genuinely is "the wall" a
  bolt bounces off, unchanged and not the reported problem); once bounces
  are exhausted, the new `_farOutOfBounds()` (margin-inflated) is what the
  actual `_expire()` waits for instead — the bolt just keeps flying
  straight in the meantime.
- `KnifeProjectileComponent`: has no bounce concept at all (D-030), so its
  one `_outOfBounds()` check is inflated by the margin directly.
- `SpiralFireProjectileComponent`: already inflated its bounds check by
  `_orbitRadiusPx` for an unrelated reason (D-038/D-039's wobble-near-edge
  fix) — the new margin is added on top of that existing one, not in place
  of it.

**Because:** A confetti *package* would be the first new dependency this
project has ever taken on for something a `CustomPainter` handles in ~50
lines — not worth the precedent. Splitting the bounce-trigger check from
the actual-despawn check (rather than just inflating the one existing
`_outOfBounds()` everywhere) preserves D-052's already-correct,
already-approved bounce-off-the-edge look for boss/mirror bolts exactly as
it was; only the *final* despawn, which had no complaint filed against the
bounce path, needed the extra margin.

**Consequences:** `flutter analyze` clean, `flutter test` 95/95 (unchanged
— confetti is pure UI/animation, the despawn margin is a component-level
distance check, neither is `core/` formula territory), `flutter build apk
--debug` succeeds. On-device verification (does the confetti actually read
as coming from off-screen and landing convincingly in front of/behind the
card, does every projectile type — bolt, knife, spiral fire, mirror bolt —
now visibly clear the screen before it poofs instead of vanishing mid-edge)
is the developer's to run.

---

## D-062 — Layered, beat-synced background music (2/3/1/4.wav)

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** Developer delivered 4 music tracks
(`assets/audio/core/1..4.wav`), all authored at 162 BPM and (near enough)
identical loop length, meant to stack rather than swap: "2.wav as the main
BGM playing everywhere while not in CORE (fighting mobs)," "3.wav... plays
alongside 2.wav once we enter core, but at 25% less volume," "1.wav starts
playing fading in with 35% less volume... when a boss spawns," "4.wav
starts playing when you die." The explicit, repeated emphasis: "when
another one starts playing over another, [it] must start at the next cue
loop point of the one that's playing already... very important otherwise
they wont be in sync," and every new layer "must fade it in from 0%-100%
... over like 2-3 seconds." Also asked: "compress sounds if needed into
mp3."

**Decision, architecture:** `BgmController` (`core/bgm_controller.dart`) —
a process-wide singleton, not tied to any screen or `ArenaGame` instance,
since the base layer has to keep playing across every menu and survive
`ArenaGame` being torn down/rebuilt between rounds (same "outlives any one
screen" category as `Settings`/`MetaProgression`, not round state per
CLAUDE.md §4.5). Uses `AudioPlayer` from `package:flame_audio/flame_audio.
dart`'s own re-export of `audioplayers` — not a new dependency (`flame_
audio` already depends on it and re-exports it wholesale); `FlameAudio`'s
own `loop`/`bgm` helpers only ever manage one track, not several
independently-faded layers stacked at once, so this manages its own
`AudioPlayer` per layer instead.

**Decision, sync:** every new layer is started via `_startSyncedLayer`,
which first awaits `_waitForBaseLoopBoundary()` — reads the permanent base
layer's `getDuration()`/`getCurrentPosition()` and delays by exactly
`duration - position` before calling `FlameAudio.loop` on the new track.
Since every track shares the same tempo and loop length, starting any new
layer at the instant the base layer wraps back to its own position 0 keeps
every layer in phase with every other from that point on, not just
approximately in time — the base layer (`2.wav`) is always the sync
reference, never any other layer, so there's one clock, not a chain of
relative offsets that could compound error.

**Decision, fades:** `_fadeVolume`/`_fadeOutAndStop` step a layer's volume
in 25 increments over 2.5s (`_fadeDuration`) via repeated `setVolume` calls
on a `Future.delayed` loop — a plain Dart singleton outside the widget
tree has no `vsync`/`AnimationController` to reach for, so this is the
equivalent for audio. Every layer fades in on start; fade-out (not
explicitly asked for, but an abrupt cut against everything else being a
smooth crossfade would be the odd one out, developer's-intent-consistent
call) uses the same shape in reverse. A `generation` counter per layer
slot lets a fade started by an old start/stop call detect it's been
superseded and bail out quietly, so rapid enter/leave-core or repeated
boss spawns can't leave two fades fighting over one slot's volume.

**Decision, relative volumes:** `_coreRelativeVolume = 0.75` (3.wav, "25%
less"), `_bossRelativeVolume = 0.65` (1.wav, "35% less"),
`_deathRelativeVolume = 1.0` (4.wav — no relative number was given for it,
full/reference volume assumed). All three multiply `Settings.musicVolume`
(the existing, previously-unwired 0-100 slider) the same way `_playSfx`
already multiplies `Settings.sfxVolume` for SFX — `setMasterVolume` is
called once at app boot (`ArenaApp`'s new `initState`, which is what
actually calls `BgmController.instance.start()`) and again live from
`SettingsScreen._update` whenever the slider moves, since a looping BGM
stack (unlike a one-shot SFX) needs to react while it's already playing,
not just on the next track that happens to start.

**Decision, triggers (judgment calls where the spec didn't say):** the
spec didn't say what stops the boss layer or the death layer, so:
`ArenaGame.onBossKilled` calls `bossCleared()` (fades `1.wav` out — a boss
theme shouldn't outlive the boss); leaving the arena via either MAIN MENU
button (Round Over's or the Pause Menu's) calls `leaveArena()` (fades
core/boss/death all back down to just the base layer, "2.wav... playing
everywhere"). `ArenaGame._endRound` itself also calls `died()` (real death)
or `leaveArena()` (any other round end, e.g. the debug END ROUND button) —
the Pause Menu's MAIN MENU button is the one real "leave Core" path
`_endRound` never sees at all (quitting mid-round without the round ever
actually ending), so both call sites exist and both are idempotent against
each other (a second `leaveArena()` on an already-`null` player is a
no-op).

**Decision, mp3 compression — explicitly NOT done:** the developer asked
to "compress sounds if needed into mp3." Judgment call: **not done**, for
a real technical reason, not laziness — MP3 is a lossy, frame-based format
with encoder delay/padding at the start of the file (the LAME/Xing gap);
whether a decoder strips that gap correctly for genuinely sample-accurate
looping varies by platform and player stack, and this entire feature's
one hard requirement, stated twice, is that the loop boundary be *exact*
("very important otherwise they wont be in sync"). Trading that
correctness for a smaller APK on 4 files totaling ~8MB reads as the wrong
trade here. The 4 tracks stay lossless WAV. Flagged back to the developer
rather than silently doing either extreme (compressing and risking the
one thing that mattered most, or silently ignoring an explicit ask) — if
this is still wanted despite the risk, worth actually testing on-device
before committing to it, not assuming the tradeoff either way from a build
machine.

**Because:** A background-audio decision (sync/fade/layering) belongs
outside the widget tree and outside `ArenaGame`'s round-scoped state for
the same reason `Settings`/`MetaProgression` do — none of screens/rounds
own the app's actual lifetime, and BGM has to outlive all of them. Reusing
`flame_audio`'s own re-exported `AudioPlayer` keeps this at zero new
dependencies while still getting the low-level per-layer control
`FlameAudio.loop`'s single-track model doesn't offer.

**Consequences:** `flutter analyze` clean, `flutter test` 95/95 (unchanged
— this is audio/timing plumbing, not `core/` gameplay formula territory),
`flutter build apk --debug` succeeds. On-device verification (does the
whole stack actually stay in phase after several boss spawns/clears over
a long round — the one thing that can't be verified without real device
audio output — does the crossfade actually sound smooth at 2-3s, does
Settings' Music Volume slider affect it live) is the developer's to run;
this is also the first time this project's BGM has ever been wired to
anything at all, so it's genuinely untested past the build line.

---

## D-063 — Confetti: independent per-piece timing, falls off-screen instead of stopping mid-air

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** Follow-up on D-061's confetti: "shoot the confetti pieces
independently, and make them fall more outside of the screen, because
they stop in the middle now."

**Decision:** Two changes to `_ConfettiPainter`/`_buildConfetti`
(`arena_screen.dart`):
- **Independent timing:** each `_ConfettiParticle` gained
  `startDelayFraction` (random, 0-35% of the burst's total duration).
  `_ConfettiPainter.paint` now computes a *local* timeline per particle
  (`[startDelayFraction, 1]` of the shared controller remapped to
  `[0, 1]`) instead of every particle sharing one global flight fraction —
  pieces launch, arc, and spin on their own individual clocks within the
  shared burst, not all in lockstep.
- **Falls off-screen, doesn't stop:** `endAlign` used to land close to the
  card (roughly ±0.4 `Alignment` units) — every piece visibly came to
  rest and hung there, which read as "stop in the middle." `endAlign` is
  now well outside the visible box on both axes (`dy` up to `2.4`, more
  than a full screen-height past the bottom edge) — a piece's animation
  now ends by actually leaving the screen, same as real confetti falling
  away, not settling inside it. The flight curve changed from
  `Curves.easeOut` (decelerates into a stop — exactly the wrong shape for
  "keeps falling") to `Curves.easeIn` (accelerates, reading as gravity).
  Burst duration extended 950ms → 1400ms so the longer, staggered flights
  have room to actually finish leaving the screen before the animation
  ends.

**Because:** Both complaints trace to the same root cause — the original
design treated the burst as one synchronized swarm that all arrived at a
fixed point together, which is neither how real confetti moves nor what
was asked for either time.

**Consequences:** `flutter analyze` clean, `flutter test` 95/95
(unchanged — animation-only), `flutter build apk --debug` succeeds.
On-device verification (does the burst now read as individual pieces
rather than one synchronized clump, do pieces actually exit the screen
instead of parking mid-air) is the developer's to run.

---

## D-064 — Layered BGM reverted to a single track; character-select unlock bar-fill height bug; coin icon replaced with the real coin asset

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** Three unrelated developer asks in one pass: "Remove all of the
BGM, and leave only the main one." / "The filling of the progressbar in
character select screen, is different sizes for all of the characters -
its correct up until where its filled, but the sizing its wrong." / "We
need to modify the coin-icon with our actual coin asset in the game,
character select, upgrades, end of match screen" (new asset delivered:
`assets/images/consumables/coin-icon.png`, a 240x16 single-row, 15-frame
coin-spin sheet).

**Decision, BGM:** D-062's layered Core/boss/death stack (3.wav/1.wav/
4.wav) is removed outright, not disabled — `BgmController` now only owns
the permanent base layer (`2.wav`) plus `start()`/`setMasterVolume()`.
Every trigger call (`enterCore`/`bossSpawned`/`bossCleared`/`died`/
`leaveArena`) is deleted from its call sites (`ArenaGame.resetRound`/
`onBossKilled`/`_maybeSpawnBoss`/`_endRound`, both `arena_screen.dart` MAIN
MENU buttons) rather than left as unused no-ops — D-062 was two commits
old and never verified on-device (TASKS 18.6 was still open), so there was
no in-flight behavior worth preserving behind a flag. The 3 extra WAV
files stay on disk (not asked to delete assets) but nothing references
them anymore.

**Decision, unlock bar:** `_LockedPanel` (`character_select_screen.dart`)
stacks `bar-empty.png` (full-width background) under `bar-filling.png`
(width clipped to the unlock fraction via `FractionallySizedBox`). Neither
`Image.asset` had an explicit `height` — `bar-empty` always got `width:
double.infinity`, so its derived height (via the sheet's own aspect ratio,
since nothing pinned it) came out constant by accident; `bar-filling`'s
width is `widthFactor: fraction`, which is a *different* value per
character (each has its own kills-to-unlock ratio), so its derived height
came out different per character too — the exact symptom described
("correct up until where its filled, but the sizing is wrong"). Fix: both
images now get an explicit `height: barHeight` (22, matching the
surrounding `SizedBox`) so only width varies and height is pinned
regardless of fraction.

**Decision, coin icon:** new `CoinIcon` widget (`ui/widgets/coin_icon.dart`)
crops frame 0 of `coin-icon.png` — same crop-a-cell-from-a-sheet technique
`_SpriteCell` (`arena_screen.dart`, D-043) already used for the round-over
flying coins, pulled out shared rather than duplicated a third time.
Replaces `ui/currency-counter.png` (the old placeholder badge) in all 3
places it was a standalone wallet icon: `character_select_screen.dart`'s
and `upgrades_screen.dart`'s `_WalletRow`, and Round Over's `_CoinCounter`
badge. The flying coins themselves (`_SpriteCell`, "in the game") also
switch from `money.png`'s tier-0 cell to `coin-icon.png`'s frame 0, so
every coin shown anywhere is now the same real asset. Round Over's badge
used to be `currency-counter.png` (a plaque shaped to hold a number)
stacked with the count on top of it (D-043's own fix for the count reading
"outside the panel") — `coin-icon.png` is just a coin, not a plaque, so
that spot is now an icon+text `Row` instead, the same shape every other
wallet display already uses; text color switched from the plaque-matched
`0xFF6B2E00` to `ArenaColors.accent` for the same reason.

**Decision, `_SpriteCell` NaN fix:** `_SpriteCell`'s alignment math
(`2 * (row * cellSize) / (sheetHeight - cellSize) - 1`) divides by 0 when
a sheet is exactly one cell tall — true of every prior sheet it was used
on (`money.png` is 192 tall) but not `coin-icon.png` (16 tall, single
row), which produced a NaN `Alignment` and would have rendered nothing.
Guarded both axes: `sheetWidth == cellSize` / `sheetHeight == cellSize`
short-circuit to `0` instead of dividing, since a single row/column has
only one cell to crop along that axis regardless of alignment value.

**Because:** The BGM ask was explicit and unambiguous ("leave only the
main one") — deleting the layering is more honest than leaving dead code
that looks wired but never fires. The bar bug and the coin-icon swap were
both concrete, reproducible UI defects/asks with a single root cause each
once traced.

**Consequences:** `flutter analyze` clean, `flutter test` 95/95
(unchanged — no `core/` formula touched), `flutter build apk --debug`
succeeds. On-device verification (bar fills to a consistent height across
all 3 locked characters; the coin icon renders correctly everywhere,
including the flying coins and the round-over badge; only the base track
plays, with no Core/boss/death layers ever kicking in) is the developer's
to run. TASKS 18 (D-062/D-063) is superseded by this entry for the BGM
half — its layering claims no longer describe the code.

**Follow-up, same day:** developer reported "can't see the coin icon at
all" after this landed. Root cause, found by reading Flutter's own SDK
source (`decoration_image.dart`'s `paintImage`, not guessable from the
Dart docs alone): `Image`'s `fit` defaults to `BoxFit.scaleDown` when
unset, and `scaleDown` **never scales up** — only down, or not at all.
Both `CoinIcon` and the pre-existing `_SpriteCell` (D-043's flying-coin
crop, this class copied its shape) give `Image.asset` an explicit `width`/
`height` bigger than the source sheet, without an explicit `fit`, expecting
it to stretch to that size the way the crop math (`OverflowBox` sized to
the *scaled* sheet, positioned by `alignment`) assumes. Instead the image
drew at native pixel size, centered in the middle of that oversized box —
nowhere near the small window `ClipRect` actually shows, so the crop was
blank. This is a latent bug in `_SpriteCell` too, present since D-043: the
round-over flying coins have likely never been visible either, just easy
to miss on a small, 1.6s, edge-of-screen animation. Fixed both call sites
with an explicit `fit: BoxFit.fill` (stretch exactly to width/height,
matching what `scale` already assumes) — confirmed by simulating the same
resize-then-crop in a standalone script against the real asset (not
guessed): the coin renders correctly.

**Because:** a Flutter widget-test render couldn't confirm this directly —
real image decode through the asset bundle hangs under the fake-async test
clock (the same root cause as CLAUDE.md rule 11's `GameWidget` limitation,
now confirmed to reach plain `Image.asset` too, not just Flame's image
cache) even wrapped in `tester.runAsync`. Reading the framework source
directly, then verifying the fix against the real PNG bytes outside the
widget tree, was the reliable path to an actual root cause instead of a
guess.

**Consequences:** `flutter analyze` clean, `flutter test` 95/95 (unchanged),
`flutter build apk --debug` succeeds. On-device verification (the coin icon
now actually shows in all 4 places, plus the round-over flying coins,
never confirmed visible before this fix either) is the developer's to run.

---

## D-065 — Debug "unlock all characters" button; character-select tap arrows

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** Two developer asks: a debug way to unlock every character
without grinding lifetime kills (testing convenience, same spirit as the
existing coin/gem debug tools), and a non-swipe way to page the
character-select carousel. Asked which "arrow keys" meant (on-screen tap
buttons vs. physical keyboard input) — developer picked on-screen buttons.

**Decision, unlock debug:** `MetaProgressionRepository.
debugSetLifetimeKills(value)` raises `lifetimeKills` to `max(current,
value)` — never lowers it, so it can't accidentally re-lock a character
real play already unlocked. Settings' DEBUG section (loaded unconditionally,
same as the existing coin/gem debug rows — reachable from the main menu,
not just the arena's Pause Menu) gets one more button, "UNLOCK ALL
CHARACTERS", which passes the highest `unlockKillThreshold` across
`kCharacters` computed inline rather than adding a second exported
constant next to it.

**Decision, carousel arrows:** `_CarouselArrow` (`character_select_screen.
dart`) is a small flat tap target (`PixelButton`'s look — no rounded
corners/gradients — but not `PixelButton` itself, which is always
`double.infinity` wide) flanking the `PageView` on both sides, calling
`PageController.previousPage`/`nextPage`. Disabled (dimmed, no tap) at
either end of `kCharacters` instead of wrapping around. No dedicated
pixel-art asset exists for this yet, so it uses a plain Material
`Icons.chevron_left`/`chevron_right` rather than blocking on new art —
swap for a real sprite if/when one gets delivered.

**Consequences:** `flutter analyze` clean, `flutter test` 95/95 (unchanged
— no `core/` formula touched), `flutter build apk --debug` succeeds.
On-device verification is the developer's to run.

---

## D-066 — Android back button could exit a round with no reward

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** Developer report: "user is able to exit round without rewards
if he presses android back button." `ArenaGame._endRound` is the only place
`MetaProgressionRepository.addCoins`/`addGems`/`addLifetimeKills` get
called, and it only ever runs on death. `ArenaScreen` had no back-press
handling, so the platform default (pop the current route) let a single
back press or edge-swipe drop the whole arena route mid-round, `_endRound`
never running — silent, no confirmation, from any state including mid-fight
with no menu open.

**Decision:** `ArenaScreen` wraps its `Scaffold` in `PopScope(canPop:
false, ...)` and handles back explicitly in `_handleBack()`, mirroring
whatever the deliberate exit/resume action already is for the current
state rather than inventing a new one: round already over (`roundOver`
true, reward already banked) — leaves, same as RoundOver's own MAIN MENU
button; Pause Menu open — resumes, same as RESUME; LevelUp/ChestReveal
open — no-op, those need an explicit choice and there's nothing safe to
redirect back to; actively playing, nothing open — opens the Pause Menu,
same as tapping the pause button. Leaving mid-round (no reward) is still
possible from the Pause Menu's own MAIN MENU button — that's an existing,
deliberate action, not the bug; what's fixed is a bare back press no
longer bypasses it.

**Consequences:** `flutter analyze` clean, `flutter test` 95/95 (unchanged
— no `core/` formula touched), `flutter build apk --debug` succeeds.
On-device verification is the developer's to run.

---

## D-067 — Upgrades screen redesigned into a non-scrolling carousel; 3 new persistent dials

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** Developer, with a screenshot of the old one-long-scrolling-list
Upgrades screen (which also showed a real pre-existing bug: `StatBar`'s
label column wrapped "CORRUPTION" into 3 stacked lines): "get rid of the
scrolling... must not allow scrolling"; "use the same model from character
select with arrow keys; have normal stats (STR/VIT/DEX/INT) on first page,
corruption + come up with 3 new upgrades like corruption on the second
page + placeholder third page with coming soon."

**Decision, layout:** `UpgradesScreen` is now a `PageView` of 3 fixed
(non-scrolling) pages, paged by the same `CarouselArrowRow`/`PageDots`
carousel Character Select uses — both were pulled out of
`character_select_screen.dart` into `ui/widgets/carousel_arrow.dart` as
shared, public widgets rather than duplicated a second time. Page 1 is the
4 raw attributes (STR/VIT/DEX/INT); page 2 is Corruption plus the 3 new
dials below; page 3 is a `COMING SOON` placeholder, same empty-state
pattern as `ShopScreen`. Each page lays its 4 rows out with `Expanded`
(no `SingleChildScrollView`/`ListView` anywhere) so the page always
exactly fills whatever height the carousel gives it — the literal fix for
"must not allow scrolling." `MetaStat`'s own declaration order is now the
row order for both pages (`UpgradesScreen._statPages` just slices
`MetaStat.values`), so a future dial is an enum member, not a second list
to keep in sync.

**Decision, the 3 new dials (HASTE/FORTUNE/RESOLVE):** developer explicitly
delegated the design ("come up with 3 new upgrades like corruption") —
structurally, "like Corruption" means a persistent *global multiplier*
dial (`core/game_rules.dart`), not a raw per-point attribute add like
STR/VIT/DEX/INT. Unlike Corruption, none of the 3 trade anything away —
they're the "pure reward" counterparts, bought instead of traded for:
- **HASTE** — `hasteAttackSpeedMultiplier`, +5%/level, shrinks
  `ArenaGame`'s own `_fireCooldown` calc for the base attack only
  (deliberately not reaching into every skill's independent cooldown —
  same narrow-scope precedent as Corruption only ever touching spawn/
  enemy-stat/reward).
- **FORTUNE** — `fortuneRewardMultiplier`, +10%/level, layers onto
  `ArenaGame._rollCoins()` alongside (not instead of)
  `corruptionRewardMultiplier`.
- **RESOLVE** — `resolveDamageResistance`/`resolveHpRegenPerSec`, +2%
  damage resistance and +0.05 HP/s per level, same additive-layer shape as
  Defence Crystal's in-round bonus (`PlayerComponent.takeDamage`/
  `update`) but persistent instead of an in-round pick, clamped together
  with it so a future overstack still can't invert into bonus damage.

All 3 get their own `MetaProgression` field/`SharedPreferences` key,
buyable 0-10 through the existing `buy`/`metaUpgradeCost` machinery
unchanged.

**Decision, the wrap bug:** `StatBar`'s label column widened from a fixed
36px (fine for 3-letter STR/VIT/DEX/INT, not "CORRUPTION"/"FORTUNE") to
80px, plus `maxLines: 1`/`softWrap: false`/`TextOverflow.ellipsis` so a
future long label degrades to an ellipsis instead of wrapping into
stacked single letters again.

**Consequences:** `flutter analyze` clean, `flutter test` 100/100 (+5 new:
`game_rules_test.dart`'s haste/fortune/resolve multiplier tests,
`meta_progression_test.dart`'s buy-independently and save/load-round-trip
tests), `flutter build apk --debug` succeeds. On-device verification is
the developer's to run.

---

## D-068 — Locked-character panel's progress bar removed, just the hollow star stays

**Date:** 2026-09-10 · **Status:** Accepted
**Context:** Developer: "Get rid of the progressbar, keep just the hollow
star" — the bar-empty/bar-filling unlock-progress bar under a locked
character's star icon in `_LockedPanel` (`character_select_screen.dart`,
DECISIONS D-055/D-064's fill-height fix).

**Decision:** `_LockedPanel` drops the `bar-empty`/`bar-filling` `Stack`
entirely — just `star-empty.png` (the hollow star) plus the existing
`'$lifetimeKills / $threshold kills to unlock'` text underneath it, same
as before. The raw kill-count text already carried the same information
the bar did, so nothing about "how close am I" is actually lost.

**Consequences:** `flutter analyze` clean, `flutter test` 100/100
(unchanged), `flutter build apk --debug` succeeds. On-device verification
is the developer's to run.

---

## D-069 — Gem currency display, a real SHOP, and 4 more Upgrades dials (MAGNET/LUCK/REGEN/CRIT)

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer asked for three things in one message: (1) gem
currency shown on character select and Round Over, (2) SHOP filled with
items that actually do something, using the highest-tier gem asset for the
gem counter icon, (3) more upgrades on the Upgrades screen's 3rd page
(D-067 shipped it as a "COMING SOON" placeholder). Two real design
questions — what SHOP sells and priced in what, what the 4 new dials are —
were asked and confirmed rather than guessed (`AskUserQuestion`, both
"Recommended" options chosen): SHOP sells **gem-priced, permanent one-time
boosts** (distinct from the leveled coin dials); the 3 new dials are
**MAGNET / LUCK / REGEN / CRIT**.

**Decision, gem icon:** `ui/widgets/gem_icon.dart`'s `GemIcon` crops
`consumables/gems.png`'s legendary column (rightmost, frame 0) — same
"crop one real frame out of the actual sheet" approach `CoinIcon` (D-064)
already uses for coins. Character select's wallet row swaps the
`star-full.png` placeholder for this; Round Over gets a new `_GemCounter`
(`arena_screen.dart`) — the same icon+tweened-count treatment `_CoinCounter`
already has, minus the flying-particle flourish (one currency reveal
already sells the moment), replacing the old plain `'Gems collected: N'`
text row.

**Decision, SHOP:** new `core/shop.dart` — `ShopItemId` enum, `ShopItem`
(label/description/`costGems`), `kShopItems` (5 entries, declaration order
is display order). `MetaProgression` gained `ownedItemIds` (a
`Set<String>` of `ShopItemId.name`, persisted via
`SharedPreferences.setStringList`) and `buyItem`/`ownsItem` (same
afford-check-then-deduct shape as `.buy()`), plus bonus getters
(`bonusMaxHpFromShop` etc.) combat code reads directly. The 5 items:
- **Vitality Charm** (200 gems) — +30 max HP, read in
  `PlayerComponent.effectiveMaxHp`.
- **Swift Boots** (200 gems) — +20 move speed, read in
  `PlayerComponent.effectiveMoveSpeed`.
- **Sharp Edge** (250 gems) — +15% auto-attack damage. Scoped to just the
  base attack (`ArenaGame.resolveAttackDamage`, called from every
  `AttackBehavior`), same deliberately narrow precedent Haste already set
  for attack speed — Ray/Thunder/Aura/Mirror stay unaffected.
- **Iron Will** (250 gems) — +8% damage resistance, folded into
  `PlayerComponent.takeDamage`'s existing resistance clamp alongside
  Defence Crystal's and Resolve's.
- **Second Wind** (500 gems) — survive one lethal hit per round at 50% HP.
  `ArenaGame.tryConsumeRevive()`/`reviveAvailable` gate it to once per
  round (`_reviveUsedThisRound`, reset in `resetRound` — the *ownership* is
  permanent, the *use* is round state, CLAUDE.md §4.5); checked in
  `PlayerComponent.takeDamage` right where the death path used to fire
  unconditionally.
`ShopScreen` (`ui/screens/shop_screen.dart`) is a scrolling list of
`_ShopItemRow`s (same visual language as `UpgradesScreen`'s `_UpgradeRow` —
label/description/buy button, OWNED once bought) instead of the D-047
empty-state placeholder.

**Decision, new dials:** `core/game_rules.dart` gained 4 more pure
functions, same per-level-multiplier shape as Corruption/Haste/Fortune/
Resolve: `magnetPickupRadiusMultiplier` (widens `gem`/`potion`/`chest`
pickup radius, +15%/level), `luckGemDropBonus` (an additive term
`economy.dart`'s `gemDropChance` now takes as an optional `bonusChance`
param, +1pt/level), `regenHpPerSec` (a 4th additive HP-regen layer in
`PlayerComponent.update`, alongside Defence Crystal's/Resolve's own),
`critChance` (rolled by `ArenaGame.resolveAttackDamage`, same narrow
base-attack-only scope Sharp Edge above shares — ×1.5 damage on a hit,
+3%/level). `MetaStat` gained `magnet`/`luck`/`regen`/`crit` members;
`UpgradesScreen._statPages` gained a 3rd real entry
`[magnet, luck, regen, crit]`, and `_ComingSoonPage` is deleted (nothing
references it anymore).

**Consequences:** `flutter analyze` clean, `flutter test` green (new cases
added for the 4 dial functions, `gemDropChance`'s new optional param, and
`MetaProgression.buyItem`/`ownsItem`). `flutter build apk --debug`
succeeds. On-device verification is the developer's to run: gem icon/count
reads correctly on both screens; SHOP purchases deduct gems, persist
across an app restart, and are actually felt next round (HP/speed/damage/
resistance/revive); the 3rd Upgrades page's 4 rows buy and level
correctly with coins, same as pages 1-2.

---

## D-070 — SHOP paged (no scrolling) with 2 more pages of items; Round Over's gem reveal gets coin-style flying pieces plus its own sparkle VFX

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer, in one message: (1) SHOP (D-069) should page like
Upgrades instead of scrolling, with 2 more pages of items that actually do
something; (2) Round Over's gem counter (D-069) should get the same flying-
piece animation the coin counter has, plus additional VFX of its own.

**Decision, SHOP paging:** `core/shop.dart`'s `kShopItems` (one flat list)
became `kShopPages` (`List<List<ShopItem>>`, 3 pages of 5 — page order and
in-page order are both just the list's own declaration order, same
convention `MetaStat.values` already set); `kShopItems` is now a derived
flattening (`[for (final page in kShopPages) ...page]`) so every existing
buy-lookup/test that read it as a flat list is untouched. `ShopScreen`
rebuilt around the exact `UpgradesScreen` shape: `PageController` +
`CarouselArrowRow`/`PageDots`, each page laying its rows out with
`Expanded` — no scroll view anywhere, can't overflow regardless of screen
height.

**Decision, 10 new items (pages 2-3):** Same "permanent one-time, gem-
priced" shape as page 1, but reaching into gameplay hooks that were already
single choke points, so almost none of this touched `attack_behavior.dart`
or added new per-kit branches:
- **Quick Hands** (220g) — +10% attack speed, folded into `ArenaGame`'s
  `_fireCooldown` calc alongside Haste's own multiplier.
- **Battle Fury** (280g) — +20% auto-attack damage while below 50% HP. The
  one item that can't be a bare `MetaProgression` getter (it needs the
  *live* player's current HP) — checked directly in
  `ArenaGame.resolveAttackDamage`, the one place that already has both
  `meta` and `player`.
- **Potion Master** (180g) — potions heal 50% more (`ArenaGame.
  collectPotion`).
- **Steel Nerves** (200g) — halves the Elite spawn roll. `game_rules.dart`'s
  `rollIsElite` gained an optional `chanceMultiplier` param (default 1,
  every existing call/test unaffected), same shape `gemDropChance`'s
  `bonusChance` param already set.
- **Vampiric Touch** (260g) — a small flat heal on every kill
  (`ArenaGame.onEnemyKilled`); the bonus getter reads 0 when unowned, so
  the call site is an unconditional `player.heal(...)`, no branch needed.
- **Treasure Hunter** (260g) — +30% gems from chests (`ArenaGame.
  onChestOpened`).
- **Scholar's Insight** (220g) — +20% XP from every kill (`ArenaGame.
  grantXp`).
- **Golden Touch** (240g) — +20% coin value, folded into `ArenaGame.
  _rollCoins` alongside Corruption's/Fortune's own multipliers.
- **Gem Hoarder** (220g) — +5% flat gem drop chance, summed into the same
  `bonusChance` term LUCK's dial already feeds `gemDropChance`.
- **Boss Hunter** (350g) — bosses (which otherwise drop no gems at all —
  `onBossKilled`'s own long-standing "not designed yet" gap) now drop a
  flat 50-gem bonus haul.

**Decision, gem reveal VFX:** `_GemCounter` (`arena_screen.dart`) gained
the same flying-piece mechanic `_CoinCounter` has — `_FlyingCoinSpec`
(already generic, no coin-specific fields) reused as-is, rendering a
legendary-tier gem cell via the existing `_SpriteCell` instead of the coin
cell. On top of that, gems get VFX coins don't: a looping burst of 6
sparkle glints (`_GemSparkleSpec`, `Icons.auto_awesome`) fixed around the
gem icon, each fading in/out on its own staggered local timeline off one
shared repeating `AnimationController` — reads as gems being the fancier,
premium currency rather than an identical reskin of the coin reveal.

**Consequences:** `flutter analyze` clean, `flutter test` green (new cases:
`kShopPages`/`kShopItems` shape, the new bonus getters neutral-until-owned
and reflecting ownership, `rollIsElite`'s `chanceMultiplier`).
`flutter build apk --debug` succeeds. On-device verification is the
developer's to run: SHOP pages through 3 screens with arrows/dots, never
scrolls on any page; all 10 new items are felt in a round once bought
(attack speed, low-HP damage spike, potion heal size, fewer Elites,
on-kill healing, chest/XP/coin/gem-drop bumps, a bonus gem drop on a boss
kill); Round Over's gem counter shows small gems flying in and shrinking
like the coins do, plus the sparkle twinkle looping around it.

---

## D-071 — Chest anima resized/de-contrasted, independent-falling confetti +30%, CORRUPTION shortened to CHAOS, Round Over gets a kill counter with a golden-star landing bounce

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer, four asks in one message: (1) the chest-opening
anima flourish reads "wayy too big," reduce its size and contrast, smaller
than the chest itself; (2) chest-reveal confetti should fall with each
piece moving independently, plus +30% count and +30% spawn-location
spread; (3) shorten CORRUPTION's displayed name, same functionality; (4)
add a kill counter to Round Over using the hollow star, golden stars flying
in the way coins/gems do, the icon itself turning into a golden star with
the same jump/land bounce the chest reveal's card has.

**Decision, chest anima:** `ArenaGame.spawnEffect` gained a `contrast`
param (default 1, no-op) — generalized from `AuraComponent`'s own private
`_colorMatrix` (D-032) so any one-shot VFX can dial contrast down, not just
brightness; the old pure-multiply `_brightnessMatrix` is gone, folded into
this one function (`contrast == 1` reduces to exactly the old formula).
`ChestComponent._startOpening` now sizes the anima off its *own* rendered
width (`size.x * kChestAnimaSizeFactor`, 0.85 — DECISIONS constants.dart)
instead of the flat, much bigger `kAnimaWidthPx` (160px vs. the chest's own
96px) every other anima flourish shares, and passes `kChestAnimaContrast`
(0.7).

**Decision, confetti:** `_confettiCount` 26 -> 34 (+30%, rounded).
`_buildConfetti`'s start-position (`startAlign`) random ranges widened 30%
(1.4/0.9 -> 1.82/1.17 horizontal magnitude, -0.4/0.8 -> -0.52/1.04
vertical) — only the *spawn* range, `endAlign`'s landing spread is
untouched. `_ConfettiParticle` gained `wobbleAmplitudePx`/
`wobbleFrequency`/`wobblePhase`, randomized per piece; `_ConfettiPainter.
paint` adds a `sin(localT * frequency * 2π + phase) * amplitude` horizontal
offset on top of the shared start->end lerp, so pieces now visibly diverge
mid-flight instead of all tracing the same line with just different
endpoints.

**Decision, CORRUPTION rename:** Display label only —
`MetaStatLabels.label`'s `MetaStat.corruption` case now returns `'CHAOS'`.
The enum member, every field (`corruptionLevel` etc.), and all 3 multiplier
functions in `game_rules.dart` keep the `corruption` name — "same
functionality," nothing to migrate in `SharedPreferences` or anywhere else.

**Decision, kill counter:** New `_KillCounter` (`arena_screen.dart`),
replacing the plain `'Enemies killed'` text row, sitting alongside
`_CoinCounter`/`_GemCounter`. Center icon starts as `star-empty.png`
(hollow) with `game.kills` counting up; small `star-full.png` (golden)
stars fly in exactly like `_CoinCounter`'s coins (`_FlyingCoinSpec` reused
as-is, plain `Image.asset` since stars aren't a sprite sheet). The instant
the count-up finishes, the center icon swaps to `star-full.png` and plays
the *literal same* jump/land bounce `_ChestRevealOverlayState`'s card
landing uses — identical `TweenSequence` (520ms, 35% easeOut to -22 / 65%
bounceOut back to 0) rather than a second hand-tuned bounce that happens to
look similar.

**Consequences:** `flutter analyze` clean, `flutter test` 111/111
(unchanged — no new pure-function logic to unit test; the changed code is
either UI/VFX or a generalized private color-matrix helper, same
untestable-by-design shape `AuraComponent`'s own version already has,
CLAUDE.md §4.11/rule 11). `flutter build apk --debug` succeeds. On-device
verification is the developer's to run: chest anima reads smaller than the
chest and flatter/less punchy; confetti burst is visibly bigger and wider,
individual pieces drifting differently as they fall; CHAOS shows correctly
on Upgrades page 2 and still does everything Corruption always did; Round
Over's kill counter shows golden stars flying in, and the hollow star
visibly turns gold with a jump/bounce the instant the count finishes.

---

## D-072 — LevelUp screen redesigned, 4 skills made mutually exclusive (a real meta), chest confetti replaced with a sparkle burst

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer, three asks: (1) the LevelUp ("choose a power")
screen needs a real redesign, and its text needs to actually fit inside
its panels; (2) some powers are too strong stacked together — make picking
one lock out specific others, on purpose, to force real build choices; (3)
the chest-reveal confetti (D-061/D-063/D-071) "is not it" — remove it,
replace with different VFX when the card lands.

**Decision, exclusivity ("create a meta"):** `core/progression.dart`
gained `kExclusiveUpgradeGroups` — one group so far: `{aura, ultimateMirror,
projectileRay, projectileThunder}`, the 4 independent screen-clearing
damage skills, each already strong enough alone to carry a build, with no
real tradeoff stacked together. `lockedOutByExclusiveGroups(pickCounts)`
computes every kind locked out because a *different* member of its group
already has a pick (the picked one itself stays eligible, so it can still
level toward its own cap); `rollUpgradeChoices` excludes those alongside
the existing max-picks check. Deliberately narrow: flat stat bumps (vit/
dex/str/intellect), `knifeMastery` (a modifier on an existing attack, not
a 5th independent damage source), and `defenceCrystal` (pure
survivability) aren't in any group, so they keep stacking freely
alongside whichever one of the 4 gets picked — same "narrow scope on
purpose" precedent Haste/Sharp Edge/CRIT already set (D-069/D-070) rather
than a blanket "only one skill ever" rule. `isExclusiveUpgrade(kind)`
exposes group membership for the UI to warn about *before* a pick, not
just via the kind's later absence.

**Decision, LevelUp redesign:** The 3 choices were bare `OutlinedButton`s
with no overflow guard — a long description (Knife Mastery's, worst case)
had nothing stopping the whole popup's `Column` from exceeding screen
height, since nothing wrapped it in a scroll view. New `_LevelUpCard`
(`arena_screen.dart`): a bordered panel, left accent stripe, label +
category tag (`UpgradeKindLabels.tag` — STAT/SKILL/PASSIVE) row up top,
and the *full* description underneath with no truncation. An exclusive
kind (`isExclusiveUpgrade`) swaps the stripe/tag to danger-red and adds a
one-line "Locks out the other 3 offense skills this round" warning, so
the new tradeoff from this same decision is visible on the card itself.
The whole popup (`_LevelUpOverlayState.build`) is now wrapped in a
`SingleChildScrollView`, same overflow fix `_ChestRevealOverlay` already
uses (D-058) — it can't overflow again regardless of how long a future
description gets.

**Decision, chest VFX:** The rotated-rect confetti burst
(`_ConfettiParticle`/`_ConfettiLayer`/`_ConfettiPainter`) is deleted
outright. In its place: a radial sparkle burst reusing the *exact* visual
language the gem counter's own sparkle VFX already established (D-070) —
`Icons.auto_awesome` glints (`_CardLandSparkleSpec`) firing outward from
the card's center at a random angle/distance, each staggered by its own
delay, fading and scaling down over one non-looping 750ms
`AnimationController` fired alongside the existing landing bounce. Reads
as "something good just landed" using a VFX language the app already
speaks, rather than a third one-off effect.

**Consequences:** `flutter analyze` clean, `flutter test` 117/117 (+6 new:
exclusive-group roll behavior, `isExclusiveUpgrade`/
`lockedOutByExclusiveGroups`). `flutter build apk --debug` succeeds.
On-device verification is the developer's to run: LevelUp cards read
clearly and never overflow/clip text on any description, including Knife
Mastery's; picking any of Aura/Mirror/Ray/Thunder removes the other 3 from
every later level-up that round (the picked one can still come back up to
level further); the EXCLUSIVE badge/warning shows on all 4 before picking;
the chest reveal shows the new sparkle burst with zero confetti rectangles
anywhere.

---

## D-073 — BGM track swapped to electric-eel-fishing.ogg, gapless loop confirmed

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer: "Remove the current bgm, and add
electric-eel-fishing.ogg, perfect loop it."

**Decision:** `BgmController._basePath` changed from `core/2.wav` to
`core/electric-eel-fishing.ogg` (delivered pre-session, already covered by
`pubspec.yaml`'s `assets/audio/core/` folder entry — no asset declaration
needed). The old base track (2.wav) and the already-unused layered stack
(1/3/4.wav, D-064) stay in the repo unreferenced, same precedent D-064
already set rather than deleting audio assets outright. "Perfect loop" is
already what `BgmController.start()` gets for free: it calls
`FlameAudio.loop` (`PlayerMode.lowLatency`), which loops gaplessly on
Android — confirmed by reading `flame_audio`'s own source, whose sibling
method `loopLongAudio` (`PlayerMode.mediaPlayer`) carries an explicit doc
warning that *that* one has "an audio gap between loop iterations" on
Android and recommends `loop` for a gapless one. No code-shape change
needed beyond the path swap; the class doc comment now spells out why
`loop` (not `loopLongAudio`) is load-bearing for this ask, so a future
track swap doesn't accidentally regress onto the gapped method.

**Consequences:** `flutter analyze` clean, `flutter build apk --debug`
succeeds (no unit test exists for `BgmController` — a Flame-audio
component with no pure logic, same untested-by-design shape every other
audio/VFX component has, CLAUDE.md §4.11/rule 11). On-device verification
is the developer's to run: electric-eel-fishing.ogg plays app-wide from
boot, fades in the same ~2.5s as before, and loops with no audible
click/gap/silence at the seam.

---

## D-074 — Chest/boss anima moved behind their sprites, chest-reveal corner sparkles fixed + added, boss teleport cooldown, hurt no longer freezes movement

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer, four asks in one message: (1) the chest-opening
anima flourish renders in front of the chest, should be behind; (2) the
chest-reveal sparkle VFX (D-072) is good, but add one in each of the
card's 4 corners while it's still choosing, behind the card — "right now
we can see where we're storing them before we choose the card"; (3) the
boss's teleport anima renders in front of the boss, should be behind, plus
a 3-second cooldown on the teleport itself; (4) taking damage visibly
slows/freezes the character, remove that.

**Decision, anima z-order (chest + boss):** Both were spawned via
`ArenaGame.spawnEffect` without an explicit `priority`, defaulting to
`ArenaPriority.hitEffects` (25) — above both the chest's own
`ArenaPriority.pickup` (7, `chest.dart`) and the boss's own
`ArenaPriority.enemy` (10, `boss.dart`). Both call sites now pass
`priority: ArenaPriority.groundEffects` (5), rendering behind either
sprite.

**Decision, chest-reveal sparkles — real bug, not just a missing feature:**
`_buildLandSparkle`'s fade/offset math reads as fully opaque and
un-offset at the burst controller's own *rest* value (0, before
`.forward()` is ever called: `raw = ((0 - delay) / (1 - delay)).clamp(0,
1)` is 0 for every particle regardless of `delay`) — so all 14 landing-
burst glints sat fully visible, dead-center on the card, for the entire
shuffle+spin, before the reveal ever fired. That's exactly "we can see
where we're storing them." Fix: the whole landing-burst layer is now only
mounted once `!_shuffling && !_spinning` (i.e., landed) — before that it
isn't built at all, not just invisible. Separately, the actually-requested
new VFX: 4 small ambient glints (`_buildCornerSparkle`, one per
`Alignment` corner, `FractionalTranslation`-nudged slightly past the
card's own edge), pulsing on a shared looping `_cornerSparkleController`
staggered per corner, shown only `if (_shuffling || _spinning)` and
painted *before* (behind, in `Stack` paint order) the card image inside
the same `Stack` — gone the instant the spin lands, when the landing burst
takes over.

**Decision, boss teleport cooldown:** `BossStats.teleportCooldownSec`
(3.0) — `BossComponent._teleportCooldownTimer` starts counting down the
instant a teleport *begins* (`_beginTeleport`, not once it finishes), and
the trigger check (`distance <= teleportTriggerDistancePx`) is now also
gated on it being `<= 0`. Without this, a player standing still right at
the trigger distance could chain wind-ups back to back with no real gap.

**Decision, hurt no longer freezes movement:** `PlayerComponent.update`'s
movement block used to skip applying `input.direction` entirely whenever
`current == AnimState.hurt` (`if (moving && current != AnimState.hurt)`)
— every non-lethal hit froze the player in place for the whole hurt-pose
duration, reading as "slowed down." The `hurt` pose (D-021: "recoil pose
only, no tint") was only ever meant to be a visual reaction, not a control
lock (unlike the `spawn` state, which *is* deliberately a control lock per
PRD §6.5) — movement now applies unconditionally; the animation-state
transition logic right below (switching back to `run`/`idle` once the hurt
pose finishes) is untouched.

**Consequences:** `flutter analyze` clean, `flutter test` 117/117
(unchanged — every change here is either a VFX z-order/visibility fix, a
Flame-component timer, or a movement-gate removal, none of it pure logic
in `core/` to unit-test, CLAUDE.md §4.11/rule 11). `flutter build apk
--debug` succeeds. On-device verification is the developer's to run: chest
and boss anima both read behind their sprite now; the chest reveal shows
4 pulsing corner glints behind the card *only* while it's still shuffling/
spinning, replaced cleanly by the landing burst once it lands, with no
sparkles visible before that; the boss can't re-teleport for a full 3s
after starting one; taking damage no longer stops or slows movement.

---

## D-075 — BGM static noise fixed: `loopLongAudio` (MediaPlayer) instead of `loop` (SoundPool)

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer, marked highest priority: "I hear static noise when
BGM is playing" — surfaced immediately after D-073 swapped the BGM track
to a full-length OGG music file.

**Decision:** `BgmController.start()` now calls `FlameAudio.loopLongAudio`
(`PlayerMode.mediaPlayer`, backed by Android's real media decoder/
`ExoPlayer`) instead of `FlameAudio.loop` (`PlayerMode.lowLatency`, backed
by `SoundPool`). `SoundPool` is an Android API meant for short SFX played
with minimal latency — decoding and holding a whole music track's PCM
through it is exactly the kind of load known to produce audible static/
distortion on real hardware and emulators alike, and lines up with the
static appearing the moment D-073 pointed a full track at it (the previous
`2.wav` track apparently didn't trigger it as audibly, or as noticeably,
but the underlying risk was the same). The trade-off, documented at both
D-073 and here: `loopLongAudio`'s own doc comment warns of "an audio gap
between loop iterations" on Android — the exact seam D-073 picked `loop`
specifically to avoid ("perfect loop it"). Clean audio with a possible
small seam beats a seamless loop full of static; revisit if the seam turns
out to be audible in practice (the actual fix then would be re-encoding
the source file with proper loop points and reaching for a lower-level
gapless-loop technique, not reverting to `loop`).

**Consequences:** `flutter analyze` clean, `flutter build apk --debug`
succeeds (no unit test exists for `BgmController`, same untested-by-design
shape as D-073, CLAUDE.md §4.11/rule 11). On-device verification is the
developer's to run: BGM plays with no static/distortion at any point
during playback, and the loop point (however it sounds) is checked
separately from the static fix itself.

---

## D-076 — A real SFX layer: footsteps, damage, tap sounds on every button, projectile shots, level-up, chest-card sounds; an XP bar to match the HP bar

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer delivered 7 new SFX files
(`step-concrete-one/two.ogg`, `sfx_player-damage.ogg`, `sfx_tap_input.ogg`,
`chest-card-select.wav`, `chest-card-chosen.wav`,
`player-projectile-shoot.wav`, `level-up-sound.wav`) and asked for all of
them wired in, plus a bottom XP bar matching the existing top HP bar.

**Decision, a second SFX singleton:** New `core/sfx_player.dart` —
`SfxPlayer`, an app-wide singleton alongside `BgmController`
(`core/bgm_controller.dart`), same "read `Settings` once at boot
(`ArenaApp.initState`), update live off the SFX Volume slider
(`SettingsScreen._update`)" shape. Needed as its own thing, not folded
into `ArenaGame._playSfx` (the original explosion/death SFX, D-044),
because most of these have to play from plain menu screens with no live
`ArenaGame` at all — tap sounds, most obviously. Every one-shot still goes
through `kSfxVolumeCap` (D-044's "make sure they are not that loud"), plus
a further per-sound `relativeVolume` for anything either especially
frequent (taps, footsteps, the chest-card flicker) or explicitly asked to
stay quiet.

**Decision, each sound's hook:**
- **Footsteps** — `PlayerComponent`'s movement block now runs a small
  timer (`_footstepIntervalSec`, a first-guess cadence, not synced to a
  specific run-cycle frame) alternating `step-concrete-one`/`-two` while
  actually moving; resets to 0 the instant movement stops.
- **Player damage** — `PlayerComponent.takeDamage`, right where
  `spawnBloodImpact()` already fires (D-033) — same "only on a hit that
  actually lands" guard for free.
- **Tap on every button** — the widest-reaching one. `PixelButton` and
  `CarouselArrow` (the two shared, heavily-reused button widgets) play it
  internally; `ScreenScaffold`'s back button switched from
  `automaticallyImplyLeading`'s default (no hook to play a sound from) to
  an explicit `BackButton`; every other raw `OutlinedButton`/`TextButton`/
  `IconButton`/bare `InkWell` (Round Over's MAIN MENU, the LevelUp card's
  own tap, VIEW YOUR UPGRADES/BACK, the Pause Menu's 3 buttons via its
  shared `_menuButton` helper, ChestReveal's CONTINUE, the debug DIE
  button, the pause button) is wrapped with a new
  `ui/widgets/tap_sfx.dart`'s `withTapSfx(onPressed)` at its call site —
  `null` in, `null` out, so a disabled button stays silent. Sliders/
  radios/switches are deliberately out of scope — this is for discrete
  button presses, not continuous controls.
- **Projectile shoot, "not power-ups"** — `PlayerComponent.playFire()`.
  Every base `AttackBehavior` (`ProjectileAttack`/`KnifeAttack`/
  `SpiralFireAttack`/`WardenSlamAttack`) already calls this once per shot/
  swing; Ray/Thunder/Aura/Mirror never call it, so the "not power-ups"
  scoping is true by construction, not a filter that has to be kept in
  sync by hand.
- **Level up** — `ArenaGame.grantXp`'s `while` loop and
  `debugGrantLevelUp`, right where `level++` actually happens (once per
  level gained, even across a multi-level XP grant).
- **Chest-card select/chosen** — `_ChestRevealOverlayState`'s existing
  shuffle/spin `Timer` callbacks (every swap plays `chest-card-select`),
  except the very last one, which plays `chest-card-chosen` instead of
  another select (the same moment the landing bounce/sparkle burst already
  fire). `chest-card-select` specifically needed a *held* `AudioPlayer`
  (`SfxPlayer._cardSelectPlayer`), not a fire-and-forget one-shot like
  everything else here — the developer's spec ("interrupts the other one
  so they don't play over another," "change its pitch each time") means
  explicitly `.stop()`-ing the previous instance before starting a new one
  with a randomized `setPlaybackRate`. `setPlaybackRate`'s own doc warns it
  must be called *after* `play()`/`resume()`, not before — got this wrong
  on the first pass internally, caught by reading the doc before shipping.

**Decision, XP bar:** New `game/components/xp_bar.dart`'s
`XpBarComponent` — same background/fill/border shape as `HpBarComponent`,
added to `camera.viewport` (HUD, not world) the same way. Unlike the HP
bar's fixed `(24, 24)` (top-left is top-left on any screen size), a
*bottom* position needs the actual viewport height, which isn't known at
construction — `onGameResize` (called by Flame on every mounted component
whenever the game resizes, including once on first mount) is what places
it, 24px up from the bottom edge. `ArenaGame` gained a public `xpFraction`
getter (`_xpToNextLevel` itself stays private, CLAUDE.md §4.5) for the bar
to read.

**Consequences:** `flutter analyze` clean, `flutter test` 117/117
(unchanged — every change here is SFX plumbing, a movement-block timer, or
a HUD component, none of it pure `core/` logic to unit-test, CLAUDE.md
§4.11/rule 11). `flutter build apk --debug` succeeds. On-device
verification is the developer's to run: footsteps alternate while moving
and stop instantly when idle; a hit plays the damage sound; every button
across every screen (menus, pause menu, level-up, chest reveal, round
over) makes a tap sound, sliders/switches don't; only the base auto-attack
(never Ray/Thunder/Aura/Mirror) plays the shoot sound; leveling up plays
its sound; the chest reveal's card flicker pitches around per swap with no
sounds overlapping, at a volume that doesn't dominate, landing on a
distinct "chosen" sound; the XP bar fills left-to-right at the bottom of
the arena and doesn't visually collide with the movement-input joystick.

---

## D-077 — A real pixel font, applied app-wide

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer delivered `assets/fonts/pixel.ttf`: "this needs to
be our main font in this game."

**Decision:** Declared as a `PixelFont` family in `pubspec.yaml`'s new
`fonts:` section, then set as `ThemeData.fontFamily` in `app.dart`'s
`_theme` — not on individual `TextStyle`s. `Text`'s own merge-with-
ambient-`DefaultTextStyle` logic (every `TextStyle` in this codebase
leaves `fontFamily`/`inherit` unset, so `inherit` defaults `true`) means
every screen's text picks this up automatically, menus and Flame overlays
alike, with zero changes to any of the ~40 existing `TextStyle` call sites.

**Consequences:** `flutter analyze` clean, `flutter build apk --debug`
succeeds (confirms the font asset resolves and packages correctly — a
build failure would be the way a bad `pubspec.yaml` font path actually
surfaces). On-device verification is the developer's to run: the pixel
font renders everywhere (main menu, settings, character select, shop/
upgrades, every arena overlay) — legible at every size actually used,
including the smallest label text.

---

## D-078 — Chest sparkles still visible pre-choice (bug), exclusive pairs instead of one 4-way clique, and a real LevelUp card redesign

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer, three more asks/reports on top of D-072/D-076: (1)
the chest-card sparkles are still visible on screen before a card is
chosen; (2) one 4-way exclusive clique (D-072) is too much — pair the
skills instead, at least 2-3 exclusive relationships; (3) the LevelUp
screen (D-072's redesign) still looks cheap, needs more.

**Decision, sparkles:** The D-074 fix already gated the *landing* burst
correctly (only mounts once `!_shuffling && !_spinning`) — the residual
visibility was the D-074 corner-sparkle feature itself (4 ambient glints
behind the card, deliberately visible for the whole shuffle/spin). Being
*behind* the card didn't stop them reading as exactly the reported
complaint in practice. Rather than trying to hide them further, that
feature is removed outright — `_cornerSparkleController`,
`_buildCornerSparkle`, and the `Stack` wrapper around `_PlayingCardImage`
are gone; the card display reverts to the plain jump-bounce
`AnimatedBuilder` it had before D-074. No sparkle VFX exists anywhere
before the spin actually lands, full stop.

**Decision, exclusive pairs:** `kExclusiveUpgradeGroups` (D-072's single
`{aura, ultimateMirror, projectileRay, projectileThunder}` clique) is now
3 separate pairs instead, chaining all 4 kinds together without any one
pick locking the *other two*: `{aura, ultimateMirror}`,
`{ultimateMirror, projectileThunder}`, `{projectileThunder,
projectileRay}` — each with its own "why these two" rationale in the code
comment (redundant always-on AoE, redundant scale-to-everything nukes,
redundant second-attack rotations). `ultimateMirror` deliberately sits in
2 pairs (the existing `lockedOutByExclusiveGroups` already unions across
every group a kind belongs to, so this needed no code change, only data);
non-adjacent combos (Aura+Ray, Aura+Thunder, Mirror+Ray) are now valid
picks, unlike D-072's all-or-nothing version. New `exclusiveLockTargets
(kind)` (`lockedOutByExclusiveGroups({kind: 1})`) feeds the LevelUp card's
warning line the *real* paired partner(s) by name instead of D-072's now-
inaccurate hardcoded "the other 3."

**Decision, LevelUp redesign:** `_LevelUpCard` gained a 44px icon badge
(`_UpgradeIcon`/`_UpgradeIconSprite`) cropping each skill's own real game
art (`ultimate-mirror.png`/`projectile-ray-beam.png`/
`projectile-thunder.png`/`defence-crystal.png`/`effect_electric-shield.png`/
`knife_clean.png` — every asset D-049/D-032/D-029 already shipped) instead
of a plain text-only row; the 4 flat stat bumps (no dedicated art) get a
plain `Icon` glyph instead. `_UpgradeIconSprite` generalizes `_SpriteCell`'s
crop trick for non-square cells (the ray beam/thunder sheets aren't) —
scales by the cell's *larger* dimension and centers in a square box, so a
wide or tall frame letterboxes instead of stretching. The card itself
gained a soft accent-tinted `BoxShadow` and a double border (outer dim,
inner accent) for real depth instead of one flat outline. Layered on top
of D-077's font swap, applied for free.

**Consequences:** `flutter analyze` clean, `flutter test` 120/120 (+3 net
new/rewritten: pairwise lock behavior replacing the old clique tests,
`exclusiveLockTargets`). `flutter build apk --debug` succeeds. On-device
verification is the developer's to run: zero sparkle VFX visible before a
chest card actually lands; picking Aura only removes Ultimate Mirror (Ray/
Thunder still offerable), picking Ultimate Mirror removes both Aura and
Thunder, etc. — the "Locks out: X" line on each exclusive card always
names the right partner(s); LevelUp cards show each skill's real icon,
read with real depth (shadow + double border), and no longer read as
"cheap."

---

## D-079 — Root-caused and fixed a real SFX resource leak (BGM stopping/restarting, static, desync, a freeze); boss now drops a chest

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer reported 4 audio symptoms in one message: BGM
stopping and restarting on its own roughly every 30 seconds; static noise
persisting even after D-075's fix; sounds not syncing with the actions
that trigger them; and one full game freeze, suspected to be sound-
related. Also asked, separately: make the boss drop a chest on death.

**Diagnosis:** All 4 audio symptoms trace back to one bug in `SfxPlayer`
(D-076): every one-shot call (`playTap`/`playFootstep`/`playDamage`/
`playProjectileShoot`/`playLevelUp`/`playChestCardChosen`) went through
`FlameAudio.play(file, ...)`, which constructs a **brand-new**
`AudioPlayer` — a fresh platform-channel object, a fresh decode, fresh
`setAudioContext`/`setReleaseMode` round-trips — on every single trigger,
and never disposes it. Footsteps alone fire roughly 3 times a second
while moving; across taps, shots, and footsteps in a real round, that
leaked hundreds of live native audio objects within well under a minute.
That fully explains all 4 reports at once: the extra per-call native
setup work is exactly what "not synced" sounds like; the accumulating
resource pressure on a shared, limited platform audio subsystem is a
textbook cause of a periodic audio-wide hiccup (the BGM player — otherwise
untouched after its one-time creation — getting starved or reset counts
as "stopping and restarting"); the same contention reads as static; and
enough leaked native objects on this machine's already-documented
resource-constrained emulator (CLAUDE.md §2's own history) is a plausible
route to a genuine freeze. D-075's `loopLongAudio` switch was chasing a
symptom (static) whose actual cause was never the BGM player itself.

**Decision:** `SfxPlayer` now uses `FlameAudio.createPool` — one
`AudioPool` per sound file (2-4 pre-`setSource`'d players, default
`PlayerMode.mediaPlayer`), created once and reused for the app's whole
lifetime, same "outlives any screen" shape `BgmController`'s single player
already has. `.start(volume:)` on an already-prepared player is fast, and
the pool auto-returns a player to itself the instant playback completes —
no manual disposal, no unbounded growth. New `SfxPlayer.preload()`,
called from `ArenaApp.initState` alongside `BgmController.start`, warms
every pool up front so the very first sound in a session doesn't pay the
one-time creation cost. `chest-card-select` (pitch varies per call,
D-076) deliberately stays on its own dedicated held-`AudioPlayer`
mechanism — a pool's fixed players don't support per-play pitch — but
that path was never the leak: it explicitly stops+disposes the previous
instance before creating the next, so at most one extra player is ever
alive, for one short chest-reveal burst at a time, not continuously
across a whole round.

**Decision, boss chest:** `ArenaGame.onBossKilled` now calls the existing
`spawnChest(deathPosition)` (the same method `ChestSpawner`'s periodic
timer already calls) right where the boss died, unconditionally — a real
milestone reward instead of the "not designed yet" gap the class doc used
to flag. Boss Hunter's flat gem bonus (D-070) is unaffected and stacks
with this.

**Consequences:** `flutter analyze` clean, `flutter test` 120/120
(unchanged — this is audio-pipeline/component plumbing, none of it pure
`core/` logic to unit-test, CLAUDE.md §4.11/rule 11). `flutter build apk
--debug` succeeds. On-device verification is the developer's to run: BGM
plays continuously through a full round with no stop/restart and no
static; footsteps/taps/shots/damage all fire in sync with the action that
triggers them, including during a long, sound-heavy round; no freeze
across an extended play session; a boss kill always drops a chest at its
death position.

---

## D-080 — Global text scale reduced 25%

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer, after D-077's pixel font shipped: "the font is
too big, we need to reduce it by 25%."

**Decision:** `MaterialApp.builder` in `app.dart` wraps every screen in a
`MediaQuery` whose `textScaler` is a flat `TextScaler.linear(0.75)` —
touches one place instead of every one of the ~40 existing `TextStyle`'s
own `fontSize`. Deliberately replaces rather than composes with the
platform's own accessibility text-scale setting: this is a pixel-art game
with hand-fitted panel layouts (the LevelUp cards, stat bars, HUD), not a
text-heavy app, and a user's system font-scaling stacking on top would
just as easily break those layouts in the other direction.

**Consequences:** `flutter analyze` clean, `flutter build apk --debug`
succeeds. On-device verification is the developer's to run: every screen's
text reads at the smaller, correctly-proportioned size, still legible at
the smallest sizes used (LevelUp card descriptions, tags).

---

## D-081 — Real crash root-caused via logcat: SFX pools were on the wrong `PlayerMode`

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer: "the sound got really desynced and the game
crashed, it was like 5-6 seconds behind" — reported after D-079's pooled-
`AudioPool` fix had already shipped, meaning pooling alone wasn't enough.
Pulled the device's actual logcat rather than re-theorizing, and found two
real, distinct log entries:

```
E flutter : Unhandled Exception: TimeoutException after 0:00:30.000000: Future not completed
E flutter : #2 AudioPlayer._completePrepared (package:audioplayers/src/audioplayer.dart:372:5)
E flutter : #6 FlameAudio._preparePlayer (package:flame_audio/flame_audio.dart:67:5)
```
```
E AndroidRuntime: FATAL EXCEPTION: main
E AndroidRuntime: java.lang.IllegalStateException
E AndroidRuntime: 	at android.media.MediaPlayer._prepareAsync(Native Method)
E AndroidRuntime: 	at ...MediaPlayerWrapper.prepare(MediaPlayerWrapper.kt:88)
E AndroidRuntime: 	at ...WrappedPlayer.stop(WrappedPlayer.kt:238)
E AndroidRuntime: 	at ...WrappedPlayer.onCompletion(WrappedPlayer.kt:300)
```

**Diagnosis:** Both trace to `PlayerMode.mediaPlayer` — the default
`AudioPool`/`FlameAudio` backend, and what D-079's pools and
`BgmController` (D-075) both used. `MediaPlayer` wraps Android's
heavyweight media pipeline, built for one long-lived stream (correct for
BGM); `audioplayers`' own `mediaPlayer`-mode `AudioPool` auto-returns a
finished player to the pool by calling `stop()`, which internally calls
`prepareAsync()` to reset it for reuse. Under the trigger rate footsteps
alone produce (~3/sec), that reset raced hard enough to throw
`IllegalStateException` from inside the native completion callback —
uncatchable from Dart, and fatal (`FATAL EXCEPTION: main`, process died).
Separately, `BgmController`'s own lone `MediaPlayer` (D-075) hung for the
full 30s the library allows for "prepared" to fire, at the same time all
the SFX pools' `MediaPlayer` instances were also churning through the
identical native pipeline — exactly the "BGM stops... 5-6 seconds behind"
report, caused by resource contention on a pipeline never meant to host
this many concurrent short-lived instances.

**Decision:** Every pooled SFX (`SfxPlayer`'s tap/damage/shoot/level-up/
footstep/chest-chosen) now explicitly requests `PlayerMode.lowLatency`
(`AudioPool.create` called directly, since `FlameAudio.createPool` doesn't
expose `playerMode` at all) — `SoundPool`, the Android API actually
designed for rapid repeated short clips, with no prepare-per-play state
machine to race. The cost, per `AudioPool`'s own doc: `lowLatency` pools
don't auto-return a player on completion, so `_playPooledAsync` now
returns each one by hand after a fixed 2s delay (generous for every clip
here). Added a second, cheap layer of defense: `_inFlight`/
`_cardSelectBusy` guards drop (don't queue) a trigger that arrives while
the previous call for the same sound is still mid-setup, so a burst can
never pile up regardless of a device's momentary slowness — this also
closes a real, previously-unguarded race in `chest-card-select`'s own
dedicated player (overlapping calls during the spin's fastest steps could
race reading/writing `_cardSelectPlayer`). `BgmController` stays on
`mediaPlayer`/`loopLongAudio` — correct for one long stream — and should
no longer contend with anything now that every SFX pool has moved off
that pipeline entirely.

**Consequences:** `flutter analyze` clean, `flutter test` 120/120
(unchanged — audio-pipeline plumbing, no pure `core/` logic, CLAUDE.md
§4.11/rule 11). `flutter build apk --debug` succeeds. On-device
verification is the developer's to run: no crash and no BGM stop/restart
across a long, sound-heavy round; SFX stay in sync with the actions that
trigger them start to finish, not just for the first 30 seconds.

---

## D-082 — `splash_bg.png`: native launch screen + main menu background

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer delivered `assets/images/bg/splash_bg.png` (a full
1080x1920 title-art piece with the game's logo lockup baked in): "it needs
to be the game's splash art + background only in the main menu."

**Decision:** Two separate mechanisms, since the native launch screen
renders before Flutter's engine (and its `assets/` bundle) is even
available:
- **Native splash** — the file is copied into
  `android/app/src/main/res/drawable-nodpi/splash_bg.png` (a real Android
  resource, `-nodpi` so it's never density-pre-scaled) and both
  `drawable/launch_background.xml` and `drawable-v21/launch_background.xml`
  (the latter is the one actually used, minSdkVersion 24) now point their
  single layer-list `<item>` straight at `@drawable/splash_bg`, replacing
  the boilerplate white/`colorBackground` placeholder.
- **Main menu background** — `MainMenuScreen` (`assets/images/bg/` newly
  declared in `pubspec.yaml`) renders the same file full-bleed
  (`Image.asset(..., fit: BoxFit.cover)`) behind its existing buttons, and
  nowhere else, per the "only in the main menu" spec. Since the art already
  bakes in the "PIXEL ARENA BRAWL" title lockup, the screen's old plain
  `Text('ARENA')` title is gone — the art *is* the title now, not a second,
  redundant one drawn on top of it.

**Consequences:** `flutter analyze` clean, `flutter test` 120/120,
`flutter build apk --debug` succeeds — this is also the one place a bad
Android resource actually surfaces: the first build attempt failed
outright (`[Fatal Error] launch_background.xml:2:64: The string "--" is
not permitted within comments` — Dart-style `--` inside an XML comment
isn't legal XML, unlike Dart itself), caught and fixed before shipping.
On-device verification is the developer's to run: the splash art shows
during cold start before the first Flutter frame, and the main menu shows
it as a full-bleed background with the buttons readable over it.

---

## D-083 — Exclusive-skill color: warm amber instead of bright red

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer: "get rid of that bright red for exclusives, it's
wayy to bright. Pick something a little bit more warm, but still pricking
players' attention for it to read."

**Decision:** New `ArenaColors.warning` (`0xFFE0964B`, warm amber) added
alongside the existing `ArenaColors.danger` (`0xFFE0526C`) rather than
changing `danger` itself — `danger` is also used for God Mode's switch,
the debug DIE button, and ROUND OVER, which are genuinely "danger," not
"notice this." `_LevelUpCard`'s exclusive-skill accent (stripe, tag,
border, shadow, and the "Locks out: X" line) now reads `warning` instead.

**Consequences:** `flutter analyze` clean, `flutter test` 120/120,
`flutter build apk --debug` succeeds. On-device verification is the
developer's to run: exclusive cards read warm/amber, not bright red, while
still standing out from the regular accent-teal cards; every other
`danger` usage (God Mode, DIE, ROUND OVER) is unchanged.

---

## D-084 — First-time-user tutorial: 3 slides, auto-shown on a fresh save, reachable via a "?" button

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer: "First time user experience, booting the game with
fresh saves, should have a 3 slide tutorial explaining the game. You can
pick assets to explain powers and what we built. Can also be accessed from
the top right in the main menu, a circular ? button."

**Decision:** New `core/tutorial_state.dart`'s `TutorialState` — one
persisted bool (`tutorial.hasSeenIntro`), same minimal shape as every
other small persisted flag in this project rather than a full repository
class. New `ui/screens/tutorial_screen.dart`'s `TutorialScreen` — a fixed
3-page `PageView` using the same carousel chrome
(`CarouselArrowRow`/`PageDots`) every other multi-page screen already
uses, built entirely out of real in-game assets rather than new
illustration:
1. **MOVE & SURVIVE** — plain `Icon` glyphs (no dedicated art exists for
   "movement"/"auto-attack"/"survive").
2. **LEVEL UP & CHOOSE POWERS** — 5 real skill icons via the newly-shared
   `SkillIcon` widget (promoted out of `arena_screen.dart`'s
   `_LevelUpCard` into `ui/widgets/skill_icon.dart` the moment a second
   screen needed the identical per-skill iconography — `SkillIcon`/
   `SpriteCellIcon` are now public, `_LevelUpCard` imports them same as
   this screen does), plus a line about the EXCLUSIVE mechanic (D-072/
   D-078).
3. **LOOT, SHOP & UPGRADE** — the real `CoinIcon`/`GemIcon` widgets plus
   the actual `chest_01.png` sprite.

`MainMenuScreen` (now `StatefulWidget`, was stateless) checks
`TutorialState.hasSeenIntro()` in `initState` and pushes `TutorialScreen`
once if it's `false` — true only on a genuinely fresh save, since nothing
has written the key yet. A new circular "?" button, top-right (developer's
spec verbatim), pushes the same route on demand regardless of that flag.
Both paths converge on the same `_finish()` (`TutorialState.markSeen()`
then pop), so there's only one way this screen ever exits, whether it was
auto-triggered or manually opened.

**Consequences:** `flutter analyze` clean, `flutter test` 122/122 (+2
new: a genuinely-fresh-save `setMockInitialValues({})` test confirming the
tutorial auto-opens and that finishing it flips the persisted flag and
returns to the menu; a seeded-`hasSeenIntro: true` test confirming the "?"
button still reopens it manually). The 2 pre-existing widget tests were
updated to seed `hasSeenIntro: true` (they test the menu/character-select
flow itself, not the tutorial) and to drop the now-removed `Text('ARENA')`
assertion (D-082 replaced it with the splash art). `flutter build apk
--debug` succeeds. On-device verification is the developer's to run: a
freshly-installed app (or `adb shell pm clear com.awwwi.arena` on this
one) opens straight to the tutorial after the main menu's first frame;
finishing or skipping it lands back on the main menu and it doesn't
reappear on next launch; the "?" button reopens it any time after that.

---

## D-085 — Audio checkup: mixer split confirmed already correct; explosion/death SFX migrated onto the pooled path

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer flagged BGM and SFX as "routed to the same mixer,"
asking for them to be split into separate tracks, plus a general audio
correctness pass.

**Decision (mixer split — no code change needed):** Traced the full chain
(`Settings.sfxVolume`/`musicVolume` → two prefs keys →
`SettingsScreen`'s two independent sliders → `SfxPlayer.
setVolumeMultiplier`/`BgmController.setMasterVolume`, both read once at
boot in `app.dart` and live on every slider move) and confirmed the two
were already fully independent — separate fields, separate persistence,
separate controllers, separate players. Not a real bug; no change made.
The one thing genuinely shared is Android's default audio stream
(`STREAM_MUSIC`, via `audioplayers`' default `AudioContext` on both
`BgmController`'s `mediaPlayer` player and `SfxPlayer`'s `lowLatency`
pools) — the hardware volume rocker moves both together, which is normal
mobile-game behavior, not the app-level "mixer" the developer meant.

**Decision (real bug found and fixed):** `ArenaGame._playSfx` (explosion +
player-death SFX, D-044) was never migrated onto `SfxPlayer`'s pooled
playback when D-079/D-081 fixed every other one-shot — it still called
raw `FlameAudio.play(file, ...)`, the exact leak-a-fresh-`AudioPlayer`-
per-call bug D-079 fixed, on the exact wrong default `PlayerMode.
mediaPlayer` D-081 root-caused a real crash to. Not just a once-a-round
cost: `spawnExplosionEffect` (the explosion SFX's only call site) fires on
every Skirmisher spiral-fire kill, every chest open, and every boss death
— frequent enough in a real round to reproduce D-079/D-081's symptoms
again. Fixed by adding `sfx-explosion.wav`/`sfx-you-died.wav` to
`SfxPlayer._pooledFiles` and two new methods (`playExplosion`/
`playPlayerDeath`), deleting `ArenaGame._playSfx` entirely, and switching
its two call sites to `SfxPlayer.instance`. Removed the now-unused
`flame_audio` import from `arena_game.dart` — nothing else in that file
touches `FlameAudio` directly anymore, every SFX trigger in the app now
goes through the one pooled player.

**Consequences:** `flutter analyze` clean, `flutter test` 122/122
(unchanged — this is playback plumbing, not gameplay logic, covered by
CLAUDE.md §11's "verify on-device" carve-out, not a unit-testable rule).
On-device verification is the developer's to run: a Skirmisher round with
several spiral-fire kills and a chest open shouldn't reproduce any of
D-079's symptoms (BGM stopping/restarting, static, desync) even under
sustained play; explosion and death SFX should still sound and be
volume-scaled the same as before, just via the pool now.

---

## D-086 — BGM pauses on app-background, not just app-quit

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer: "music kept playing on device when minimizing the
game." `BgmController` (D-062/D-075) starts once at app boot and had no
lifecycle wiring at all — `audioplayers` doesn't stop on its own when
Flutter loses visibility, so the looping BGM kept running in the
background with no way to reach it (no notification, no OS audio-focus
integration).

**Decision:** `ArenaApp`'s `_ArenaAppState` now mixes in
`WidgetsBindingObserver` and pauses/resumes `BgmController`'s single
player off `didChangeAppLifecycleState`. `pause()`/`resume()` (new on
`BgmController`, wrapping the underlying `AudioPlayer.pause`/`resume`) are
used instead of stop/restart so the track picks back up exactly where it
left off. Only `AppLifecycleState.paused`/`hidden` trigger a pause —
`inactive` is deliberately left alone since it also fires for transient
foreground interruptions (a permission dialog, the notification shade, an
incoming call banner) where cutting the music mid-interruption would read
worse than a half-second of it playing under a dialog. `resumed` undoes
whichever of the two actually fired. `SfxPlayer`'s one-shots are
untouched — they're short and don't loop, so there's nothing to leave
running in the background the way BGM does.

**Consequences:** `flutter analyze` clean, `flutter test` 122/122
(unchanged — lifecycle wiring isn't gameplay logic, CLAUDE.md §11).
`flutter build apk --debug` succeeds. On-device verification is the
developer's to run: minimize the app (home button or recent-apps) during
a round or a menu — BGM should stop; bring it back to the foreground — BGM
should resume from where it paused, not restart from the top.

---

## D-087 — Second audio checkup: a real startup race in `BgmController.start()`, everything else confirmed correct

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer asked for another full pass over the sound
implementation after D-085/D-086, specifically to look for bugs.

**Decision:** Re-read `BgmController`, `SfxPlayer`, `app.dart`'s lifecycle
wiring, every `SfxPlayer` call site (footsteps/damage/tap/projectile-shoot/
level-up/chest-card select+chosen/explosion/death), and cross-checked
`AudioPool`'s actual implementation (pub cache source, not just its doc
comments) against how `SfxPlayer` uses it — confirmed the pooled
start/stop/reuse/release lifecycle, the `lowLatency`-skips-auto-return
behavior, and every asset path all match what `sfx_player.dart` assumes.
Found one real bug: **`BgmController.start()` races `pause()`/`resume()`**
(D-086) — `start()` is async and there's a real window, right after a cold
launch, where the app can be minimized *while `FlameAudio.loopLongAudio`
is still preparing the player*. `pause()` fires during that window, sees
`_basePlayer == null`, and no-ops; `start()` then finishes moments later
and begins playing (fading in) regardless, in the background — the exact
bug D-086 was supposed to close, just reachable from the other direction.
Fixed with a new `_pausedByLifecycle` flag: `pause()`/`resume()` set/clear
it in addition to touching the player (so it's authoritative even before
one exists), and `start()` checks it once the player is actually created —
if set, it sets volume straight to the real target and pauses immediately
instead of fading in, so a later `resume()` plays at the right volume
instead of silently at the 0 the fade-in would have started from.
Everything else re-checked came back clean: the mixer split (D-085), the
explosion/death SFX migration (D-085), no other raw `FlameAudio`/
`AudioPlayer` calls anywhere outside `bgm_controller.dart`/`sfx_player.dart`
(grepped the whole `lib/` tree), every pooled SFX asset path exists on
disk and is declared in `pubspec.yaml`, and the chest-reveal's
shuffle/spin `Timer`s are cancelled on `dispose()` so closing that overlay
mid-animation can't leave a dangling scheduled sound trigger.

**Consequences:** `flutter analyze` clean, `flutter test` 122/122
(unchanged — playback plumbing, not gameplay logic, CLAUDE.md §11).
`flutter build apk --debug` succeeds. On-device verification is the
developer's to run: force-close and relaunch the app, then immediately
hit home/recents within roughly the first second (before the title screen
would normally finish appearing) — BGM should not be audible while
backgrounded, and should resume at the normal volume (not silently) when
foregrounded again.

---

## D-088 — Root cause of total pooled-SFX silence: `AudioPool` was never given `FlameAudio.audioCache`, every load path was double-prefixed

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer, on-device: "I have SFX at max, BGM at 0, not
hearing footsteps, not hearing projectile when character attacks, etc."
D-076/D-079/D-081/D-085 had all been "on-device verification pending" —
this was the first real confirmation that the pooled SFX system produced
*no audio at all*, not a volume/mixer issue.

**Decision:** Root-caused by reading `audioplayers` 6.8.1's actual source
(not just its doc comments) for `AudioPool`, `AudioCache`, and
`AssetSource`. `SfxPlayer._poolFor`'s `AudioPool.create(...)` call never
passed an `audioCache:` argument, so `AudioPool` fell back to its own
default, `AudioCache.instance` — the `audioplayers` package's own global
cache, prefix `'assets/'` — not `FlameAudio.audioCache` (prefix
`'assets/audio/'`, the one every asset in this project actually lives
under). `_poolFor` was also handing it an already-prefixed path
(`'assets/audio/$file'`). Every asset load therefore resolved to
`'assets/' + 'assets/audio/core/<file>'` = `assets/assets/audio/core/
<file>` — doesn't exist, so `rootBundle.load` threw inside `AudioPool.
create`'s player setup. That failed `Future` got permanently memoized by
`_pools`' `putIfAbsent`, so every later `_playPooledAsync` call re-awaited
the same rejected `Future`, threw again, and — since nothing in that call
chain has a `catch`, only a `finally` — the error surfaced only as an
unhandled-Future-error log line, never as visible failure. Net effect:
**every one of the 9 pooled sounds** (tap, damage, projectile-shoot,
level-up, both footstep files, chest-card-chosen, and D-085's
explosion/death) silently no-op'd for the app's entire lifetime, every
session, regardless of the SFX slider. `playChestCardSelect` (the one
sound that was never reported missing) was never affected — it builds its
own raw `AudioPlayer` and sets `audioCache = FlameAudio.audioCache` by
hand, with a bare (non-prefixed) path, which is the actually-correct
shape. Fixed `_poolFor` to match that same shape: `AudioPool.create(...,
audioCache: FlameAudio.audioCache)` with the bare `file` path instead of
`'assets/audio/$file'`.

**Consequences:** `flutter analyze` clean, `flutter test` 122/122
(unchanged — this is asset-loading plumbing, not gameplay logic,
CLAUDE.md §11 — nothing in this codebase's test suite ever exercised real
audio decoding, see D-019). `flutter build apk --debug` succeeds. This is
the one that actually matters for on-device verification: **every**
previous "SFX... on-device verification pending" note back through D-076
was verifying against a system that could never have produced sound in
the first place — footsteps, damage, tap, projectile-shoot, level-up,
chest-card-chosen, explosion, and player-death should all be audible now
for the first time.

---

## D-089 — Fixed a real race: coin/gem round-over credits could be clobbered by the kills write landing last

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer, on-device: "coins and gems are not saved to main
wallet, after completing round. Only kills."

**Decision:** `ArenaGame._endRound()` fired `MetaProgressionRepository.
addCoins`/`addGems`/`addLifetimeKills` concurrently (three separate
`unawaited(...)` calls). Each of those is its own independent
load-modify-save cycle against `SharedPreferences` (DECISIONS D-047's
documented shape) — with all three racing, every `load()` could grab the
same pre-round snapshot before any `save()` landed, and whichever
`save()` finished *last* would write back **all** fields from its own
snapshot, silently reverting the other two to their stale, pre-round
values. `addLifetimeKills` being called last made it the most likely of
the three to win that race, which is exactly the reported symptom (kills
persisted, coins/gems didn't). Fixed by moving the three calls into a new
`_persistRoundRewards()` and awaiting them there *sequentially* — still
fire-and-forget from `_endRound`'s own side (one `unawaited(...)` around
the whole helper, nothing on screen blocks on it), but each `addX` now
starts from the state the previous one actually saved, so there's no
window for one to overwrite another. `addCoins`/`addGems`/
`addLifetimeKills` themselves are unchanged — same three symmetric
methods NEXT.md documents as the pattern for a future 4th persistent
counter; the bug was purely in how the caller invoked them, not in the
methods themselves.

**Consequences:** `flutter analyze` clean, `flutter test` 122/122
(unchanged — round-end persistence isn't exercised by the test suite,
`GameWidget` can't run under `flutter test`, CLAUDE.md §11). `flutter
build apk --debug` succeeds. On-device verification is the developer's
to run: finish a round with nonzero coins, gems, and kills, back out to
Character Select, and confirm all three wallet numbers (not just kills)
reflect the round's haul.

---

## D-090 — External build-time tuning config: `assets/config/game_config.json`

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer: "Create a configuration file with parameters that
get read by the game first time we open it, and when we build or create
an apk build with that configuration so that I can easily influence the
game economy/things, AI spawn/AI damage, Character, etc etc etc. Make
sure starting sound levels is also there." Asked which categories to
cover before touching anything, since "etc etc etc" spans most of
CLAUDE.md §4.3's hardcoded `core/` numbers — developer confirmed all 4
offered: Economy, Enemy AI, Character balance, Progression/leveling, plus
starting audio levels named explicitly in the follow-up.

**Decision:** New `core/game_config.dart`'s `GameConfig` — a process-wide
singleton (same shape as `BgmController`/`SfxPlayer`) that reads and
parses `assets/config/game_config.json` once, in `main()`, *before*
`runApp` — required because `kCharacters`, `EnemyStats`/`BossStats`, the
XP curve, and `Settings.defaults` are all read synchronously by the very
first frame (no `FutureBuilder`, no loading state anywhere downstream), so
the config has to already be populated by then rather than racing the UI
to load. Every getter has a hardcoded fallback matching the file's own
shipped defaults, and [load] never throws past its own `try`/`catch` — a
missing file, a missing section/key (a partial edit), or a malformed file
all silently degrade to "identical to what this project already shipped
with," never a crash. This is a *build-time* file, not a live settings
screen: it's read once per app launch straight out of the installed APK,
so a change requires an actual rebuild (`rebuildinstall.bat`/`flutter
build apk`) to take effect — exactly what was asked for ("when we build
or create an apk build with that configuration").

Wired into a **curated subset** of the existing `core/` constants, chosen
to be genuinely useful tuning knobs without touching every one of the
~150 numbers across `stats.dart`/`game_rules.dart`/`progression.dart`/
`economy.dart`/`data/characters.dart` (deliberately not attempted this
pass — see below):
- **Economy:** `coinValueMultiplier` and `gemDropChanceBonus` (applied at
  `ArenaGame._rollCoins`/`onEnemyKilled`, the same axis Corruption/
  Fortune/SHOP's own multipliers already use — `kCoinValueByRarity`/
  `kGemBaseDropChance`/`kRarityWeights` themselves are untouched, so
  `economy_test.dart`'s direct assertions on those exact numbers still
  hold), plus `bossCoinMultiplier` (was `economy.dart`'s own `const`).
- **Enemy AI:** `Spawner`'s starting/min spawn interval, decay factor, and
  max live enemies; `EnemyStats.maxHp`/`moveSpeedPxPerS`/`contactDamage`;
  `BossStats.maxHp`/`contactDamage`/`boltDamage`;
  `game_rules.dart`'s `kEnemyScalePerLevel` (per-level toughness ramp,
  D-026) and `kEliteChance` (D-035).
- **Character balance:** each `CharacterDef`'s base STR/VIT/DEX/INT
  (`data/characters.dart`) — id/name/descriptor/sprite/attack-kit/unlock-
  threshold stay plain literals, only the 4 base stats per character are
  config-editable this pass.
- **Progression:** `kXpPerKill`, `kBaseXpToNextLevel`, `kXpGrowthFactor`
  (`kBossXpReward` derives from `kXpPerKill` same as before).
- **Starting audio:** `Settings.defaults.sfxVolume`/`musicVolume` — only
  matters for a fresh install; once a player touches a slider,
  `SettingsRepository`'s saved value takes over same as always.

Mechanically, every touched `const` became a `get` getter reading
`GameConfig.instance` (`kCharacters` became a getter function returning a
fresh `List<CharacterDef>`, since its `StatBlock`s are no longer
compile-time constants) — checked every existing call site and test
first for any reliance on compile-time constancy (a `const` context, a
`switch` case, etc.); none exist, so this is purely a "same bare-
identifier read, now backed by a getter instead of a literal" swap with
zero call-site changes needed anywhere outside the ~7 files above.

**What's deliberately NOT in this pass** (keeps the diff reviewable,
matches CLAUDE.md §6 "ask before scope"): the deeper skill-tier tables
(Aura/Mirror/Ray/Thunder/Defence Crystal's per-stack amounts), SHOP item
prices/effects, the exact `kRarityWeights`/`kCoinValueByRarity`/
`kPotionHealByRarity` tables (multiplied via the economy knobs above
instead of replaced), boss timing (teleport cooldown/delay, fire burst
count), and every `StatBlock`-derived combat formula's own coefficients
(`maxHp = 50 + vit*10`, etc.) — those stay hardcoded `core/` constants for
now. `GameConfig.characterStat`'s 3-argument shape (id, stat key,
fallback) generalizes cleanly to more character fields later without a
new mechanism, same as every other documented NEXT.md extension point.

**Consequences:** `flutter analyze` clean, `flutter test` 124/124 (+2 new
in `test/core/game_config_test.dart` — one asserts every getter matches
the real shipped JSON file end-to-end through `TestWidgetsFlutterBinding`'s
real asset bundle, not just the in-code fallback; one covers an unknown
character/stat key falling back to the caller's given default). Verified
the wiring is real, not just compiling: bumped `enemyMaxHp` to a sentinel
`999` in the shipped JSON, re-ran the new test (failed exactly as
expected, `Expected: <20> Actual: <999.0>`), then restored it — confirms
an edited config value actually reaches a `core/` getter through the full
load→parse→override chain. `flutter build apk --debug` succeeds, and the
built APK was inspected directly (`unzip -l`) to confirm
`assets/config/game_config.json` is genuinely bundled at the path
`rootBundle` reads. On-device verification is the developer's to run:
edit a value in `assets/config/game_config.json` (e.g. `enemyMaxHp` or
`startingMusicVolume`), rebuild+install, and confirm the change is
actually felt in a round (or on the Settings screen, for the audio
sliders' starting position on a fresh install / after `adb shell pm clear
com.awwwi.arena`).

---

## D-091 — Pickup SFX, HP/XP bars redesigned as a stacked top HUD, a 20-achievement wallet-reward system

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer, one request: "Add sfx for when you pickup gems/
potions/chests. Make XP bar and hp bar both at the top, as long as the
screen. Make hp bar red, make xp bar yellow. Create an achievements &
rewards system in the main menu, called 'ACHIEVEMENTS' put it inbetween
start and settings. Create a list of 20 achievements that give rewards to
your wallet and implement them. Make sure starting sound levels is also
there" (the last line closed out over from the previous turn's config
work, already covered by D-090's `audio` section).

**Decision — pickup SFX:** New `SfxPlayer.playPickup()`, reusing the
existing tap click (`core/sfx_tap_input.ogg`) at a louder relative volume
rather than a dedicated asset — no pickup-specific sound file exists in
this project yet, and reusing a pooled file already in `_pooledFiles`
needed zero new pool. Wired into the 3 actual collect points:
`ArenaGame.collectGem`, `ArenaGame.collectPotion`, and `ChestComponent.
_startOpening` (the touch/trigger instant, distinct from the explosion SFX
that already plays ~0.35s later when the chest actually pops open — a
chest now has 2 layered beats, touch then explosion, not a replacement of
one by the other). Swapping in a real dedicated asset later is a one-file-
path change in `SfxPlayer.playPickup`, nothing else.

**Decision — HP/XP bar layout:** `HpBarComponent`/`XpBarComponent`
(`game/components/`) both moved to the top of the screen, stacked, full
viewport width — new shared layout constants in `constants.dart`
(`kHudBarSideMarginPx`/`kHudBarTopMarginPx`/`kHudBarHeightPx`/
`kHudBarGapPx`) so the two bars can't drift out of alignment with each
other, and so anything else that needs to lay out relative to them (the
FPS counter, the pause button, the debug DIE button) reads the same
numbers instead of guessing. HP's fill is `ArenaColors.danger` (already
established as "red" everywhere else it's used — God Mode's switch, the
debug DIE button, ROUND OVER); XP's fill is a new `ArenaColors.xp`
(`0xFFF2C94C`, warm yellow), since no yellow existed in the palette.
Real layout fallout from going full-width: the pause button (top-right)
and the debug DIE button (top-center) both used to sit clear of the old
small-boxed HP bar and would now visually collide with the new full-width
bars — both padded down below the stacked bars (`_topOffsetPx`, same
shared constants) rather than left overlapping.

**Decision — achievements system:** New `core/achievements.dart` — 20
`Achievement` entries (`kAchievements`), each gated on one
`AchievementStat` (a lifetime counter) crossing a threshold, paying out a
one-time coin or gem reward. Tiered across every lifetime stat the
round-end flow already had real numbers for (kills, bosses, gems, coins,
chests, potions) plus 2 per-round high-water marks (level reached,
survival time, since those are naturally "best run" not "cumulative").
Deliberately zero imports of `meta_progression.dart` — evaluation works
against a plain `Map<AchievementStat, num>` (`buildStatValues` builds one
from named values) rather than the `MetaProgression` type directly, so
`meta_progression.dart` can import *this* file (to grant rewards) without
the reverse import ever needing to exist; a real two-file import cycle,
avoided by keeping `achievements.dart` a leaf. `MetaProgression` gained 6
new lifetime counters (`lifetimeBossKills`/`lifetimeGemsCollected`/
`lifetimeCoinsEarned`/`lifetimeChestsOpened`/`lifetimePotionsCollected`/
`highestLevelReached`/`longestSurvivalTimeSec`) distinct from the
*spendable* `coins`/`gems` balances (which go down when the player buys
something — an achievement needs a total that only ever goes up, same
reasoning `lifetimeKills` already existed for) plus
`claimedAchievementIds` (same "own it or don't" shape `ownedItemIds`
already has for SHOP). New `MetaProgressionRepository.recordRoundEnd`
supersedes calling `addCoins`/`addGems`/`addLifetimeKills` separately at
round-end (those 3 stay available for any other future single-field
bump): one load, every counter updated in memory, achievements evaluated
and claimed against the *updated* totals, one save — genuinely atomic,
not just sequential awaits like D-089's fix was; a round that crosses two
thresholds at once claims both in the same write. `ArenaGame` gained 3
new round-scoped counters (`bossesKilledThisRound`/`chestsOpenedThisRound`/
`potionsCollectedThisRound`, reset in `resetRound` alongside `kills`/
`coinsEarned`/`gemsCollected`) feeding `_persistRoundRewards`, which now
calls `recordRoundEnd` instead of the old 3 separate `addX` calls.

Rewards are granted automatically the instant a threshold is crossed at
round-end — no "claim" button anywhere. New `ui/screens/
achievements_screen.dart`'s `AchievementsScreen` is read-only progress +
history (a scrollable `ListView`, not a page-carousel like SHOP/Upgrades —
20 items is too many for a fixed non-scrolling page), each row showing
name/description/a progress bar/the reward icon+amount, dimmed until
claimed. New `ACHIEVEMENTS` button on the main menu, between START and
SETTINGS (developer's spec verbatim).

**Consequences:** `flutter analyze` clean, `flutter test` 138/138 (+16
new — `test/core/achievements_test.dart` covers `kAchievements`'
structure (20 entries, unique ids, positive thresholds/rewards, every
`AchievementStat` used at least once) and `isAchievementMet`;
`meta_progression_test.dart` gained round-trip coverage for the 6 new
lifetime fields + `claimedAchievementIds`, and `recordRoundEnd` coverage
(crediting, high-water-mark-only-goes-up, claim-and-grant-exactly-once,
zero-progress-claims-nothing). `flutter build apk --debug` succeeds. Also
fixed a real design flaw surfaced while writing this batch: D-090's own
`game_config_test.dart` had pinned literal "shipped default" values, which
broke the instant the developer actually tuned the file (`xpPerKill`/
`startingSfxVolume`/`startingMusicVolume` had already changed on-device) —
rewritten to parse the same file independently inside the test and compare
`GameConfig`'s getters against *that*, so the test only fails if
`GameConfig`'s own parsing breaks, never because someone used the feature
as intended. On-device verification is the developer's to run: gem/potion/
chest pickups are audible; HP (red) and XP (yellow) bars both sit at the
top, full width, and the pause/debug-die buttons no longer overlap them;
the ACHIEVEMENTS button opens a scrollable list between START and
SETTINGS; playing a round that crosses a threshold (e.g. the first kill,
"First Blood") shows the reward already added to the wallet next time the
screen is checked.

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
- ~~**Progression model**~~ — closed by D-025: in-round only, resets every
  round. No save data needed yet.
- ~~**Power-up delivery**~~ — closed by D-025: mid-round choice popup (1 of
  3), not between-round unlocks.
- ~~**Enemy scaling mechanism**~~ — closed by D-026: linear HP/damage
  multiplier by player level, baked in at spawn. Faster spawns / distinct
  tougher `EnemySkin` tiers stay open as later options if this alone isn't
  enough.
