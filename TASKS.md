# TASKS.md — Pixel Arena Brawl (PAB)

The checklist. One item at a time; after each, the app should still build
and run (CLAUDE.md §6). Tick items off as you go — a stale checklist is
worse than none.

**Numbering resets here.** Pre-alpha history (Phases 0–37 of the original
build) lives in `docs/archive/TASKS_pre-alpha.md`. This file starts fresh
at **Phase 0 — Alpha baseline**.

---

## Phase 0 — Alpha baseline: PAB Alpha 1.0.0 (built, on-device verification pending)
*Goal: capture what's actually shipped as of the rebrand, and close out the
backlog of on-device checks that accumulated across the pre-alpha build so
the project has one clean, verified starting line.*

### What's already built (condensed from the pre-alpha archive)

- [x] **0.1 Core loop** — roaming open world, no walls, camera follows the
      player; endless floor tiling; enemies spawn in a ring just outside
      the visible view and scale with player level; a round ends on death.
- [x] **0.2 Characters** — 4 playable, each with a distinct attack kit
      (bolt, piercing knife, orbiting spiral fire, ground slam) and a
      progression-gated unlock threshold (lifetime kills). Swipe-carousel
      Character Select.
- [x] **0.3 Progression (in-round)** — kill → XP → level → pick 1 of 3
      upgrades (stat bumps or a real skill: Aura, Ultimate Mirror,
      Projectile Ray, Projectile Thunder, Defence Crystal — 3 overlapping
      exclusive pairs, not stack-everything). HP bar (red) and XP bar
      (yellow) both stacked at the top of the screen, full width.
- [x] **0.4 Boss** — spawns at level milestones, telegraphed teleport,
      its own ranged attack, drops a chest on death.
- [x] **0.5 Economy** — coins, gems, potions, and chests (opened via a
      real playing-card deck spin+reveal) drop in the world; a persistent
      cross-round wallet; a SHOP (15 gem-priced permanent items, 3-page
      carousel) and UPGRADES (12 coin-priced leveled dials, 3-page
      carousel) reachable from Character Select.
- [x] **0.6 Achievements** — 20 achievements gated on lifetime stats
      (kills, boss kills, gems/coins/potions/chests, best level reached,
      longest survival), auto-granting coin/gem rewards at round-end. An
      ACHIEVEMENTS screen on the main menu (between START and SETTINGS)
      shows progress.
- [x] **0.7 Audio** — a full SFX layer (footsteps, damage, tap, attack,
      level-up, chest-card select/chosen, explosion, death, pickup),
      pooled and lifecycle-aware (pauses/resumes with the app); one
      looping BGM track with its own volume slider.
- [x] **0.8 Onboarding** — a 3-slide first-boot tutorial, reachable any
      time from the main menu's "?" button.
- [x] **0.9 Tuning** — `assets/config/game_config.json`, a
      developer-editable build-time file overriding a curated set of
      economy/enemy-AI/character-balance/progression/starting-audio
      numbers without a source edit.
- [x] **0.10 Rebrand** — project renamed Pixel Arena Brawl (PAB); this
      version is Alpha 1.0.0. Main menu version text and the debug
      DIE button updated accordingly. `CLAUDE.md`/`TASKS.md`/
      `DECISIONS.md`/`NEXT.md` reset to a lean Phase-0 baseline; the full
      pre-alpha history archived to `docs/archive/`.

### Alpha verification checklist (on-device — developer)

Consolidated from every "on-device verification pending" item the
pre-alpha build accumulated but never got a dedicated on-device pass for
as one batch. Not exhaustive regression testing — a real, focused pass
over the game as it stands today.

- [ ] **0.11 Core loop feel** — a full round start-to-death: movement,
      auto-attack, enemy spawning/scaling, level-up popups, at least one
      boss encounter, at least one chest opened.
- [ ] **0.12 All 4 characters** — enter the arena as each one at least
      once; each attack kit fires and reads distinctly.
- [ ] **0.13 Economy/wallet** — a round with nonzero coins/gems/kills
      persists all 3 to the wallet (not just kills); SHOP and UPGRADES
      purchases actually apply their effect in the next round.
- [ ] **0.14 Achievements** — crossing a threshold (try "First Blood," the
      first kill) shows the reward already in the wallet afterward; the
      ACHIEVEMENTS screen's progress bars track real play.
- [ ] **0.15 Audio** — every pooled SFX is actually audible (footsteps,
      attack, damage, level-up, chest sounds, pickup); BGM plays, respects
      its volume slider, and stops when the app is backgrounded/minimized
      and resumes when foregrounded (including right after a cold launch).
- [ ] **0.16 HUD layout** — HP (red) and XP (yellow) bars both read as one
      stacked bar at the top, full width; the pause button and debug DIE
      button sit clear of them, no overlap.
- [ ] **0.17 Tuning config** — edit a value in
      `assets/config/game_config.json`, rebuild, confirm the change is
      actually felt in-game (e.g. `enemyMaxHp` or `startingMusicVolume`).
- [ ] **0.18 Rebrand text** — main menu shows "PAB Alpha 1.0.0" where the
      old version string used to be; nothing else on-screen still reads
      like a placeholder debug build.

**Exit criterion:** every item above confirmed on-device once. From here,
new work is Phase 1 onward, following the same one-item-at-a-time
discipline as always.

---

## Phase 1 — Animation polish & world objects

*Goal: small visual/gameplay additions on top of the Alpha 1.0.0 baseline,
one at a time, same discipline as Phase 0.*

- [x] **1.1 Coin icon animation** — `CoinIcon` (`ui/widgets/coin_icon.dart`)
      now spins through all 15 frames of `coin-icon.png` on a loop instead
      of showing a static frame 0, everywhere it's used (Character Select,
      Upgrades, Achievements, Round Over, tutorial).
- [x] **1.2 Standing torches** — `TorchComponent`/`TorchSpawner`
      (DECISIONS D-002): scattered randomly around the roaming world,
      minimum-spaced from each other, solid to both the player and
      enemies. Config: `worldObjects.torchCount`/`torchMinSpacingPx`.
- [x] **1.3 Gem vases** — `VaseComponent`/`VaseSpawner` (DECISIONS D-002):
      scattered randomly, minimum-spaced from each other; breaks on player
      touch with the chest's own "card chosen" SFX, a new sparkle burst
      VFX, and a left/right gem scatter. Config:
      `worldObjects.vaseCount`/`vaseMinSpacingPx`/`vaseGemsMin`/
      `vaseGemsMax`.

### On-device verification (not yet checked)

- [ ] **1.4 Torch collision feel** — walking into a torch actually blocks
      movement (player and enemy both), doesn't jitter/stick, and the
      default spacing (`torchMinSpacingPx`) reads as "spread out," not
      clustered.
- [ ] **1.5 Vase break** — walking into a vase plays the card-chosen SFX,
      the sparkle burst reads clearly, gems visibly scatter left/right and
      are collectible, and the default live count/spacing feels right
      scattered across the map.
- [ ] **1.6 Coin spin** — the coin icon's spin is legible at every size it's
      shown at (28/32/40px) and doesn't look janky next to the gem icon's
      static frame beside it.

### Per-character Character Upgrades (DECISIONS D-003, revised)

- [x] **1.7 Rename + fully per-character split** — "UPGRADES" is now
      "CHARACTER UPGRADES" everywhere (button, screen title, route); **all
      12** dials (STR/VIT/DEX/INT plus CHAOS/HASTE/FORTUNE/RESOLVE/MAGNET/
      LUCK/REGEN/CRIT) are scoped to whichever character launched the
      screen (`MetaProgression.characterUpgradeLevels`) — no global
      Character Upgrades dial is left. BONUSES SHOP (renamed from SHOP)
      untouched in substance — still permanent, still for every character.
- [x] **1.8 Character Select stat bars** — each of the 4 STR/VIT/DEX/INT
      bars shows a red "+N" delta (this character's own bonus), fills
      toward base+10 (the purchasable ceiling), and turns gold once that
      bonus is fully bought; the HP/DMG/shots-per-sec/speed line below
      reflects the same boosted total.
- [x] **1.9 Two summary panels below ENTER ARENA** — "Stat Upgrades:"
      (this character's own CHAOS/HASTE/FORTUNE/RESOLVE/MAGNET/LUCK/REGEN/
      CRIT levels) and "Shop Bonuses:" (owned BONUSES SHOP items, global,
      new — Character Select never showed these before).
- [x] **1.10 Button width** — SHOP/CHARACTER UPGRADES row given its own
      16px side margin (was the ambient 24px), reading visibly wider.
- [x] **1.11 FTUE rewrite (x2)** — the "LOOT, SHOP & UPGRADES" slide
      explains BONUSES-SHOP-vs-CHARACTER-UPGRADES (permanent-for-everyone
      vs. fully per-character); separately, every slide's body is now
      several short paragraphs (not one dense block) with inline
      **bold**/_italic_ emphasis, more space between paragraphs and
      before the bottom of the slide.

- [ ] **1.12 On-device: per-character isolation** — buy a level of *any*
      dial (not just STR/VIT/DEX/INT — try CHAOS/HASTE too) on one
      character, swipe to another, confirm its own values still read 0.
- [ ] **1.13 On-device: legibility** — the red "+N" chip, the gold
      maxed-out fill color, the widened button row, and both new summary
      panels all read clearly at actual on-screen size/text-scale.
- [ ] **1.14 On-device: FTUE** — the 3 slides' paragraph spacing/bold/
      italic actually reads better than the old dense block, and nothing
      overflows on a real device screen.
- [x] **1.15 "Shop Bonuses:" overflow fix (DECISIONS D-004)** — replaced
      the full item-label list with a fixed-height "N / 15 owned" count +
      "VIEW ALL" link to BONUSES SHOP, so the panel's height stops growing
      as more items get bought (was pushing the whole page into needing a
      scroll).
- [ ] **1.16 On-device: Shop Bonuses panel** — "VIEW ALL" opens BONUSES
      SHOP and the count updates correctly after buying something there;
      Character Select's page no longer needs scrolling regardless of how
      many of the 15 items are owned.
- [x] **1.17 No scrolling on Character Select (DECISIONS D-005)** —
      `_CharacterPage` is a plain non-scrolling `Column` now
      (`SingleChildScrollView` removed); several sizes tightened (portrait
      art, name/descriptor, HP/DMG line) so the content actually fits.
- [ ] **1.18 On-device: no-scroll fits for real** — the real, biggest risk
      this branch is shipping unverified: confirm the page genuinely
      doesn't overflow on the smallest real screen available, for every
      character (locked-panel characters included) — the test suite only
      proves it fits a simulated 360x780 logical surface, not every real
      device.

**Before merging this branch to `main`:** `README.md` is now stale in at
least the Character Select/Upgrades description (DECISIONS D-003) — update
it as part of the merge, not after.

### Vase break + LevelUp animation polish (DECISIONS D-006)

- [x] **1.19 Vase break VFX removed** — the sparkle burst
      (`spawnCardChosenBurst`/`cardChosenBurstAnimation`/`kCardChosenBurst*`)
      is deleted outright, not just uncalled. The card-chosen SFX still
      plays.
- [x] **1.20 Staggered gem fly-out** — `VaseGemBurstComponent` spawns one
      gem every 0.5s (first immediate) instead of all at once; each gem
      visibly flies from the vase's position to its landing spot
      (`GemComponent.launchFrom`) over 0.35s. Scatter distance widened
      (18-42px → 40-90px).
- [x] **1.21 LevelUp entrance animation** — title shows immediately, the
      3 choice cards slide in from off-screen left, staggered 150ms apart,
      350ms each, starting 500ms after the title.
- [x] **1.22 LevelUp selection animation** — tapping a card no longer
      resolves instantly: the other 2 vanish immediately, the chosen one
      pulses (a couple of flashes, not one glow) for 1 full second, and
      only then does the actual upgrade grant + overlay close happen.

- [x] **1.23 Vase burst faster + small explosion VFX (DECISIONS D-007)** —
      gem interval 0.5s → 0.125s; a small explosion VFX (reusing the
      Warden's own shockwave sheet, sized well down) plays at the break
      point, SFX unchanged (only the existing card-chosen sound, no boom).
- [x] **1.24 LevelUp title/button fixes (DECISIONS D-007)** — fixed a real
      layout bug where the title visibly jumped when the card block first
      appeared (cards/button are now always in the tree, animated via
      opacity/position only, never conditionally added); "VIEW YOUR
      UPGRADES" now only builds at all if the player has picked at least
      one upgrade already, and slides in from the right only after every
      card has finished its own entrance.

- [ ] **1.25 On-device: vase break** — the faster staggered gem fly-out
      and the new explosion VFX both read well at actual size/speed, and
      the sound still matches (no accidental double-boom).
- [ ] **1.26 On-device: LevelUp** — the title genuinely never moves once
      the popup opens; "VIEW YOUR UPGRADES" is absent on a first-ever
      level-up and slides in from the right afterward on a later one; the
      flash pulse and 1-second close delay still feel right (none of this
      has any test coverage — DECISIONS D-019/CLAUDE.md §4.11 — this is
      first-look-ever on a real device).

---

## Backlog (do not start without asking first)

Kept here so ideas have somewhere to go that isn't the current sprint —
still true and open as of Alpha 1.0.0, condensed from the pre-alpha
archive (fully-shipped items dropped, partial ones re-scoped to what's
actually still open).

- **Skill system depth** — the reserved animation states (teleport, dash,
  charge, channel, cast) exist in `AnimState` but nothing uses them yet.
- **Enemy variety** — 3 visual skins exist but share one `EnemyStats`
  profile; no ranged/fast/tanky archetypes yet. "Elite" is a visual-only
  fire-glow marker (~15% of spawns), no stat/behavior difference.
- **Structured waves** — spawning is continuous + level-scaled + boss
  milestones, not discrete waves with a shape of their own.
- **Multiple arenas/backgrounds** — one floor tileset exists.
- **Enemy separation/steering** — enemies are allowed to stack with no
  spacing.
- **Object pooling** — enemies/projectiles are plain `add()`/
  `removeFromParent()`, no pool; only revisit if a real perf budget check
  says it's needed.
- **Haptics** on hit/death.
- **Play Store packaging** — signing config, store listing, everything
  beyond a straight debug/release APK build.
