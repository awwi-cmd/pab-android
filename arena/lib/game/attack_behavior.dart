import 'dart:math';

import 'package:flame/components.dart' show Vector2;

import '../core/game_rules.dart';
import '../core/progression.dart';
import '../core/stats.dart';
import 'arena_game.dart';
import 'components/knife_projectile.dart';
import 'components/projectile.dart';
import 'components/spiral_fire_projectile.dart';

/// How a `CharacterDef` attacks (DECISIONS D-024). `ArenaGame` owns the
/// cooldown timer (round state stays on `ArenaGame`, CLAUDE.md §4.5) and
/// calls [perform] once it elapses; behaviors are stateless so they can be
/// `const` and shared across `CharacterDef`s without leaking state between
/// rounds.
///
/// The demo only ships [ProjectileAttack]. This exists as an extension
/// point so a melee or otherwise different character (D-005 already flags
/// that the ranged stat formulas won't fit one) is a new class here, not a
/// rewrite of `ArenaGame`.
abstract class AttackBehavior {
  const AttackBehavior();

  /// Seconds between attacks, given this character's current stats.
  double cooldownSeconds(StatBlock stats);

  /// Called once the cooldown elapses. Whatever this does — spawn a
  /// projectile, start a melee swing — it's responsible for its own
  /// "nothing to attack" no-op case.
  void perform(ArenaGame game);
}

/// The only attack in the demo: fires one projectile at the nearest enemy
/// in range, straight line, no leading/homing, one target per shot
/// (PRD §6.2-§6.3, DECISIONS D-005).
class ProjectileAttack extends AttackBehavior {
  const ProjectileAttack();

  @override
  double cooldownSeconds(StatBlock stats) => 1 / stats.attacksPerSec;

  @override
  void perform(ArenaGame game) {
    final stats = game.character.stats;
    final player = game.player;

    final positions = [for (final enemy in game.enemies) enemy.position];
    final index = nearestWithinRange(
      player.position,
      positions,
      stats.attackRangePx,
    );
    if (index == -1) return;
    final target = game.enemies[index];

    final direction = target.position - player.position;
    if (direction.length2 == 0) return; // exactly on top of the target
    direction.normalize();

    game.add(
      ProjectileComponent(
        startPosition: player.position.clone(),
        direction: direction,
        damage: stats.damagePerHit + game.upgrades.bonusDamage,
        knockback: stats.knockbackImpulse,
        speedPxPerS: stats.projSpeedPxPerS,
        maxRangePx: stats.attackRangePx * 1.5,
        animation: game.boltAnimation,
      ),
    );
    player.playFire();
  }
}

/// The Bruiser's kit (DECISIONS D-029/D-030/D-031): a spinning knife thrown
/// at the nearest enemy in range, same targeting as [ProjectileAttack] but
/// it pierces through every enemy in its path instead of stopping at the
/// first one, flies until it leaves the arena (no max-range despawn), and
/// its sprite turns bloody the moment it draws blood. Reuses
/// [ProjectileAttack]'s cooldown formula as a base, then applies its own
/// multipliers on top (see the fields below) — pierce is the core
/// differentiator, the multipliers are tuning.
///
/// `knifeMastery` (Bruiser-only, DECISIONS D-031) changes the throw itself
/// once picked: level 1 is a flat damage buff on the single knife, level 2
/// adds a second knife thrown behind the player, level 3 throws 4 at once
/// (one to every side). All of them still originate from the one target
/// lookup below — the extra knives are geometric offsets from that
/// direction, not separate targeting.
class KnifeAttack extends AttackBehavior {
  const KnifeAttack();

  /// 2026-09-08 tune: -30% vs. the shared per-hit formula, to offset
  /// pierce hitting multiple enemies per throw.
  static const _damageMultiplier = 0.7;

  /// 2026-09-09 tune: -30% attack speed (i.e. the cooldown is longer) to
  /// offset the knife no longer despawning on its own and hitting harder
  /// per stray hit than a single-target bolt would.
  static const _attackSpeedMultiplier = 0.7;

  /// 2026-09-09 tune: +15% targeting range vs. the shared formula — the
  /// knife flies until it leaves the screen now (D-030), so it can afford
  /// to pick fights a bit further out.
  static const _rangeMultiplier = 1.15;

  @override
  double cooldownSeconds(StatBlock stats) =>
      (1 / stats.attacksPerSec) / _attackSpeedMultiplier;

  @override
  void perform(ArenaGame game) {
    final stats = game.character.stats;
    final player = game.player;

    final positions = [for (final enemy in game.enemies) enemy.position];
    final index = nearestWithinRange(
      player.position,
      positions,
      stats.attackRangePx * _rangeMultiplier,
    );
    if (index == -1) return;
    final target = game.enemies[index];

    final direction = target.position - player.position;
    if (direction.length2 == 0) return; // exactly on top of the target
    direction.normalize();

    final knifeLevel = game.upgrades.pickCounts[UpgradeKind.knifeMastery] ?? 0;
    final damage = (stats.damagePerHit + game.upgrades.bonusDamage) *
        _damageMultiplier *
        (knifeLevel >= 1 ? UpgradeAmounts.knifeMasteryTier1DamageMultiplier : 1);

    for (final angleOffset in _throwAngleOffsets(knifeLevel)) {
      game.add(
        KnifeProjectileComponent(
          startPosition: player.position.clone(),
          direction: _rotated(direction, angleOffset),
          damage: damage,
          knockback: stats.knockbackImpulse,
          speedPxPerS: stats.projSpeedPxPerS,
          cleanSprite: game.knifeCleanSprite,
          bloodySprite: game.knifeBloodySprite,
        ),
      );
    }
    player.playFire();
  }

  /// Radian offsets from the forward (targeted) direction for the knives
  /// thrown this cycle, keyed by `knifeMastery` level (DECISIONS D-031):
  /// level < 2 is just the one forward knife, level 2 adds one thrown
  /// behind, level 3 is all 4 cardinal offsets from the forward direction
  /// (front/back/left/right relative to the throw, not the world).
  static List<double> _throwAngleOffsets(int knifeLevel) {
    if (knifeLevel >= 3) return [0, pi / 2, pi, -pi / 2];
    if (knifeLevel == 2) return [0, pi];
    return [0];
  }

  static Vector2 _rotated(Vector2 v, double angleRad) {
    if (angleRad == 0) return v.clone();
    final cosA = cos(angleRad);
    final sinA = sin(angleRad);
    return Vector2(v.x * cosA - v.y * sinA, v.x * sinA + v.y * cosA);
  }
}

/// The Skirmisher's kit (DECISIONS D-034): "Spiral Fire" — two
/// `SpiralFireProjectileComponent`s launched together at the nearest enemy
/// in range (pi radians of orbit phase apart, so they spiral around each
/// other like a yin-yang pair converging on the target), plus a cast
/// sparkle on the caster's own body (`ArenaGame.spawnCastSparkle`). Same
/// targeting/cooldown formula as [ProjectileAttack]; unlike it, two shots go
/// out per cast instead of one — full per-hit damage each, not halved, so
/// this hits harder than a single bolt in exchange for however that first
/// on-device pass reads (no tune pass yet, unlike the knife which took two).
class SpiralFireAttack extends AttackBehavior {
  const SpiralFireAttack();

  @override
  double cooldownSeconds(StatBlock stats) => 1 / stats.attacksPerSec;

  @override
  void perform(ArenaGame game) {
    final stats = game.character.stats;
    final player = game.player;

    final positions = [for (final enemy in game.enemies) enemy.position];
    final index = nearestWithinRange(
      player.position,
      positions,
      stats.attackRangePx,
    );
    if (index == -1) return;
    final target = game.enemies[index];

    if ((target.position - player.position).length2 == 0) {
      return; // exactly on top of the target
    }

    final damage = stats.damagePerHit + game.upgrades.bonusDamage;
    for (final phase in [0.0, pi]) {
      game.add(
        SpiralFireProjectileComponent(
          startPosition: player.position.clone(),
          targetPoint: target.position.clone(),
          damage: damage,
          knockback: stats.knockbackImpulse,
          speedPxPerS: stats.projSpeedPxPerS,
          phase: phase,
          animation: game.pixelFireAnimation,
        ),
      );
    }
    game.spawnCastSparkle(player);
    player.playFire();
  }
}
