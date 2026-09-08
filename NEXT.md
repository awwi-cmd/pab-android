# NEXT — what the skills phase needs from this codebase

Written per TASKS 6.7, ahead of schedule (during the tune pass) because the
question "what else should we build skeleton-wise" came up directly. Read
this before starting the real game on top of the demo.

---

## The extension points that already exist

**`AnimState` (`game/anim/anim_state.dart`)** lists every state on the
reference sheet, not just the six the demo wires (DECISIONS D-012). Adding
a skill that needs `dash`/`charge`/`channelStaff`/etc. is: drop the sprite
sheet in, add a line to `CharacterAnimations._fileNames`, done — the enum
member and the `SpriteAnimationGroupComponent` machinery are already there.

**`AttackBehavior` (`game/attack_behavior.dart`, DECISIONS D-024/D-029).**
`ArenaGame` doesn't know how a character attacks — it owns the cooldown
timer (round state stays on `ArenaGame`, CLAUDE.md §4.5) and calls
`character.attackBehavior.perform(this)` when it elapses. `ProjectileAttack`
is still the default; `KnifeAttack` (D-029, the Bruiser) is the second real
example — a piercing thrown weapon that reuses `ProjectileAttack`'s exact
targeting/cooldown/damage math and only differs in what the projectile
component itself does (keeps flying and hitting instead of despawning on the
first hit, swaps its own sprite mid-flight). That split — new behavior class
+ new projectile component, `ArenaGame`/`PlayerComponent` untouched — is the
pattern to repeat for the Warden kit still open in TASKS 8.3. `SpiralFireAttack`
(D-034, the Skirmisher) is the third example and the first built around real
VFX beyond a sprite swap — two projectiles orbiting a shared advancing point,
plus a cast/hit/kill flourish each. `TrackingSpriteEffect`
(`game/components/tracking_effect.dart`, D-034/D-035) is the new shared piece
worth knowing: a VFX glued to any still-alive `PositionComponent` (follows it
every frame, self-removes once that component leaves the tree) — reused
as-is for the Skirmisher's cast sparkle and for elite enemies' fire glow
(D-035), and the thing to reach for whenever a future skill needs a visual
that has to track a moving character rather than sit at a fixed point.
This is also where a skill system's "active ability" hook would attach: an
`AttackBehavior` doesn't have to be the *auto*-attack specifically, it's
just "what happens when this timer fires" — a second timer/behavior pair
on `CharacterDef` would give you a second, independently-cooling ability
without touching the first one.

**`EnemySkin` (`game/anim/enemy_animations.dart`, DECISIONS D-022).** Three
sprite skins exist and are already keyed by an enum; all three currently
read the same `EnemyStats`. If/when real enemy variety (ranged, fast,
tanky — see Backlog) gets built, `EnemySkin` is already the hook to key a
per-type stats table off of — you're not introducing a new concept, just
making the existing one do more.

**`UpgradeKind` (`core/progression.dart`, DECISIONS D-025/D-027).** A new
power-up is still: add an enum member, a case in `PlayerUpgrades.apply`, a
label/description, an entry in `kUpgradeWeights` — the popup, the
weighted roll, the "view your upgrades" screen and the pause-menu plumbing
all generalize to N upgrades. D-027's Aura is the second real example and
it's a genuine skill, not a stat bump — `kUpgradeMaxPicks` (`null` =
unlimited, an int = cap) is there for exactly that, and a skill that needs
a live Flame component (like Aura's shield ring, D-032) follows the same
pattern: `ArenaGame` owns the component (`_aura`), creates it lazily off
`upgrades.pickCounts` the first time it's picked (`_syncAura()`), and the
component reads its own current strength from `pickCounts` every tick
rather than being handed a value or rebuilt per pick. The roll itself is
weighted now (`kUpgradeWeights`, Efraimidis-Spirakis sampling in
`rollUpgradeChoices`) with placeholder equal weights — the actual balance
pass is still to come, this just wires the knob.

**Character-locked upgrades (DECISIONS D-031).** `kCharacterLockedUpgrades`
(`UpgradeKind -> CharacterDef.id`) + `upgradeKindsFor(characterId)` in
`core/progression.dart` restrict the roll pool per character —
`rollUpgradeChoices`'s `candidates` param (defaults to every kind, so
existing callers/tests are unaffected). `knifeMastery` (Bruiser only) is the
first one. A future Skirmisher/Warden kit wanting its own locked upgrade is
one more map entry, not new branching — same shape as adding a plain
upgrade, just also touch this map.

**`CharacterDef` (`data/characters.dart`).** Every field a character needs
to be playable — stats, sprite location (`spriteFolder` +
`spritePrefix`, D-024), attack behavior — is already on this one data
class. A new playable character (unlocking slot 2/3/4) is: drop the sprite
sheets in a new folder, write a `CharacterDef`, flip `unlocked: true`. No
other file should need editing for that alone.

**`core/game_rules.dart` (D-024).** Pure gameplay math — targeting, spawn
interval decay, knockback distance — lives here specifically so it's
unit-testable without a `GameWidget` (see the testing section below). When
adding a new rule (a new targeting mode, a different ramp curve), put the
*math* here and have the component call it, rather than inlining it in an
`update()` method. `test/core/game_rules_test.dart` is the pattern to
follow.

## What's explicitly NOT built, and why that's fine for now

- **Audio** — `flame_audio` is a dependency, nothing plays through it.
  Settings sliders persist values into `SharedPreferences` but there's no
  audio bus reading them. Small, contained, deliberately deferred
  (developer's call) rather than unknown/forgotten.
- **Object pooling** — enemies/projectiles are `add()`/`removeFromParent()`
  each time, no pool. CLAUDE.md §4.4 asks for "pooled or at least cheap";
  right now it's the "cheap" half only. Deliberately deferred until the
  Phase 6 perf check (TASKS 4.15/6.4) actually measures whether it's
  needed — don't build a pool speculatively.
- **Per-enemy-type stats** — see `EnemySkin` above. Visual variety shipped,
  distinct stats didn't (D-022, developer's explicit call when asked,
  since it's real PRD §9 scope).
- **Everything else in PRD §9** — more playable characters, more enemy
  types, waves, a boss, loot, real audio, multiple arenas. All Backlogged,
  not started. If any of these start looking necessary to make things
  better, stop and ask before building past that line — CLAUDE.md says so
  for a reason, and it's already come up more than once in practice.
  - **Progression is the exception — it's started.** Phase 7 (TASKS.md,
    DECISIONS D-025/D-026) shipped both halves now: in-round XP from kills,
    levelling, a 1-of-3 upgrade popup, pause menu, debug tools, and enemies
    scaling HP/contact damage linearly with player level
    (`enemyStatMultiplier`, `core/game_rules.dart`). Faster spawns tied to
    level, or distinct tougher `EnemySkin` tiers, are still open if the
    linear stat scale alone doesn't carry the curve far enough — see
    TASKS Backlog.

## Testing — read this before adding gameplay logic

**A `GameWidget` cannot be exercised in `flutter test`** (DECISIONS D-019).
Real PNG decoding through Flame's image cache never resolves under the
fake-async test clock, no matter how `tester.runAsync` is positioned
around it — confirmed by reproducing `GameWidget`'s exact load sequence in
isolation. Automated widget-test coverage stops at Character Select.

This means: **the arena itself has zero regression coverage.** Nothing
catches a broken targeting rule, a wrong spawn curve, a knockback that's
too strong, except playing it. The fix isn't to fight the test harness
again — it's `core/game_rules.dart`: pull the actual game-rule *math* out
of `update()` methods into plain functions that take/return plain types
(`Vector2`, `double`, no `Component`/`Game`), and unit-test those the same
way `stats.dart` already is. The component still owns the Flame wiring
(reading positions off other components, calling `add()`, etc.) but the
decision logic — "which enemy is the target," "what's the next interval,"
"how far does this get knocked back" — is tested directly.

When adding a new gameplay rule, ask: does this need a live `GameWidget` to
verify (an animation looking right, a touch gesture feeling right — no,
don't fight that), or is it actually just math wearing a component's
clothing (yes — pull it into `game_rules.dart`)?

## Smaller things worth knowing

- `AttackBehavior` types are `const`-constructible and stateless on
  purpose (D-024) — cooldown state lives on `ArenaGame`, not the behavior,
  so behaviors can be shared across `CharacterDef`s without leaking state
  between rounds (CLAUDE.md §4.5's "never carry state across rounds" rule
  applies to more than just obvious round counters).
- `data/characters.dart` importing `game/attack_behavior.dart` (data layer
  reaching into the game layer) is a real layering wrinkle, accepted for
  now rather than adding an interface purely to avoid it. If it starts
  hurting — e.g. `data/` needing to stay Flame-free for some reason — the
  fix is a narrower interface (`AttackContext`) exposing just what
  `AttackBehavior.perform` needs, instead of the full `ArenaGame`.
- HP bar is a fixed top bar, not floating above the player (D-020) —
  specifically because enemies are allowed to stack on the player with no
  separation (PRD §6.4). If separation/steering ever gets built, revisit
  whether floating would read better now that the crowd problem is gone.
