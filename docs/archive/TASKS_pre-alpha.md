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
      bug, not a tune. **Incomplete — the actual overflow was a separate,
      inner fixed-height box further down the same tree; the real fix
      landed in 16.1 (DECISIONS D-060).**
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

## Phase 16 — Chest overflow (the real fix), boss teleport telegraph/delay/pop/distance
*Goal: fix the chest reveal overflow for real (15.1's fix addressed a
different overflow than the one actually reported), and rework the boss's
teleport into a telegraphed, delayed, longer jump with an arrival bounce
(DECISIONS D-060).*

- [x] **16.1** Chest reveal overflow, the real fix — the reward text sat in
      a fixed `SizedBox(height: 46)` a couple of lines of real text were
      taller than; replaced with `ConstrainedBox(minHeight: 46)` + `Center`,
      which can grow to fit content but never clips it. 15.1's
      `SingleChildScrollView` (a different, real fix for a different,
      real overflow source) stays.
- [x] **16.2** Boss teleport destination telegraph — `effect_anima` now
      plays at the destination the boss is about to appear at, not at its
      current position (D-042's original behavior).
- [x] **16.3** Boss teleport delay — `BossStats.teleportDelaySec` (0.5s):
      the boss is frozen (no walk/fire/contact damage) between the
      telegraph appearing and it actually arriving.
- [x] **16.4** Boss teleport arrival pop — a size-down-then-up sine bounce
      (`BossComponent._popScale`/`_tickTeleportPop`, 0.28s, dips to 60%
      size at its midpoint) plays once the boss actually appears.
- [x] **16.5** Boss teleport distance — `BossStats.
      teleportDistanceMultiplier` (1.6) lands further past the exact
      opposite-of-player mirror point D-042 used, instead of exactly on it.
- [x] **16.6** `flutter analyze` clean, `flutter test` 95/95 (unchanged —
      no new `core/` formula, both changes are UI layout and
      component-level behavior), `flutter build apk --debug` succeeds.
- [ ] **16.7** On-device verification — **developer** (CLAUDE.md §2): the
      "BOTTOM OVERFLOWED" warning is actually gone now; the destination
      telegraph clearly shows where the boss is about to appear before he
      does; the freeze during the wind-up reads as an intentional cast, not
      a hang/bug; the arrival pop reads as landing, not a glitch; the
      teleport distance feels meaningfully longer than before.

**Exit criterion:** no overflow warning fires from the chest reveal under
any content/screen combination; a full boss teleport reads as one clear
sequence — telegraph, wait, jump, land — landing noticeably further away
than the old exact-mirror teleport.

---

## Phase 17 — Chest reveal confetti, projectiles despawn further off-screen
*Goal: a confetti burst on the chest reveal's landing, and fix every
projectile type despawning right at the visible edge instead of fully
clearing the screen first (DECISIONS D-061).*

- [x] **17.1** Chest reveal confetti — ~26 particles (`_ConfettiParticle`),
      half starting off-screen left and half off-screen right
      (`Alignment` beyond ±1), arcing in and landing scattered near the
      card; half painted behind the card, half in front
      (`_ConfettiLayer`/`_ConfettiPainter`, a `CustomPainter`, no new
      package). Fires alongside the existing D-058 landing bounce.
- [x] **17.2** Every projectile now despawns only once it's cleared the
      visible edge by a full extra sprite-width
      (`kProjectileDespawnMarginFactor`), not the instant its center
      crosses the bare edge — real bug fix, not a tune (the knife
      "spawning [poofing] right at the outside border" was the reported
      symptom, but the bare-edge check was shared by the bolt/mirror bolt
      and Spiral Fire too). Boss/mirror bolts still bounce off the exact
      bare edge as before (DECISIONS D-052, unaffected) — the margin only
      delays the *final* despawn once bounces are exhausted.
- [x] **17.3** `flutter analyze` clean, `flutter test` 95/95 (unchanged —
      confetti is UI/animation, the despawn margin is a component-level
      distance check, neither is `core/` formula territory), `flutter
      build apk --debug` succeeds.
- [ ] **17.4** On-device verification — **developer** (CLAUDE.md §2): the
      confetti visibly flies in from both screen edges and settles
      convincingly in front of/behind the card, not just a flash; every
      projectile type (bolt, knife, spiral fire, mirror bolt) now clears
      the screen before poofing instead of vanishing mid-edge.

**Exit criterion:** the chest reveal's landing moment reads as a real
celebration (card + bounce + confetti together); no projectile type visibly
despawns while still partly on-screen.

---

## Phase 18 — Layered BGM (2/3/1/4.wav), confetti independent-fall fix
*Goal: wire the 4 delivered music tracks into a beat-synced, layered BGM
system (base + Core + boss + death), and fix the two real complaints on
the D-061 confetti burst (DECISIONS D-062/D-063).*

- [x] **18.1** `BgmController` (`core/bgm_controller.dart`) — app-wide
      singleton, started once from `ArenaApp.initState`. `2.wav` is the
      permanent base layer; `enterCore()`/`bossSpawned()`/`bossCleared()`/
      `died()`/`leaveArena()` layer `3.wav`/`1.wav`/`4.wav` in and out.
      Every new layer syncs to the base layer's own loop boundary before
      starting (`_waitForBaseLoopBoundary`) and fades 0%→100% over 2.5s;
      layers fade back out the same way when removed.
- [x] **18.2** Wired into `ArenaGame` (`resetRound` → `enterCore`,
      `_maybeSpawnBoss`/`onBossKilled` → `bossSpawned`/`bossCleared`,
      `_endRound` → `died` on a real death or `leaveArena` otherwise) and
      `arena_screen.dart` (both MAIN MENU buttons → `leaveArena`, covering
      the one path `_endRound` never sees: quitting mid-round via the
      Pause Menu). `Settings.musicVolume` (previously unwired) now
      actually drives every layer's volume, live.
- [x] **18.3** mp3 compression — considered, explicitly **not done**: MP3's
      encoder-delay/gapless-looping behavior varies by platform/decoder,
      and this whole feature's one hard requirement (stated twice by the
      developer) is exact loop-boundary sync. Kept as lossless WAV; see
      DECISIONS D-062 for the full reasoning.
- [x] **18.4** Confetti: independent per-particle timing
      (`startDelayFraction`) instead of one shared flight fraction, and
      `endAlign` moved well outside the visible box (was landing near the
      card and visibly stopping there) with `Curves.easeIn` instead of
      `easeOut` so it reads as falling away, not decelerating into a stop.
- [x] **18.5** `flutter analyze` clean, `flutter test` 95/95 (unchanged —
      audio/timing plumbing and animation tuning, no new `core/` formula),
      `flutter build apk --debug` succeeds.
- [ ] **18.6** On-device verification — **developer** (CLAUDE.md §2, and
      the first real audio-output check this project has ever needed): the
      whole BGM stack stays in phase with itself through several
      boss-spawn/clear cycles over a long round (this can't be verified
      without real speakers); fades actually sound like 2-3s crossfades,
      not clicks; Music Volume slider affects it live; the confetti burst
      now reads as individual pieces launching over time and actually
      exits the screen instead of stopping mid-air.

**Exit criterion:** a full round's audio is one continuous, in-phase
layered track from menu → Core → boss → (death or menu), with no audible
seam at any layer transition; the confetti burst reads as a real scatter,
not a synchronized clump that freezes.

**Superseded by Phase 19 below** — the layered BGM this phase built was
pulled back out before 18.6's on-device pass ever happened; the layering
claims above no longer describe the code (DECISIONS D-064).

---

## Phase 19 — BGM reverted to one track; unlock bar-fill height bug; real coin icon
*Goal: three developer-reported fixes in one pass — deleting the D-062
layered BGM stack the developer decided against, a genuine sizing bug on
the character-select unlock bar, and swapping the placeholder coin badge
for the real coin asset the developer delivered (DECISIONS D-064).*

- [x] **19.1** `BgmController` cut down to just the permanent base layer
      (`2.wav`) + `setMasterVolume` — the Core/boss/death layers (3/1/4.wav)
      and every trigger call site (`ArenaGame`, both `arena_screen.dart`
      MAIN MENU buttons) are deleted, not disabled.
- [x] **19.2** `_LockedPanel` (`character_select_screen.dart`): both
      `bar-empty.png` and `bar-filling.png` now get an explicit
      `height: barHeight` — previously only `bar-empty` (always
      full-width) accidentally kept a constant derived height,
      `bar-filling`'s width varies per character so its un-pinned height
      did too.
- [x] **19.3** `CoinIcon` (`ui/widgets/coin_icon.dart`) crops frame 0 of
      the real `consumables/coin-icon.png` sheet; replaces
      `ui/currency-counter.png` in `character_select_screen.dart`'s and
      `upgrades_screen.dart`'s wallet rows and Round Over's `_CoinCounter`
      badge (now an icon+text row instead of a plaque). The flying coins
      in that same Round Over reveal switch from `money.png`'s tier-0 cell
      to `coin-icon.png` too. Fixed a latent NaN-alignment bug in
      `_SpriteCell` along the way (divide-by-zero on a single-row sheet).
- [x] **19.4** `flutter analyze` clean, `flutter test` 95/95 (unchanged —
      no `core/` formula touched), `flutter build apk --debug` succeeds.
- [x] **19.5** Coin icon was actually invisible on-device (developer
      report) — root cause was `Image`'s default `fit` (`BoxFit.
      scaleDown`, never scales up) drawing the sheet at native pixel size
      centered in the oversized crop box instead of stretched to it, so
      the visible crop window showed nothing. Both `CoinIcon` and the
      pre-existing `_SpriteCell` (D-043's flying coins, likely never
      visible either) now pass `fit: BoxFit.fill` explicitly. See D-064's
      follow-up.
- [ ] **19.6** On-device verification — **developer**: only the base
      track plays through a full round (menu → Core → boss → death/menu),
      no layers ever kick in; the unlock bar fills to the same visual
      height for every locked character, just different widths; the coin
      icon actually shows now (not stretched/cropped wrong) in the wallet
      rows, the round-over badge, and the flying-coin reveal.

**Exit criterion:** one BGM track, no layering; the unlock bar-fill height
matches `bar-empty` for every character regardless of fill fraction; the
real coin asset is the only coin graphic shown anywhere coins are
displayed.

---

## Phase 20 — Debug character unlock; character-select tap arrows
*Goal: two developer-requested dev-convenience/UX additions, unrelated to
each other, in one pass (DECISIONS D-065).*

- [x] **20.1** `MetaProgressionRepository.debugSetLifetimeKills` — raises
      `lifetimeKills` to at least the given value (never lowers it).
      Settings' DEBUG section (main-menu reachable, same as the currency
      debug rows) gets an "UNLOCK ALL CHARACTERS" button that passes the
      highest `unlockKillThreshold` across `kCharacters`.
- [x] **20.2** `_CarouselArrow` (`character_select_screen.dart`) — tap
      buttons flanking the character-select `PageView`, paging via
      `PageController.previousPage`/`nextPage`; disabled at either end of
      `kCharacters`. Placeholder `Icons.chevron_left`/`chevron_right`, no
      dedicated pixel-art asset yet.
- [x] **20.3** `flutter analyze` clean, `flutter test` 95/95 (unchanged),
      `flutter build apk --debug` succeeds.
- [ ] **20.4** On-device verification — **developer**: UNLOCK ALL
      CHARACTERS (Settings, reachable from the main menu) makes all 4
      character-select slots selectable immediately; the left/right arrows
      beside the character page it, disabled/dimmed at the first and last
      character.

**Exit criterion:** every character-select slot can be unlocked from
Settings without playing; the carousel can be paged by tapping the arrows
as well as swiping.

---

## Phase 21 — Android back button could skip round rewards
*Goal: one developer-reported bug fix (DECISIONS D-066).*

- [x] **21.1** `ArenaScreen` wrapped in `PopScope(canPop: false, ...)`;
      `_handleBack()` redirects back to the existing deliberate action for
      the current state (leave if round's over and rewards are already
      banked, resume if Pause Menu's open, no-op on LevelUp/ChestReveal,
      otherwise open the Pause Menu) instead of letting the platform pop
      the arena route straight off the Navigator.
- [x] **21.2** `flutter analyze` clean, `flutter test` 95/95 (unchanged),
      `flutter build apk --debug` succeeds.
- [ ] **21.3** On-device verification — **developer**: mid-round back
      press/edge-swipe opens the Pause Menu instead of exiting; back while
      Pause Menu is open resumes; back after death (Round Over showing)
      still leaves normally.

**Exit criterion:** a bare Android back press can no longer exit a round
in progress without going through the Pause Menu's own MAIN MENU button.

---

## Phase 22 — Upgrades screen redesign: non-scrolling carousel, 3 new dials
*Goal: developer-requested redesign of the Upgrades screen, from a
screenshot showing both the scrolling and a real label-wrap bug
(DECISIONS D-067).*

- [x] **22.1** `ui/widgets/carousel_arrow.dart` — `CarouselArrow`/
      `CarouselArrowRow`/`PageDots` extracted out of
      `character_select_screen.dart` into shared, public widgets;
      `CharacterSelectScreen` updated to use them (no behavior change
      there).
- [x] **22.2** `UpgradesScreen` rebuilt as a 3-page `PageView` (STR/VIT/
      DEX/INT — Corruption + 3 new dials — COMING SOON placeholder),
      paged with the same carousel widgets. Every page lays its rows out
      with `Expanded`, no scroll view anywhere — can't overflow-scroll
      regardless of screen height.
- [x] **22.3** 3 new persistent `MetaStat` dials — HASTE (+5% attack speed/
      level), FORTUNE (+10% coin value/level), RESOLVE (+2% damage
      resistance/level, +0.05 HP regen/level) — `core/game_rules.dart`
      formulas, `MetaProgression` fields + `SharedPreferences` persistence,
      wired into `ArenaGame`'s fire-cooldown/coin-roll and
      `PlayerComponent`'s regen/damage-resistance calcs.
- [x] **22.4** Fixed `StatBar`'s real label-wrap bug (the screenshot's
      "COR / RUP / TION" stack) — wider label column + `maxLines: 1`/
      `TextOverflow.ellipsis`.
- [x] **22.5** `flutter analyze` clean, `flutter test` 100/100 (+5 new:
      haste/fortune/resolve multiplier tests, MetaProgression buy/persist
      tests), `flutter build apk --debug` succeeds.
- [ ] **22.6** On-device verification — **developer**: Upgrades screen
      never scrolls on any page; arrows/dots page through all 3 pages;
      CORRUPTION/HASTE/FORTUNE/RESOLVE labels render on one line, not
      stacked; buying a level of each of the 3 new dials visibly does
      something in a round (faster attacks, bigger coin drops, less
      damage taken / faster regen).

**Exit criterion:** the Upgrades screen never scrolls; STR/VIT/DEX/INT are
page 1, CORRUPTION+HASTE+FORTUNE+RESOLVE are page 2, page 3 reads COMING
SOON; every label renders on one line.

---

## Phase 23 — Locked-character panel's progress bar removed
*Goal: one developer-requested trim (DECISIONS D-068).*

- [x] **23.1** `_LockedPanel` (`character_select_screen.dart`) drops the
      bar-empty/bar-filling progress bar; keeps `star-empty.png` plus the
      existing kill-count text.
- [x] **23.2** `flutter analyze` clean, `flutter test` 100/100 (unchanged),
      `flutter build apk --debug` succeeds.
- [ ] **23.3** On-device verification — **developer**: locked character
      slots show just the hollow star + "X / Y kills to unlock" text, no
      bar underneath it.

**Exit criterion:** locked-character panel shows the hollow star and kill
count only, no progress bar.

---

## Phase 24 — Gem currency display, a real SHOP, 3rd Upgrades page
*Goal: gems get shown properly and finally spent on something; the
Upgrades screen's "COMING SOON" 3rd page becomes real. Developer asked for
all three in one message; SHOP's currency/item-type and the 3 new dials
were asked and confirmed rather than guessed (DECISIONS D-069).*

- [x] **24.1** `ui/widgets/gem_icon.dart` — `GemIcon`, cropping
      `consumables/gems.png`'s legendary column (highest tier), same
      technique `CoinIcon` (D-064) uses for coins. Character select's
      wallet row swaps `star-full.png` for it; Round Over gets a new
      `_GemCounter` (icon + tweened count) replacing the old plain
      `'Gems collected: N'` text row.
- [x] **24.2** `core/shop.dart` — `ShopItemId`/`ShopItem`/`kShopItems` (5
      gem-priced, permanent one-time items: Vitality Charm, Swift Boots,
      Sharp Edge, Iron Will, Second Wind). `MetaProgression` gained
      `ownedItemIds` + `buyItem`/`ownsItem` + bonus getters, persisted via
      `SharedPreferences`.
- [x] **24.3** All 5 items wired into real gameplay effects: max HP/move
      speed (`PlayerComponent`), auto-attack damage multiplier
      (`ArenaGame.resolveAttackDamage`, base-attack-only scope), damage
      resistance (`PlayerComponent.takeDamage`), and a once-per-round
      revive (`ArenaGame.tryConsumeRevive`/`reviveAvailable`).
- [x] **24.4** `ShopScreen` rebuilt from the D-047 empty placeholder into a
      real scrollable list of buyable items (same visual language as
      `UpgradesScreen`'s rows).
- [x] **24.5** `core/game_rules.dart` gained 4 more dials — MAGNET (pickup
      radius), LUCK (gem drop chance), REGEN (HP regen), CRIT (crit chance
      + damage) — wired into `gem`/`potion`/`chest` pickup radius,
      `economy.dart`'s `gemDropChance`, `PlayerComponent`'s regen calc, and
      `ArenaGame.resolveAttackDamage`. `MetaStat` gained the 4 matching
      members; `UpgradesScreen`'s 3rd page is now real, `_ComingSoonPage`
      deleted.
- [x] **24.6** `flutter analyze` clean, `flutter test` green (new cases:
      the 4 dial functions, `gemDropChance`'s new optional param,
      `MetaProgression.buyItem`/`ownsItem`), `flutter build apk --debug`
      succeeds.
- [ ] **24.7** On-device verification — **developer**: gem icon (legendary
      sprite, not a star) shows on character select and Round Over with
      the right count; SHOP purchases deduct gems, persist across an app
      restart, and are actually felt next round (HP/speed/damage/
      resistance/a lethal hit surviving once at 50% HP with Second Wind
      owned); Upgrades page 3's MAGNET/LUCK/REGEN/CRIT buy and level with
      coins same as pages 1-2, and each is felt in a round (wider pickup
      range, more gem drops, passive regen, occasional bigger hits).

**Exit criterion:** gems are a real, visible, spendable currency; SHOP has
5 working items; Upgrades has 12 total dials across 3 full pages, no
placeholder left.

---

## Phase 25 — SHOP paged (10 more items), Round Over gem reveal gets flying pieces + sparkle VFX
*Goal: SHOP stops scrolling and gets 2 more real pages; gems' Round Over
reveal matches coins' flying-piece animation, plus its own extra flourish.
Developer asked for both in one message (DECISIONS D-070).*

- [x] **25.1** `core/shop.dart` — `kShopItems` (flat) restructured into
      `kShopPages` (3 pages of 5, `kShopItems` now a derived flattening so
      nothing downstream changed shape). 10 new `ShopItemId`s across pages
      2-3: Quick Hands, Battle Fury, Potion Master, Steel Nerves, Vampiric
      Touch, Treasure Hunter, Scholar's Insight, Golden Touch, Gem Hoarder,
      Boss Hunter.
- [x] **25.2** All 10 wired into real gameplay effects — attack cooldown,
      `ArenaGame.resolveAttackDamage` (Battle Fury's live-HP check),
      potion heal, `game_rules.dart`'s `rollIsElite` (new optional
      `chanceMultiplier` param), on-kill heal, chest gem reward, XP gain,
      coin roll, gem drop chance, and a boss-kill gem bonus (bosses
      previously dropped none at all).
- [x] **25.3** `ShopScreen` rebuilt into the exact `UpgradesScreen` shape —
      `PageController` + `CarouselArrowRow`/`PageDots`, `Expanded` rows, no
      scroll view anywhere.
- [x] **25.4** `_GemCounter` (`arena_screen.dart`) gained `_CoinCounter`'s
      flying-piece mechanic (reusing `_FlyingCoinSpec`/`_SpriteCell` as-is,
      cropping the legendary gem cell instead of the coin cell), plus a
      looping 6-glint sparkle burst (`_GemSparkleSpec`) coins don't have.
- [x] **25.5** `flutter analyze` clean, `flutter test` green (new cases:
      `kShopPages` shape, all 10 new bonus getters, `rollIsElite`'s new
      param), `flutter build apk --debug` succeeds.
- [ ] **25.6** On-device verification — **developer**: SHOP pages through
      3 screens with arrows/dots and never scrolls on any page; each of
      the 10 new items is felt once bought (attack speed, a damage spike
      under 50% HP, bigger potion heals, fewer Elites, on-kill healing,
      bigger chest/XP/coin payouts, more frequent gem drops, a bonus gem
      haul on a boss kill); Round Over's gem counter shows gems flying in
      and shrinking like the coins do, with a sparkle twinkle looping
      around the total the whole time the overlay is up.

**Exit criterion:** SHOP is a 3-page, non-scrolling carousel of 15 working
items; Round Over's gem reveal visually matches the coin reveal's flying
pieces and reads fancier, not just a reskin.

---

## Phase 26 — Chest anima tune, independent-falling confetti, CHAOS rename, Round Over kill counter
*Goal: 4 small, unrelated polish asks in one message (DECISIONS D-071).*

- [x] **26.1** `ArenaGame.spawnEffect` gained a `contrast` param (folded into
      one generalized `_colorMatrix`, replacing the old pure-multiply
      `_brightnessMatrix`); `ChestComponent`'s anima now sizes off its own
      chest's rendered width (`kChestAnimaSizeFactor`, 0.85) instead of the
      much-bigger flat `kAnimaWidthPx`, plus a reduced-contrast tune
      (`kChestAnimaContrast`, 0.7).
- [x] **26.2** Chest-reveal confetti: count 26 -> 34 (+30%), spawn-location
      spread widened 30%, and each `_ConfettiParticle` gained its own
      wobble amplitude/frequency/phase so pieces visibly diverge while
      falling instead of all tracing the same line.
- [x] **26.3** `MetaStatLabels`'s CORRUPTION label shortened to CHAOS
      (display only — enum member/fields/formulas all still `corruption*`).
- [x] **26.4** New `_KillCounter` (`arena_screen.dart`) — hollow star +
      counting kills, golden stars flying in like coins/gems, center icon
      swaps to gold and plays the exact same jump/land bounce
      `_ChestRevealOverlay`'s card landing uses, once the count finishes.
      Replaces the old plain `'Enemies killed'` text row.
- [x] **26.5** `flutter analyze` clean, `flutter test` 111/111 (unchanged —
      no new pure-function logic), `flutter build apk --debug` succeeds.
- [ ] **26.6** On-device verification — **developer**: chest anima reads
      smaller than the chest itself and flatter/less punchy; confetti burst
      is bigger, wider, and pieces drift independently as they fall; CHAOS
      shows on Upgrades page 2 and still functions exactly like Corruption
      did; Round Over's kill counter shows golden stars flying in and the
      hollow star turning gold with a jump/bounce right as the count lands.

**Exit criterion:** all 4 asks land as specced with no regression to the
existing chest/confetti/Upgrades/Round-Over behavior around them.

---

## Phase 27 — LevelUp redesign, exclusive skill groups (a real meta), chest confetti replaced
*Goal: the "choose a power" screen gets a real visual redesign with
text-fit guaranteed, some powers become mutually exclusive on purpose, and
the chest-reveal confetti is replaced with a different VFX (DECISIONS
D-072).*

- [x] **27.1** `core/progression.dart` gained `kExclusiveUpgradeGroups`
      (`{aura, ultimateMirror, projectileRay, projectileThunder}`),
      `lockedOutByExclusiveGroups`, and `isExclusiveUpgrade`;
      `rollUpgradeChoices` excludes locked-out kinds alongside the existing
      max-picks check. Stat bumps, `knifeMastery`, and `defenceCrystal`
      stay outside any group.
- [x] **27.2** New `_LevelUpCard`/`_Tag` (`arena_screen.dart`) replace the
      bare `OutlinedButton` choices — bordered panel, label + STAT/SKILL/
      PASSIVE tag, full untruncated description, and an EXCLUSIVE
      badge/warning on the 4 grouped skills. The whole popup is wrapped in
      a `SingleChildScrollView` so it can't overflow on any screen size or
      description length.
- [x] **27.3** Chest-reveal confetti (`_ConfettiParticle`/`_ConfettiLayer`/
      `_ConfettiPainter`) deleted; replaced with a radial sparkle burst
      (`_CardLandSparkleSpec`) reusing the gem counter's own
      `Icons.auto_awesome` sparkle look (D-070), firing outward from the
      card once it lands.
- [x] **27.4** `flutter analyze` clean, `flutter test` 117/117 (+6 new:
      exclusive-group roll/lockout tests), `flutter build apk --debug`
      succeeds.
- [ ] **27.5** On-device verification — **developer**: every LevelUp card's
      text is fully visible, nothing clipped/overflowing, on every
      description including Knife Mastery's; picking Aura (or Mirror/Ray/
      Thunder) removes the other 3 from every later choice that round,
      while the picked one can still level further; the EXCLUSIVE badge
      shows before picking; chest reveal shows the new sparkle burst with
      no confetti anywhere.

**Exit criterion:** LevelUp never clips text on any card; exactly one of
Aura/Mirror/Ray/Thunder is pickable per round (whichever comes first);
confetti is gone, replaced by the sparkle burst.

---

## Phase 28 — BGM track swap
*Goal: swap the app-wide BGM track (DECISIONS D-073).*

- [x] **28.1** `BgmController._basePath` -> `core/electric-eel-fishing.ogg`
      (was `core/2.wav`); confirmed `FlameAudio.loop`'s `PlayerMode.
      lowLatency` is already the gapless looping mode ("perfect loop"),
      documented so a future swap doesn't regress onto `loopLongAudio`'s
      gapped one.
- [x] **28.2** `flutter analyze` clean, `flutter build apk --debug`
      succeeds.
- [ ] **28.3** On-device verification — **developer**: the new track plays
      app-wide from boot, fades in, and loops with no audible click/gap at
      the seam.

**Exit criterion:** electric-eel-fishing.ogg is the only BGM track, looping
seamlessly.

---

## Phase 29 — Anima z-order fixes, chest-reveal corner sparkles, boss teleport cooldown, hurt no longer freezes movement, BGM static fixed
*Goal: 5 bug/polish fixes in one message, one marked highest priority
(DECISIONS D-074/D-075).*

- [x] **29.1 (highest prio)** BGM static noise fixed — `BgmController`
      switched from `FlameAudio.loop` (SoundPool/`lowLatency`, prone to
      static on a full music track) to `FlameAudio.loopLongAudio`
      (MediaPlayer), accepting `loopLongAudio`'s own documented small
      loop-point seam as the trade-off.
- [x] **29.2** Chest-opening anima and the boss's teleport-destination
      anima both now pass `priority: ArenaPriority.groundEffects` to
      `ArenaGame.spawnEffect`, rendering behind the chest/boss sprite
      instead of `spawnEffect`'s default (above both).
- [x] **29.3** Chest-reveal sparkle VFX: fixed a real bug where the
      landing-burst glints (D-072) sat fully visible, dead-center on the
      card for the whole shuffle+spin (the burst controller's own rest
      value read as "fully faded in, no offset") — that layer is now only
      mounted once landed. Added the actually-requested new VFX: 4 ambient
      corner glints, pulsing, painted behind the card, visible only while
      still shuffling/spinning.
- [x] **29.4** `BossStats.teleportCooldownSec` (3.0) — the boss can't start
      a new teleport wind-up until this many seconds after the last one
      began, even if the player is still (or again) inside the trigger
      distance.
- [x] **29.5** `PlayerComponent`'s movement no longer skips applying input
      while the `hurt` recoil pose is playing — every non-lethal hit used
      to freeze the player in place for that pose's whole duration.
- [x] **29.6** `flutter analyze` clean, `flutter test` 117/117 (unchanged —
      no pure `core/` logic changed), `flutter build apk --debug`
      succeeds.
- [ ] **29.7** On-device verification — **developer**: BGM has no static
      anywhere in playback; chest and boss anima both read behind their
      sprite; chest reveal shows 4 pulsing corner glints behind the card
      only while still choosing, no sparkles visible before that, clean
      handoff to the landing burst; the boss can't re-teleport within 3s
      of its last one; taking damage no longer stops/slows the character.

**Exit criterion:** all 5 fixes verified with no regression to BGM, the
chest reveal, the boss fight, or basic movement.

---

## Phase 30 — A real SFX layer + an XP bar
*Goal: wire 7 new SFX files in end to end, and add an XP bar matching the
existing HP bar (DECISIONS D-076).*

- [x] **30.1** `core/sfx_player.dart` — `SfxPlayer`, an app-wide singleton
      (same "read Settings at boot, update live off the slider" shape as
      `BgmController`), covering footsteps, player damage, button taps,
      projectile shoot, level up, and chest-card select/chosen (the last
      one via a held, interrupt-and-repitch `AudioPlayer`, not a
      fire-and-forget one-shot).
- [x] **30.2** Footsteps wired into `PlayerComponent`'s movement block
      (alternating, timer-based, resets when idle).
- [x] **30.3** Player-damage SFX wired into `PlayerComponent.takeDamage`.
- [x] **30.4** Tap SFX on every button — `PixelButton`/`CarouselArrow`
      play it internally, `ScreenScaffold` gained an explicit `BackButton`
      to hook, every other raw button wrapped via new
      `ui/widgets/tap_sfx.dart`'s `withTapSfx`.
- [x] **30.5** Projectile-shoot SFX wired into `PlayerComponent.playFire`
      (every base `AttackBehavior`'s shared post-attack hook — Ray/
      Thunder/Aura/Mirror never call it, so "not power-ups" holds by
      construction).
- [x] **30.6** Level-up SFX wired into `ArenaGame.grantXp`/
      `debugGrantLevelUp`.
- [x] **30.7** Chest-card select/chosen wired into
      `_ChestRevealOverlayState`'s shuffle/spin timers — select on every
      swap (pitch-varied, self-interrupting), chosen on the final landing.
- [x] **30.8** New `game/components/xp_bar.dart`'s `XpBarComponent` — same
      shape as `HpBarComponent`, positioned via `onGameResize` since a
      bottom anchor (unlike the HP bar's fixed top-left) needs the actual
      viewport height. `ArenaGame` gained a public `xpFraction` getter.
- [x] **30.9** `flutter analyze` clean, `flutter test` 117/117 (unchanged —
      no new pure `core/` logic), `flutter build apk --debug` succeeds.
- [ ] **30.10** On-device verification — **developer**: footsteps play
      while moving and stop when idle; damage sound plays on a hit; every
      button everywhere makes a tap sound (sliders/switches don't); only
      the base auto-attack plays the shoot sound, never a power-up; level
      up plays its sound; chest-card flicker pitches per swap with no
      overlap and isn't too loud, landing on a distinct chosen sound; the
      XP bar fills at the bottom without colliding with the joystick.

**Exit criterion:** all 7 new SFX are audible at their specced trigger and
nowhere else; the XP bar reads clearly at the bottom of the arena.

---

## Phase 31 — Pixel font app-wide, chest sparkle bug fixed for real, exclusive pairs, a real LevelUp redesign
*Goal: 4 follow-up asks in one message on top of D-072/D-076 (DECISIONS
D-077/D-078).*

- [x] **31.1** `pixel.ttf` declared as a `PixelFont` family in
      `pubspec.yaml`, set as `ThemeData.fontFamily` in `app.dart` — every
      screen's text picks it up automatically, no per-`TextStyle` edits.
- [x] **31.2** The D-074 "corner sparkles behind the card while choosing"
      feature removed outright (it read as the same "sparkles visible
      before chosen" complaint regardless of z-order) — card display
      reverts to the plain jump-bounce it had pre-D-074. The landing burst
      (already correctly gated) is untouched.
- [x] **31.3** `kExclusiveUpgradeGroups` restructured from one 4-way clique
      into 3 pairs (`{aura, ultimateMirror}`, `{ultimateMirror,
      projectileThunder}`, `{projectileThunder, projectileRay}`) — a pick
      only locks its paired partner(s), not the whole roster. New
      `exclusiveLockTargets(kind)` feeds the LevelUp card's warning the
      real partner name(s).
- [x] **31.4** `_LevelUpCard` redesigned: a 44px icon badge per skill
      (real game art cropped via new `_UpgradeIconSprite`, generalizing
      `_SpriteCell` for non-square cells; stat bumps get a plain `Icon`),
      a soft drop shadow, and a double border for real depth.
- [x] **31.5** `flutter analyze` clean, `flutter test` 120/120 (exclusivity
      tests rewritten for pairs), `flutter build apk --debug` succeeds.
- [ ] **31.6** On-device verification — **developer**: pixel font renders
      everywhere, legibly at every size; zero sparkles visible before a
      chest card lands; picking one of the 4 exclusive skills only locks
      its real paired partner(s), not all 3 others; LevelUp cards show
      real per-skill icons and read with actual depth, not flat/cheap.

**Exit criterion:** pixel font is the app's only font; chest reveal shows
no sparkle VFX pre-landing; the exclusive-skill mechanic is pairwise, not
all-or-nothing; LevelUp cards read as a finished UI, not a placeholder.

---

## Phase 32 — Root-caused an SFX resource leak (BGM stop/restart, static, desync, a freeze), boss drops a chest, global text scale -25%
*Goal: fix 4 audio symptoms traced to one root cause, add a boss reward,
and shrink the D-077 pixel font (DECISIONS D-079/D-080).*

- [x] **32.1** Root cause found: `SfxPlayer`'s one-shot calls built a
      brand-new, never-disposed `AudioPlayer` on every trigger — leaking
      hundreds of live native audio objects within under a minute of real
      play (footsteps alone fire ~3x/sec), explaining all 4 reported
      symptoms (BGM stopping/restarting, static, desync, a freeze) at once.
- [x] **32.2** `SfxPlayer` rewritten onto `FlameAudio.createPool` — one
      small pre-warmed player pool per sound file, reused for the app's
      whole lifetime, auto-returned to the pool on completion. New
      `SfxPlayer.preload()`, called at boot. `chest-card-select` (needs
      per-play pitch) stays on its own bounded, self-interrupting
      dedicated player — confirmed not the leak source.
- [x] **32.3** `ArenaGame.onBossKilled` now calls the existing
      `spawnChest` at the boss's death position, unconditionally.
- [x] **32.4** `MaterialApp.builder` wraps the app in a `MediaQuery` with
      `TextScaler.linear(0.75)` — a flat 25% text-scale cut everywhere,
      one edit instead of ~40 individual `fontSize`s.
- [x] **32.5** `flutter analyze` clean, `flutter test` 120/120 (unchanged),
      `flutter build apk --debug` succeeds.
- [ ] **32.6** On-device verification — **developer**: BGM plays a full
      round with no stop/restart and no static; every SFX fires in sync
      with its action, including in a long sound-heavy round; no freeze
      over an extended session; a boss kill always drops a chest; text
      reads smaller everywhere and still legible at the smallest sizes.

**Exit criterion:** a full round's worth of continuous footsteps/taps/
shots produces no audio degradation and no freeze; boss kills reward a
chest; text is visibly smaller app-wide.

---

## Phase 33 — Root-caused a real crash via logcat: SFX pools on the wrong `PlayerMode`
*Goal: D-079's pooling fix wasn't enough — find and fix the actual crash
(DECISIONS D-081).*

- [x] **33.1** Pulled the device's logcat and found 2 real log entries: a
      `FATAL EXCEPTION`/`IllegalStateException` from `MediaPlayer.
      prepareAsync` inside `audioplayers`' own completion-triggered
      player-reset, and a 30s `TimeoutException` on `BgmController`'s own
      player waiting to prepare — both traced to `PlayerMode.mediaPlayer`
      (D-079's pools, D-075's BGM) contending for the same native pipeline
      under load.
- [x] **33.2** Every pooled SFX now explicitly uses `PlayerMode.lowLatency`
      (`AudioPool.create` called directly) — `SoundPool`, actually built
      for rapid repeated short clips, no prepare-per-play race. Players
      are returned to the pool by hand after a fixed delay (`lowLatency`
      skips the auto-return `mediaPlayer` pools get, since that's the
      exact codepath that crashed).
- [x] **33.3** Added `_inFlight`/`_cardSelectBusy` guards — a trigger
      arriving mid-setup for the same sound is dropped, not queued,
      closing a real unguarded race in `chest-card-select`'s own dedicated
      player too.
- [x] **33.4** `flutter analyze` clean, `flutter test` 120/120 (unchanged),
      `flutter build apk --debug` succeeds.
- [ ] **33.5** On-device verification — **developer**: no crash and no BGM
      stop/restart across a long, sound-heavy round; SFX stay synced to
      their actions for the whole session, not just the first 30 seconds.

**Exit criterion:** a genuinely long round (5+ minutes) with continuous
movement/combat produces no crash, no BGM interruption, no audio desync.

---

## Phase 34 — Splash art, a warmer exclusive-skill color, a first-time tutorial
*Goal: wire in `splash_bg.png` as both native splash and main menu
background, tone down the exclusive-skill red, and ship a 3-slide
first-boot tutorial reachable from a new "?" button (DECISIONS
D-082/D-083/D-084).*

- [x] **34.1** `splash_bg.png` copied into
      `android/app/src/main/res/drawable-nodpi/`; both
      `launch_background.xml` variants point at it (caught and fixed a
      real XML-comment syntax error the first build attempt surfaced).
      `MainMenuScreen` renders the same file full-bleed as its own
      background; its old plain `Text('ARENA')` title is gone (the art
      bakes the logo in already).
- [x] **34.2** `ArenaColors.warning` (warm amber) added; `_LevelUpCard`'s
      exclusive-skill accent switched to it from `danger`, which stays
      untouched everywhere else it's used.
- [x] **34.3** `core/tutorial_state.dart` (one persisted bool) +
      `ui/screens/tutorial_screen.dart` (3-slide `PageView`, same carousel
      chrome as every other multi-page screen) built from real in-game
      assets — `SkillIcon` (promoted from `_LevelUpCard` into a shared
      `ui/widgets/skill_icon.dart`), `CoinIcon`/`GemIcon`, and the real
      chest sprite. `MainMenuScreen` auto-pushes it on a fresh save
      (`TutorialState.hasSeenIntro() == false`) and via a new circular "?"
      button top-right, both converging on the same finish-and-pop path.
- [x] **34.4** `flutter analyze` clean, `flutter test` 122/122 (+2 new:
      fresh-save auto-open, manual "?" reopen; 2 pre-existing tests
      updated for the removed title text and to skip the tutorial
      auto-push where it isn't what's being tested), `flutter build apk
      --debug` succeeds.
- [ ] **34.5** On-device verification — **developer**: splash art shows on
      cold start; main menu shows it as background with buttons readable;
      exclusive cards read warm amber, not bright red; a fresh install (or
      `adb shell pm clear com.awwwi.arena`) opens straight to the
      tutorial, doesn't reappear next launch, and the "?" button reopens
      it any time.

**Exit criterion:** splash/background art wired in both places; exclusive
color reads warm, not alarming; every first-time player sees the tutorial
once, and anyone can reopen it from the main menu.

---

## Phase 35 — Currency HUD polish (built, on-device verification pending)
*Goal: 3 currency-display bugs the developer flagged as the next thing to
pick up, reported together but not yet implemented.*

- [x] **35.1 (highest prio)** Round Over's `_CoinCounter` icon size-matched
      down to 40 (was 48) to read the same size as `_GemCounter`'s
      `GemIcon`/`_KillCounter`'s star (both already 40) — all 3 now render
      identically sized, vertically centered the same way (each already sat
      in an identical `SizedBox(height: 64)` + centered `Row`, so matching
      the icon size was the actual fix).
- [x] **35.2** Coin count text recolored `ArenaColors.accent` →
      `ArenaColors.textPrimary` (matching the gem count) in all 3 places
      that had it wrong: Character Select's `_WalletRow`, Upgrades'
      `_WalletRow`, Round Over's `_CoinCounter`. Settings' debug currency
      readout (`'Coins: $x   Gems: $y'`) was already one `textPrimary`
      string, not colored per-currency — nothing to change there.
- [x] **35.3** Character Select's `_WalletRow` rebuilt from one centered
      `Row` into two `Expanded` halves mirroring the SHOP/UPGRADES button
      `Row` right below it (same split, same 12px gap) — gems now center
      above SHOP (left), coins above UPGRADES (right), matching which
      currency actually spends on which screen.
- [x] **35.4 (found during the audio checkup requested alongside this
      phase, not originally scoped — see DECISIONS D-085)**
      `ArenaGame._playSfx` (explosion + player-death SFX) was
      still on the pre-D-079 unpooled `FlameAudio.play` path — migrated onto
      `SfxPlayer`'s pooled playback (`playExplosion`/`playPlayerDeath`),
      `_playSfx` deleted, unused `flame_audio` import removed from
      `arena_game.dart`.
- [x] **35.5** `flutter analyze` clean, `flutter test` 122/122 (unchanged —
      HUD layout/color and SFX playback plumbing, not gameplay logic;
      CLAUDE.md §11), `flutter build apk --debug` succeeds.
- [x] **35.6 (reported alongside this phase, not originally scoped — see
      DECISIONS D-086)** BGM kept playing when the app was minimized —
      `ArenaApp` had no app-lifecycle wiring at all. `_ArenaAppState` now
      mixes in `WidgetsBindingObserver`; `BgmController` gained
      `pause()`/`resume()`, called on `AppLifecycleState.paused`/`hidden`
      and `.resumed` respectively (`inactive` deliberately left alone —
      transient foreground interruptions like a permission dialog
      shouldn't cut the music).
- [ ] **35.7** On-device verification — **developer**: Round Over's 3
      currency rows (coins/gems/kills) read as one consistent set —
      same icon size, same vertical alignment, coin count no longer green;
      Character Select's gem count sits above SHOP and coin count above
      UPGRADES; a Skirmisher round with several spiral-fire kills plus a
      chest open doesn't reproduce D-079's old symptoms (BGM stopping/
      restarting, static, desync) under sustained play, and explosion/death
      SFX still sound and are volume-scaled the same as before; minimizing
      the app (home button or recent-apps) stops the music, and bringing it
      back to the foreground resumes it from where it left off, not from
      the top; also try minimizing within ~1s of a fresh cold launch (D-087's
      race window) and confirm BGM still doesn't play in the background.

- [x] **35.8 (found during a second audio checkup, not originally scoped —
      see DECISIONS D-087)** `BgmController.start()` raced `pause()`/
      `resume()`: minimizing the app in the brief window while `start()`
      was still preparing the player (right after a cold launch) left
      BGM playing anyway once `start()` finished. Fixed with a
      `_pausedByLifecycle` flag `start()` checks once the player exists —
      lands paused at the real target volume instead of fading in.
      `flutter analyze` clean, `flutter test` 122/122, `flutter build apk
      --debug` succeeds. Also re-verified (no bugs found): `AudioPool`'s
      real pub-cache source matches how `SfxPlayer` uses it, no stray
      `FlameAudio`/`AudioPlayer` calls anywhere outside `bgm_controller.
      dart`/`sfx_player.dart`, every pooled SFX asset exists and is
      declared in `pubspec.yaml`, chest-reveal's shuffle/spin `Timer`s are
      cancelled on `dispose()`.
- [x] **35.9 (developer, on-device: "SFX at max, BGM at 0, not hearing
      footsteps, not hearing projectile when character attacks, etc." —
      root cause found, see DECISIONS D-088)** Every pooled SFX
      (`_poolFor`/`AudioPool.create`) was silently, permanently broken:
      `AudioPool` was never given `audioCache: FlameAudio.audioCache`, so
      it defaulted to a different cache with the wrong prefix, and the
      path was *also* pre-prefixed by hand — the two combined into a
      double-prefixed path that never resolved to a real asset. Every
      pooled sound (tap/damage/projectile-shoot/level-up/both footstep
      files/chest-card-chosen/explosion/death — all of D-076/D-085) has
      been silent since the pooling rewrite in D-079, this whole time.
      Fixed by passing `audioCache: FlameAudio.audioCache` and dropping
      the hand-baked prefix from the path, matching the one sound
      (`playChestCardSelect`) that already did this correctly and was
      never reported broken. `flutter analyze` clean, `flutter test`
      122/122, `flutter build apk --debug` succeeds.
- [x] **35.10 (developer, on-device: "coins and gems are not saved to
      main wallet, after completing round. Only kills" — see DECISIONS
      D-089)** `ArenaGame._endRound()` fired the 3 `MetaProgressionRepository.
      addX` round-over credits concurrently — each is its own
      load-modify-save cycle, so racing them meant whichever `save()`
      landed last (usually kills, called last) clobbered the other two
      fields back to their pre-round values. Fixed by awaiting the three
      calls sequentially inside a new `_persistRoundRewards()` helper
      (still fire-and-forget from `_endRound`'s own side). `flutter
      analyze` clean, `flutter test` 122/122, `flutter build apk --debug`
      succeeds.

**Exit criterion:** all 3 currency counters on Round Over match visually;
Character Select's wallet row lines up currency-to-button; explosion/death
SFX play through the same pooled path every other one-shot already does;
BGM stops when the app is backgrounded (including right after a cold
launch) and resumes at the right volume when it's foregrounded; every
pooled SFX (footsteps, projectile-shoot on attack, tap, damage, level-up,
chest-card-chosen, explosion, player-death) is actually audible with SFX
volume up; finishing a round with nonzero coins/gems/kills persists all
3 into the wallet, not just kills.

---

## Phase 36 — External build-time tuning config (built, on-device verification pending)
*Goal: a developer-editable JSON file, bundled into the APK at build time,
that overrides a curated set of economy/AI/character/progression/audio
numbers without touching Dart source. See DECISIONS D-090.*

- [x] **36.1** New `core/game_config.dart`'s `GameConfig` singleton —
      reads/parses `assets/config/game_config.json` once via `main()`
      (before `runApp`, since `kCharacters`/`EnemyStats`/etc. are all read
      synchronously by the first frame). Every getter falls back to the
      file's own shipped default on a missing file/section/key/malformed
      edit — never crashes.
- [x] **36.2** Wired into: economy (`coinValueMultiplier`,
      `gemDropChanceBonus`, `bossCoinMultiplier`), enemy AI (spawn
      starting/min interval, decay factor, max live enemies, grunt HP/
      speed/contact damage, boss HP/contact damage/bolt damage, per-level
      scale, elite chance), character balance (all 4 characters' base
      STR/VIT/DEX/INT), progression (XP per kill, base XP to next level,
      XP growth factor), and starting audio (SFX/Music volume on a fresh
      install).
- [x] **36.3** `flutter analyze` clean, `flutter test` 124/124 (+2 new,
      `test/core/game_config_test.dart` — one round-trips the real shipped
      JSON through `TestWidgetsFlutterBinding`'s asset bundle end to end,
      one covers an unknown character/stat falling back safely).
      `flutter build apk --debug` succeeds; confirmed the JSON is actually
      bundled inside the built APK (`unzip -l`) at the path `rootBundle`
      reads.
- [x] **36.4** End-to-end wiring sanity check: bumped `enemyMaxHp` to a
      sentinel `999` in the real shipped file, re-ran the new test (failed
      exactly as expected — `Expected: <20> Actual: <999.0>`), restored it
      to the real default. Confirms an edited JSON value genuinely reaches
      a `core/` getter through the full load→parse→override chain, not
      just "compiles."
- [ ] **36.5** On-device verification — **developer**: edit a value in
      `assets/config/game_config.json` (try `enemyMaxHp` or
      `startingMusicVolume`), rebuild+install, and confirm the change is
      actually felt in a round (or on Settings' sliders' starting position
      on a fresh install / after `adb shell pm clear com.awwwi.arena`).

**Exit criterion:** editing `assets/config/game_config.json` and
rebuilding the APK measurably changes the named economy/AI/character/
progression/audio numbers in-game; a missing or reverted file behaves
identically to today's shipped defaults.

---

## Phase 37 — Pickup SFX, top-stacked HP/XP bars, 20-achievement rewards system (built, on-device verification pending)
*Goal: one developer request covering 4 things — pickup sound cues, HP/XP
bar layout+color, and a new ACHIEVEMENTS screen with 20 real achievements
that pay into the wallet. See DECISIONS D-091.*

- [x] **37.1** `SfxPlayer.playPickup()` (reuses the tap click, no dedicated
      asset exists yet) wired into `ArenaGame.collectGem`/`collectPotion`
      and `ChestComponent._startOpening` (the touch instant, distinct from
      the explosion beat that already plays ~0.35s later).
- [x] **37.2** `HpBarComponent`/`XpBarComponent` moved to the top of the
      screen, stacked, full viewport width (new shared
      `kHudBarSideMarginPx`/`kHudBarTopMarginPx`/`kHudBarHeightPx`/
      `kHudBarGapPx` constants). HP fill is `ArenaColors.danger` (red),
      XP fill is new `ArenaColors.xp` (yellow). The pause button and debug
      DIE button both padded down below the stacked bars — they used to
      sit clear of the old small HP box and would otherwise now overlap
      the full-width bars.
- [x] **37.3** New `core/achievements.dart` — 20 `Achievement` entries
      (`kAchievements`), each gated on one lifetime stat crossing a
      threshold, paying a one-time coin/gem reward. Zero imports of
      `meta_progression.dart` on purpose (works against a plain value map,
      not the `MetaProgression` type) so the reverse import never has to
      exist.
- [x] **37.4** `MetaProgression` gained 6 new lifetime counters (boss
      kills/gems collected/coins earned/chests opened/potions collected,
      plus highest level reached + longest survival time) distinct from
      the spendable coins/gems balances, plus `claimedAchievementIds`.
      New `MetaProgressionRepository.recordRoundEnd` — one load, every
      counter updated, achievements evaluated and claimed, one save
      (supersedes calling `addCoins`/`addGems`/`addLifetimeKills`
      separately at round-end, though those 3 stay available for other
      callers). `ArenaGame` gained 3 new round-scoped counters
      (bosses/chests/potions this round) feeding it.
- [x] **37.5** New `ui/screens/achievements_screen.dart` — scrollable list
      (20 items, not a page carousel), each row showing name/description/
      progress bar/reward, dimmed until claimed. Rewards grant
      automatically at round-end; no "claim" button. New `ACHIEVEMENTS`
      button on the main menu between START and SETTINGS.
- [x] **37.6** Found and fixed a real design flaw in D-090's own
      `game_config_test.dart` while doing this: it pinned literal "shipped
      default" values, which broke the moment the developer actually
      tuned the file (`xpPerKill`/`startingSfxVolume`/
      `startingMusicVolume` had already changed on-device by this point in
      the session) — rewritten to parse the same file independently in the
      test and compare `GameConfig`'s getters against *that*, so it only
      fails on a real parsing bug, never on legitimate tuning.
- [x] **37.7** `flutter analyze` clean, `flutter test` 138/138 (+16 new:
      `test/core/achievements_test.dart` — `kAchievements` structure (20
      entries, unique ids, positive thresholds/rewards, every stat used);
      `meta_progression_test.dart` — round-trip for the 6 new fields +
      `claimedAchievementIds`, `recordRoundEnd` crediting/high-water-mark/
      claim-exactly-once/zero-progress-claims-nothing coverage). `flutter
      build apk --debug` succeeds.
- [ ] **37.8** On-device verification — **developer**: gem/potion/chest
      pickups are audible; HP (red) and XP (yellow) bars both sit at the
      top, full width, and the pause/debug-die buttons don't overlap them;
      the ACHIEVEMENTS button opens a scrollable list between START and
      SETTINGS; a round that crosses a threshold (try "First Blood," your
      very first kill) shows the reward already in the wallet afterward.

**Exit criterion:** pickups are heard; HP/XP read as one stacked red/yellow
HUD at the top with nothing else overlapping it; ACHIEVEMENTS is reachable
from the main menu and its progress/rewards reflect real play.

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
