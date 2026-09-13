import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flame/game.dart' show Vector2;

import 'game_config.dart';

/// Pure gameplay math with no Flame `Component`/`Game` dependency —
/// deliberately kept separate from the components that call it so it's
/// unit-testable the same way `stats.dart` is, without a `GameWidget`
/// (DECISIONS D-019 found real asset-loading needs one; this sidesteps
/// that entirely for the logic that doesn't need it).
///
/// If a rule here changes (targeting, spawn ramp, knockback), a test can
/// catch the regression — nobody has to notice it broke by playing the
/// round.

/// Index of the closest point in [candidates] to [from] that's within
/// [maxRange], or -1 if none qualify. Ties keep whichever candidate was
/// found first. PRD §6.2: auto-attack targets the nearest enemy in range.
int nearestWithinRange(
  Vector2 from,
  List<Vector2> candidates,
  double maxRange,
) {
  var bestIndex = -1;
  var bestDistance = maxRange;
  for (var i = 0; i < candidates.length; i++) {
    final distance = candidates[i].distanceTo(from);
    if (distance <= bestDistance) {
      bestIndex = i;
      bestDistance = distance;
    }
  }
  return bestIndex;
}

/// All indices in [candidates] within [maxRange] of [from] — unlike
/// [nearestWithinRange] (single target, for the auto-attack), this is for
/// area-effect abilities that hit everything in a radius (e.g. the Aura
/// skill, DECISIONS D-027).
List<int> allWithinRange(
  Vector2 from,
  List<Vector2> candidates,
  double maxRange,
) {
  final result = <int>[];
  for (var i = 0; i < candidates.length; i++) {
    if (candidates[i].distanceTo(from) <= maxRange) {
      result.add(i);
    }
  }
  return result;
}

/// PRD §6.4: the spawn interval shrinks by [factor] every decay tick,
/// floored at [floor] so it never reaches (or goes below) zero.
double nextSpawnInterval(
  double current, {
  required double factor,
  required double floor,
}) {
  final next = current * factor;
  return next < floor ? floor : next;
}

/// Converts the PRD §6.3 px/s knockback formula into a one-off shove
/// distance over a fixed short duration — simpler than a decaying
/// velocity, and plenty for the demo's feel (see `EnemyComponent`).
double knockbackDistance(double impulsePxPerS, double durationSec) {
  return impulsePxPerS * durationSec;
}

/// DECISIONS D-026: the other half of the progression vision — enemies get
/// tougher as the player levels, not just the player getting stronger.
/// Linear per level, applied to `EnemyStats.maxHp`/`contactDamage` at spawn
/// time (`ArenaGame.spawnEnemy`) — deliberately not `moveSpeedPxPerS`, so a
/// higher level never makes an enemy literally impossible to outrun, only
/// costlier to fight or facetank.
/// `GameConfig`-backed (DECISIONS D-090) instead of a raw `const` — a
/// developer-editable tuning knob in `assets/config/game_config.json`.
double get kEnemyScalePerLevel => GameConfig.instance.enemyStatScalePerLevel;

double enemyStatMultiplier(int playerLevel) {
  assert(playerLevel >= 1);
  return 1 + (playerLevel - 1) * kEnemyScalePerLevel;
}

/// DECISIONS D-035: "elite" enemies are a visual-only marker for now (a fire
/// glow, `ArenaGame.spawnEnemy`) — no stat change, unlike `enemyStatMultiplier`
/// above. Rolled independently per spawn, not tied to player level.
/// `GameConfig`-backed (DECISIONS D-090), same reasoning as
/// [kEnemyScalePerLevel].
double get kEliteChance => GameConfig.instance.eliteChance;

/// [chanceMultiplier] scales the base chance down (or up) -- SHOP's Steel
/// Nerves (DECISIONS D-070) halves it. Defaults to 1 so every existing call
/// site (and test) is unaffected.
bool rollIsElite(Random random, {double chanceMultiplier = 1.0}) {
  return random.nextDouble() < kEliteChance * chanceMultiplier;
}

/// DECISIONS D-042: the boss gets ~20% stronger each time it spawns
/// (levels 3, 6, 9 — `spawnIndex` 0/1/2), compounding rather than flat, so
/// the 3rd fight is noticeably tougher than "just" +40% over the 1st.
const double kBossScalePerSpawn = 0.2;

double bossStatMultiplier(int spawnIndex) {
  assert(spawnIndex >= 0);
  return pow(1 + kBossScalePerSpawn, spawnIndex).toDouble();
}

/// Corruption (DECISIONS D-047, the Upgrades shop's 5th track) — developer's
/// spec verbatim: "increases your enemy spawn rate/enemy HP/enemy damage but
/// increases rewards per level bought." Linear per level (0-10, per
/// character since DECISIONS D-003 — `ArenaGame.metaLevel(MetaStat.
/// corruption)`), same shape as [enemyStatMultiplier] above but layered
/// on top of it rather than replacing it. First-guess placeholders, not
/// tuned on-device.
const double kCorruptionSpawnRatePerLevel = 0.08;
const double kCorruptionEnemyStatPerLevel = 0.08;
const double kCorruptionRewardPerLevel = 0.10;

/// Multiplies `Spawner`'s scheduled interval — below 1 means faster spawns.
/// Clamped so max corruption (level 10, -80%) can't collapse the interval to
/// zero and spawn-lock the frame.
double corruptionSpawnIntervalMultiplier(int corruptionLevel) {
  return (1 - corruptionLevel * kCorruptionSpawnRatePerLevel).clamp(0.2, 1.0);
}

/// Multiplies enemy HP/contact damage at spawn, alongside (not instead of)
/// [enemyStatMultiplier].
double corruptionEnemyStatMultiplier(int corruptionLevel) {
  return 1 + corruptionLevel * kCorruptionEnemyStatPerLevel;
}

/// Multiplies coin rewards per kill — the "but increases rewards" half of
/// the trade-off.
double corruptionRewardMultiplier(int corruptionLevel) {
  return 1 + corruptionLevel * kCorruptionRewardPerLevel;
}

/// 3 more Upgrades-screen dials (DECISIONS D-067), same shape as Corruption
/// above — a per-level multiplier/bonus read straight off `MetaProgression`,
/// not a raw attribute add like STR/VIT/DEX/INT. Unlike Corruption none of
/// these trade anything away; they're the "pure reward" half of the same
/// dial idea. First-guess placeholders, not tuned on-device.
const double kHasteAttackSpeedPerLevel = 0.05;
const double kFortuneRewardPerLevel = 0.10;
const double kResolveDamageResistancePerLevel = 0.02;
const double kResolveHpRegenPerLevel = 0.05;

/// Multiplies the player's attack cooldown (`ArenaGame`'s own
/// `_fireCooldown` calc) — above 1 means faster attacks. +50% at max level.
double hasteAttackSpeedMultiplier(int hasteLevel) {
  return 1 + hasteLevel * kHasteAttackSpeedPerLevel;
}

/// Multiplies coin rewards per kill, layered on top of (not instead of)
/// [corruptionRewardMultiplier] — a permanent version of the same reward
/// bump, bought instead of traded for.
double fortuneRewardMultiplier(int fortuneLevel) {
  return 1 + fortuneLevel * kFortuneRewardPerLevel;
}

/// A flat damage-resistance fraction, same shape as Defence Crystal's
/// in-round bonus (`core/progression.dart`'s `damageResistance`) but
/// persistent across every run instead of an in-round pick. Clamped at the
/// call site alongside Defence Crystal's own bonus, same reasoning: a
/// future overstack can't invert it into bonus damage. 20% at max level.
double resolveDamageResistance(int resolveLevel) {
  return resolveLevel * kResolveDamageResistancePerLevel;
}

/// A flat HP-regen-per-second bonus, same additive-layer shape as Defence
/// Crystal's `bonusHpRegenPerSec`.
double resolveHpRegenPerSec(int resolveLevel) {
  return resolveLevel * kResolveHpRegenPerLevel;
}

/// 4 more Upgrades-screen dials, the 3rd page (DECISIONS D-069) — same
/// per-level-multiplier-off-`MetaProgression` shape as Corruption/Haste/
/// Fortune/Resolve above. First-guess placeholders, not tuned on-device.
const double kMagnetPickupRadiusPerLevel = 0.15;
const double kLuckGemDropChancePerLevel = 0.01;
const double kRegenHpPerSecPerLevel = 0.08;
const double kCritChancePerLevel = 0.03;
const double kCritDamageMultiplier = 1.5;

/// Multiplies every pickup's collect radius (gems/potions/chests) — above 1
/// means the player sweeps up loot from further away. +150% at max level.
double magnetPickupRadiusMultiplier(int magnetLevel) {
  return 1 + magnetLevel * kMagnetPickupRadiusPerLevel;
}

/// An additive bonus on top of `economy.dart`'s own `gemDropChance` curve,
/// not a second multiplier — Luck raises the flat odds a kill drops a gem
/// at all, the same axis the base chance already scales on. +10 points at
/// max level.
double luckGemDropBonus(int luckLevel) {
  return luckLevel * kLuckGemDropChancePerLevel;
}

/// A flat HP-regen-per-second bonus, same additive-layer shape as Defence
/// Crystal's/Resolve's own regen bonuses (`resolveHpRegenPerSec` above) —
/// this one is REGEN's own dial, not a duplicate of Resolve's.
double regenHpPerSec(int regenLevel) {
  return regenLevel * kRegenHpPerSecPerLevel;
}

/// Chance the base auto-attack's hit rolls as a critical, dealing
/// [kCritDamageMultiplier]x damage (`ArenaGame.resolveAttackDamage`) — same
/// deliberately narrow "base attack only, not every skill" scope Haste
/// already set for attack speed (see `hasteAttackSpeedMultiplier`'s own
/// doc comment). 30% at max level.
double critChance(int critLevel) {
  return critLevel * kCritChancePerLevel;
}

/// A random point *inside* [visible], inset by [marginFactor] of its own
/// width/height so it doesn't land glued to the very edge (DECISIONS D-049
/// — Ultimate Mirror: "mirrors spawn only on screen where player can see",
/// the opposite requirement from [randomPerimeterPoint] below, which spawns
/// just *outside* what's visible).
Vector2 randomVisiblePoint(
  Random random,
  Rect visible, {
  double marginFactor = 0.1,
}) {
  final insetX = visible.width * marginFactor;
  final insetY = visible.height * marginFactor;
  final left = visible.left + insetX;
  final right = visible.right - insetX;
  final top = visible.top + insetY;
  final bottom = visible.bottom - insetY;
  return Vector2(
    left + random.nextDouble() * (right - left),
    top + random.nextDouble() * (bottom - top),
  );
}

/// Indices of every candidate within [halfWidth] of the line segment from
/// [origin] to `origin + direction.normalized() * maxRange`, and not behind
/// [origin] or past the far end (DECISIONS D-049 — Projectile Ray: a
/// piercing beam hits everything along its line, not just one target like
/// [nearestWithinRange] or one radius like [allWithinRange]). Order
/// preserved, same as [allWithinRange].
List<int> alongLineWithinRange(
  Vector2 origin,
  Vector2 direction,
  List<Vector2> candidates,
  double maxRange,
  double halfWidth,
) {
  final dir = direction.normalized();
  final result = <int>[];
  for (var i = 0; i < candidates.length; i++) {
    final toCandidate = candidates[i] - origin;
    final along = toCandidate.dot(dir);
    if (along < 0 || along > maxRange) continue;
    final perpendicular = (toCandidate - dir * along).length;
    if (perpendicular <= halfWidth) result.add(i);
  }
  return result;
}

/// Pushes a moving circle straight out of a static circular obstacle it's
/// currently overlapping (DECISIONS D-002 — the standing torch: "must have
/// player & enemy collision"). Mutates [position] in place rather than
/// returning a new `Vector2` (CLAUDE.md §4.4's "mutate in place, no
/// per-frame allocation") — cheap enough to run every entity × every live
/// torch, every frame, since only a handful of torches are ever alive at
/// once (`GameConfig.torchCount`). No-op if the circles don't overlap.
void resolveCircleObstacle(
  Vector2 position,
  double entityRadius,
  Vector2 obstacleCenter,
  double obstacleRadius,
) {
  final dx = position.x - obstacleCenter.x;
  final dy = position.y - obstacleCenter.y;
  final minDist = entityRadius + obstacleRadius;
  final distSq = dx * dx + dy * dy;
  if (distSq >= minDist * minDist) return;
  final dist = sqrt(distSq);
  if (dist == 0) {
    // Degenerate (exactly on top of the obstacle's own center) -- push
    // along a fixed axis rather than divide by zero.
    position.setValues(obstacleCenter.x + minDist, obstacleCenter.y);
    return;
  }
  final scale = minDist / dist;
  position.setValues(
    obstacleCenter.x + dx * scale,
    obstacleCenter.y + dy * scale,
  );
}

/// True if [candidate] is at least [minSpacing] away from every point in
/// [existing] (DECISIONS D-002 — `TorchSpawner`/`VaseSpawner` reject a
/// candidate spawn point too close to one of their own already-live
/// siblings, "not too close to each other").
bool farEnoughFrom(Vector2 candidate, List<Vector2> existing, double minSpacing) {
  for (final point in existing) {
    if (candidate.distanceTo(point) < minSpacing) return false;
  }
  return true;
}

/// A random point just outside [visible], by [marginFactor] of its own
/// width/height (DECISIONS D-041/D-042) — shared by `Spawner` (enemies) and
/// the boss's spawn point, so both land just off whatever the player can
/// currently see, wherever that is.
Vector2 randomPerimeterPoint(
  Random random,
  Rect visible, {
  required double marginFactor,
}) {
  final marginX = visible.width * marginFactor;
  final marginY = visible.height * marginFactor;
  final left = visible.left - marginX;
  final right = visible.right + marginX;
  final top = visible.top - marginY;
  final bottom = visible.bottom + marginY;

  final side = random.nextInt(4);
  switch (side) {
    case 0: // top
      return Vector2(left + random.nextDouble() * (right - left), top);
    case 1: // bottom
      return Vector2(left + random.nextDouble() * (right - left), bottom);
    case 2: // left
      return Vector2(left, top + random.nextDouble() * (bottom - top));
    default: // right
      return Vector2(right, top + random.nextDouble() * (bottom - top));
  }
}
