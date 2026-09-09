# CLAUDE.md — ARENA

Instructions for Claude Code working in this repository. Read this fully before
touching anything.

---

## 0. FIRST RUN — BOOTSTRAP

**If `startemulator.bat` and `rebuildinstall.bat` do not exist in the repo root,
create them before doing anything else.** Write them exactly as given in
[§9 Bootstrap scripts](#9-bootstrap-scripts) — do not improvise, do not
"improve" them, do not convert them to PowerShell. They are known-good on this
machine. Then tell the user they were created and what each one does.

If the Flutter project directory `arena/` does not exist either, this is a fresh
clone of the plan folder: follow [§8 Project bootstrap](#8-project-bootstrap).

---

## 1. What this project is

A top-down survival game for Android, built in Flutter with the Flame game
engine. The player picks a character and moves it around; the character
auto-attacks the nearest enemy while enemies stream in from off-screen.
Round ends on death. Originally a walled, fixed-camera arena (the demo, PRD.md) —
**Phase 9 (started) is converting this to a Vampire-Survivors-style roaming
world**: no bounds, camera follows the player through an effectively
infinite space (DECISIONS D-040). Built incrementally, one slice at a time
(developer's explicit call) — see TASKS.md Phase 9 for what's landed vs.
still a known gap.

**The demo (TASKS Phases 0-6) was called done 2026-09-07.** `PRD.md` describes
that demo and is frozen as a record of it — `§9 Explicitly out of scope` there
was binding *for the demo* and mostly still is, but the project has moved past
it: **Phase 7 (in-round leveling, upgrade choices, pause menu, enemy scaling,
and the Aura skill) is built** — see DECISIONS D-025/D-026/D-027. **Phase 8
(roster expansion — all 4 characters unlocked and playable) is started** —
see D-028. **Phase 9 (roaming world: camera + free movement) is started** —
see D-040. **Phase 10 (boss fight, SFX, loot economy) is built** — see
D-042/D-043/D-044. **Phase 11 (persistent meta-progression: SHOP + UPGRADES
from character select) is built** — see D-047. **Phase 12 (four new powers:
Ultimate Mirror, Projectile Ray, Projectile Thunder, Defence Crystal) is
built, on-device verification pending** — see D-049. **Phase 13
(progression-gated character unlocks, swipe-carousel character select, and
a chest economy with a persistent gem wallet) is built, on-device
verification pending** — see D-055. **The Warden's own `AttackBehavior`
(TASKS 8.3's last open sub-item — closes the CLAUDE.md §4.12 "every
character has a distinct kit" goal) is built, on-device verification
pending** — see D-056. **A debug end-round button (Settings' debug section)
and chest rewards drawn from a real playing-card deck instead of a
gem-rarity group are built, on-device verification pending** — see D-057.
**Chest reveal polish (overflow fix, card-back shuffle lead-in, jump/land
bounce) plus main-menu-reachable currency debug tools and a batch of
gem-drop/gem-float/boss-anima/Aura/Ultimate-Mirror tunes are built,
on-device verification pending** — see D-058/D-059. **The chest reveal's
real overflow fix, and a reworked boss teleport (destination telegraph,
0.5s delay, arrival size-down/up pop, longer distance) are built,
on-device verification pending** — see D-060. **Chest reveal confetti and
every projectile type despawning further off-screen instead of at the bare
visible edge are built, on-device verification pending** — see D-061. This
is real, ongoing post-demo work now, not speculative scope;
new post-demo phases get their own section in `TASKS.md` the same way, not
dumped in the Backlog.
The Backlog is still binding for what hasn't been explicitly asked for — keep
asking before building ahead of what's actually been requested (CLAUDE.md §6
"Ask before scope" — this has come up for real more than once and the answer
each time was to stop and ask, not guess).

Read in this order when picking up work: `PRD.md` → `TASKS.md` → `DECISIONS.md`
→ `NEXT.md` (extension points and rough edges for whoever picks up the next
feature — written for exactly that, keep it current the same way as TASKS.md).

---

## 2. Environment

The developer is on **Windows**, with Android Studio and a `Pixel_10` AVD.

| Thing | Value |
|---|---|
| Flutter SDK | `C:\src\flutter\bin\flutter.bat` — use this full path in scripts, never bare `flutter` |
| AVD name | `Pixel_10` |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` |
| Package id | `com.awwwi.arena` |
| App name | ARENA |
| Flutter project dir | `arena/` (a subfolder of this repo root) |

**Why the full Flutter path:** on this machine `where flutter` turns up both the
extensionless POSIX shim and `flutter.bat`, which breaks quoted `%VAR%` calls in
batch files. Always `set FLUTTER=C:\src\flutter\bin\flutter.bat`.

### Running things
- **Verified 2026-09-07: on this machine you have a real shell (MINGW64/git
  bash) with direct access to the Windows filesystem and the Flutter SDK** —
  not a sandboxed Linux container. You *can* and *should* run
  `C:/src/flutter/bin/flutter.bat analyze`, `test`, and `build apk --debug`
  yourself after every change, the same way `stats_test.dart`/
  `game_rules_test.dart`/`progression_test.dart` etc. have been run and kept
  green throughout this project. Don't just claim something builds — verify it.
  (If a future session finds itself genuinely sandboxed with no filesystem/SDK
  access, the old guidance still applies: say what to run and wait.)
- Prefer running `flutter analyze`/`test`/`build apk --debug` directly for fast
  iteration; use `rebuildinstall.bat` itself (which also (re)launches the
  emulator) when you want the on-device install loop, or tell the developer to
  run it when the change needs eyes/hands on the actual emulator (feel, touch
  input, animation timing) rather than just a clean build.
- Never run `flutter clean` casually — it costs minutes of rebuild.
- **Never drive the emulator UI yourself (adb input tap/swipe, screenshots,
  uiautomator) to test a change.** Developer's explicit instruction
  (2026-09-09), after a session burned a long stretch fighting a
  resource-starved emulator (repeated "System UI isn't responding" ANRs,
  the app's own task getting killed) trying to tap through to the arena.
  `flutter analyze`/`test`/`build apk --debug` are still yours to run and
  verify — that's static/build correctness. On-device play (does it look
  right, does it feel right, does a new screen actually navigate) is the
  developer's to check, same as every other on-device item already in this
  file (TASKS 6.2-6.5, 8.2, 9.2, etc.) — end your message with what to run
  and what to look for, then stop.

---

## 3. Repository layout

Kept current as of Phase 13 (2026-09-09) — update this tree when you add a
file that will confuse the next person if it's missing here, same discipline
as `TASKS.md`.

```
ArenaDemo/                    <- repo root, open this in your editor
├── CLAUDE.md                 <- you are here
├── PRD.md                    <- what the demo was (frozen; see §1 above)
├── TASKS.md                  <- the checklist, keep it current
├── DECISIONS.md              <- why things are the way they are
├── NEXT.md                   <- extension points + rough edges for the next feature
├── startemulator.bat         <- created on first run (§0)
├── rebuildinstall.bat        <- created on first run (§0)
├── docs/
│   └── reference/            <- art reference (labelled mockup, not sliceable art)
└── arena/                    <- the Flutter project
    ├── pubspec.yaml
    ├── assets/
    │   ├── images/
    │   │   ├── characters/main/       // Apprentice sheets, main-<state>.png (D-015)
    │   │   ├── characters/second/     // Bruiser sheets, black-<state>.png (D-028)
    │   │   ├── characters/third/      // Skirmisher sheets, third-<state>.png (D-028)
    │   │   ├── characters/fourth/     // Warden sheets, fourth-<state>.png (D-028)
    │   │   ├── characters/enemies/    // 3 grunt skins + boss_map1.png (D-022/D-042)
    │   │   ├── vfx/projectiles/       // bolt + hit-spark + Bruiser's knife (D-029)
    │   │   ├── vfx/vfx/                // shield/blood/fire/pixel-fire/sparkle/impact/explosion/
    │   │   │                            //   anima — 9x7 grid PNGs — D-032/D-033/D-034/D-035/D-042
    │   │   ├── consumables/            // gems/money/potions.png, 5 rarity cols x N anim rows (D-043)
    │   │   ├── ui/                     // currency-counter.png (round-over "big red coin", D-043)
    │   │   ├── cards/                  // real 52-card deck + 2 Jokers + backs, chest reveal draw (D-057)
    │   │   └── scenes/                // floor tile variants + border tile (D-023)
    │   └── audio/
    │       └── core/                  // sfx-explosion.wav, sfx-you-died.wav (D-044)
    └── lib/
        ├── main.dart              // runApp only
        ├── app.dart               // MaterialApp, routes, theme
        ├── core/
        │   ├── constants.dart     // design size, colors, layer priorities, render scales
        │   ├── stats.dart         // StatBlock + ALL derived-stat formulas, EnemyStats
        │   ├── settings.dart      // Settings model + SharedPreferences I/O
        │   ├── game_rules.dart    // pure gameplay math (targeting, spawn decay, knockback,
        │   │                      //   enemy/boss level-scaling D-026/D-042, randomPerimeterPoint D-041)
        │   ├── progression.dart   // XP curve, UpgradeKind (Aura + Mirror/Ray/Thunder/Crystal), PlayerUpgrades — D-025/D-027/D-049
        │   ├── economy.dart       // ItemRarity + gem/coin/potion value tables; kChestDeck/rollChestCard (54-card chest reward) — D-043/D-057
        │   └── meta_progression.dart // MetaStat (STR/VIT/DEX/INT/CORRUPTION), coins+gems+lifetimeKills wallet; debugAdjustCoins/debugAdjustGems/debugResetWallet — D-047/D-055/D-059
        ├── data/
        │   └── characters.dart    // CharacterDef list; unlockKillThreshold gates slots 2-4 — D-028/D-055
        ├── ui/
        │   ├── screens/
        │   │   ├── main_menu_screen.dart
        │   │   ├── settings_screen.dart        // currency debug always shown; god mode/grant-level-up/end-round only when opened from pause (D-025/D-059)
        │   │   ├── credits_screen.dart
        │   │   ├── character_select_screen.dart // swipe carousel, one character at a time; locked slots show a bar-fill unlock panel — D-055
        │   │   ├── shop_screen.dart       // empty placeholder, back button only — D-047
        │   │   ├── upgrades_screen.dart   // 5 MetaStat rows, buy buttons — D-047
        │   │   └── arena_screen.dart      // hosts GameWidget + overlays (RoundOver/LevelUp/PauseMenu/ChestReveal)
        │   └── widgets/                   // buttons, stat bars, shared chrome
        └── game/
            ├── arena_game.dart            // FlameGame subclass, ALL round state incl. leveling; addToWorld/addToHud split — D-040.
            │                              //   Split from ~820 lines (D-045/D-048): asset loading moved to game_assets.dart
            ├── game_assets.dart           // GameAssets — every SpriteAnimation/Sprite, loaded once, held by ArenaGame — D-045/D-048
            ├── attack_behavior.dart       // AttackBehavior (+ onEquipped hook) + ProjectileAttack + KnifeAttack + SpiralFireAttack + WardenSlamAttack — D-024/D-029/D-034/D-036/D-056
            ├── components/
            │   ├── player.dart              // takeDamage applies Defence Crystal resistance + blood-impact VFX (D-033/D-049); heal() for potions (D-043); free movement, no bounds clamp (D-040)
            │   ├── enemy.dart              // hp/contactDamage scaled by level at spawn (D-026); implements Damageable (D-042)
            │   ├── damageable.dart          // shared hit-detection interface, enemy + boss — D-042
            │   ├── boss.dart                // idle/walk/fire/death state machine; teleport is telegraph->0.5s delay->pop-in, longer distance — D-042/D-060
            │   ├── projectile.dart          // _outOfBounds (bare edge, bounce trigger) vs _farOutOfBounds (margin, real despawn) — D-040/D-042/D-051/D-052/D-059/D-061; tint/targetsPlayer/maxBounces/neverExpire params
            │   ├── projectile_poof.dart     // shrink+drift despawn flourish, shared by every projectile type — D-053
            │   ├── knife_projectile.dart    // Bruiser kit: pierces, clean->bloody sprite swap; despawn margin — D-029/D-061
            │   ├── spiral_fire_projectile.dart // Skirmisher kit: orbiting yin-yang pair; despawn margin — D-034/D-061
            │   ├── tracking_effect.dart      // VFX glued to a moving target, optional fade-out — D-034/D-035/D-036
            │   ├── spawner.dart              // camera-relative spawn ring + straggler culling — D-041
            │   ├── gem.dart                  // world pickup, float bob, self-collects near the player — D-043/D-059
            │   ├── potion.dart               // world pickup + float bob, heals on touch — D-043/D-059
            │   ├── potion_spawner.dart       // periodic random-area drop — D-043
            │   ├── chest.dart                // world chest: anima+explosion then chest_01-12 opening sequence — D-055
            │   ├── chest_spawner.dart        // periodic random-area drop, same shape as potion_spawner.dart — D-055
            │   ├── hp_bar.dart               // now on camera.viewport (HUD), not world — D-040
            │   ├── damage_text.dart
            │   ├── arena_floor.dart          // endless tiling from camera.visibleWorldRect, no border — D-041
            │   ├── aura.dart                // Aura skill: shield-ring visual, area-tick damage — D-027/D-032
            │   ├── mirror.dart              // Ultimate Mirror skill: cycling turret, staggered per-mirror phase, random fire axis, immortal bolts — D-049/D-050/D-059
            │   ├── ray_beam.dart            // Projectile Ray skill: visual only, hit-test lives in ArenaGame — D-049
            │   └── defence_crystal.dart     // Defence Crystal skill: figure-8 orbit visual only, stat bonus on PlayerUpgrades — D-049
            ├── input/
            │   ├── movement_input.dart    // the 3 control schemes, scheme-agnostic Vector2
            │   └── joystick_overlay.dart  // the 3 schemes' actual Flutter touch capture
            └── anim/
                ├── anim_state.dart            // AnimState enum, every state incl. unbuilt ones
                ├── sheet_loader.dart          // generic "slice a uniform-cell sheet" loader
                ├── character_animations.dart  // per-character sheet loading, D-024 prefix
                └── enemy_animations.dart      // EnemySkin + per-skin run/death animations
```

---

## 4. Architecture rules

These are the rules that keep the demo from turning into a mess. They are not
negotiable without a new entry in `DECISIONS.md`.

1. **Flutter owns the menus, Flame owns the arena.** Main menu, settings, credits
   and character select are ordinary Flutter widgets and routes. The arena is a
   single `GameWidget` hosting `ArenaGame`. Do not build menus inside Flame; do
   not build gameplay in widgets.

2. **Round Over, Level Up, and the Pause Menu are Flame overlays, not routes.**
   The frame underneath must stay visible/paused behind them. A `GameWidget`
   overlay must be registered in `overlayBuilderMap` before `ArenaGame` ever
   calls `overlays.add`/`remove` on it — doing so from `onLoad()`/`resetRound()`
   (before `GameWidget` finishes mounting) throws an assertion that gets
   silently swallowed and looks like a hang, not a crash (hit for real once,
   see D-025's writeup). `DebugDie` and the pause button are the deliberate
   exception: plain Flutter widgets, not Flame overlays, gated by the same
   `roundOver`/`menuOpen` `ValueNotifier`s the movement-input overlay uses —
   simpler than fighting the registration-order rule for something that
   doesn't need to render *inside* Flame's canvas.

3. **All combat/gameplay numbers come from `core/`, never typed inline.**
   `core/stats.dart` (`StatBlock`, `EnemyStats`) for anything derived from a
   character's 4 stats or an enemy's flat stats. `core/progression.dart` for
   XP/level/upgrade amounts. `core/game_rules.dart` for gameplay *math* that
   isn't a stat exactly — targeting, spawn-interval decay, knockback distance
   — kept here specifically because it has no Flame `Component`/`Game`
   dependency, which means it can be unit-tested the way nothing inside an
   `update()` method can (`GameWidget` can't run under `flutter test`, see
   rule 11). If you find yourself typing a number or a formula anywhere else,
   stop and put it in one of these three files. This is the single most
   important rule in the file — the tuning phase depends on it.

4. **Enemies and projectiles are pooled or at least cheap.** Target is 60 live
   enemies. Do not allocate per frame in `update()`; no `Vector2` construction in
   hot loops — mutate in place with `setFrom`/`setValues`.

5. **`ArenaGame` owns round state** — elapsed time, kills, damage dealt, spawn
   interval, and (since Phase 7) level/XP/upgrade bonuses — and resets ALL of it
   in `onLoad`/`resetRound`. Never carry state across rounds via globals or
   singletons. A fresh arena entry must look exactly like the first one. This
   includes debug state (`debugGodMode`, pending debug level-ups) — it's still
   round state, just developer-triggered instead of gameplay-triggered.

6. **Input goes through `MovementInput`.** Game components read a normalised
   `Vector2`. They never know which control scheme is active.

7. **Animation states are an enum, not strings.** `AnimState` lists every state in
   the PRD §8, including the ones not yet built. Adding an animation later must be
   a data change.

8. **Pixel art is never smoothed.** Nearest-neighbour everywhere
   (`FilterQuality.none`, `Paint()..filterQuality = FilterQuality.none`). If
   something looks blurry, that is a bug, not a style choice.

9. **No new dependencies without an entry in `DECISIONS.md`.** The intended set is
   `flame`, `flame_audio`, `shared_preferences`, and nothing else. Do not add a
   state-management library — the demo does not need one.

10. **Layer order via `priority` constants** in `constants.dart`, not magic ints
    scattered through components.

11. **`GameWidget` cannot be exercised under `flutter test`.** Confirmed twice
    now (D-019, D-024/D-025) — real asset decoding through Flame's image cache
    never resolves under the fake-async test clock, no `tester.runAsync`
    positioning fixes it. Don't spend time re-litigating this; it's a harness
    limitation, not a bug to fix. The actual fix is rule 3: pull gameplay
    *logic* (not rendering) into plain functions/classes in `core/` that don't
    touch `Component`/`Game`, and unit-test those directly — that's the only
    way this codebase's gameplay rules get regression coverage at all.
    Automated widget-test coverage stops at Character Select; verify anything
    past that on-device.

12. **Character-specific behavior is a strategy object on `CharacterDef`, not a
    branch in `ArenaGame`.** `attackBehavior: AttackBehavior`
    (`game/attack_behavior.dart`) is the existing example — `ArenaGame` only
    owns the cooldown timer and calls `perform(this)`, it has no idea what
    kind of attack that is. A melee character, a second independently-cooling
    ability, a skill — each is a new class implementing the relevant
    interface, not new `if`/`switch` branches in `ArenaGame` or
    `PlayerComponent`. If you're about to add a per-character `if` to either
    of those files, stop and make it a strategy object instead.

---

## 5. Code conventions

- Dart standard style; `flutter analyze` must be clean before you call anything
  done. Prefer `const` constructors, `final` fields.
- Files and directories `snake_case.dart`. Classes `PascalCase`. Private members
  `_leadingUnderscore`.
- Comment **why**, not what. A comment explaining a tuning value or a workaround is
  valuable; a comment restating the line above it is noise.
- Keep files under ~300 lines. If a component grows past that, it is doing two
  things.
- Do not write tests for visual/gameplay feel. **Do** write plain Dart unit tests
  for `core/stats.dart` formulas and anything with arithmetic that can silently
  drift.

---

## 6. Working style

- **Small, verifiable steps.** One TASKS.md item at a time. After each, the app
  should still build and run — never leave the tree in a state where
  `rebuildinstall.bat` fails.
- **Update `TASKS.md` as you go.** Tick items off, add ones you discover. It is
  the shared picture of where the project is; a stale checklist is worse than none.
- **Log decisions.** Any time you choose between real alternatives — a package, an
  architectural split, a tuning approach, a workaround for an engine limitation —
  add an entry to `DECISIONS.md` in the existing format. Do not silently decide.
- **When the PRD is wrong, say so.** The PRD is a starting point written before any
  code existed. If building reveals it is mistaken, raise it and propose the change
  rather than quietly diverging.
- **Ask before scope.** If a task seems to require something in PRD §9
  (out of scope), stop and ask.
- **After a change the developer must verify**, end your message with what to run
  and what to look for. Example: "Run `rebuildinstall.bat`. You should see the
  spawn animation play for ~1s before the first enemy appears."

---

## 7. Common commands

Run from the repo root on Windows:

| Command | What |
|---|---|
| `startemulator.bat` | Boots the Pixel_10 AVD. **That window is the emulator** — closing it kills it. Leave it open. |
| `rebuildinstall.bat` | Deletes the old debug APK, launches the emulator if none is running, builds and installs. This is the main loop. |
| `cd arena && C:\src\flutter\bin\flutter.bat run` | Hot-reload session — much faster for UI iteration than a full rebuild |
| `cd arena && C:\src\flutter\bin\flutter.bat analyze` | Static analysis, must be clean |
| `cd arena && C:\src\flutter\bin\flutter.bat test` | Unit tests |
| `adb devices` | Check what is connected |
| `adb logcat -s flutter` | App logs only |

Typical rhythm: `startemulator.bat` once at the start of a session, then
`flutter run` for iteration, then `rebuildinstall.bat` when you want a clean
installed build.

---

## 8. Project bootstrap

If `arena/` does not exist yet, do this once, then update TASKS.md:

```bat
cd /d "<repo root>"
C:\src\flutter\bin\flutter.bat create --org com.awwwi --project-name arena --platforms=android arena
cd arena
C:\src\flutter\bin\flutter.bat pub add flame flame_audio shared_preferences
```

Then:
1. Lock portrait orientation in `main.dart`
   (`SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`).
2. Set the app label to `ARENA` in `android/app/src/main/AndroidManifest.xml`.
3. Set `minSdkVersion` to 24 in `android/app/build.gradle` if it is lower.
4. Declare the `assets/` folders in `pubspec.yaml`.
5. Record the resolved `flame` version in `DECISIONS.md` under D-002.
6. Delete the counter-app boilerplate from `lib/main.dart` — do not build on top
   of it.

---

## 9. Bootstrap scripts

Create these two files **verbatim** in the repo root on first run (§0).

### `startemulator.bat`

```bat
@echo off
REM ============================================================
REM  ARENA - start the Pixel_10 emulator
REM  Double-click to run. This window IS the emulator process --
REM  closing this window (or Ctrl+C) closes the emulator with it.
REM  Leave it open while you build/install/play; close it when done.
REM ============================================================
setlocal enabledelayedexpansion

set EMULATOR=%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe
set AVD=Pixel_10

if not exist "%EMULATOR%" (
    echo Emulator not found at %EMULATOR%
    echo Check the Android SDK install location.
    pause
    exit /b 1
)

echo.
echo === Checking for an already-running device/emulator ===
adb devices | findstr /r /c:"device$" >nul
if %errorlevel%==0 (
    echo A device/emulator is already online. Not starting a second one.
    echo Close this window, or run "adb devices" to see what is connected.
    pause
    exit /b 0
)

echo.
echo === Starting %AVD% ===
echo This window is the emulator. Closing it shuts the emulator down.
echo.
"%EMULATOR%" -avd %AVD%

echo.
echo === Emulator process ended ===
pause
```

### `rebuildinstall.bat`

```bat
@echo off
REM ============================================================
REM  ARENA - rebuild & reinstall debug APK
REM  Double-click to run. Deletes old debug APK, rebuilds,
REM  installs on running emulator (launches Pixel_10 if needed).
REM ============================================================
setlocal enabledelayedexpansion
cd /d "%~dp0arena"

REM --- always use the known full path (avoids PATH ambiguity between the
REM     extensionless posix "flutter" shim and "flutter.bat" that "where"
REM     turns up together, which breaks quoted %VAR% calls below) ---
set FLUTTER=C:\src\flutter\bin\flutter.bat

set "APK=build\app\outputs\flutter-apk\app-debug.apk"

echo.
echo === 1. Delete old debug APK ===
if exist "%APK%" (
    del /f /q "%APK%"
    echo Deleted %APK%
) else (
    echo No existing APK found, skipping.
)

echo.
echo === 2. Check for running emulator ===
adb devices | findstr /r /c:"device$" >nul
if %errorlevel%==0 goto deviceready

echo No device/emulator online. Launching Pixel_10...
start "" "%FLUTTER%" emulators --launch Pixel_10
echo Waiting for emulator to come online, can take 30 to 90 seconds...

:waitloop
timeout /t 5 >nul
adb devices | findstr /r /c:"device$" >nul
if %errorlevel% neq 0 goto waitloop
echo Emulator online.
goto afterdevice

:deviceready
echo Device/emulator already online.

:afterdevice

echo.
echo === 3. Build debug APK ===
call "%FLUTTER%" build apk --debug
if %errorlevel% neq 0 (
    echo.
    echo BUILD FAILED. See errors above.
    pause
    exit /b 1
)

echo.
echo === 4. Install on emulator ===
call "%FLUTTER%" install --debug
if %errorlevel% neq 0 (
    echo.
    echo INSTALL FAILED. See errors above.
    pause
    exit /b 1
)

echo.
echo === Done. com.awwwi.arena installed and ready. ===
pause
```

**Note:** `rebuildinstall.bat` assumes the Flutter project lives in `arena/`
next to the script. If the project folder is ever renamed, update the `cd /d`
line and the package id in the final echo.
