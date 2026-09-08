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

- [x] **2.1** `stats.dart` — `StatBlock` (STR/VIT/DEX/INT) + all 8 derived formulas from PRD §5.1
- [x] **2.2** Unit tests for every derived formula against the PRD's worked example (The Apprentice → 90 HP, 13 dmg, 1.40/s, 140 px/s) — `test/core/stats_test.dart`, 9 cases
- [x] **2.3** `characters.dart` — `CharacterDef` (id, name, descriptor, stats, spriteFolder, unlocked) and the 4 slot definitions
- [x] **2.4** Character select screen — 2×2 grid, slots 2–4 locked silhouettes (padlock icon, not tappable)
- [x] **2.5** Stat bars + raw numbers for the selected character
- [x] **2.6** Derived readout line (`HP 90 · DMG 13 · 1.4 shots/s · 140 speed`) computed live from the formulas, not typed in
- [x] **2.7** Enter Arena passes the chosen `CharacterDef` through to the arena route (route arguments; `ArenaScreen` stores it, unused until Phase 3's `PlayerComponent`)

Portrait is a placeholder icon, not the real idle animation — that's Phase 5.13, needs the sheet loader (5.1-5.3) first.

**Exit criterion:** changing a stat in `characters.dart` changes both the bars and the derived readout with no other edit.

---

## Phase 3 — Arena core
*Goal: a controllable character in a bounded space.*

- [x] **3.1** `ArenaGame` (FlameGame) mounted in a `GameWidget` on the arena route
- [x] **3.2** `arena_floor.dart` — real tiled floor + border (D-023), was a flat fill placeholder through Phase 3/4
- [x] **3.3** `PlayerComponent` — placeholder rectangle, stats read from the `CharacterDef` passed through Character Select
- [x] **3.4** `movement_input.dart` — floating joystick scheme (D-018: capture lives in Flutter, `game/input/joystick_overlay.dart`, not Flame's gesture mixins)
- [x] **3.5** Fixed joystick scheme + side preference
- [x] **3.6** Drag-anywhere scheme
- [x] **3.7** Settings selects the active scheme at arena entry (code done, all 3 schemes wired) — **developer to verify feel of each on-device**, touch feel isn't something a widget test can judge
- [x] **3.8** Safe-area clamp — screen inset by 24px + system insets (`MediaQuery.padding` captured once at arena entry); clamped per-axis so it slides along the boundary rather than sticking
- [x] **3.9** Show-FPS toggle wires up `FpsTextComponent` (added when `settings.showFps` is true in `resetRound`)

Debug "die" button + Round Over are now real Flame overlays on `ArenaGame`
(fulfilling D-010, which Phase 1 only stubbed as a Flutter widget) rather than
new scope — needed so swapping the placeholder screen for the real
`GameWidget` didn't regress the working flow from Phases 1-2.

**Exit criterion:** a box you can drive with any of the three schemes, that cannot leave the safe area, at a solid 60 fps.

---

## Phase 4 — Combat
*Goal: the loop actually plays.*

- [x] **4.1** `EnemyComponent` — placeholder square (per developer's call), HP 20, walks straight at the player
- [x] **4.2** `spawner.dart` — off-screen perimeter spawning, 1.5s interval, −4 % per 10s, floor 0.25s, cap 60
- [x] **4.3** Nearest-enemy targeting on the player (respecting `attackRangePx`)
- [x] **4.4** Auto-fire timer at `attacksPerSec`; `ProjectileComponent` travelling straight at `projSpeedPxPerS` — uses the real `projectile-bolt.png` sheet, not a placeholder (pulls forward 5.11)
- [x] **4.5** Projectile → enemy collision, damage, despawn; despawn on range and on leaving bounds
- [x] **4.6** Knockback impulse on hit — instant shove (impulse × fixed 0.15s), not a decaying velocity
- [x] **4.7** Enemy death — remove, count the kill
- [x] **4.8** Enemy → player contact damage with 1.0s per-enemy cooldown
- [x] **4.9** Player i-frames (0.6s) + hurt flash — opacity flicker, not a colour tint (D-021)
- [x] **4.10** HP bar component — fixed top bar (D-020, closes the open question)
- [x] **4.11** Passive HP regen
- [x] **4.12** Round state on `ArenaGame`: elapsed time, kills, damage dealt
- [x] **4.13** Death → freeze → Round Over overlay showing the real numbers
- [x] **4.14** Main Menu from Round Over fully resets — re-entering the arena creates a fresh `ArenaGame` instance via Navigator, so this falls out of D-007's "never carry state across rounds" for free
- [ ] **4.15** Perf check: 40 live enemies at 60 fps with Show FPS on — **developer to verify on-device**, not checkable from here

Also pulled forward from Phase 5 (developer's call, assets were ready):
real player animations — `idle`/`run`/`fire`/`spawn`/`hurt`/`death` all wired
to the `main-*.png` sheets (5.2-5.9), and the real hit-spark VFX (5.11, other
half). Damage numbers (5.12) also landed — PRD §10.5's own done-criteria
needs them, not just a later art pass. See DECISIONS D-021 for the hurt-state
asset choice and D-020 for HP bar placement.

**No automated test coverage of any of this** (DECISIONS D-019) — `flutter
test` can't get a `GameWidget` past real asset loading. Verify with
`rebuildinstall.bat` on the emulator.

**Exit criterion:** every numbered item in PRD §10 passes.

---

## Phase 5 — Art pass
*Goal: it looks like the reference sheet, not like boxes.*

Most of this landed early (Phase 4, developer's call — assets were ready).
Remaining: enemy sprite and the select-screen portrait.

- [x] **5.1** Sprite sheet layout decided (D-015): one PNG per state under `assets/images/characters/main/`, `main-<state>.png`, 16×24 cell, frames left-to-right, count = width/16
- [x] **5.2** `anim_state.dart` — `AnimState` enum covering **all** PRD §8 states, including the unbuilt ones
- [x] **5.3** Sheet loader: per-file `Image` → `SpriteAnimation`, keyed by filename not row index (D-015) — `game/anim/sheet_loader.dart` + `character_animations.dart`
- [x] **5.4** `idle` (4f, delivered) and `run` (4f, delivered — PRD's "6" was a placeholder)
- [x] **5.5** Swap the player rectangle for the animated sprite; horizontal flip on facing
- [x] **5.6** `fire` (5f, delivered — PRD's "3" was a placeholder) — plays on auto-attack, returns to idle/run
- [x] **5.7** `spawn` (6f, delivered) — 1.0s round-start sequence with controls locked
- [x] **5.8** `hurt` — `main-hurt.png` (4f) recoil pose (D-021: developer's call, no tint). `main-flash.png` loaded by nothing, reserved for later. Separately, i-frames get an opacity flicker (PRD §6.2), not tied to either sheet.
- [x] **5.9** Death anim (D-016) — `main-die.png` (4f) wired. Fade+shrink fallback kept in reserve only, unused.
- [x] **5.10** Enemy sprite — 3 real skins (`enemy-{one,two,three}-{run,die}.png`), random per spawn, same stats (D-022). "Death puff" is the real death animation now, not a separate puff effect.
- [x] **5.11** Projectile sprite + hit spark — real `projectile-bolt.png`/`projectile-spark.png`, done in Phase 4
- [x] **5.12** Floating damage numbers — done in Phase 4 (PRD §10.5 needs them, not deferrable)
- [x] **5.13** Portrait on the character select screen playing `idle` — `SpriteAnimationWidget` (Flame), no `GameWidget` needed for a single looping animation outside the arena

**Exit criterion:** no placeholder shapes remain in the arena.

---

## Phase 6 — Polish & handoff
*Goal: the demo is stable enough to build the real game on top of.*

- [x] **6.1** `flutter analyze` clean, no warnings
- [ ] **6.2** Tune pass — play 10 rounds, adjust the PRD §5.1 constants for feel, record what changed and why (**developer, on-device**)
- [ ] **6.3** Round Over numbers sanity-checked against a manual count (**developer, on-device**)
- [ ] **6.4** No memory growth over 5 consecutive rounds (watch the profiler) (**developer, on-device**)
- [ ] **6.5** Test on a second AVD with a different aspect ratio; confirm letterboxing (**developer, on-device**)
- [x] **6.6** Update PRD with anything the build proved wrong — §4.4 (portrait location), §6.4 (enemy skins), §8 (frame counts, real death anim, per-asset scale) all corrected against DECISIONS
- [x] **6.7** Write `NEXT.md` — done ahead of schedule (D-024), the "skeleton hardening" pass prompted it directly

**Exit criterion:** the demo is done. Stop, play it, and only then plan the game.

**Called done 2026-09-07.** 6.2-6.5 are on-device checks (tune feel, memory,
second-AVD letterboxing) that weren't formally run round-by-round, but the
developer played it through this session's build across every phase and
called the feel acceptable ("enemies feel ok"). Not blocking moving on to
planning the next phase — revisit 6.4/6.5 (memory, aspect ratio) before any
real release, they're cheap checks that just haven't been run yet.

---

## Phase 7 — Progression & pause system
*Goal: the player gets stronger over a round through kills, not just by playing
longer. First real post-demo feature (developer's vision, planned last session,
built 2026-09-07 — see DECISIONS D-025 for the full design reasoning).*

- [x] **7.1** `core/progression.dart` — `UpgradeKind` (vit/dex/str/intellect),
      placeholder bonus amounts, XP curve (`xpThresholdForLevel`), upgrade-roll
      helper, `PlayerUpgrades` bonus accumulator. Pure, unit-tested
      (`test/core/progression_test.dart`), no Flame dependency (D-019/D-024
      pattern)
- [x] **7.2** Kills grant XP directly (`ArenaGame.grantXp`, called from
      `onEnemyKilled`) — no drops, matches spec
- [x] **7.3** Levelling pauses the round and shows "LEVEL UP! Choose 1 of 3"
      (`LevelUp` Flame overlay) — 3 random `UpgradeKind`s out of the 4, picking
      one applies it via `PlayerComponent.grantUpgrade`
- [x] **7.4** "View your upgrades" / back-to-choices toggle inside the same
      popup, showing pick counts per kind
- [x] **7.5** XP curve tuned to feel deliberately slow to climb (developer's
      explicit ask), not the first number that worked
- [x] **7.6** Top-right pause button → Pause Menu overlay (Resume / Settings /
      Main Menu)
- [x] **7.7** Settings reached from the Pause Menu (only) shows a Debug
      section: God Mode toggle, "Grant Level Up" (queues a free level-up that
      plays out once the pause menu closes, not immediately)
- [x] **7.8** Queued level-ups (debug-granted or otherwise earned while the
      pause menu happened to be open) chain into the popup immediately after
      closing the menu, still paused — not resumed first
- [x] **7.9** Enemy scaling to match player level — done (DECISIONS D-026):
      linear HP/contact-damage multiplier by player level
      (`enemyStatMultiplier`, `core/game_rules.dart`), baked into each enemy
      at spawn time. Move speed left unscaled deliberately. Unit-tested;
      on-device feel (does 0.12/level actually read as harder) is part of
      7.10
- [ ] **7.10** On-device verification — **developer**: level-up popup timing/
      feel, pause menu across all 3 control schemes, god mode actually
      prevents damage, grant-level-up queuing behaves as described
- [x] **7.11** Aura skill — a 5th level-up option, a damaging ring built from
      `projectile-spark.png` orbiting the player (DECISIONS D-027), mixed
      into the same weighted roll as the 4 stat upgrades (placeholder equal
      weights, `kUpgradeWeights` in `core/progression.dart` — real tuning
      later), capped at 3 stacks unlike the others. flutter analyze clean,
      flutter test passes (42 tests, 10 new), flutter build apk --debug
      succeeds. On-device feel (ring readability, tick damage, radius) is
      part of 7.12 below
- [x] **7.12** On-device verification of the Aura skill — **developer**: ring
      visually reads as an aura (not just spinning dots), tick damage/radius
      feel right, stacking to 3 actually feels like it's getting stronger,
      it still shows up in "view your upgrades"
      — **2026-09-08 update:** first pass read as no/negligible damage; no
      logic bug found (DECISIONS D-027 update), added a visible ring at
      the exact hit radius and bumped the numbers ~25-50%. Re-verify.
      — **2026-09-08 update 2:** second pass reported damage only on the
      outside, not inside, the ring. Re-verified the range check is a full
      disk (still no logic bug found). Replaced the static debug ring with
      a full-disk pulse flash fired on every connecting tick, so the
      interior visibly lights up too.
      — **2026-09-08 update 3: confirmed working.** Coverage was correct
      the whole time; the diagnostic pulse is now removed, aura ships with
      just the orbiting sparks. Merged to main.
      — **2026-09-09 update 4 (DECISIONS D-032):** visual swapped from the
      orbiting-sparks placeholder to a real asset,
      `vfx/vfx/effect_electric-shield.png` (a 9x7 grid sheet, 60 frames —
      `game/anim/sheet_loader.dart` gained grid-sheet support for this).
      Sized to the damage diameter exactly so it can't read bigger than the
      hit area. Radius/damage logic untouched. `flutter analyze` clean,
      `flutter test` 47/47, `flutter build apk --debug` succeeds. On-device
      re-verify needed: does the new ring read clearly, does its spin speed
      (first guess: ~1.8s per loop) feel right.
      — **2026-09-09 update 5:** -20% opacity, -20% contrast (developer's
      call: too bright/in-your-face). `flutter analyze` clean, `flutter
      test` 47/47, `flutter build apk --debug` succeeds.

flutter analyze clean, flutter test passes (32 tests, 12 new), flutter build
apk --debug succeeds. No automated coverage of the pause/overlay orchestration
itself (D-019 still applies) — 7.10 is the real check.

**2026-09-08 update (7.9):** flutter analyze clean, flutter test passes (34
tests, 2 new for `enemyStatMultiplier`), flutter build apk --debug succeeds.

**Exit criterion:** a full round can level up multiple times, review picks,
pause/resume through all menus, and reset cleanly on re-entry, without the
demo's existing flow (Phases 0-6) regressing.

---

## Phase 8 — Roster expansion
*Goal: all 4 select-screen slots are real, playable characters, not one demo
character plus placeholders. Started 2026-09-08 when the developer delivered
full sprite sheets for the Bruiser/Skirmisher/Warden slots (DECISIONS D-028).*

- [x] **8.1** Wire the Bruiser/Skirmisher/Warden slots to their real sprite
      folders (`second`/`black` prefix, `third`, `fourth`) and unlock all 4
      characters — no progression gate yet, everything just defaults open
      (D-028). `flutter analyze` clean, `flutter test` passes (42 tests, no
      new ones — no new gameplay logic), `flutter build apk --debug`
      succeeds.
- [ ] **8.2** On-device verification — **developer**: all 4 tiles show real
      idle portraits (not padlocks) on Character Select, each is selectable,
      stat bars/derived readout update correctly per character, each enters
      the arena and plays/animates/fires correctly
- [~] **8.3** Give each of the 3 new characters its own `AttackBehavior`
      instead of sharing `ProjectileAttack()`.
      - [x] Bruiser — `KnifeAttack` (DECISIONS D-029): spinning knife,
        pierces every enemy in its path, sprite swaps clean→bloody on first
        blood. `flutter analyze` clean, `flutter test` 42/42 (no new tests —
        no new gameplay math, pierce is component-level, not `game_rules.dart`
        material), `flutter build apk --debug` succeeds. On-device feel is
        part of 8.3's on-device pass below.
        — **2026-09-08 first tune (developer's call, pre-on-device):** knife
        +25% size (`kKnifeRenderScale`), spin +10% (`_rotationSpeedRadPerSec`
        in `knife_projectile.dart`), damage -30% vs. the shared per-hit
        formula (`KnifeAttack._damageMultiplier`) to offset pierce hitting
        several enemies per throw.
        — **2026-09-09 second tune (DECISIONS D-030):** fixed a real bug —
        the knife was despawning mid-flight (inherited `ProjectileAttack`'s
        max-travel-range); now the only despawn condition is leaving the
        arena. Also: -30% attack speed (`KnifeAttack._attackSpeedMultiplier`),
        knife +20% size again (now 1.5x total, `kKnifeRenderScale`), +15%
        targeting range (`KnifeAttack._rangeMultiplier`, targeting only — the
        thrown knife's travel distance is now unlimited).
      - [x] **Knife Mastery** — Bruiser-only 3-level upgrade (DECISIONS
        D-031, `UpgradeKind.knifeMastery`): lvl1 +20% knife damage, lvl2
        throws a second knife behind the player, lvl3 throws 4 at once (one
        to every side). First character-locked upgrade —
        `kCharacterLockedUpgrades`/`upgradeKindsFor` in
        `core/progression.dart` gate the level-up roll pool by
        `CharacterDef.id`. `flutter analyze` clean, `flutter test` 47/47 (5
        new), `flutter build apk --debug` succeeds.
      - [x] Skirmisher — **Spiral Fire** (DECISIONS D-034): two
        `SpiralFireProjectileComponent`s launched together, pi radians of
        orbit phase apart, spiraling around a shared advancing point that
        converges on the target (yin-yang look); a `sparkles-constelation`
        flourish plays behind the caster's body. Non-lethal hits play
        `effect_impact`, kills play `effect_explosion2` — on top of, not
        instead of, the existing shared hit-spark/damage-number feedback.
        `flutter analyze` clean, `flutter test` 49/49, `flutter build apk
        --debug` succeeds.
        — **2026-09-09 tune (DECISIONS D-036/D-037):** fixed a real bug —
        the cast sparkle was a one-shot per cast, developer wants it
        visible at all times; it's now spawned once per round
        (`AttackBehavior.onEquipped`, a new lifecycle hook) as a permanent
        looping effect on the caster instead. Also: sparkle opacity 35% →
        50% ("a little more visible"), +40% targeting range
        (`SpiralFireAttack._rangeMultiplier`), -30% orbit spin speed
        (`SpiralFireProjectileComponent._spinSpeedRadPerSec`, the wobble,
        not the forward travel speed), -40% damage per hit
        (`SpiralFireAttack._damageMultiplier`) — two shots at 0.6x each is
        still more total damage than a single-shot kit, deliberately not
        brought to parity.
        — **2026-09-09 bugfix (DECISIONS D-038):** fixed a real bug —
        projectiles sometimes despawned before reaching their target,
        effective range reading shorter than the targeting range that
        picked that target. Cause: the orbit wobble could push on-screen
        `position` outside the world bounds near a screen edge while
        `_traveled` was still short of `_totalDistance`, triggering a
        leftover out-of-bounds check copied from the bolt/knife. Removed —
        `_traveled >= _totalDistance` alone already guarantees exact,
        on-time termination at the target regardless of wobble.
        — **2026-09-09 second bugfix (DECISIONS D-039):** developer asked
        for confirmation firing again doesn't despawn an in-flight shot
        (it never could — no shared state between projectile instances,
        almost certainly the same symptom as the above bug) and for
        projectiles to keep flying past their target until they actually
        leave the screen, same "no despawn on its own" rule the knife got
        in D-030. The distance-based despawn is gone; `_outOfBounds()` is
        back as the only exit condition, this time with a margin (equal to
        the orbit's own wobble radius) so it can't falsely trigger near an
        edge the way the pre-D-038 version did. **This closes out the
        Skirmisher's main attack** — no further changes requested.
      - [ ] Warden — something tankier, fits `vit`-heavy stats
      - [ ] On-device verification of the Bruiser's knife — **developer**:
        pierce reads clearly (doesn't look like it stopped at the first
        enemy), clean→bloody swap is visible mid-flight, spin doesn't look
        broken at the knife's actual travel speed, knife now flies all the
        way off-screen instead of vanishing early, Knife Mastery only shows
        up in the level-up popup when playing the Bruiser, and its 3 levels
        actually look/feel like 1 → 2 → 4 knives
      - [ ] On-device verification of the Skirmisher's Spiral Fire —
        **developer**: the spiral/yin-yang motion reads as intentional (not
        just wobbly) at the slower spin speed, sparkle is visible on the
        caster's body at all times (not just mid-cast) at 50% opacity,
        impact vs. explosion picks correctly (explosion only on a kill),
        overall damage output feels right vs. the other 2 kits
- [ ] **8.4** Real unlock-by-progression: lock slots 2-4 again and gate them
      behind a persistent unlock condition (kills/rounds/levels — TBD).
      Needs a persistence story beyond `SharedPreferences` settings (round
      state resets every round by design, CLAUDE.md §4.5 — unlocks can't).
      Ask before picking the unlock condition/mechanism; don't guess.
- [x] **8.5** Player hit feedback — `effect_blood-impact` plays somewhere on
      the player's own body (a random spot each time, not a fixed decal)
      whenever damage actually lands, any character (DECISIONS D-033).
      `flutter analyze` clean, `flutter test` 49/49, `flutter build apk
      --debug` succeeds.
- [x] **8.6** Elite enemies — 15% of spawns (`kEliteChance`,
      `core/game_rules.dart`) get a persistent `effect_dithered-fire` glow,
      sized to never exceed the enemy's own width (DECISIONS D-035).
      Visual-only for now — no stat/behavior difference, so this is a first
      slice of the Backlog's "enemy variety" item, not the whole thing.
      `flutter analyze` clean, `flutter test` 49/49 (2 new, including a
      statistical check on the roll rate), `flutter build apk --debug`
      succeeds.
      — **2026-09-09 update (DECISIONS D-036):** developer feedback — glow
      now renders on top of the enemy (new `ArenaPriority.enemyOverlay`,
      was `groundEffects`/behind), and fades out over 0.4s
      (`kEliteFireFadeOutSec`) starting the instant the enemy starts dying
      (`EnemyComponent.isDying`) instead of staying at full brightness
      through the whole death animation and then vanishing on removal.
- [ ] **8.7** On-device verification of 8.5/8.6 — **developer**: blood
      splat lands on the body (not off it), position visibly varies hit to
      hit, roughly 1 in 6-7 enemies shows the fire glow on top of them
      (not behind), it visibly fades out as soon as that enemy dies rather
      than cutting off abruptly, and it never reads wider than the enemy
      sprite itself

**Exit criterion:** 4 distinct playable characters, each unlocked by real
progression instead of by default, each with its own attack kit.

---

## Backlog (post-demo — do not start)

Kept here so ideas have somewhere to go that isn't the current sprint.

- Skill system using the reserved animation states (teleport, dash, charge, channel, cast)
- ~~Additional playable characters (slots 2–4)~~ — started Phase 8 (D-028):
  assets wired, all 4 unlocked, sharing one bolt attack. Distinct
  attack kits (8.3) and real unlock-by-progression (8.4) still open.
- Enemy variety with distinct stats: ranged, fast/swarm, tanky, elite (D-022:
  3 skins were wired for visual variety only, one shared `EnemyStats` profile
  — still true "one enemy type" per PRD §9, so this backlog item stands).
  "Elite" got a first visual-only slice in Phase 8.6 (D-035, a fire glow on
  ~15% of spawns) — no stat/behavior difference yet, that part is still open.
- Structured waves and a boss
- **Enemy scaling to match player progression** — done as of Phase 7.9
  (D-026): HP/contact damage scale linearly with player level. Faster
  spawns tied to level, or distinct tougher `EnemySkin` tiers, remain
  Backlog if the linear stat scale alone doesn't carry the difficulty
  curve far enough.
- Real audio: SFX bank + music, wired to the existing volume sliders
- Multiple arenas and backgrounds
- Camera larger than the screen, with scroll
- Enemy separation/steering so they stop stacking
- Object pooling if the perf budget gets tight
- Haptics on hit and death
- Play Store packaging, signing, release build config
