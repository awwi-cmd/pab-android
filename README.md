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
  - *In-round:* kill enemies → gain XP (a bottom XP bar tracks the climb
    to the next level, mirroring the HP bar up top) → level up → pick 1 of
    3 random upgrades (stat boosts or a real skill — an aura, orbiting
    mirrors, a piercing ray, a chain-lightning burst, a defensive
    crystal). 4 of those skills are paired into mutually-exclusive
    rivalries (pick one, its paired rival is off the table for the rest of
    the round) — real build identity instead of collecting everything. All
    of it resets when the round ends.
  - *Persistent, across every round:* coins buy permanent STR/VIT/DEX/INT/
    CORRUPTION/HASTE/FORTUNE/RESOLVE/MAGNET/LUCK/REGEN/CRIT levels (12
    dials across 3 pages) from the character-select screen's UPGRADES tab;
    gems buy 15 one-time permanent items (extra max HP, a once-per-round
    revive, better loot odds, and more) from the SHOP tab. Lifetime kills
    separately gate which of the four characters are unlocked. Corruption
    is the odd one out among the dials — it's a difficulty/reward knob, not
    a stat: tougher, faster enemies in exchange for bigger drops.

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
- **A loot economy** — enemies and chests drop gems/coins/potions; chests
  play out a real card-draw reveal (a full 52-card + jokers deck) before
  paying out, with its own landing sparkle burst.
- **A shop and an upgrades screen**, reachable from character select — 15
  real gem-priced permanent items in SHOP, 12 coin-priced leveled dials
  across 3 pages in UPGRADES, both spending the same persistent wallet the
  HUD shows.
- **A real sound layer** — footsteps, hits, level-ups, shots, and a tap on
  every button, plus background music, all pooled/latency-tuned to survive
  a long, sound-heavy round without desyncing or crashing.
- **A first-time tutorial** — 3 slides built from the game's own real
  assets, shown once on a fresh save and reachable any time from a "?"
  button on the main menu.
- **Three control schemes** (floating joystick, fixed joystick, drag
  anywhere), each switchable from Settings.

## What's still rough

- The demo's original scope (`PRD.md` §9) is long since exceeded, but a
  few things are still deliberately unbuilt: no object pooling yet (not
  needed until a perf check says otherwise), no real enemy-type variety
  (three cosmetic skins share one stat profile). See [`NEXT.md`](NEXT.md)
  for the current extension points and open rough edges in detail.
- Several recent phases are built but not yet verified on a real device —
  `TASKS.md` marks exactly which checklist items are still open.
- Currency-HUD polish is queued next: the gem icon isn't size/position
  matched against the coin and kill counters on Round Over, the coin
  count's color doesn't match the gem count's, and Character Select's
  wallet row isn't aligned with the SHOP/UPGRADES buttons it actually
  spends on. See `TASKS.md` Phase 35.

---

## Tech stack

- **Flutter** for every menu, screen, and route (main menu, settings,
  character select, shop/upgrades).
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
