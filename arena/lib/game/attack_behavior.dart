import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart' show Vector2;

import '../core/constants.dart';
import '../core/game_rules.dart';
import '../core/progression.dart';
import '../core/stats.dart';
import 'arena_game.dart';
import 'components/knife_projectile.dart';
import 'components/projectile.dart';
import 'components/spiral_fire_projectile.dart';
import 'components/tracking_effect.dart';

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

  /// Called once when this becomes the active character's kit for the
  /// round (`ArenaGame.resetRound`, right after the player is created) —
  /// the hook for any persistent per-kit visual/setup that isn't tied to a
  /// single [perform] call (DECISIONS D-036: `SpiralFireAttack`'s always-on
  /// cast sparkle is the first user). Default no-op; override only if the
  /// kit needs one. Kept here rather than an `if (character.id == ...)` in
  /// `ArenaGame` (CLAUDE.md §4.12).
  void onEquipped(ArenaGame game) {}
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
    final stats = game.effectiveStats;
    final player = game.player;

    final targets = game.damageableTargets;
    final positions = [for (final t in targets) t.position];
    final index = nearestWithinRange(
      player.position,
      positions,
      stats.attackRangePx,
    );
    if (index == -1) return;
    final target = targets[index];

    final direction = target.position - player.position;
    if (direction.length2 == 0) return; // exactly on top of the target
    direction.normalize();

    game.addToWorld(
      ProjectileComponent(
        startPosition: player.position.clone(),
        direction: direction,
        damage: game.resolveAttackDamage(
          stats.damagePerHit + game.upgrades.bonusDamage,
        ),
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
    final stats = game.effectiveStats;
    final player = game.player;

    final targets = game.damageableTargets;
    final positions = [for (final t in targets) t.position];
    final index = nearestWithinRange(
      player.position,
      positions,
      stats.attackRangePx * _rangeMultiplier,
    );
    if (index == -1) return;
    final target = targets[index];

    final direction = target.position - player.position;
    if (direction.length2 == 0) return; // exactly on top of the target
    direction.normalize();

    final knifeLevel = game.upgrades.pickCounts[UpgradeKind.knifeMastery] ?? 0;
    final damage = game.resolveAttackDamage(
      (stats.damagePerHit + game.upgrades.bonusDamage) *
          _damageMultiplier *
          (knifeLevel >= 1
              ? UpgradeAmounts.knifeMasteryTier1DamageMultiplier
              : 1),
    );

    for (final angleOffset in _throwAngleOffsets(knifeLevel)) {
      game.addToWorld(
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

/// The Skirmisher's kit (DECISIONS D-034/D-037): "Spiral Fire" — two
/// `SpiralFireProjectileComponent`s launched together at the nearest enemy
/// in range (pi radians of orbit phase apart, so they spiral around each
/// other like a yin-yang pair converging on the target), plus a permanent
/// cast-sparkle visual on the caster's own body (D-036, [onEquipped] below)
/// that's on for the whole round, not just while casting. Same cooldown
/// formula as [ProjectileAttack]; targeting range and per-hit damage each
/// get their own multiplier (see the fields below) rather than reusing the
/// shared formula as-is, same pattern as [KnifeAttack]'s tuning fields.
class SpiralFireAttack extends AttackBehavior {
  const SpiralFireAttack();

  /// 2026-09-09 tune: +40% targeting range vs. the shared formula.
  static const _rangeMultiplier = 1.4;

  /// 2026-09-09 tune: -40% vs. the shared per-hit formula, to offset two
  /// full shots going out per cast instead of one.
  static const _damageMultiplier = 0.6;

  @override
  double cooldownSeconds(StatBlock stats) => 1 / stats.attacksPerSec;

  @override
  void onEquipped(ArenaGame game) {
    // Always-on for the round (DECISIONS D-036) -- not spawned per cast
    // anymore, so it's visible at all times rather than flashing only when
    // the Skirmisher actually fires.
    final player = game.player;
    final width = player.size.x * kSparkleWidthFactor;
    game.addToWorld(
      TrackingSpriteEffect(
        target: player,
        animation: game.sparkleAnimation,
        size: Vector2(width, width * kSparkleAspect),
        priority: ArenaPriority.groundEffects, // behind the caster
        paint: Paint()
          ..filterQuality = FilterQuality.none // D-011
          ..color = const Color.fromRGBO(255, 255, 255, kSparkleOpacity),
      ),
    );
  }

  @override
  void perform(ArenaGame game) {
    final stats = game.effectiveStats;
    final player = game.player;

    final targets = game.damageableTargets;
    final positions = [for (final t in targets) t.position];
    final index = nearestWithinRange(
      player.position,
      positions,
      stats.attackRangePx * _rangeMultiplier,
    );
    if (index == -1) return;
    final target = targets[index];

    if ((target.position - player.position).length2 == 0) {
      return; // exactly on top of the target
    }

    final damage = game.resolveAttackDamage(
      (stats.damagePerHit + game.upgrades.bonusDamage) * _damageMultiplier,
    );
    for (final phase in [0.0, pi]) {
      game.addToWorld(
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
    player.playFire();
  }
}

/// The Warden's kit (TASKS 8.3, DECISIONS D-056): "Ground Slam" — no new art,
/// built from what the character sheet + shared VFX already had. Unlike
/// every other kit here it isn't a projectile at all: a short-range AoE hit
/// centered on the player, damaging and knocking back every
/// [Damageable] caught inside the radius (same [allWithinRange] shape
/// `AuraComponent` uses for its tick, but a single instant burst on the
/// normal attack-cooldown loop instead of a DOT). Fits the VIT-heavy stat
/// line (`kCharacters`'s Warden: 9 VIT) — trades the ranged cast every other
/// kit gets for standing in the middle of a cluster and hitting all of it at
/// once, with a bigger shove than a single-target hit would apply.
///
/// Visual reuses `fire` (already loaded for every character, DECISIONS
/// D-024) for the windup/swing and the existing `explosionAnimation`
/// (`vfx/vfx/effect_explosion2.png`, DECISIONS D-034) sized to the hit
/// radius itself for the slam's shockwave — same "derive the VFX size from
/// the actual gameplay radius" approach `AuraComponent` already uses,
/// rather than a fixed width constant that could drift out of sync with the
/// real hitbox.
class WardenSlamAttack extends AttackBehavior {
  const WardenSlamAttack();

  /// Melee, not ranged (DECISIONS D-056) -- a fraction of the shared
  /// attackRangePx formula, same "own multiplier on the shared base" pattern
  /// [KnifeAttack]/[SpiralFireAttack] use.
  static const _rangeMultiplier = 0.35;

  /// -25% attack speed vs. the shared formula (tankier: hits less often,
  /// but every hit is a multi-target burst with knockback attached).
  static const _attackSpeedMultiplier = 0.75;

  /// -15% per-hit damage vs. the shared formula, to offset it landing on
  /// every enemy in the radius at once rather than just the nearest one.
  static const _damageMultiplier = 0.85;

  /// +50% knockback -- the Warden shoving a cluster of enemies back is the
  /// whole point of a VIT-heavy melee tank.
  static const _knockbackMultiplier = 1.5;

  @override
  double cooldownSeconds(StatBlock stats) =>
      (1 / stats.attacksPerSec) / _attackSpeedMultiplier;

  @override
  void perform(ArenaGame game) {
    final stats = game.effectiveStats;
    final player = game.player;
    final radiusPx = stats.attackRangePx * _rangeMultiplier;

    final targets = game.damageableTargets;
    final positions = [for (final t in targets) t.position];
    final hitIndices = allWithinRange(player.position, positions, radiusPx);
    if (hitIndices.isEmpty) return; // nothing in range -- no swing

    final damage = game.resolveAttackDamage(
      (stats.damagePerHit + game.upgrades.bonusDamage) * _damageMultiplier,
    );
    final knockback = stats.knockbackImpulse * _knockbackMultiplier;
    for (final index in hitIndices) {
      final target = targets[index];
      if (target.isDying) continue;
      final direction = target.position - player.position;
      // Radially outward from the player; on-top-of-player targets just
      // skip the knockback rather than dividing by a zero-length vector.
      if (direction.length2 > 0) {
        direction.normalize();
        target.applyKnockback(direction, knockback);
      }
      target.takeDamage(damage);
      game.onProjectileHit(target.position.clone(), damage);
    }

    game.spawnEffect(
      game.gameAssets.explosionAnimation,
      player.position.clone(),
      size: Vector2.all(radiusPx * 2),
    );
    player.playFire();
  }
}
