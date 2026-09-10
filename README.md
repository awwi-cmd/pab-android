# ARENA

A top-down survival game for Android, built in **Flutter + Flame**. Pick a
character, drop into an open world, and survive — your character
auto-attacks the nearest enemy while you focus entirely on movement and
positioning.

> Started as a small fixed-arena demo (see [`PRD.md`](PRD.md)). That demo
> shipped 2026-09-07 and is now well behind where the project actually is —
> it's grown into a full roaming-world survival game with bosses, loot,
> persistent progression, and four distinct playable kits. See
> [`TASKS.md`](TASKS.md) for the phase-by-phase build log and
> [`DECISIONS.md`](DECISIONS.md) for the reasoning behind every non-obvious
> call along the way.

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
  - *In-round:* kill enemies → gain XP → level up → pick 1 of 3 random
    upgrades (stat boosts or a real skill — an aura, orbiting mirrors, a
    piercing ray, a chain-lightning burst, a defensive crystal). All of it
    resets when the round ends.
  - *Persistent, across every round:* coins and gems you bring home buy
    permanent STR/VIT/DEX/INT/CORRUPTION levels from the character-select
    screen, and lifetime kills gate which of the four characters are
    unlocked. Corruption is the odd one out — it's a difficulty/reward
    dial, not a stat: tougher, faster enemies in exchange for bigger drops.

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

- **A boss** telegraphs and teleports around the arena, adding a real fight
  on top of the trash-mob stream.
- **A loot economy** — enemies and chests drop gems/coins/potions; chests
  play out a real card-draw reveal (a full 52-card + jokers deck) before
  paying out.
- **A shop and an upgrades screen**, reachable from character select,
  spend the persistent coin/gem wallet on permanent stat levels (the shop
  itself is still an empty placeholder — nothing to spend gems on yet).
- **Three control schemes** (floating joystick, fixed joystick, drag
  anywhere), each switchable from Settings.

## What's still rough

- The demo's original scope (`PRD.md` §9) is long since exceeded, but a
  few things are still deliberately unbuilt: no object pooling yet (not
  needed until a perf check says otherwise), no real enemy-type variety
  (three cosmetic skins share one stat profile), the shop screen is empty.
  See [`NEXT.md`](NEXT.md) for the current extension points and open rough
  edges in detail.
- Several recent phases are built but not yet verified on a real device —
  `TASKS.md` marks exactly which checklist items are still open.

---

## Tech stack

- **Flutter** for every menu, screen, and route (main menu, settings,
  character select, shop/upgrades).
- **[Flame](https://flame-engine.org/)** for the arena itself — a single
  `GameWidget` hosting all gameplay (camera, world, entities, combat).
  Round-over/level-up/pause/chest-reveal are Flame overlays, not routes, so
  the frame underneath stays visible.
- **`shared_preferences`** for settings and the persistent meta-progression
  wallet. No other dependencies, no state-management library — deliberate,
  see `CLAUDE.md` §4.9.
- Pixel art throughout, nearest-neighbour filtered (no smoothing).

## Project layout

```
├── PRD.md          — what the original demo was (frozen, historical)
├── TASKS.md         — the phase-by-phase build checklist, kept current
├── DECISIONS.md     — why things are the way they are, one entry per call
├── NEXT.md          — extension points & open edges for whoever builds next
├── CLAUDE.md        — the working agreement / architecture rules for this repo
└── arena/           — the Flutter project
    ├── lib/
    │   ├── core/     — pure gameplay math & data: stats, progression, the
    │   │               economy, meta-progression, settings — no Flame
    │   │               dependency, so this is the part with real unit tests
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
```

See `CLAUDE.md` for the full environment setup and the architecture rules
this codebase is held to.
