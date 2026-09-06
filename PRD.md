# PRD — ARENA (working title)

**Status:** Demo / vertical slice
**Platform:** Android (phone, portrait), built and tested on the Pixel_10 emulator
**Stack:** Flutter + Flame
**Owner:** avion

**Reconciled against the build 2026-09-07** (TASKS 6.6) — §4.4, §6.4 and §8
updated where the build proved an original assumption wrong (mostly art layout
and frame counts guessed before any sprites existed). Nothing here changed
because a *decision* was reconsidered — those live in `DECISIONS.md`, which
this section points to throughout.

---

## 1. What this is

A top-down arena survival game. You pick a character, get dropped into a walled
arena, and enemies pour in from off-screen to kill you. Your character **attacks
automatically** — you only control movement. You survive as long as you can. When
your HP hits zero the round ends.

This document describes **the demo only**. The demo exists to get a real,
installable APK on the emulator that proves the flow end-to-end, so that the next
phase — animations, skills, and the actual meta-game — has something to be built
inside of. Anything that is not needed to prove the flow is explicitly out of
scope (see §9).

---

## 2. Design pillars

1. **The player moves, the character fights.** One input axis. No attack button,
   no aim stick. Positioning *is* the skill.
2. **Readable at arm's length.** Pixel art, high contrast, everything the player
   needs to know is on screen without a HUD panel.
3. **A round is short.** 1–3 minutes. Death is cheap, restarting is one tap.
4. **Stats are visible and honest.** Four numbers on the select screen that map to
   effects the player can feel within ten seconds of play.

---

## 3. Screen flow

```
                    ┌──────────────┐
                    │  MAIN MENU   │
                    │              │
                    │  START       │──────┐
                    │  SETTINGS    │──┐   │
                    │  CREDITS     │─┐│   │
                    └──────────────┘ ││   │
                       ▲   ▲   ▲     ││   │
                       │   │   └─────┘│   │
                       │   └──────────┘   │
                       │                  ▼
                       │        ┌──────────────────┐
                       │        │ CHARACTER SELECT │
                       │        │  4 slots, 1 open │
                       │        │  stat readout    │
                       │        │  [ ENTER ARENA ] │
                       │        └──────────────────┘
                       │                  │
                       │                  ▼
                       │        ┌──────────────────┐
                       │        │      ARENA       │
                       │        │  spawn → fight   │
                       │        │  HP hits 0       │
                       │        └──────────────────┘
                       │                  │
                       │                  ▼
                       │        ┌──────────────────┐
                       └────────│   ROUND OVER     │
                                │  time, kills     │
                                │  [ MAIN MENU ]   │
                                └──────────────────┘
```

Back navigation: Settings and Credits return to Main Menu. Character Select
returns to Main Menu. Arena has **no** back — the only exit is death (a debug
"kill me" button exists in debug builds only).

---

## 4. Screens in detail

### 4.1 Main Menu
- Title text, three buttons: **Start**, **Settings**, **Credits**.
- No animation requirement beyond a button press state.
- Version string in the bottom corner (`v0.1.0 (debug)`).

### 4.2 Settings
Persisted to `SharedPreferences`, read at app start.

| Setting | Values | Default | Notes |
|---|---|---|---|
| Control scheme | `Floating joystick` / `Fixed joystick` / `Drag anywhere` | Floating joystick | Must be switchable and take effect on the next arena entry |
| Joystick side | Left / Right | Left | Only shown for the two joystick modes |
| SFX volume | 0–100 | 70 | Wired to a stub audio bus for the demo |
| Music volume | 0–100 | 50 | Wired to a stub audio bus for the demo |
| Show FPS | on/off | off | Flame `FpsTextComponent` |

### 4.3 Credits
Static scrollable text. Placeholder content plus asset attribution block.

### 4.4 Character Select
- Four slots in a 2×2 grid. Slot 1 is playable; slots 2–4 render as locked
  silhouettes with a padlock and are not tappable.
- The portrait (idle animation playing) lives **in the grid tile itself** — the
  square you tap to select doubles as the portrait, rather than a separate block
  below (built this way at the developer's request; simpler than the original
  two-places-at-once layout implied here).
- Selecting slot 1 shows: name, a one-line descriptor, and the four stats as
  **labelled bars plus the raw number**.
- A "derived" readout under the bars showing what the stats actually produce:
  `HP 90 · DMG 13 · 1.4 shots/s · 140 speed`. This is how the player learns the
  mapping.
- **Enter Arena** button.

### 4.5 Arena
See §5 and §6.

### 4.6 Round Over
- Overlay on top of a dimmed, frozen arena (not a new route — a Flame overlay, so
  the death frame stays visible behind it).
- Shows: **Time survived** (mm:ss.ms), **Enemies killed**, **Damage dealt**.
- Single button: **Main Menu**. (A **Retry** button is deliberately *not* in the
  demo — see DECISIONS D-009.)

---

## 5. Stats

Four stats per character. The demo character's values are the baseline; every
formula below is a **starting point to be tuned in play, not a law**.

| Stat | Full name | Governs |
|---|---|---|
| **STR** | Strength | Projectile damage, knockback |
| **VIT** | Vitality | Max HP, passive regen |
| **DEX** | Dexterity | Move speed, fire rate |
| **INT** | Intellect | Projectile speed, attack range |

### 5.1 Derived-stat formulas (v1, tunable)

Implement these in one place — `lib/core/stats.dart` — as pure functions on a
`StatBlock`. Nothing else in the codebase may hardcode a combat number.

```
maxHp            = 50  + VIT * 10
hpRegenPerSec    = 0.0 + VIT * 0.05
damagePerHit     = 5   + STR * 2
knockbackImpulse = 40  + STR * 6          // pixels/sec applied to the enemy
attacksPerSec    = 1.0 + DEX * 0.08
moveSpeedPxPerS  = 120 + DEX * 4
projSpeedPxPerS  = 260 + INT * 8
attackRangePx    = 180 + INT * 6
```

Stat range for playable characters: **1–10** per stat, 20 points total at start.

### 5.2 Demo character

**Slot 1 — "The Apprentice"** (the wizard in the reference sheet)

| STR | VIT | DEX | INT |
|---|---|---|---|
| 4 | 4 | 5 | 7 |

Derived: 90 HP · 0.20 hp/s regen · 13 dmg · 1.40 shots/s · 140 px/s move ·
316 px/s projectile · 222 px range.

Slots 2–4 are defined as data (name + stats) so the select screen has something
to render behind the padlock, but have no sprites and cannot be entered:

- **Slot 2 — "The Bruiser"** — STR 8, VIT 7, DEX 3, INT 2
- **Slot 3 — "The Skirmisher"** — STR 4, VIT 3, DEX 9, INT 4
- **Slot 4 — "The Warden"** — STR 3, VIT 9, DEX 4, INT 4

---

## 6. Arena rules

### 6.1 Space
- The arena is a fixed-size world, **larger than the screen is not required for
  the demo**: world size = screen size. The camera does not scroll.
- The player is clamped to a **safe area**: the screen rect inset by 24 px on all
  sides, plus the system safe-area insets (notch, gesture bar). The player can
  never leave it; movement into the boundary slides along it rather than sticking.
- Enemies are *not* clamped — they spawn outside and walk in.

### 6.2 Player
- Moves at `moveSpeedPxPerS` in the direction of the control input. Input
  magnitude scales speed (a half-pushed stick is half speed).
- Faces the direction of travel (horizontal flip only — no 8-way sprite set).
- **Attacks automatically**: every `1 / attacksPerSec` seconds, if an enemy is
  within `attackRangePx`, fire one projectile at the **nearest** enemy's current
  position (no leading, no homing).
- Takes damage on contact with an enemy body. On hit: 0.6 s of invulnerability,
  sprite flashes white, no knockback on the player.
- Regenerates `hpRegenPerSec` continuously.

### 6.3 Projectiles
- Straight line, constant `projSpeedPxPerS`.
- Despawn on: hitting an enemy, or travelling `attackRangePx * 1.5`, or leaving
  the world bounds.
- One enemy per projectile (no pierce in the demo).
- On hit: deal `damagePerHit`, apply `knockbackImpulse` to the enemy, spawn a hit
  spark, show a floating damage number.

### 6.4 Enemies
One enemy type for the demo. A "grunt": walks straight at the player, damages on
contact. Ships with **3 visual skins**, picked at random per spawn, purely for
variety — every skin reads the same stats below (DECISIONS D-022). Still one
enemy type as far as this document and §9 are concerned; distinct stats per
skin is the real "enemy variety" feature and stays out of scope for the demo.

| Property | Value |
|---|---|
| HP | 20 |
| Move speed | 70 px/s |
| Contact damage | 8 |
| Contact cooldown | 1.0 s per enemy |
| Radius | 12 px |

- **Spawning**: from a rect 64 px outside the screen on all four sides, at a
  uniformly random point along that perimeter.
- **Spawn rate**: starts at 1 enemy / 1.5 s, and the interval shrinks by 4 % every
  10 s, floored at 0.25 s. Hard cap of 60 live enemies.
- **Behaviour**: normalise the vector to the player, move. No pathfinding, no
  flocking, no separation in v1 — they will stack, and that is acceptable for the
  demo.
- **Death**: HP ≤ 0 → play a brief death puff, remove, increment kill counter.

### 6.5 Round start / end
- **Start**: 1.0 s spawn sequence — the player's `spawn` animation plays, controls
  are locked, no enemies spawn. Then the spawner starts.
- **End**: player HP ≤ 0 → freeze all components (`game.pauseEngine()` after the
  death frame), show Round Over overlay.

---

## 7. Controls

Three schemes, switchable in Settings, all thumb-driven and all producing the same
normalised `Vector2` in `[-1, 1]`:

1. **Floating joystick** *(default)* — the stick appears wherever the thumb first
   lands in the lower half of the screen and follows drags from there.
2. **Fixed joystick** — the stick is always drawn in the lower corner
   (side per Settings) and only responds to touches near it.
3. **Drag anywhere** — no visible stick; a drag anywhere on screen moves the
   character relative to the drag delta.

All three go through a single `MovementInput` abstraction so the game code never
knows which is active.

---

## 8. Art & animation

> **Revised post-build.** This section originally described the target vocabulary
> against `docs/reference/character_states.png`, a labelled mockup — before any
> production sheets existed. The real assets that got delivered differ from that
> mockup in layout, frame counts, and which states got real frames vs. a
> fallback. What follows describes what's actually in the build; see
> DECISIONS D-015/D-016/D-021/D-024 for the full reasoning trail.

### 8.1 Built for the demo

One PNG per state, `<prefix>-<state>.png`, frames left-to-right, uniform
16×24 cell (not the 32×32 the mockup implied — see §8.4).

| State | Frames | Loops | Trigger |
|---|---|---|---|
| `idle` | 4 | yes | no movement input |
| `run` | 4 | yes | movement input non-zero (mockup guessed 6; delivered 4) |
| `fire` | 5 | no | auto-attack fires; returns to idle/run (mockup guessed 3) |
| `spawn` | 6 | no | round start, 1.0s, controls locked |
| `hurt` | 4 | no | takes damage — a real recoil-pose animation, not a tint (D-021) |
| `death` | 4 | no | HP ≤ 0. A real animation exists (`*-die.png`) — **not** a fallback, see §8.3 |

Separately, PRD §6.2's "sprite flashes white" during the 0.6s invulnerability
window is a plain opacity flicker on the player sprite — unrelated to the
`hurt` animation above, and not using the sheet's flash cells either (D-021).

### 8.2 Defined now, built later (skills phase)

`teleport`, `warp`, `fly`, `dash`, `pose`, `charge`, `channelStaff`,
`channelWand`, `casting`. Named in `AnimState` from day one so that adding
them later is a data change, not a refactor (D-012). Delivered sheets exist
for `fly`, `dash`, and `warp` too, but nothing plays them yet — they're
loaded by nothing until a skill actually calls for them.

### 8.3 Art gap: closed
The reference mockup had no death animation and empty flash cells, and the
demo was originally going to fall back to a fade+shrink effect. The real
delivered sheets included a proper 4-frame death animation
(`*-die.png`), so that fallback was never needed — it's still in the code as
a reserve, unused (D-016). A `*-flash.png` sheet was also delivered but isn't
wired to anything (D-021) — reserved for a future effect, not the `hurt`
state.

### 8.4 Technical
- Source sprites are pixel art. Rendered with **nearest-neighbour filtering**
  (`FilterQuality.none`) everywhere there's a texture — no smoothing, ever.
- **One PNG file per animation state** (not one sheet with a row per state as
  originally planned) — `game/anim/character_animations.dart` loads each file
  and reads its frame count off the image width, rather than a hardcoded
  per-state count.
- Design resolution: **360 × 800 logical px**, letterboxed on other aspect
  ratios (untested past the emulator as of this writing — TASKS 6.5).
  Characters/enemies are authored at 16×24 and drawn at 3× (48×72 on screen);
  projectile/VFX sheets are 16×16 drawn at 2×; floor/border tiles are 32×32
  drawn at 2× — three separate scale constants
  (`kCharacterRenderScale`/`kProjectileRenderScale`/`kFloorTileRenderScale` in
  `core/constants.dart`), not the single 32→2×→64px figure originally assumed.

---

## 9. Explicitly out of scope for the demo

Listing these so they do not creep in:

- Progression, XP, levelling, upgrades between rounds
- Skills, cooldowns, active abilities (the animation states are *reserved*, not
  implemented)
- More than one enemy type; bosses; waves with structure
- Loot, currency, shops, unlocks
- Sound design (volume sliders exist and are wired to a bus; the bus is silent)
- Multiple arenas or backgrounds — one flat tiled floor
- Save games beyond Settings
- iOS, tablet layouts, landscape
- Ads, analytics, IAP, Play Store listing

---

## 10. Done means

The demo is finished when, on the Pixel_10 emulator, a person can:

1. Launch the app to the Main Menu.
2. Change the control scheme in Settings and see it take effect in the arena.
3. Start → pick The Apprentice → read stats that match the derived numbers.
4. Enter the arena, watch the spawn animation, then move with the chosen control
   scheme and never leave the safe area.
5. See the character auto-fire at the nearest enemy, kill enemies, watch damage
   numbers and knockback.
6. Take contact damage, see the HP bar drain and the hurt flash.
7. Die, see the Round Over overlay with a plausible time/kill/damage readout.
8. Tap Main Menu and land back at step 1 with no leaked state — spawn rate, kill
   count and HP all reset on the next run.

And a frame budget of **60 fps with 40 live enemies** on the emulator, verified
with the Show FPS setting on.
