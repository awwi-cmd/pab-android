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
