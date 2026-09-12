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
