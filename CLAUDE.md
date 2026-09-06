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

A top-down arena survival game for Android, built in Flutter with the Flame game
engine. The player picks a character and moves it around a walled arena; the
character auto-attacks the nearest enemy while enemies stream in from off-screen.
Round ends on death.

**Current phase: the demo.** The demo's whole job is to make the flow real and
installable so that animation and skill work has somewhere to live. `PRD.md` is
the contract for what the demo contains; `§9 Explicitly out of scope` in the PRD
is binding. Do not build ahead of it.

Read in this order when picking up work: `PRD.md` → `TASKS.md` → `DECISIONS.md`.

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
- You are typically running in a Linux container, **not** on the Windows machine.
  You can read, write, and reason about the code, but you generally cannot run
  `flutter build` yourself. **The developer runs the scripts.** When you finish a
  change that needs verifying, say: "run `rebuildinstall.bat`", and wait.
- If you *do* have a shell on the Windows machine, use the two `.bat` scripts
  rather than raw flutter commands, so behaviour matches what the developer sees.
- Never run `flutter clean` casually — it costs the developer minutes of rebuild.

---

## 3. Repository layout

```
ArenaDemo/                    <- repo root, open this in your editor
├── CLAUDE.md                 <- you are here
├── PRD.md                    <- what the demo is
├── TASKS.md                  <- the checklist, keep it current
├── DECISIONS.md              <- why things are the way they are
├── startemulator.bat         <- created on first run (§0)
├── rebuildinstall.bat        <- created on first run (§0)
├── docs/
│   └── reference/            <- art reference, sprite sheets in progress
└── arena/                    <- the Flutter project
    ├── pubspec.yaml
    ├── assets/
    │   ├── images/
    │   │   └── characters/apprentice/apprentice.png
    │   └── audio/
    └── lib/
        ├── main.dart              // runApp only
        ├── app.dart               // MaterialApp, routes, theme
        ├── core/
        │   ├── constants.dart     // design size, colors, layer priorities
        │   ├── stats.dart         // StatBlock + ALL derived-stat formulas
        │   └── settings.dart      // Settings model + SharedPreferences I/O
        ├── data/
        │   └── characters.dart    // CharacterDef list (4 slots, 1 unlocked)
        ├── ui/
        │   ├── screens/
        │   │   ├── main_menu_screen.dart
        │   │   ├── settings_screen.dart
        │   │   ├── credits_screen.dart
        │   │   ├── character_select_screen.dart
        │   │   └── arena_screen.dart      // hosts GameWidget + overlays
        │   └── widgets/                   // buttons, stat bars, shared chrome
        └── game/
            ├── arena_game.dart            // FlameGame subclass, round state
            ├── components/
            │   ├── player.dart
            │   ├── enemy.dart
            │   ├── projectile.dart
            │   ├── spawner.dart
            │   ├── hp_bar.dart
            │   ├── damage_text.dart
            │   └── arena_floor.dart
            ├── input/
            │   └── movement_input.dart    // the 3 control schemes
            └── anim/
                └── anim_state.dart        // AnimState enum + sheet mapping
```

---

## 4. Architecture rules

These are the rules that keep the demo from turning into a mess. They are not
negotiable without a new entry in `DECISIONS.md`.

1. **Flutter owns the menus, Flame owns the arena.** Main menu, settings, credits
   and character select are ordinary Flutter widgets and routes. The arena is a
   single `GameWidget` hosting `ArenaGame`. Do not build menus inside Flame; do
   not build gameplay in widgets.

2. **The Round Over screen is a Flame overlay, not a route.** The death frame must
   stay visible behind it.

3. **All combat numbers come from `core/stats.dart`.** If you find yourself typing
   a damage value, a speed, or an HP number anywhere else, stop and put it there
   as a formula or a named constant. This is the single most important rule in the
   file — the tuning phase depends on it.

4. **Enemies and projectiles are pooled or at least cheap.** Target is 60 live
   enemies. Do not allocate per frame in `update()`; no `Vector2` construction in
   hot loops — mutate in place with `setFrom`/`setValues`.

5. **`ArenaGame` owns round state** (elapsed time, kills, damage dealt, spawn
   interval) and resets it in `onLoad`/`resetRound`. Never carry state across
   rounds via globals or singletons. A fresh arena entry must look exactly like the
   first one.

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
