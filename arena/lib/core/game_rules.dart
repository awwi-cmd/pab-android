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
