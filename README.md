# Pixel Arena Brawl (PAB)

A top-down survival game for Android, built in **Flutter + Flame**. Pick a
character, drop into an open world, and survive — your character
auto-attacks the nearest enemy while you focus entirely on movement and
positioning.

> **Alpha 1.0.0.** Started as a small fixed-arena demo (see
> [`PRD.md`](PRD.md), now a frozen historical record). It's since grown
> into a full roaming-world survival game with bosses, a loot economy,
> persistent meta-progression, achievements, four distinct playable kits,
> and a full audio layer. See [`TASKS.md`](TASKS.md) for what's built and
> what's still open, and [`DECISIONS.md`](DECISIONS.md) for the reasoning
> behind every non-obvious call. Pre-alpha build history (the first ~90
> decisions and 37 phases) is archived in full under
> [`docs/archive/`](docs/archive/).

## Download

Grab the latest APK from [Releases](../../releases) and sideload it onto
an Android device (min SDK 24). This is an alpha build — expect rough
edges, and see `TASKS.md`'s Alpha verification checklist for what's known
to still need an on-device pass.

---

## What it plays like

- **One input, one axis.** You only move. Your character's attack fires on
  its own cooldown at the nearest enemy — positioning *is* the skill.
- **No walls.** The camera follows you through an effectively infinite
  world; enemies spawn in a ring around the edge of what's visible and
  stream toward you.
- **A round ends on death.** Survive as long as you can, level up mid-run,
  bank whatever you earned, and go again.
- **Two progression layers stack on top of each other:**
  - *In-round:* kill enemies → gain XP (a yellow XP bar sits right under
    the red HP bar, both full-width at the top of the screen) → level up
    → pick 1 of 3 random upgrades (stat boosts or a real skill — an aura,
    orbiting mirrors, a piercing ray, a chain-lightning burst, a defensive
    crystal). 4 of those skills are paired into mutually-exclusive
    rivalries (pick one, its paired rival is off the table for the rest of
    the round) — real build identity instead of collecting everything. All
    of it resets when the round ends.
  - *Persistent, across every round:* coins buy STR/VIT/DEX/INT/CORRUPTION/
    HASTE/FORTUNE/RESOLVE/MAGNET/LUCK/REGEN/CRIT levels (12 dials across 3
    pages) from the character-select screen's CHARACTER UPGRADES tab — and
    every one of those 12 belongs to *one character*; swap to a different
    character and its own dials start back at zero. Gems buy 15 one-time
    permanent items (extra max HP, a once-per-round revive, better loot
    odds, and more) from BONUSES SHOP — unlike Character Upgrades, SHOP
    purchases are shared: one buy applies to every character. Lifetime
    kills separately gate which of the four characters are unlocked.
    Corruption is the odd one out among the 12 dials — it's a
    difficulty/reward knob, not a stat: tougher, faster enemies in
    exchange for bigger drops.
- **20 achievements** track lifetime stats — kills, boss kills, gems/coins/
  potions/chests, best level reached, longest survival — and pay coin or
  gem rewards straight into the persistent wallet the instant a threshold
  is crossed, no claim button needed. Reachable from the main menu's
  ACHIEVEMENTS button.

## The four characters

Each has its own stat spread and its own attack, not just a reskinned bolt:

| Character | Kit |
|---|---|
| **The Apprentice** | Ranged bolt — the baseline caster, always unlocked. |
| **The Bruiser** | A thrown knife that pierces through the whole line of enemies it hits. |
| **The Skirmisher** | Twin spiral flames that orbit each other on the way to the target. |
| **The Warden** | Ground Slam — a melee AoE around the player instead of a projectile. |

The Bruiser, Skirmisher, and Warden unlock as lifetime kill totals climb
(or instantly from the Settings debug menu, for testing).

## Beyond the core loop

- **A boss** telegraphs and teleports around the arena (on a cooldown, so
  it can't chain-teleport back to back), adding a real fight on top of the
  trash-mob stream — and always drops a chest on death.
- **A loot economy** — enemies, potions, and chests drop with their own
  pickup sound cue; chests play out a real card-draw reveal (a full
  52-card + jokers deck) before paying out, with its own landing sparkle
  burst. Standing torches and breakable gem vases are scattered around the
  world too — torches are solid (block both the player and enemies),
  vases play the same card-draw sparkle burst and scatter a handful of
  gems left and right when you walk into one.
- **BONUSES SHOP and CHARACTER UPGRADES**, reachable from character
  select — 15 real gem-priced permanent items in BONUSES SHOP (shared
  across every character), 12 coin-priced leveled dials across 3 pages in
  CHARACTER UPGRADES (each character's own — nothing carries over when
  you switch). Character select itself shows each character's own
  STR/VIT/DEX/INT as bars (base stat plus whatever's been bought, with a
  gold fill once a stat's fully upgraded), plus two summary panels below
  ENTER ARENA: this character's other dial levels, and how many of the 15
  BONUSES SHOP items are owned overall.
- **A real sound layer** — footsteps, hits, level-ups, shots, pickups, and
  a tap on every button, plus background music that pauses when the app
  is backgrounded and resumes where it left off — all pooled and
  latency-tuned to survive a long, sound-heavy round without desyncing.
- **A first-time tutorial** — 3 slides built from the game's own real
  assets, shown once on a fresh save and reachable any time from a "?"
  button on the main menu.
- **Three control schemes** (floating joystick, fixed joystick, drag
  anywhere), each switchable from Settings.
- **A developer-editable tuning file**
  (`arena/assets/config/game_config.json`) overrides a curated set of
  economy/enemy-AI/character-balance/progression/starting-audio numbers at
  build time — no source edit needed for a balance pass.

## What's still rough

This is an alpha. A few things are still deliberately unbuilt — no object
pooling yet (not needed until a perf check says otherwise), no real
enemy-type variety (three cosmetic skins share one stat profile), no
enemy separation/steering. See [`NEXT.md`](NEXT.md) for the current
extension points and open rough edges in detail, and `TASKS.md`'s
Backlog for the full still-open list. `TASKS.md`'s Alpha verification
checklist tracks what's built but not yet confirmed on a real device.

---

## Tech stack

- **Flutter** for every menu, screen, and route (main menu, settings,
  character select, BONUSES SHOP/CHARACTER UPGRADES, achievements).
- **[Flame](https://flame-engine.org/)** for the arena itself — a single
  `GameWidget` hosting all gameplay (camera, world, entities, combat).
  Round-over/level-up/pause/chest-reveal are Flame overlays, not routes, so
  the frame underneath stays visible.
- **`shared_preferences`** for settings and the persistent meta-progression
  wallet. **`flame_audio`** for BGM and every SFX, pooled and tuned to
  survive a long session without desyncing. No other dependencies, no
  state-management library — deliberate, see `CLAUDE.md` §4.9.
- Pixel art throughout, nearest-neighbour filtered (no smoothing), with a
  dedicated pixel font applied app-wide.

## Project layout

```
├── PRD.md           — what the original demo was (frozen, historical)
├── TASKS.md         — the phase-by-phase build checklist, kept current
├── DECISIONS.md     — why things are the way they are, one entry per call
├── NEXT.md          — extension points & open edges for whoever builds next
├── CLAUDE.md        — the working agreement / architecture rules for this repo
├── docs/archive/    — full pre-alpha history of the 4 files above
└── arena/           — the Flutter project
    ├── lib/
    │   ├── core/     — pure gameplay math & data: stats, progression, the
    │   │               economy, achievements, meta-progression, settings,
    │   │               the tuning config — no Flame dependency, so this is
    │   │               the part with real unit tests
    │   ├── data/     — CharacterDef roster
    │   ├── game/     — the Flame side: ArenaGame, components, attacks,
    │   │               spawning, animations, input
    │   └── ui/       — every Flutter screen and shared widget
    └── test/         — unit tests for core/ + a couple of widget tests
```

Read `TASKS.md` → `DECISIONS.md` → `NEXT.md` in that order to pick up
where the project actually stands; `PRD.md` is a historical snapshot of
the original demo, not the current spec.

## Running it

Built and tested on Windows against a `Pixel_10` Android emulator.

```
startemulator.bat     # boots the emulator (leave the window open)
rebuildinstall.bat     # rebuilds the debug APK and installs it
```

Or, for faster iteration from inside `arena/`:

```
C:\src\flutter\bin\flutter.bat run       # hot-reload session
C:\src\flutter\bin\flutter.bat analyze   # static analysis
C:\src\flutter\bin\flutter.bat test      # unit tests
C:\src\flutter\bin\flutter.bat build apk --release   # release APK (debug-signed for now)
```

See `CLAUDE.md` for the full environment setup and the architecture rules
this codebase is held to.
