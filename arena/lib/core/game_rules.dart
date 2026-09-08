import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flame/game.dart' show Vector2;

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
int nearestWithinRange(Vector2 from, List<Vector2> candidates, double maxRange) {
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
List<int> allWithinRange(Vector2 from, List<Vector2> candidates, double maxRange) {
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
const double kEnemyScalePerLevel = 0.12;

double enemyStatMultiplier(int playerLevel) {
  assert(playerLevel >= 1);
  return 1 + (playerLevel - 1) * kEnemyScalePerLevel;
}

/// DECISIONS D-035: "elite" enemies are a visual-only marker for now (a fire
/// glow, `ArenaGame.spawnEnemy`) — no stat change, unlike `enemyStatMultiplier`
/// above. Rolled independently per spawn, not tied to player level.
const double kEliteChance = 0.15;

bool rollIsElite(Random random) => random.nextDouble() < kEliteChance;

/// DECISIONS D-042: the boss gets ~20% stronger each time it spawns
/// (levels 3, 6, 9 — `spawnIndex` 0/1/2), compounding rather than flat, so
/// the 3rd fight is noticeably tougher than "just" +40% over the 1st.
const double kBossScalePerSpawn = 0.2;

double bossStatMultiplier(int spawnIndex) {
  assert(spawnIndex >= 0);
  return pow(1 + kBossScalePerSpawn, spawnIndex).toDouble();
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
