# NEXT — what the skills phase needs from this codebase

Written per TASKS 6.7, ahead of schedule (during the tune pass) because the
question "what else should we build skeleton-wise" came up directly. Read
this before starting the real game on top of the demo.

---

## `arena_game.dart` was split (DECISIONS D-045, closed by D-048)

Done as of Phase 12 — the ~20 `SpriteAnimation`/`Sprite` fields and the
whole `onLoad()` loading block now live in `game/game_assets.dart`'s
`GameAssets` class; `ArenaGame` holds one `late GameAssets gameAssets` and
keeps round state, spawn/kill bookkeeping, `addToWorld`/`addToHud`. Adding
a new asset is a new field + load call in `game_assets.dart`, not another
few lines inline in `ArenaGame.onLoad()` — keep it that way, don't let this
regrow the way it grew the first time. One naming trap worth knowing:
`assets` was the obvious field name and is already taken — Flame's own
`Game` base class declares an `assets` member (an `AssetsCache`), so
`ArenaGame`'s field is `gameAssets` instead. `flutter analyze` catches the
collision immediately if you forget and reach for `assets` again.

## The extension points that already exist

**`Damageable` (`game/components/damageable.dart`, DECISIONS D-042).** Any
future thing a player attack should be able to hit — a destructible object,
a second boss, a turret — implements this small interface (`isDying`/
`position`/`size`/`applyKnockback`/`takeDamage`) and adds itself to
`ArenaGame.damageableTargets` (currently `[...enemies, ?_boss]`) rather
than teaching every attack file about a new concrete type. `BossComponent`
is the existing second example alongside `EnemyComponent` — worth reading
if the next thing needs its own state machine (idle/walk/fire/death) that
doesn't fit `EnemyComponent`'s simpler always-chase behavior.

**The economy's shared rarity model (`core/economy.dart`, DECISIONS D-043).**
`ItemRarity` + `rollRarity` + `kRarityWeights` is one roll shared by gems,
money, and potions — a fourth resource should roll the same way (add a
value table keyed by `ItemRarity`, don't invent a new probability scheme).
`loadColumnAnimation` (`sheet_loader.dart`) is the loader for any future
sheet arranged as side-by-side item-type columns rather than the row-major
layout every character/VFX sheet uses — check which layout a new sheet
actually is before assuming `loadSheetAnimation` fits.

**`ArenaGame.addToWorld`/`addToHud` (DECISIONS D-040, Phase 9).** As of the
roaming-world work, `ArenaGame` actually uses `FlameGame`'s built-in
`world`/`camera` split — before this it never did (everything was a sibling
of them, not a child of `world`, so nothing was ever subject to the
camera's transform). **Any new component you add to the arena must go
through one of these two methods, never a bare `add(...)`/`game.add(...)`:**
`addToWorld` for anything that exists in the game world and should scroll
with the camera (enemies, projectiles, VFX, the floor, the player itself);
`addToHud` for the two things that must stay screen-fixed regardless of
where the camera is (the HP bar, the FPS counter) — it adds to `camera.
viewport`, which is screen-space by construction. Getting this wrong is an
easy, quiet bug: a component added the old way still renders, just without
ever moving relative to the camera, which reads as "this thing is following
the player like a HUD element" even though it's meant to sit in the world.

**Endless world rendering pattern (DECISIONS D-041, Phase 9.3/9.4).**
`ArenaFloor` and `Spawner` both derive everything from
`game.camera.visibleWorldRect` fresh each frame/tick rather than any cached
notion of "where the world is" — that's the pattern to follow for any
future component that needs to cover or react to the area around the
player in an unbounded world (a minimap, a fog-of-war effect, a boss that
should always spawn just off-screen). `ArenaFloor`'s per-cell tile pick is
a deterministic hash of `(col, row)` plus a per-round seed, not
`Random()` per frame — anything else that needs "this world location always
looks/behaves the same way" should use the same trick rather than caching a
grown-on-demand data structure. `Spawner._cullStragglers` is the other half
worth knowing: in an unbounded world, anything slower than the player
(enemies at 70px/s vs. 120+px/s for every character) can fall behind
forever, so any future spawned-and-chasing entity needs its own answer to
"what happens if it never catches up" — silent removal via a
kill-stat-free method (`ArenaGame.cullEnemy`) is the existing answer for
enemies specifically.

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
plus a persistent cast-sparkle visual and a hit/kill flourish each.
`TrackingSpriteEffect` (`game/components/tracking_effect.dart`,
D-034/D-035/D-036) is the new shared piece worth knowing: a VFX glued to any
still-alive `PositionComponent` (follows it every frame, self-removes once
that component leaves the tree, or fades out first if a `fadeOutWhen` poll
closure is given — elite enemies' fire glow fades the instant
`enemy.isDying` flips, D-036) — reused as-is for the Skirmisher's
always-on cast sparkle and elite enemies' fire glow, and the thing to reach
for whenever a future skill needs a visual that has to track a moving
character rather than sit at a fixed point. `AttackBehavior.onEquipped(game)`
(D-036) is the companion hook for a kit's persistent, not-per-cast, visual —
called once from `ArenaGame.resetRound()` right after the player is created;
default no-op, override only if the kit needs one (a branch on
`character.id` inside `ArenaGame` for this would violate CLAUDE.md §4.12).
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

**The 4 newest skills (DECISIONS D-049) split into two more variants of the
same "sync once on first pick, read the current stack count live" shape:**
Ultimate Mirror still owns a live component per stack (`_mirrors`, a
`List<MirrorComponent>` — `_syncMirrors` tops it up to the current stack
count rather than spawning exactly one like Aura); Projectile Ray and
Projectile Thunder own nothing to render between triggers, so they're a
bare `bool _xActive` + `double _xCooldownTimer` pair ticked in `ArenaGame.
update()` next to `character.attackBehavior`'s own cooldown, `_syncX()`
starting the timer only on the first pick. Defence Crystal is the odd one
out — its spec is a flat, non-scaling effect ("higher damage resistance and
low hp regen," no "levels increase" language), so it doesn't read
`pickCounts` live at all; it's back to D-025's original flat-bonus-on-
`PlayerUpgrades` pattern (now also home to `damageResistance`/
`bonusHpRegenPerSec`, alongside the original `bonusMaxHp`/`bonusMoveSpeed`/
`bonusDamage`), applied once at pick time like vit/dex/str/intellect. Which
shape a new skill needs is really just: does its effect need to be *read*
every frame by something else (damage resistance — yes, in
`PlayerComponent.takeDamage`), or does it need to *act* on its own timer
(everything else)? The former is a `PlayerUpgrades` field; the latter is a
component or a bare timer depending on whether there's anything to render
between triggers.

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
`spritePrefix`, D-024), attack behavior, unlock gate
(`unlockKillThreshold`, D-055) — is already on this one data class. A new
playable character (a 5th slot) is: drop the sprite sheets in a new folder,
write a `CharacterDef`, pick a kill threshold (or omit it for
always-unlocked). No other file should need editing for that alone — the
carousel (`CharacterSelectScreen`) iterates `kCharacters` generically, same
as the old grid did.

**Persistent per-round credits, the `addCoins` shape (D-047/D-055).**
`MetaProgressionRepository` has three of these now — `addCoins`, `addGems`,
`addLifetimeKills` — all the same read-modify-write shape: load the current
saved state, bump one field, save it back, called once each from
`ArenaGame._endRound`. A future 4th persistent counter (a scoring metric,
a "bosses killed" unlock condition) is a 4th field on `MetaProgression` +
a 4th `addX` method on the repository, not a new mechanism.

**A world pickup that spawns randomly and self-collects, the
`PotionSpawner`/`GemComponent` shape (D-043, `ChestSpawner`/`ChestComponent`
D-055's second example).** Two matched pieces: a `Component` that ticks its
own interval timer and calls one `ArenaGame.spawnX(Vector2)` method
(`spawnPotion`/`spawnChest`), and the spawned component itself checking
`position.distanceTo(player.position) < someRadius` in its own `update()`
and calling back into `ArenaGame` when close enough. A chest generalizes
this one step further — first a proximity trigger, then a short fixed VFX
beat (`ArenaGame.spawnEffect`/`spawnExplosionEffect`, already-existing
one-shot helpers), *then* the payout — worth reading
(`game/components/chest.dart`) if a future pickup needs "something happens
before the reward," not just an instant collect.

**A 4th Flame overlay and the level-up chaining pattern generalized
(D-025 → D-055).** `ArenaGame._afterMenuClosed()` is now the one place that
decides what shows next once any of LevelUp/PauseMenu/ChestReveal closes —
pending level-ups first, then a pending chest reveal, then actually
resume. A 5th thing that needs to interrupt the round with a paused popup
(its own overlay registered in `ArenaScreen.overlayBuilderMap`, CLAUDE.md
§4.2) slots into this same priority chain rather than needing its own
bespoke coordination with the other three — decide where in the priority
order it belongs, add one more branch to `_afterMenuClosed`, done.

**SHOP's permanent one-time items, the `ShopItem` shape (D-069).**
`core/shop.dart`'s `kShopItems` is a flat, declaration-ordered list — a new
item is a new `ShopItemId` member + a new `ShopItem` entry + a bonus getter
on `MetaProgression` (`bonusXFromShop`, reading `ownsItem(id)`) + wiring
that getter into wherever the effect actually applies (`PlayerComponent`
for stat bonuses, `ArenaGame.resolveAttackDamage` for damage). Unlike the
leveled `MetaStat` dials, these are owned-or-not, not leveled — no cost
curve, `ownedItemIds` is just a `Set<String>`. `ArenaGame.
tryConsumeRevive`/`reviveAvailable` is the pattern for a shop item whose
*ownership* is permanent but whose *effect* is consumed once per round
(Second Wind) — round-scoped state on `ArenaGame`, reset in `resetRound`,
gated by a `MetaProgression.ownsX` check rather than living on
`MetaProgression` itself.

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

**Adding a new build-time tuning knob, the `GameConfig` shape (D-090).**
`core/game_config.dart`'s `GameConfig` is a curated overlay on top of
select `core/` constants, not a replacement for CLAUDE.md §4.3 — most
combat numbers still live as plain `const`s in `stats.dart`/
`game_rules.dart`/`progression.dart`/`economy.dart`, and should keep being
added there first. Promote one to config-editable only when there's an
actual reason a developer would want to change it without touching code
(a balance pass, a build flavor). The shape to copy: add a typed getter to
`GameConfig` with a fallback matching the constant's current value, add
the same key/section to `assets/config/game_config.json` (so the shipped
file documents every knob that exists), then change the *one* place that
number is actually declared from `const` to `get` (`double get kFoo =>
GameConfig.instance.foo;`) — every existing call site keeps reading the
same bare identifier, zero other files need touching (verified for the
whole first batch: no call site anywhere in this codebase relies on
compile-time constancy for these). Whole maps
(`kCoinValueByRarity`/`kRarityWeights`/`kPotionHealByRarity`) were
deliberately left alone rather than made config-editable field-by-field —
existing tests assert their exact values directly, and a multiplier
applied at the one real consuming call site (`ArenaGame._rollCoins`) gets
the same practical tuning power without touching the table or the tests
that pin it. Add `GameConfig` test coverage for a new knob the same way
`test/core/game_config_test.dart` does: assert against the real shipped
JSON (not a mock), so a typo'd key name in the file itself gets caught,
not just a typo in the Dart getter.

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
