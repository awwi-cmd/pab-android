# CLAUDE.md — Pixel Arena Brawl (PAB)

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
clone: follow [§8 Project bootstrap](#8-project-bootstrap).

---

## 1. What this project is

**Pixel Arena Brawl (PAB)** — a top-down survival game for Android, built in
Flutter with the Flame game engine. The player picks one of 4 characters,
each with a distinct attack kit, and drops into a roaming, camera-following
open world with no walls. The character auto-attacks the nearest enemy on
its own cooldown; the player's only job is movement and positioning.
Enemies stream in endlessly from off-screen, scaling with the player's
in-round level; a boss spawns at level milestones. A round ends on death.

**Current baseline: PAB Alpha 1.0.0 (Phase 0).** As of this version the
game has, end to end: a roaming world with an endless floor and
camera-relative spawning; in-round leveling with a 1-of-3 upgrade choice on
level-up (stat bumps and 5 real skills — Aura, Ultimate Mirror, Projectile
Ray, Projectile Thunder, Defence Crystal); 4 playable characters, each with
its own distinct attack behavior (bolt, piercing knife, orbiting spiral
fire, ground slam) and a progression-gated unlock threshold; a boss fight
with a telegraphed teleport and its own ranged attack; a loot economy
(coins, gems, potions, chests opened via a real playing-card reveal) with a
persistent cross-round wallet; a SHOP (15 gem-priced permanent items) and
an UPGRADES screen (12 coin-priced leveled dials) reachable from Character
Select; a 20-achievement ACHIEVEMENTS screen that auto-grants coin/gem
rewards as lifetime stats cross thresholds; a full SFX + BGM audio layer;
a first-boot tutorial; and an external, developer-editable build-time
tuning file (`assets/config/game_config.json`) for economy/AI/character/
progression/starting-audio numbers.

**`PRD.md` is a frozen historical record** of the very first build (a
small fixed-camera arena demo, shipped 2026-09-07) — it does **not**
describe the current game. Its `§9 Explicitly out of scope` no longer
applies; the project has grown well past it. Keep it around for the
original vision/reasoning, but don't treat it as current spec.

**Pre-alpha history (everything before this reset) lives in
`docs/archive/`** — the old `CLAUDE.md`/`TASKS.md`/`DECISIONS.md`/
`NEXT.md`, each renamed `*_pre-alpha.md`, preserved verbatim. That's ~90
logged decisions and 37 build phases of real reasoning — if something
about *why* the codebase looks the way it does isn't explained by the
architecture rules below, it's probably in there. The active `TASKS.md`/
`DECISIONS.md`/`NEXT.md` from here on start fresh at Phase 0 — don't
re-import the old numbering or phase history into them.

Read in this order when picking up work: `TASKS.md` → `DECISIONS.md` →
`NEXT.md` (extension points and rough edges for whoever picks up the next
feature — written for exactly that, keep it current the same way as
`TASKS.md`). `PRD.md` is background only, per above.

**Ask before scope.** If a task seems to require something not already
built and not explicitly asked for, stop and ask rather than guess — this
has come up for real more than once (see the archive) and the answer was
always to stop and ask.

---

## 2. Environment

The developer is on **Windows**, with Android Studio and a `Pixel_10` AVD.

| Thing | Value |
|---|---|
| Flutter SDK | `C:\src\flutter\bin\flutter.bat` — use this full path in scripts, never bare `flutter` |
| AVD name | `Pixel_10` |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` |
| Package id | `com.awwwi.arena` |
| App label (installed app name) | ARENA |
| Project/version name | Pixel Arena Brawl (PAB), Alpha 1.0.0 |
| Flutter project dir | `arena/` (a subfolder of this repo root) |

**Why the full Flutter path:** on this machine `where flutter` turns up both the
extensionless POSIX shim and `flutter.bat`, which breaks quoted `%VAR%` calls in
batch files. Always `set FLUTTER=C:\src\flutter\bin\flutter.bat`.

### Running things
- **You have a real shell (MINGW64/git bash) with direct access to the
  Windows filesystem and the Flutter SDK** — not a sandboxed Linux
  container. You *can* and *should* run
  `C:/src/flutter/bin/flutter.bat analyze`, `test`, and `build apk --debug`
  yourself after every change. Don't just claim something builds — verify it.
  (If a future session finds itself genuinely sandboxed with no filesystem/SDK
  access, the fallback is: say what to run and wait.)
- Prefer running `flutter analyze`/`test`/`build apk --debug` directly for fast
  iteration; use `rebuildinstall.bat` itself (which also (re)launches the
  emulator) when you want the on-device install loop, or tell the developer to
  run it when the change needs eyes/hands on the actual emulator (feel, touch
  input, animation timing) rather than just a clean build.
- Never run `flutter clean` casually — it costs minutes of rebuild.
- **Never drive the emulator UI yourself** (adb input tap/swipe,
  screenshots, uiautomator) to test a change — developer's explicit,
  standing instruction, after a session burned a long stretch fighting a
  resource-starved emulator. `flutter analyze`/`test`/`build apk --debug`
  are still yours to run and verify — that's static/build correctness.
  On-device play (does it look right, does it feel right, does a new
  screen actually navigate) is the developer's to check — end your
  message with what to run and what to look for, then stop.

---

## 3. Repository layout

Kept current as of PAB Alpha 1.0.0 (2026-09-12) — update this tree when
you add a file that will confuse the next person if it's missing here,
same discipline as `TASKS.md`.

```
PixelArenaBrawl/               <- repo root, open this in your editor
├── CLAUDE.md                  <- you are here
├── PRD.md                     <- the original demo's spec (frozen, historical — see §1)
├── TASKS.md                   <- the checklist, keep it current
├── DECISIONS.md               <- why things are the way they are, from Phase 0 forward
├── NEXT.md                    <- extension points + rough edges for the next feature
├── README.md                  <- what a GitHub visitor sees
├── startemulator.bat          <- created on first run (§0)
├── rebuildinstall.bat         <- created on first run (§0)
├── docs/
│   ├── reference/              <- art reference (labelled mockup, not sliceable art)
│   └── archive/                <- pre-alpha CLAUDE.md/TASKS.md/DECISIONS.md/NEXT.md, verbatim
└── arena/                     <- the Flutter project
    ├── pubspec.yaml
    ├── assets/
    │   ├── images/
    │   │   ├── characters/main/       // Apprentice sheets, main-<state>.png
    │   │   ├── characters/second/     // Bruiser sheets, black-<state>.png
    │   │   ├── characters/third/      // Skirmisher sheets, third-<state>.png
    │   │   ├── characters/fourth/     // Warden sheets, fourth-<state>.png
    │   │   ├── characters/enemies/    // 3 grunt skins + boss_map1.png
    │   │   ├── vfx/projectiles/       // bolt + hit-spark + Bruiser's knife
    │   │   ├── vfx/vfx/                // shield/blood/fire/pixel-fire/sparkle/impact/explosion/
    │   │   │                            //   anima — 9x7 grid PNGs
    │   │   ├── consumables/            // gems/money/potions.png (5 rarity cols x N anim rows); coin-icon.png (15-frame single row)
    │   │   ├── ui/                     // star-empty/star-full.png (kill counter), old currency-counter.png placeholder
    │   │   ├── bg/                     // splash_bg.png — native launch screen + main menu background
    │   │   ├── cards/                  // real 52-card deck + 2 Jokers + backs, chest reveal draw
    │   │   └── scenes/                 // floor tile variants + border tile; torch-standing.png (8-frame flicker), gem-vase.png (16-frame shimmer)
    │   ├── audio/
    │   │   └── core/                   // every SFX/BGM file actually wired — see sfx_player.dart/bgm_controller.dart below
    │   └── config/
    │       └── game_config.json        // developer-editable build-time tuning knobs — economy/enemy-AI/character/progression/starting-audio
    └── lib/
        ├── main.dart               // awaits GameConfig.instance.load() before runApp
        ├── app.dart                // MaterialApp, routes, theme; starts BgmController + SfxPlayer once; ThemeData.fontFamily = PixelFont, MediaQuery textScaler 0.75; WidgetsBindingObserver pauses/resumes BGM on app background/foreground
        ├── core/
        │   ├── constants.dart      // design size, ArenaColors (incl. xp yellow, warning amber, danger red), layer priorities, render scales, kHudBar* shared HP/XP bar layout consts
        │   ├── game_config.dart    // GameConfig singleton — parses assets/config/game_config.json once at boot, typed getters with hardcoded fallbacks
        │   ├── stats.dart          // StatBlock + ALL derived-stat formulas, EnemyStats/BossStats (several fields GameConfig-backed)
        │   ├── settings.dart       // Settings model + SharedPreferences I/O (Settings.defaults.sfxVolume/musicVolume GameConfig-backed)
        │   ├── bgm_controller.dart // app-wide singleton: single looping BGM track, fades in, pauses/resumes with app lifecycle
        │   ├── game_rules.dart     // pure gameplay math: targeting, spawn-interval decay, knockback, enemy/boss level-scaling, randomPerimeterPoint, Corruption/Haste/Fortune/Resolve/Magnet/Luck/Regen/Crit dial formulas, elite-roll chance
        │   ├── progression.dart    // XP curve, UpgradeKind (5 skills + stat upgrades), PlayerUpgrades, exclusive-skill pairing, per-character locked upgrades
        │   ├── economy.dart        // ItemRarity + gem/coin/potion value tables, kChestDeck/rollChestCard (54-card chest reward)
        │   ├── shop.dart           // ShopItemId/ShopItem/kShopPages — 15 gem-priced permanent one-time SHOP purchases, 3 non-scrolling carousel pages
        │   ├── sfx_player.dart     // app-wide singleton: every one-shot SFX (footsteps, damage, tap, projectile-shoot, level-up, chest-card select/chosen, explosion, death, pickup), pooled via AudioPool, PlayerMode.lowLatency
        │   ├── meta_progression.dart // MetaStat dials (STR/VIT/DEX/INT/CORRUPTION/HASTE/FORTUNE/RESOLVE/MAGNET/LUCK/REGEN/CRIT), the persistent coins+gems+lifetimeKills+ownedItemIds wallet, 6 more lifetime achievement counters, recordRoundEnd (one atomic round-over write incl. achievement grants)
        │   ├── achievements.dart   // Achievement/kAchievements (20 entries)/buildStatValues/isAchievementMet — zero imports of meta_progression.dart on purpose, avoids a 2-file cycle
        │   └── tutorial_state.dart // one persisted bool (hasSeenIntro) gating the first-boot tutorial
        ├── data/
        │   └── characters.dart     // CharacterDef list (kCharacters, a getter); unlockKillThreshold gates slots 2-4; base STR/VIT/DEX/INT GameConfig-backed
        ├── ui/
        │   ├── screens/
        │   │   ├── main_menu_screen.dart       // Stateful: auto-pushes TutorialScreen on a fresh save, splash_bg.png full-bleed background, circular "?" button, ACHIEVEMENTS button between START/SETTINGS
        │   │   ├── achievements_screen.dart     // scrollable list of kAchievements w/ progress bars; locked/pending/claimed 3-state per card, a CLAIM button on pending ones (rewards no longer auto-grant at round-end)
        │   │   ├── tutorial_screen.dart         // 3-slide first-boot tutorial, same carousel chrome as other multi-page screens, built from real game assets
        │   │   ├── settings_screen.dart         // currency debug always shown; god mode/grant-level-up/end-round only when opened from pause; Music/SFX Volume live-drive their controllers
        │   │   ├── credits_screen.dart
        │   │   ├── character_select_screen.dart // swipe carousel, one character at a time; locked slots show a bar-fill unlock panel; wallet row aligns gems above BONUSES SHOP, coins above CHARACTER UPGRADES; per-character STR/VIT/DEX/INT bars + "Stat Upgrades:"/"Shop Bonuses:" panels below ENTER ARENA
        │   │   ├── shop_screen.dart             // 3-page non-scrolling carousel, 15 buyable kShopItems, gem-priced
        │   │   ├── character_upgrades_screen.dart // (was upgrades_screen.dart) 3-page non-scrolling carousel, all 3 pages scoped to the CharacterDef passed as this route's arguments -- every dial is per-character
        │   │   └── arena_screen.dart            // hosts GameWidget + overlays (RoundOver/LevelUp/PauseMenu/ChestReveal); Round Over's coin/gem/kill counters share one visual language; LevelUp's cards show exclusive-skill pairing; ChestReveal is a real card-deck spin+reveal
        │   └── widgets/                         // buttons, stat bars, shared chrome; coin_icon.dart/gem_icon.dart crop real sprites; tap_sfx.dart's withTapSfx wraps any button's onPressed with the shared tap SFX; skill_icon.dart shared between LevelUp and the tutorial
        └── game/
            ├── arena_game.dart          // FlameGame subclass, ALL round state incl. leveling/achievements-feeding counters; addToWorld/addToHud split
            ├── game_assets.dart         // GameAssets — every SpriteAnimation/Sprite, loaded once, held by ArenaGame
            ├── attack_behavior.dart     // AttackBehavior (+ onEquipped hook) + ProjectileAttack + KnifeAttack + SpiralFireAttack + WardenSlamAttack; every damage calc routed through ArenaGame.resolveAttackDamage
            ├── components/
            │   ├── player.dart              // takeDamage applies resistance + blood-impact VFX; heal() for potions; free movement, no bounds clamp; SHOP bonuses; footstep/damage/projectile-shoot SFX
            │   ├── enemy.dart               // hp/contactDamage scaled by level at spawn; implements Damageable
            │   ├── damageable.dart          // shared hit-detection interface, enemy + boss
            │   ├── boss.dart                // idle/walk/fire/death state machine; teleport is telegraph→delay→pop-in
            │   ├── projectile.dart          // bare-edge bounce vs. margin despawn; tint/targetsPlayer/maxBounces/neverExpire params
            │   ├── projectile_poof.dart     // shrink+drift despawn flourish, shared by every projectile type
            │   ├── knife_projectile.dart    // Bruiser kit: pierces, clean→bloody sprite swap
            │   ├── spiral_fire_projectile.dart // Skirmisher kit: orbiting yin-yang pair
            │   ├── tracking_effect.dart     // VFX glued to a moving target, optional fade-out
            │   ├── spawner.dart             // camera-relative spawn ring + straggler culling; timing/cap GameConfig-backed
            │   ├── gem.dart                 // world pickup, float bob, self-collects near the player; pickup SFX
            │   ├── potion.dart              // world pickup + float bob, heals on touch; pickup SFX
            │   ├── potion_spawner.dart      // periodic random-area drop
            │   ├── chest.dart               // world chest: anima+explosion then a real opening sequence; pickup SFX on touch
            │   ├── chest_spawner.dart       // periodic random-area drop, same shape as potion_spawner.dart
            │   ├── torch.dart               // solid world obstacle, looping flicker; player/enemy collision resolved in their own update()
            │   ├── torch_spawner.dart       // random placement + min-spacing rejection + straggler cull, GameConfig-backed
            │   ├── vase.dart                // breakable world pickup: card-chosen SFX + sparkle burst + left/right gem scatter on touch
            │   ├── vase_spawner.dart        // random placement + min-spacing rejection, GameConfig-backed
            │   ├── hp_bar.dart              // HUD (camera.viewport), top of screen, full width, red fill
            │   ├── xp_bar.dart              // stacked directly under the HP bar, full width, yellow fill
            │   ├── damage_text.dart
            │   ├── arena_floor.dart         // endless tiling from camera.visibleWorldRect, no border
            │   ├── aura.dart                // Aura skill: shield-ring visual, area-tick damage
            │   ├── mirror.dart              // Ultimate Mirror skill: cycling turret, staggered phase, immortal bolts
            │   ├── ray_beam.dart            // Projectile Ray skill: visual only, hit-test lives in ArenaGame
            │   └── defence_crystal.dart     // Defence Crystal skill: figure-8 orbit visual only, stat bonus on PlayerUpgrades
            ├── input/
            │   ├── movement_input.dart    // the 3 control schemes, scheme-agnostic Vector2
            │   └── joystick_overlay.dart  // the 3 schemes' actual Flutter touch capture
            └── anim/
                ├── anim_state.dart            // AnimState enum, every state incl. unbuilt ones
                ├── sheet_loader.dart          // generic "slice a uniform-cell sheet" loader
                ├── character_animations.dart  // per-character sheet loading
                └── enemy_animations.dart      // EnemySkin + per-skin run/death animations
```

---

## 4. Architecture rules

These are the rules that keep the codebase from turning into a mess. They
are not negotiable without a new entry in `DECISIONS.md`.

1. **Flutter owns the menus, Flame owns the arena.** Main menu, settings,
   credits, character select, shop, upgrades, achievements are ordinary
   Flutter widgets and routes. The arena is a single `GameWidget` hosting
   `ArenaGame`. Do not build menus inside Flame; do not build gameplay in
   widgets.

2. **Round Over, Level Up, the Pause Menu, and the Chest Reveal are Flame
   overlays, not routes.** The frame underneath must stay visible/paused
   behind them. A `GameWidget` overlay must be registered in
   `overlayBuilderMap` before `ArenaGame` ever calls `overlays.add`/`remove`
   on it — doing so from `onLoad()`/`resetRound()` (before `GameWidget`
   finishes mounting) throws an assertion that gets silently swallowed and
   looks like a hang, not a crash (hit for real once, see the archive's
   D-025 if it ever needs re-litigating). The debug DIE button and the
   pause button are the deliberate exception: plain Flutter widgets, not
   Flame overlays, gated by the same `roundOver`/`menuOpen` `ValueNotifier`s
   the movement-input overlay uses — simpler than fighting the
   registration-order rule for something that doesn't need to render
   *inside* Flame's canvas.

3. **All combat/gameplay numbers come from `core/`, never typed inline.**
   `core/stats.dart` (`StatBlock`, `EnemyStats`, `BossStats`) for anything
   derived from a character's 4 stats or an enemy's flat stats.
   `core/progression.dart` for XP/level/upgrade amounts. `core/game_rules.dart`
   for gameplay *math* that isn't a stat exactly — targeting, spawn-interval
   decay, knockback distance — kept here specifically because it has no
   Flame `Component`/`Game` dependency, which means it can be unit-tested
   the way nothing inside an `update()` method can (see rule 11). A value
   meant to be developer-tunable without a rebuild-from-source edit belongs
   in `core/game_config.dart`/`assets/config/game_config.json` instead —
   see that file's own doc comment for the pattern. If you find yourself
   typing a number or a formula anywhere else, stop and put it in one of
   these places. This is the single most important rule in the file — the
   tuning phase depends on it.

4. **Enemies and projectiles are pooled or at least cheap.** Target is 60
   live enemies. Do not allocate per frame in `update()`; no `Vector2`
   construction in hot loops — mutate in place with `setFrom`/`setValues`.

5. **`ArenaGame` owns round state** — elapsed time, kills, damage dealt,
   spawn interval, level/XP/upgrade bonuses, and every achievement-feeding
   round counter — and resets ALL of it in `onLoad`/`resetRound`. Never
   carry state across rounds via globals or singletons. A fresh arena
   entry must look exactly like the first one. This includes debug state
   (`debugGodMode`, pending debug level-ups) — it's still round state, just
   developer-triggered instead of gameplay-triggered.

6. **Input goes through `MovementInput`.** Game components read a normalised
   `Vector2`. They never know which control scheme is active.

7. **Animation states are an enum, not strings.** `AnimState` lists every
   state, including ones not yet built. Adding an animation later must be
   a data change.

8. **Pixel art is never smoothed.** Nearest-neighbour everywhere
   (`FilterQuality.none`, `Paint()..filterQuality = FilterQuality.none`). If
   something looks blurry, that is a bug, not a style choice.

9. **No new dependencies without an entry in `DECISIONS.md`.** The intended
   set is `flame`, `flame_audio`, `shared_preferences`, and nothing else.
   Do not add a state-management library.

10. **Layer order via `priority` constants** in `constants.dart`, not magic
    ints scattered through components.

11. **`GameWidget` cannot be exercised under `flutter test`.** Real asset
    decoding through Flame's image cache never resolves under the
    fake-async test clock, no `tester.runAsync` positioning fixes it.
    Don't spend time re-litigating this; it's a harness limitation, not a
    bug to fix. The actual fix is rule 3: pull gameplay *logic* (not
    rendering) into plain functions/classes in `core/` that don't touch
    `Component`/`Game`, and unit-test those directly — that's the only way
    this codebase's gameplay rules get regression coverage at all.
    Automated widget-test coverage stops at Character Select; verify
    anything past that on-device.

12. **Character-specific behavior is a strategy object on `CharacterDef`,
    not a branch in `ArenaGame`.** `attackBehavior: AttackBehavior`
    (`game/attack_behavior.dart`) is the existing example — `ArenaGame`
    only owns the cooldown timer and calls `perform(this)`, it has no idea
    what kind of attack that is. A melee character, a second
    independently-cooling ability, a skill — each is a new class
    implementing the relevant interface, not new `if`/`switch` branches in
    `ArenaGame` or `PlayerComponent`. If you're about to add a
    per-character `if` to either of those files, stop and make it a
    strategy object instead.

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

- **Small, verifiable steps.** One `TASKS.md` item at a time. After each,
  the app should still build and run — never leave the tree in a state
  where `rebuildinstall.bat` fails.
- **Update `TASKS.md` as you go.** Tick items off, add ones you discover.
  It is the shared picture of where the project is; a stale checklist is
  worse than none.
- **Log decisions.** Any time you choose between real alternatives — a
  package, an architectural split, a tuning approach, a workaround for an
  engine limitation, a real bug's root cause — add an entry to
  `DECISIONS.md` in the existing format. Do not silently decide.
- **Ask before scope.** If a task seems to require something not already
  built and not explicitly requested, stop and ask.
- **After a change the developer must verify**, end your message with what
  to run and what to look for. Example: "Run `rebuildinstall.bat`. You
  should see the spawn animation play for ~1s before the first enemy
  appears."

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
| `cd arena && C:\src\flutter\bin\flutter.bat build apk --release` | Signed-by-debug-key release build, for a GitHub release upload |
| `adb devices` | Check what is connected |
| `adb logcat -s flutter` | App logs only |

Typical rhythm: `startemulator.bat` once at the start of a session, then
`flutter run` for iteration, then `rebuildinstall.bat` when you want a clean
installed build.

---

## 8. Project bootstrap

If `arena/` does not exist yet, do this once, then update `TASKS.md`:

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
5. Record the resolved `flame` version in `DECISIONS.md`.
6. Delete the counter-app boilerplate from `lib/main.dart` — do not build on top
   of it.

---

## 9. Bootstrap scripts

Create these two files **verbatim** in the repo root on first run (§0).

### `startemulator.bat`

```bat
@echo off
REM ============================================================
REM  Pixel Arena Brawl (PAB) - start the Pixel_10 emulator
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
REM  Pixel Arena Brawl (PAB) - rebuild & reinstall debug APK
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
