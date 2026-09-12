# NEXT.md — Pixel Arena Brawl (PAB)

Extension points and rough edges for whoever picks up the next feature.
Keep this current the same way as `TASKS.md` — when a pattern here stops
being true, or a new one is worth documenting, update it as part of the
change, not as a separate cleanup pass later.

**Numbering resets here** (see `CLAUDE.md`/`DECISIONS.md`/`TASKS.md`) —
every pattern below is still true as of PAB Alpha 1.0.0, just no longer
cited by decision number; the reasoning behind each, if it's not obvious
from the pattern itself, is in `docs/archive/DECISIONS_pre-alpha.md`.

---

## The extension points that already exist

**`Damageable` (`game/components/damageable.dart`).** Any future thing a
player attack should be able to hit — a destructible object, a second
boss, a turret — implements this small interface (`isDying`/`position`/
`size`/`applyKnockback`/`takeDamage`) and adds itself to `ArenaGame.
damageableTargets` (currently `[...enemies, ?_boss]`) rather than teaching
every attack file about a new concrete type. `BossComponent` is the
existing second example alongside `EnemyComponent` — worth reading if the
next thing needs its own state machine (idle/walk/fire/death) that
doesn't fit `EnemyComponent`'s simpler always-chase behavior.

**The economy's shared rarity model (`core/economy.dart`).** `ItemRarity`
+ `rollRarity` + `kRarityWeights` is one roll shared by gems, money, and
potions — a fourth resource should roll the same way (add a value table
keyed by `ItemRarity`, don't invent a new probability scheme).
`loadColumnAnimation` (`sheet_loader.dart`) is the loader for any future
sheet arranged as side-by-side item-type columns rather than the row-major
layout every character/VFX sheet uses — check which layout a new sheet
actually is before assuming `loadSheetAnimation` fits.

**`ArenaGame.addToWorld`/`addToHud`.** `ArenaGame` uses `FlameGame`'s
built-in `world`/`camera` split. **Any new component you add to the arena
must go through one of these two methods, never a bare
`add(...)`/`game.add(...)`:** `addToWorld` for anything that exists in
the game world and should scroll with the camera (enemies, projectiles,
VFX, the floor, the player itself); `addToHud` for things that must stay
screen-fixed regardless of where the camera is (the HP/XP bars, the FPS
counter) — it adds to `camera.viewport`, which is screen-space by
construction. Getting this wrong is an easy, quiet bug: a component added
the old way still renders, just without ever moving relative to the
camera, which reads as "this thing is following the player like a HUD
element" even though it's meant to sit in the world.

**Endless world rendering pattern.** `ArenaFloor` and `Spawner` both
derive everything from `game.camera.visibleWorldRect` fresh each
frame/tick rather than any cached notion of "where the world is" — that's
the pattern to follow for any future component that needs to cover or
react to the area around the player in an unbounded world (a minimap, a
fog-of-war effect, a boss that should always spawn just off-screen).
`ArenaFloor`'s per-cell tile pick is a deterministic hash of `(col, row)`
plus a per-round seed, not `Random()` per frame — anything else that
needs "this world location always looks/behaves the same way" should use
the same trick rather than caching a grown-on-demand data structure.
`Spawner._cullStragglers` is the other half worth knowing: in an
unbounded world, anything slower than the player (enemies at 70px/s vs.
120+px/s for every character) can fall behind forever, so any future
spawned-and-chasing entity needs its own answer to "what happens if it
never catches up" — silent removal via a kill-stat-free method
(`ArenaGame.cullEnemy`) is the existing answer for enemies specifically.

**`AnimState` (`game/anim/anim_state.dart`)** lists every state on the
reference sheet, not just the ones currently wired. Adding a skill that
needs `dash`/`charge`/`channelStaff`/etc. is: drop the sprite sheet in,
add a line to `CharacterAnimations._fileNames`, done — the enum member
and the `SpriteAnimationGroupComponent` machinery are already there.

**`AttackBehavior` (`game/attack_behavior.dart`).** `ArenaGame` doesn't
know how a character attacks — it owns the cooldown timer (round state
stays on `ArenaGame`, CLAUDE.md §4.5) and calls `character.attackBehavior.
perform(this)` when it elapses. 4 real examples exist: `ProjectileAttack`
(the default, a simple bolt), `KnifeAttack` (pierces every enemy in its
path instead of stopping at the first), `SpiralFireAttack` (two
projectiles orbiting a shared advancing point, plus a persistent
cast-sparkle visual), `WardenSlamAttack` (melee AoE around the player
instead of a projectile). The pattern to repeat for a new kit: a new
behavior class + a new projectile/effect component, `ArenaGame`/
`PlayerComponent` untouched. `TrackingSpriteEffect`
(`game/components/tracking_effect.dart`) is the shared piece worth
knowing for VFX that has to follow a moving target: glues to any
still-alive `PositionComponent`, self-removes once that component leaves
the tree, or fades out first if a `fadeOutWhen` poll closure is given.
`AttackBehavior.onEquipped(game)` is the companion hook for a kit's
persistent, not-per-cast, visual — called once from `ArenaGame.
resetRound()` right after the player is created; default no-op, override
only if the kit needs one (a branch on `character.id` inside `ArenaGame`
for this would violate CLAUDE.md §4.12). This is also where a skill
system's "active ability" hook would attach: an `AttackBehavior` doesn't
have to be the *auto*-attack specifically, it's just "what happens when
this timer fires" — a second timer/behavior pair on `CharacterDef` would
give a second, independently-cooling ability without touching the first
one.

**`EnemySkin` (`game/anim/enemy_animations.dart`).** Three sprite skins
exist and are already keyed by an enum; all three currently read the same
`EnemyStats`. If/when real enemy variety (ranged, fast, tanky — see
`TASKS.md`'s Backlog) gets built, `EnemySkin` is already the hook to key a
per-type stats table off of — you're not introducing a new concept, just
making the existing one do more.

**`UpgradeKind` (`core/progression.dart`).** A new power-up is: add an
enum member, a case in `PlayerUpgrades.apply`, a label/description, an
entry in `kUpgradeWeights` — the popup, the weighted roll, the "view your
upgrades" screen and the pause-menu plumbing all generalize to N
upgrades. `kUpgradeMaxPicks` (`null` = unlimited, an int = cap) caps a
skill's stack count; a skill that needs a live Flame component (like
Aura's shield ring) follows the pattern Aura itself uses: `ArenaGame` owns
the component, creates it lazily off `upgrades.pickCounts` the first time
it's picked, and the component reads its own current strength from
`pickCounts` every tick rather than being handed a value or rebuilt per
pick. The roll is weighted (`kUpgradeWeights`, Efraimidis-Spirakis
sampling in `rollUpgradeChoices`) — currently placeholder equal weights,
a real balance pass is still open.

Skills split into shapes depending on what they need: **Ultimate Mirror**
owns a live component *per stack* (`_mirrors`, a `List<MirrorComponent>`
— `_syncMirrors` tops it up to the current stack count rather than
spawning exactly one like Aura); **Projectile Ray**/**Projectile Thunder**
own nothing to render between triggers, so they're a bare `bool _xActive`
+ `double _xCooldownTimer` pair ticked in `ArenaGame.update()` next to
`character.attackBehavior`'s own cooldown; **Defence Crystal** is flat and
non-scaling, so it's back to the plain flat-bonus-on-`PlayerUpgrades`
pattern (`damageResistance`/`bonusHpRegenPerSec`, applied once at pick
time like vit/dex/str/intellect). Which shape a new skill needs: does its
effect need to be *read* every frame by something else (a `PlayerUpgrades`
field, e.g. damage resistance read in `PlayerComponent.takeDamage`), or
does it need to *act* on its own timer (a component, or a bare timer
depending on whether there's anything to render between triggers)?

**Character-locked upgrades.** `kCharacterLockedUpgrades`
(`UpgradeKind -> CharacterDef.id`) + `upgradeKindsFor(characterId)` in
`core/progression.dart` restrict the roll pool per character —
`rollUpgradeChoices`'s `candidates` param (defaults to every kind, so
existing callers/tests are unaffected). `knifeMastery` (Bruiser only) is
the existing example. A future kit wanting its own locked upgrade is one
more map entry, not new branching.

**`CharacterDef` (`data/characters.dart`).** Every field a character needs
to be playable — stats (base STR/VIT/DEX/INT are `GameConfig`-backed, see
below), sprite location (`spriteFolder`/`spritePrefix`), attack behavior,
unlock gate (`unlockKillThreshold`) — is already on this one data class.
A new playable character (a 5th slot) is: drop the sprite sheets in a new
folder, write a `CharacterDef`, pick a kill threshold (or omit it for
always-unlocked). No other file should need editing for that alone — the
carousel (`CharacterSelectScreen`) iterates `kCharacters` generically.

**Persistent round-over credits and achievement evaluation, the
`recordRoundEnd` shape.** `MetaProgressionRepository.recordRoundEnd` is
the one place a round's earnings cross over into the persistent wallet —
one load, every lifetime counter updated in memory, achievements
evaluated and claimed against the updated totals, one save. A future new
persistent counter that should *also* gate an achievement: add the field
to `MetaProgression` (persisted in `load`/`save`, same primitive-field
pattern every other field there uses), update it inside
`recordRoundEnd`, and see `core/achievements.dart`'s own section below for
wiring a new `AchievementStat`. A persistent counter that does *not* need
to gate an achievement (unlikely, but possible) doesn't need the
`achievements.dart` half — just the `MetaProgression` field + the
`recordRoundEnd` update.

**A world pickup that spawns randomly and self-collects, the
`PotionSpawner`/`GemComponent` shape (`ChestSpawner`/`ChestComponent` is
the second, richer example).** Two matched pieces: a `Component` that
ticks its own interval timer and calls one `ArenaGame.spawnX(Vector2)`
method (`spawnPotion`/`spawnChest`), and the spawned component itself
checking `position.distanceTo(player.position) < someRadius` in its own
`update()` and calling back into `ArenaGame` when close enough. A chest
generalizes this one step further — first a proximity trigger (a pickup
SFX plays here), then a short fixed VFX beat (`ArenaGame.spawnEffect`/
`spawnExplosionEffect`, already-existing one-shot helpers), *then* the
payout — worth reading (`game/components/chest.dart`) if a future pickup
needs "something happens before the reward," not just an instant collect.

**A new Flame overlay and the level-up chaining pattern.**
`ArenaGame._afterMenuClosed()` is the one place that decides what shows
next once any of LevelUp/PauseMenu/ChestReveal closes — pending
level-ups first, then a pending chest reveal, then actually resume. A new
thing that needs to interrupt the round with a paused popup (its own
overlay registered in `ArenaScreen.overlayBuilderMap`, CLAUDE.md §4.2)
slots into this same priority chain rather than needing its own bespoke
coordination with the other three — decide where in the priority order it
belongs, add one more branch to `_afterMenuClosed`, done.

**SHOP's permanent one-time items, the `ShopItem` shape.**
`core/shop.dart`'s `kShopItems` is a flat, declaration-ordered list — a
new item is a new `ShopItemId` member + a new `ShopItem` entry + a bonus
getter on `MetaProgression` (`bonusXFromShop`, reading `ownsItem(id)`) +
wiring that getter into wherever the effect actually applies
(`PlayerComponent` for stat bonuses, `ArenaGame.resolveAttackDamage` for
damage). Unlike the leveled `MetaStat` dials, these are owned-or-not, not
leveled — no cost curve, `ownedItemIds` is just a `Set<String>`.
`ArenaGame.tryConsumeRevive`/`reviveAvailable` is the pattern for a shop
item whose *ownership* is permanent but whose *effect* is consumed once
per round (Second Wind) — round-scoped state on `ArenaGame`, reset in
`resetRound`, gated by a `MetaProgression.ownsX` check rather than living
on `MetaProgression` itself.

**`core/game_rules.dart`.** Pure gameplay math — targeting, spawn interval
decay, knockback distance — lives here specifically so it's unit-testable
without a `GameWidget` (see Testing, below). When adding a new rule (a new
targeting mode, a different ramp curve), put the *math* here and have the
component call it, rather than inlining it in an `update()` method.
`test/core/game_rules_test.dart` is the pattern to follow.

**Adding a new build-time tuning knob, the `GameConfig` shape.**
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
same bare identifier, zero other files need touching. Whole maps
(`kCoinValueByRarity`/`kRarityWeights`/`kPotionHealByRarity`) were
deliberately left alone rather than made config-editable field-by-field —
existing tests assert their exact values directly, and a multiplier
applied at the one real consuming call site (`ArenaGame._rollCoins`) gets
the same practical tuning power without touching the table or the tests
that pin it. Add `GameConfig` test coverage for a new knob the same way
`test/core/game_config_test.dart` does: assert against the real shipped
JSON parsed independently inside the test (not hardcoded literal values —
that broke the first time the file was actually tuned, since pinning
exact numbers fights the whole point of a developer-editable file), so a
typo'd key name gets caught without the test also breaking every time
someone legitimately tunes a number.

**Adding a 21st achievement, or a new `AchievementStat`.** A new
achievement gated on an *existing* stat is one more `Achievement(...)`
entry in `core/achievements.dart`'s `kAchievements` — pick a stable `id`
(never reuse or rename one already shipped, `MetaProgression.
claimedAchievementIds` persists it verbatim) and a threshold, done. A new
*kind* of stat needs: an `AchievementStat` enum member, a named parameter
on `buildStatValues`, a matching field on `MetaProgression`, and either a
delta or a `max()` update inside `recordRoundEnd` depending on whether
it's cumulative (kills, gems, chests — goes up every round) or a
high-water mark (level reached, survival time — replaced only if the new
round beat it). Whether `ArenaGame` needs a new round-scoped counter
feeding that update depends on whether the raw number already exists
somewhere on `ArenaGame` (`kills`/`coinsEarned`/`gemsCollected`/`level`/
`elapsed` already did; bosses/chests/potions didn't, hence the 3
round-scoped counters that exist for those). Keep `achievements.dart`
import-free of `meta_progression.dart` when doing this — that's the one
rule worth not breaking, it's what lets `meta_progression.dart` import
`achievements.dart` (for `recordRoundEnd`) without a cycle.

## What's explicitly NOT built, and why that's fine for now

See `TASKS.md`'s Backlog for the full current list (enemy variety, a real
skill system beyond the 5 shipped skills, structured waves, object
pooling, haptics, Play Store packaging, etc.) — it's kept there instead of
duplicated here so there's one place tracking "known open, not started."

## Testing — read this before adding gameplay logic

**A `GameWidget` cannot be exercised in `flutter test`.** Real PNG
decoding through Flame's image cache never resolves under the fake-async
test clock, no matter how `tester.runAsync` is positioned around it.
Don't spend time re-litigating this; it's a harness limitation.
Automated widget-test coverage stops at Character Select.

This means: **the arena itself has zero regression coverage from
gameplay-feel tests.** Nothing catches a broken targeting rule, a wrong
spawn curve, a knockback that's too strong, except playing it. The fix
isn't to fight the test harness — it's `core/game_rules.dart`: pull the
actual game-rule *math* out of `update()` methods into plain functions
that take/return plain types (`Vector2`, `double`, no `Component`/`Game`),
and unit-test those the same way `stats.dart`/`economy.dart`/
`progression.dart`/`achievements.dart`/`game_config.dart` already are. The
component still owns the Flame wiring (reading positions off other
components, calling `add()`, etc.) but the decision logic — "which enemy
is the target," "what's the next interval," "how far does this get
knocked back," "is this achievement met yet" — is tested directly.

When adding a new gameplay rule, ask: does this need a live `GameWidget`
to verify (an animation looking right, a touch gesture feeling right —
no, don't fight that), or is it actually just math wearing a component's
clothing (yes — pull it into a plain, importable, testable file)?

## Smaller things worth knowing

- `AttackBehavior` types are `const`-constructible and stateless on
  purpose — cooldown state lives on `ArenaGame`, not the behavior, so
  behaviors can be shared across `CharacterDef`s without leaking state
  between rounds (CLAUDE.md §4.5's "never carry state across rounds" rule
  applies to more than just obvious round counters).
- `data/characters.dart` importing `game/attack_behavior.dart` (data layer
  reaching into the game layer) is a real layering wrinkle, accepted
  rather than adding an interface purely to avoid it. If it starts
  hurting — e.g. `data/` needing to stay Flame-free for some reason — the
  fix is a narrower interface (`AttackContext`) exposing just what
  `AttackBehavior.perform` needs, instead of the full `ArenaGame`.
- The HP/XP bars are fixed at the top of the screen, not floating above
  the player — specifically because enemies are allowed to stack on the
  player with no separation (see `TASKS.md`'s Backlog). If separation/
  steering ever gets built, revisit whether floating would read better
  now that the crowd problem is gone.
- `achievements.dart` has zero imports of `meta_progression.dart` on
  purpose, even though every achievement's progress is ultimately read
  off a `MetaProgression` — evaluation works against a plain
  `Map<AchievementStat, num>` instead, so `meta_progression.dart` can
  import `achievements.dart` (for `recordRoundEnd`) without the reverse
  import ever needing to exist. Don't "simplify" this by having
  `Achievement.isMetBy(MetaProgression)` take the real type directly —
  that's the 2-file cycle this shape exists to avoid.
