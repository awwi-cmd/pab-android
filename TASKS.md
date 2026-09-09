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
      - [x] Warden — **Ground Slam** (DECISIONS D-056): no new art requested
        or added — a short-range AoE hit centered on the player (not a
        projectile at all), damaging + knocking back every `Damageable`
        within the radius at once (`allWithinRange`, same shape
        `AuraComponent`'s tick uses), reusing the already-loaded `fire`
        animation for the swing and the existing `explosionAnimation` sized
        to the hit radius for the shockwave. -35% range (melee, not ranged),
        -25% attack speed, -15% damage per hit (offsetting hitting every
        target in the radius at once), +50% knockback vs. the shared
        formula. Closes the last CLAUDE.md §4.12 placeholder — all 4
        characters now have a distinct kit. `flutter analyze` clean,
        `flutter test` 92/92 (no new tests — no new `core/` math, the AoE
        loop is component-level like the Bruiser's pierce was), `flutter
        build apk --debug` succeeds.
      - [ ] On-device verification of the Warden's Ground Slam —
        **developer**: swing plays the `fire` animation, the explosion VFX
        is roughly centered on the player and sized to actually match where
        enemies get hit (not visibly bigger/smaller than the real radius),
        every enemy in range takes damage + gets knocked outward (not just
        the nearest one), attack cadence feels appropriately slower/heavier
        than the other 3 kits rather than just weaker
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
- [x] **8.4** Real unlock-by-progression (closed by DECISIONS D-055,
      Phase 13) — asked rather than guessed (per this item's own note):
      lifetime kills across every round, persisted via `MetaProgression.
      lifetimeKills`/`MetaProgressionRepository.addLifetimeKills`, same
      shape as the coin wallet. `CharacterDef.unlockKillThreshold` gates
      slots 2-4 (Bruiser 50, Skirmisher 150, Warden 300); the Apprentice's
      is `null` (always unlocked). See TASKS Phase 13 for the full slice
      (also folded in a character-select redesign and a chest economy from
      the same developer message).
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

## Phase 9 — Roaming world (Vampire-Survivors-style camera + movement)
*Goal: no bounds, camera follows the player through an effectively infinite
world, matching the genre this project is actually becoming (developer's
direction). Explicitly scoped and sequenced before starting — this is the
Backlog's "Camera larger than the screen, with scroll" item, built one
slice at a time per the developer's own chosen order, not all at once
(DECISIONS D-040).*

- [x] **9.1** Camera + free movement (DECISIONS D-040): `ArenaGame` now
      actually uses `FlameGame`'s `world`/`camera` (previously unused —
      everything was added as a sibling of them, bypassing the camera
      transform entirely, which is what let `game.size` silently double as
      "world bounds" under the old fixed-camera design). New
      `addToWorld`/`addToHud` split replaces every `add(...)` call site;
      `camera.follow(player, snap: true)` in `resetRound`. Bounds clamp
      (`PlayerComponent._clampToSafeArea`, `ArenaGame.safeAreaBounds`) is
      gone outright. **Required bug fix, not optional scope:** every
      projectile's `_outOfBounds()` (bolt, knife, Spiral Fire) checked
      against a fixed `0..game.size` rect, which would have made every
      ranged attack stop working within seconds of the player walking away
      from spawn — fixed to check `camera.visibleWorldRect` instead.
      `flutter analyze` clean, `flutter test` 49/49, `flutter build apk
      --debug` succeeds.
      - **2026-09-09 on-device pass found 4 issues** (screenshotted),
        closed by 9.3/9.4 below: the border was still visible (a stray
        line where the old bounded patch's edge used to be), the floor
        genuinely didn't extend past that patch, enemies could spawn
        inside the visible view, and spawning stopped entirely far enough
        from the start.
- [x] **9.3** Endless floor tiling + border removal (DECISIONS D-041):
      `ArenaFloor` rewritten to render from `game.camera.visibleWorldRect`
      every frame instead of a fixed pattern baked into one `game.size`
      patch — tile variant per cell is a deterministic hash of `(col, row)`
      + a per-round seed, not `Random()` per frame, so revisiting a cell
      shows the same tile. Border tiles removed outright — an infinite
      world has no edge to draw one on, which is what fixed the
      still-visible-border bug for free.
- [x] **9.4** Camera-relative spawning + straggler culling (DECISIONS
      D-041): `Spawner._randomPerimeterPoint` now builds its ring from
      `visibleWorldRect` inflated 15% (`_visibleMarginFactor`, the
      developer's literal ask) instead of a fixed rect at the origin.
      Turned out (3) and (4) shared one root cause: enemies (70px/s) are
      slower than every character (120+px/s), so one that spawns behind a
      player moving mostly one direction can fall behind forever in an
      unbounded world — previously impossible under the old fixed arena.
      Unculled, those permanently ate into the 60-live-enemy cap until
      nothing new could spawn — the actual mechanism behind (4). Fixed
      with `Spawner._cullStragglers` (ticks once/sec, removes anything
      >3x the visible view's larger dimension from the player via new
      `ArenaGame.cullEnemy` — same as a kill, minus kill count/XP).
      `flutter analyze` clean, `flutter test` 49/49, `flutter build apk
      --debug` succeeds.
- [ ] **9.2** On-device verification of 9.1/9.3/9.4 together —
      **developer**: movement feels free/unbounded, camera tracks
      smoothly, HP bar/FPS counter stay fixed while the world scrolls,
      floor now tiles endlessly in every direction with no visible border
      anywhere, enemies only ever spawn just outside what's visible (never
      pop in on-screen), spawning keeps working no matter how far from the
      start point, all 3 attack kits still land hits at any distance
- [ ] **9.5** Revisit anything that assumed a fixed/bounded arena now that
      9.3/9.4 are in: `EnemyComponent`'s movement-toward-player logic, any
      future minimap/HUD element, whether 60-live-enemy cap still makes
      sense at this scale.

**Exit criterion:** the player can walk indefinitely in any direction, the
world keeps generating around them (floor + enemies), and every existing
attack kit still works at any distance from the start point.

---

## Phase 10 — Boss fight, SFX, loot economy
*Goal: a real milestone fight (the boss), the first working audio, and a
loot loop (gems/potions in the world, money revealed at round-over).
Developer delivered `boss_map1.png`, `audio/core/`, and
`consumables/{gems,money,potions}.png` and specced all three directly.*

- [x] **10.1** The boss (DECISIONS D-042) — `boss_map1.png` sliced into
      idle(6)/walk(3)/fire(5)/death(10) frames (found by inspecting actual
      non-blank cells, not the visual thumbnail, which is misleading on
      this asset). Spawns at levels 3/6/9 via a real threshold check on
      every level-up (real or debug), ~20% stronger each spawn
      (`bossStatMultiplier`, compounding). Ranged: holds range and fires a
      green-tinted bolt (`ProjectileComponent`'s new `tint` param — same
      sprite/animation as the Apprentice's bolt) on a cooldown, walks
      closer when out of range, teleports to the mirror point across the
      player (`effect_anima` at both ends) the instant the player closes
      to melee. New `Damageable` interface (`game/components/
      damageable.dart`) lets the boss and every grunt share the exact same
      attack hit-detection code (`ArenaGame.damageableTargets`) without
      either knowing the other exists. Every hit plays `effect_impact`,
      the kill plays `effect_explosion2` (+ its SFX, 10.2). `flutter
      analyze` clean, `flutter test` 62/62 (6 new), `flutter build apk
      --debug` succeeds.
- [x] **10.2** SFX (DECISIONS D-044) — first real audio in the project.
      `sfx-explosion.wav` on any explosion effect (Spiral Fire kill *or*
      boss kill, one hook) and `sfx-you-died.wav` on a real player death
      (not the debug-die button). Volume derives from the existing
      `Settings.sfxVolume` slider, capped low on top per the developer's
      "not that loud" ask.
- [x] **10.3** Gems (DECISIONS D-043) — drop from kills at
      `gemDropChance(level)` (80% base, +1%/level, capped at 100%), one of
      5 rarity tiers (`gems.png` columns, weighted `rollRarity`), sit in
      the world as `GemComponent` until the player walks within
      `kItemPickupRadiusPx`. Round-over shows a total count.
- [x] **10.4** Potions (DECISIONS D-043) — `PotionSpawner` drops one
      randomly in a generous area around the camera's current view every
      15s (capped at 5 live), floats up/down in place
      (`kPotionFloatAmplitudePx`/`Sec`) on top of its own looping
      animation, heals a flat tier-based amount on touch. "We will add
      more logic later" per the developer — healing is the whole mechanic
      for now.
- [x] **10.5** Money (DECISIONS D-043) — never a world object: every kill
      rolls a coin value (same rarity roll as gems) into a silent running
      total, revealed only at round-over via a new animated `_CoinCounter`
      widget — a number counting 0→total next to `ui/currency-counter.png`
      while up to 10 small coins fly in from off-widget and shrink to
      nothing right as they arrive, per the developer's detailed spec.
      `flutter analyze` clean, `flutter test` 62/62, `flutter build apk
      --debug` succeeds.
- [x] **10.6** On-device verification (first pass) — **developer** played a
      real round and reported two real bugs (DECISIONS D-046), both fixed:
      the boss's own bolt was self-colliding at spawn (never visibly
      traveled), and every player attack's targeting was still built from
      `game.enemies` directly, so the boss could never be shot at. Also cut
      gem drop rate 80% (was spawning gems on top of each other). `flutter
      analyze` clean, `flutter test` 71/71, `flutter build apk --debug`
      succeeds. Remaining on-device verification (bolt color, teleport
      flashes, SFX feel, potion float, coin animation accuracy) still open
      — re-check after this pass.
- [x] **10.7** `arena_game.dart` split (DECISIONS D-045, closed by D-048) —
      the ~20 `SpriteAnimation`/`Sprite` fields and the entire `onLoad()`
      loading block moved into `game/game_assets.dart`'s `GameAssets` class;
      `ArenaGame` holds one `late GameAssets gameAssets` and keeps round
      state, spawn/kill bookkeeping, `addToWorld`/`addToHud`. Every existing
      call site (`AttackBehavior`s, `BossComponent`, `AuraComponent`) is
      unchanged — `ArenaGame` still exposes `boltAnimation`/`knifeCleanSprite`/
      etc. as thin getters delegating to `gameAssets`. `flutter analyze`
      clean, `flutter test` passes, `flutter build apk --debug` succeeds.
- [x] **10.8** Fixed: boss bolt never damaged the player (DECISIONS D-051,
      developer report). `ProjectileComponent`'s hit-test only ever checked
      `game.damageableTargets` (enemies + boss — "what a player attack can
      hit"), which never contained the player, so the boss's own bolt
      always found nothing to hit despite visibly firing/travelling. New
      `targetsPlayer` param on `ProjectileComponent`, `true` for the boss's
      bolt only, checks `game.player` directly instead. `flutter analyze`
      clean, `flutter test` 85/85, `flutter build apk --debug` succeeds.
      On-device confirmation that the boss's bolt now actually lands is
      **developer's** to check (CLAUDE.md §2).
- [x] **10.9** Boss bolt: 3-shot burst, bounces, +30% speed (DECISIONS
      D-052, developer's spec). Fires 3 bolts in quick succession
      (`BossStats.boltBurstCount`/`boltBurstIntervalSec`), each re-aimed at
      the player's live position at the moment it fires; the fire-cooldown
      now gates the whole burst, not each shot. New
      `ProjectileComponent.maxBounces` (generic, default 0 — every other
      caller unaffected) reflects off the edge of `camera.visibleWorldRect`
      ("the wall," reinterpreted for a world with no fixed bounds since
      D-040) instead of despawning, up to `BossStats.boltBounceCount` (3)
      times. `boltSpeedPxPerS` +30%. `flutter analyze` clean, `flutter
      test` 85/85, `flutter build apk --debug` succeeds. On-device feel
      (burst reads as 3 shots, bounce looks intentional) is
      **developer's** to check.
- [x] **10.10** Boss bolt +5s lifetime, 9-bolt live cap; shrink+drift "poof"
      despawn shared by every projectile (DECISIONS D-053, developer's
      spec — poof scope confirmed via a clarifying question rather than
      guessed). `BossStats.boltMaxRangePx` folds in 5 extra seconds of
      travel at the bolt's own speed; `BossComponent._liveBolts` caps
      concurrent boss bolts at `BossStats.boltMaxLiveCount` (9), skipping
      over-cap burst shots rather than stalling the burst. New
      `game/components/projectile_poof.dart` (`ProjectilePoofComponent`) —
      100%→0% shrink drifting downward over 0.35s — wired into every
      projectile's "expired without hitting anything" path
      (`ProjectileComponent`, `KnifeProjectileComponent`,
      `SpiralFireProjectileComponent`), not the hit path (already has its
      own feedback). `flutter analyze` clean, `flutter test` 85/85,
      `flutter build apk --debug` succeeds. On-device feel is
      **developer's** to check.
- [x] **10.11** Death SFX now fires with the Round Over overlay, not the
      instant HP hits 0 (DECISIONS D-054, developer's spec). Moved from
      `onPlayerDied()` into `_endRound()`, gated by a new `_realDeath` bool
      instead of reusing `_roundEndDelay`'s null-ness as the "was this a
      real death" signal. `flutter analyze` clean.

**Exit criterion:** a full round can include a boss encounter with working
audio feedback, gems/potions appearing and being collected in the world,
and an accurate, well-presented coin total at round-over.

---

## Phase 11 — Persistent meta-progression (SHOP + UPGRADES)
*Goal: character select gets a real reason to visit between rounds.
Developer specced this directly (DECISIONS D-047).*

- [x] **11.1** `core/meta_progression.dart` — `MetaStat` (str/vit/dex/
      intellect/corruption), `MetaProgression` (wallet + 5 levels, 0-10
      each, `.buy()`), `metaUpgradeCost` (exponential per level),
      `MetaProgressionRepository` (`SharedPreferences`, same shape as
      `SettingsRepository`). Corruption's 3 multiplier functions live in
      `game_rules.dart` instead (gameplay math, not shop data).
- [x] **11.2** Wired into a real round: `ArenaGame.effectiveStats` (base +
      shop bonuses) replaces every direct `character.stats`/`game.
      character.stats` read in combat code; `PlayerComponent` takes a
      resolved `StatBlock` instead of reaching into `character` itself;
      `Spawner`/`spawnEnemy`/coin rolls all read the corruption
      multipliers. `ArenaGame._endRound` credits `coinsEarned` into the
      persistent wallet exactly once.
- [x] **11.3** `UpgradesScreen` — wallet readout, one row per `MetaStat`
      (level bar, description, cost, buy button, maxed state).
      `ShopScreen` — literal empty placeholder ("nothing yet, empty, just
      a back button") per the developer's explicit spec. Both routed from
      two new buttons + a wallet readout on `CharacterSelectScreen`,
      reloaded on return from either screen.
- [ ] **11.4** On-device verification — **developer**: a purchased STR/
      VIT/DEX/INT level is actually felt in the next round (check the
      derived-stat readout on character select before/after a purchase);
      Corruption actually spawns enemies faster / tougher and pays out
      more coins at increasing levels; the wallet display and cost numbers
      update correctly after each purchase and survive an app restart.
- [ ] **11.5** Real balance pass on `metaUpgradeCost` and the corruption
      multipliers once 11.4 gives a feel for the numbers — everything
      shipped in 11.1-11.3 is a first-guess placeholder, same as every
      other tuning value in this project.

**Exit criterion:** coins earned finishing a round are spendable from
character select on a permanent, felt improvement to the next run.

---

## Phase 12 — Four new powers
*Goal: 4 new level-up skills — Ultimate Mirror, Projectile Ray, Projectile
Thunder, Defence Crystal. Developer delivered
`ultimate-mirror.png`/`projectile-ray-beam.png`/`projectile-thunder.png`/
`defence-crystal.png` and specced all four directly (DECISIONS D-049).*

- [x] **12.1** `core/game_rules.dart` gained 2 new pure functions:
      `randomVisiblePoint` (a point *inside* the visible view, inset by a
      margin — the opposite of `randomPerimeterPoint`) and
      `alongLineWithinRange` (every candidate within a half-width of a line
      segment — a piercing beam's hit test). Unit-tested.
- [x] **12.2** Ultimate Mirror (`UpgradeKind.ultimateMirror`,
      `game/components/mirror.dart`) — a stationary turret that spawns
      somewhere on screen (`randomVisiblePoint`) and fires a bolt out each
      side on a fast, fixed 0.5s timer. Levels (max 3) add more mirrors;
      a single mirror's own damage/pace doesn't scale.
- [x] **12.3** Projectile Ray (`UpgradeKind.projectileRay`) — a second,
      independently-cooling attack owned by `ArenaGame` (not a
      `CharacterDef.attackBehavior` — every character can pick it): a
      piercing beam (`alongLineWithinRange`) along the line to the nearest
      target, base cooldown 3s. Levels (max 3) raise attack speed and
      damage. Visual: `game/components/ray_beam.dart`'s
      `RayBeamEffectComponent`, stretched/rotated to the shot.
- [x] **12.4** Projectile Thunder (`UpgradeKind.projectileThunder`) —
      strikes `thunderTargetCount(stacks)` random living targets with a
      lightning-bolt VFX (`ArenaPriority.hitEffects`, so it always reads on
      top of the enemy sprite) and damage, on a cooldown that shrinks 4s →
      1s over its 4 levels (the developer's literal spec — the one skill
      capped at 4 stacks instead of the usual 3); damage also rises per
      level.
- [x] **12.5** Defence Crystal (`UpgradeKind.defenceCrystal`,
      `game/components/defence_crystal.dart`) — single-pick (cap 1, no
      further levels: the spec never said "levels increase" anything for
      this one). Orbits the player in a figure-8/lemniscate path. Grants a
      flat damage-resistance multiplier (`PlayerComponent.takeDamage`) and a
      small HP-regen bonus (`PlayerComponent`'s regen line), both applied
      via `PlayerUpgrades` the same additive-layer way vit/dex/str/intellect
      are.
- [x] **12.6** All 4 wired into the existing level-up machinery for free —
      `kUpgradeWeights`/`kUpgradeMaxPicks`/`UpgradeKind.label`/`.description`
      — no UI edit needed (`LevelUp` overlay already iterates
      `UpgradeKind.values`/`currentLevelUpChoices`). `flutter analyze`
      clean, `flutter test` 85/85 (14 new), `flutter build apk --debug`
      succeeds. Debug APK installed and launched on the emulator without a
      crash (confirms the new sheet-slicing grid dimensions are valid) —
      further on-device play was blocked by the emulator itself getting
      stuck in a "System UI isn't responding" loop on this run, unrelated
      to this change; see 12.7.
- [x] **12.7** First tune pass (DECISIONS D-050, developer's call, ahead of
      on-device verification): Projectile Thunder +40% size (`kThunderWidthPx`)
      and +20% brightness (`ArenaGame.spawnEffect`'s new `brightness` param,
      a pure color-matrix multiply); Ultimate Mirror changed from a
      permanent turret to a 3s-active/3s-hidden cycle
      (`mirrorActiveDurationSec`/`mirrorCooldownDurationSec`), re-picking an
      on-screen spot each time it reappears; Defence Crystal's figure-8
      +60% bigger (`defenceCrystalOrbitRadiusXPx`/`Y`) and now toggles
      `priority` in front of/behind the player as it crosses the 8's own
      center; Projectile Ray's beam sprite +40% thicker
      (`kRayBeamThicknessPx`, visual only, hit-test width untouched).
      `flutter analyze` clean, `flutter test` 85/85, `flutter build apk
      --debug` succeeds.
- [ ] **12.8** On-device verification — **developer, not a future session**
      (CLAUDE.md §2: never drive the emulator to test): each of the 4 shows
      up in the level-up popup and its description reads correctly; Ultimate
      Mirror appears somewhere new on screen every ~6s, fires both ways for
      ~3s, then actually disappears for ~3s before reappearing; Projectile
      Ray fires every ~3s and visibly pierces multiple enemies in a line,
      beam reads thick enough now; Projectile Thunder strikes down on top of
      enemies (not behind them), reads bigger/brighter, and its
      cooldown/target-count/damage visibly ramp up to level 4; Defence
      Crystal's figure-8 reads bigger and the crystal visibly swings in
      front of then behind the character as it orbits, and damage taken/HP
      regen both change once picked; none of the 4 breaks an existing
      character's own kit.

**Exit criterion:** all 4 powers are pickable, function as specced, and
none regresses an existing attack kit or the level-up flow.

---

## Phase 13 — Character unlocks, swipe-carousel select, chest economy
*Goal: real progression-gated character unlocking (closing out TASKS 8.4), a
character-select screen that doesn't look silly with 4 idle animations
running at once, and a chest economy with its own persistent gem wallet.
Developer specced all three in one message; the unlock metric, carousel
scope, and gem-wallet-vs-coins questions were asked and confirmed rather
than guessed (DECISIONS D-055).*

- [x] **13.1** Character unlocks — `CharacterDef.unlockKillThreshold`
      (`int?`, `null` = always unlocked) replaces the old flat
      `unlocked: true` placeholder (D-028). Apprentice `null`, Bruiser 50,
      Skirmisher 150, Warden 300 lifetime kills. `MetaProgression`/
      `MetaProgressionRepository` gained `lifetimeKills`/
      `addLifetimeKills`, credited once per round from `ArenaGame._endRound`
      alongside coins/gems. Closes TASKS 8.4.
- [x] **13.2** Character select rewritten as a swipe carousel
      (`PageView.builder`, one `_CharacterPage` per character) — replaces
      the 2x2 grid that had all 4 idle-animating at once. Only the current
      page's portrait animates. Locked pages show a `_LockedPanel` (the
      `bar-empty`/`bar-filling`/`star-empty` assets — turned out to already
      be exactly "the locked panel asset" the developer asked for) instead
      of ENTER ARENA, with real stats still visible, dimmed. Wallet readout
      now shows gems (`star-full.png`) next to coins. SHOP/UPGRADES stay
      pinned above the carousel — `ShopScreen` itself is untouched, already
      the empty-placeholder-with-back-button D-047 asked for.
- [x] **13.3** Chest economy — `ChestSpawner`/`ChestComponent`
      (`game/components/`), same random-drop shape as `PotionSpawner`
      (D-043) but rarer (40s interval, 2 live cap). Opening sequence: the
      boss's teleport flourish (`animaAnimation`) first, then
      `spawnExplosionEffect` (SFX included) 0.35s later, swapping to the
      real `chest_01`-`chest_12` 12-file opening animation
      (`loadFileSequenceAnimation`, new in `sheet_loader.dart`) at the same
      moment. Rolled 3-6 gems (`rollChestGems`) into `gemsCollected` —
      **superseded by 14.2 (DECISIONS D-057):** the payout is now a single
      playing-card draw (`rollChestCard`), not a gem-count roll.
- [x] **13.4** Persistent gem wallet + ChestReveal popup —
      `MetaProgression.gems`/`addGems`, same shape as coins, credited at
      round-over. New `ChestReveal` Flame overlay (4th one, alongside
      RoundOver/LevelUp/PauseMenu) — "a fancy chest opening pop-up and
      reveal of gems & gem count," genuinely pausing the round, grouped by
      rarity. `ArenaGame._afterMenuClosed()` generalizes the level-up
      chaining logic into a 3-way priority (level-up, then chest reveal,
      then actually resume) so it can't collide with either. **The reveal's
      own content (grouped-by-rarity gem list) is superseded by 14.2** — the
      overlay itself (the popup, its pause/resume wiring, its place in the
      priority chain) is untouched.
- [x] **13.5** `flutter analyze` clean, `flutter test` 92/92 (7 new —
      `test/data/characters_test.dart`'s 4 `isUnlockedFor`/`kCharacters`
      cases, `economy_test.dart`'s 3 `rollChestGems` cases), `flutter build
      apk --debug` succeeds.
- [ ] **13.6** On-device verification — **developer** (CLAUDE.md §2, this
      session was asked not to drive the emulator itself): swiping actually
      feels smooth and reads as intentional, not laggy; a locked character's
      progress bar/kill count are legible and update after a round; unlocked
      state actually flips once the threshold is crossed (no stale lock
      after enough kills); chests are visible and walkable-to in the world,
      the anima→explosion→opening beat reads as one sequence not three
      disconnected flashes; the ChestReveal popup shows the right gem
      count/rarities and CONTINUE actually resumes the round; the gem
      count on character select matches what Round Over showed after
      collecting them; nothing about the new chest spawns/opens breaks an
      existing character's own kit or the level-up flow.

**Exit criterion:** a full playthrough can unlock a character by kills, the
select screen never shows more than one character idle-animating at once,
and chests spawn, open, and pay out gems into a wallet that survives to the
next round.

---

## Phase 14 — Debug end-round button, card-based chest reveal
*Goal: two developer asks in one message — a dedicated debug control to end
a round from the pause menu (distinct from the always-on-screen DIE button)
verified to carry kills/score/coins/gems through correctly, and replacing
the chest reveal's gem-rarity-group payout with a real playing-card draw
(`assets/images/cards`, delivered pre-session) that spins fast and settles
on one card, each card paying a specific amount (DECISIONS D-057).*

- [x] **14.1** `ArenaGame.debugEndRound()` — Settings' existing DEBUG
      section (reached via Pause Menu, alongside the god-mode toggle and
      GRANT LEVEL UP), same "queued, plays out once you close the pause
      menu" shape `debugGrantLevelUp` already uses (calling it while paused
      can't run `update()`, so it can't fire until the menu actually
      closes/resumes). Internally identical to the existing `debugDie()` —
      both just set `_roundEndDelay = 0`, read by `update()`'s existing
      check, which calls the same `_endRound()` every real death does. That
      unconditionally banks `coinsEarned`/`gemsCollected`/`kills` into the
      persistent wallet (D-047/D-055) regardless of how the round ended, so
      "make sure it takes the points/kills/score" needed no new bookkeeping
      — reusing the proven path *is* the guarantee.
- [x] **14.2** Chest reveal replaced with a card draw (DECISIONS D-057) —
      `core/economy.dart`: `kChestDeck`, a real 52-card deck (4 suits x 13
      ranks, `assets/images/cards/<Suit>/<Rank>.png`) plus 2 Jokers, 54
      cards total; `rollChestCard` draws one uniformly (natural odds for
      free — a Joker is 2/54, an Ace 4/54 — no separate weight table).
      Reward is per-rank (`kCardRankGemValue`: 2-10 face value, Jack/Queen/
      King 15/20/25, Ace 35) or the Joker jackpot (`kJokerGemValue` 75) —
      suit is cosmetic. `ChestComponent._finishOpening` rolls the card up
      front (`rollChestCard`) and hands it to `ArenaGame.onChestOpened`,
      which credits `card.gemReward` into `gemsCollected` immediately — the
      ChestReveal overlay's spin is a reveal *animation* of an
      already-decided result, not a live roll. `_ChestRevealOverlay`
      rewritten as a `StatefulWidget`: 22 flicker steps through random
      `kChestDeck` cards, per-step delay ramping 45ms → 260ms (ease-out,
      slot-reel deceleration) before landing on the real card; CONTINUE is
      disabled until the spin actually finishes.
- [x] **14.3** `flutter analyze` clean, `flutter test` 95/95 (3 new —
      `economy_test.dart`'s `kChestDeck`/`rollChestCard` cases replacing the
      old `rollChestGems` ones), `flutter build apk --debug` succeeds (new
      `assets/images/cards/<Suit>/` folders declared in `pubspec.yaml`,
      including the space in `Back Cards/` — unused by the reveal itself,
      declared anyway since it was delivered alongside the rest).
- [ ] **14.4** On-device verification — **developer** (CLAUDE.md §2): the
      Settings END ROUND button actually ends the round once the pause menu
      closes, and Round Over shows the same kills/coins/gems the round
      actually had (not zeroed/stale); opening a chest spins visibly fast
      then audibly/visually settles on one card, not a jarring hard stop;
      the card shown at the end matches the "+N gems" payout text; CONTINUE
      is unpressable mid-spin; the gem total on character select reflects
      the card's actual payout after the round ends.

**Exit criterion:** a debug round-end from the pause menu produces the same
Round Over numbers a real death would; opening a chest in the arena spins
through cards and settles on one whose payout matches what gets credited.

---

## Phase 15 — Chest reveal polish, and a batch of drop-economy/VFX tunes
*Goal: fix a real overflow bug in the chest reveal, add the shuffle lead-in
and landing bounce it was missing, add main-menu-reachable currency debug
tools, and land a batch of small, independent tuning asks across the gem
economy, the boss's teleport VFX, Aura, and Ultimate Mirror (DECISIONS
D-058/D-059).*

- [x] **15.1** Chest reveal overflow fix — `_ChestRevealOverlay`'s content
      wrapped in `SingleChildScrollView` (was `Padding` directly under
      `Center`), so a short viewport scrolls instead of overflowing. Real
      bug, not a tune.
- [x] **15.2** Chest reveal: card-back shuffle lead-in (`_shuffling` phase,
      8 steps @ 70ms through the 2 `Back Cards/` assets) before the
      existing D-057 face-card spin, and a jump/land bounce
      (`AnimationController` + `TweenSequence`, ease-out up then
      bounce-out down) once the spin lands on the real card.
- [x] **15.3** Currency debug tools reachable from Settings off the main
      menu, not just the arena's Pause Menu — `MetaProgressionRepository.
      debugAdjustCoins`/`debugAdjustGems`/`debugResetWallet`; Settings'
      DEBUG section now loads/shows the wallet unconditionally, with the
      existing `ArenaGame`-only tools (god mode, grant level up, end round)
      still gated on a live game underneath the same header.
- [x] **15.4** Gem drop chance -25% on top of D-046's existing -80%
      (`kGemBaseDropChance`/`kGemDropChancePerLevel`, `core/economy.dart`).
- [x] **15.5** Gems float in place same as potions — `GemComponent` reuses
      the exact sine-bob `PotionComponent` already has; the driving
      constants renamed `kItemFloatAmplitudePx`/`kItemFloatPeriodSec`
      (were `kPotionFloat*`) since both pickups now share them.
- [x] **15.6** Boss's teleport `effect_anima` flourish -40% size
      (`kBossAnimaWidthPx`, new constant — `kAnimaWidthPx` itself untouched
      since the chest-opening sequence also plays it and wasn't asked to
      change).
- [x] **15.7** Aura shield -25% radius (`UpgradeAmounts.auraRadiusPx`,
      also the actual damage radius, not just the visual) and -20%
      brightness (new `_brightness` constant folded into
      `AuraComponent`'s existing contrast color matrix).
- [x] **15.8** Ultimate Mirror: multiple mirrors now desync their
      active/cooldown cycle by 0.5s per spawn order
      (`UpgradeAmounts.mirrorStaggerDelaySec`, `MirrorComponent.
      staggerDelaySec`); each mirror also rolls a fire axis (horizontal or
      vertical) at spawn and re-rolls it every reactivation, instead of
      always firing left/right.
- [x] **15.9** Ultimate Mirror's bolts never expire/despawn —
      `ProjectileComponent.neverExpire` (new, default `false`, every other
      projectile unaffected) skips the max-range/out-of-bounds despawn
      checks entirely; only an actual hit removes one.
- [x] **15.10** `flutter analyze` clean, `flutter test` 95/95 (unchanged —
      every change in this phase is a tuning constant or component-level
      behavior, no new `core/` formula), `flutter build apk --debug`
      succeeds.
- [ ] **15.11** On-device verification — **developer** (CLAUDE.md §2): the
      chest reveal no longer overflows on the real device, the back-card
      shuffle reads as a distinct lead-in and the jump/land reads as
      landing (not a jitter); the main-menu Settings currency buttons
      actually move the wallet and Character Select reflects it; gems
      visibly bob like potions; the boss's teleport flourish reads smaller
      without looking wrong; the Aura ring reads smaller/dimmer without
      disappearing or feeling useless; with 2-3 mirrors up, they visibly
      fall out of sync and sometimes fire vertically; mirror bolts really
      never poof, and a long round with several mirrors up doesn't visibly
      tank performance from the growing live-bolt count.

**Exit criterion:** the chest reveal has no layout bugs and reads as a
complete shuffle→spin→land→reveal sequence; the currency debug tools work
from both Settings entry points; every tuning number above lands the way
its ask described on an actual device.

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
- ~~Camera larger than the screen, with scroll~~ — started Phase 9 (D-040):
  camera + free movement (9.1), endless floor + camera-relative spawning
  with straggler culling (9.3/9.4) all land — D-040/D-041.
- Enemy separation/steering so they stop stacking
- Object pooling if the perf budget gets tight
- Haptics on hit and death
- Play Store packaging, signing, release build config
