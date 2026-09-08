import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../arena_game.dart';
import 'enemy.dart';

/// One half of the Skirmisher's Spiral Fire skill (DECISIONS D-034): two of
/// these are always launched together, [phase] apart by pi radians, so they
/// orbit a shared advancing center point on opposite sides of it — a
/// yin-yang pair rather than two independent shots. The orbit radius shrinks
/// to 0 as the projectile nears [targetPoint], so the pair visually converges
/// right as it arrives instead of still circling on impact.
///
/// Aimed at [targetPoint] once at launch, not homing (matches
/// [ProjectileComponent]'s "no leading/homing" rule, DECISIONS D-005) —
/// single-target hit, despawns on the first enemy it touches (not piercing,
/// unlike the Bruiser's knife).
class SpiralFireProjectileComponent extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  SpiralFireProjectileComponent({
    required Vector2 startPosition,
    required Vector2 targetPoint,
    required this.damage,
    required this.knockback,
    required this.speedPxPerS,
    required double phase,
    required SpriteAnimation animation,
  }) : _start = startPosition.clone(),
       _direction = (targetPoint - startPosition).normalized(),
       // 90-degree rotation of the same direction, for the orbit's
       // sideways axis (construction-time only, cheap to recompute here).
       _perpendicular = (targetPoint - startPosition)
           .normalized()
           .scaleOrthogonalInto(1, Vector2.zero()),
       _totalDistance = (targetPoint - startPosition).length,
       _angle = phase,
       super(
         animation: animation,
         position: startPosition,
         size: Vector2(kPixelFireWidthPx, kPixelFireWidthPx * kPixelFireAspect),
         anchor: Anchor.center,
         paint: Paint()..filterQuality = FilterQuality.none, // D-011
         priority: ArenaPriority.projectile,
       );

  final double damage;
  final double knockback;
  final double speedPxPerS;

  final Vector2 _start;
  final Vector2 _direction;
  final Vector2 _perpendicular;
  final double _totalDistance;

  static const _orbitRadiusPx = 24.0; // first guess, not tuned on-device yet
  // 2026-09-09 tune: -30% vs. the original 10.0 first guess.
  static const _spinSpeedRadPerSec = 7.0;

  double _traveled = 0;
  double _angle;
  final Vector2 _scratch = Vector2.zero(); // reused every frame

  @override
  void update(double dt) {
    super.update(dt);

    _traveled += speedPxPerS * dt;
    _angle += _spinSpeedRadPerSec * dt;

    // No out-of-bounds check here (unlike ProjectileComponent/
    // KnifeProjectileComponent, which travel indefinitely-ish and need one
    // as a backstop) -- _traveled is already a hard, exact cap tied to the
    // real distance to targetPoint, so this always terminates on schedule
    // regardless of on-screen position. Bounds-checking `position` directly
    // was a real bug: the orbit wobble (+/- _orbitRadiusPx sideways) could
    // briefly push it past a screen edge near the end of a long-range shot,
    // despawning it before it ever reached the target.
    if (_traveled >= _totalDistance) {
      removeFromParent();
      return;
    }

    // Orbit radius shrinks to 0 right as the projectile reaches its target
    // point -- the spiral converges instead of still circling on arrival.
    final progress = (_totalDistance == 0) ? 1.0 : _traveled / _totalDistance;
    final radius = _orbitRadiusPx * (1 - progress);

    // position = start + direction*(traveled + radius*sin(angle)) +
    //            perpendicular*(radius*cos(angle)) -- built via the shared
    //            scratch vector (no per-frame Vector2 allocation, CLAUDE.md
    //            §4.4) instead of Vector2's +/* operators.
    position.setFrom(_start);
    _scratch
      ..setFrom(_direction)
      ..scale(_traveled + radius * sin(_angle));
    position.add(_scratch);
    _scratch
      ..setFrom(_perpendicular)
      ..scale(radius * cos(_angle));
    position.add(_scratch);
    angle = _angle; // the sprite itself tumbles in sync with the orbit

    final enemies = game.enemies;
    EnemyComponent? hit;
    for (var i = 0; i < enemies.length; i++) {
      final enemy = enemies[i];
      if (enemy.isDying) continue;
      final touching = position.distanceTo(enemy.position) <
          (size.x / 2 + enemy.size.x / 2);
      if (touching) {
        hit = enemy;
        break;
      }
    }

    if (hit != null) {
      hit.applyKnockback(_direction, knockback);
      hit.takeDamage(damage);
      game.onProjectileHit(hit.position.clone(), damage);
      // hit.isDying is true iff this hit was the killing blow (EnemyComponent
      // sets it synchronously inside takeDamage) -- explosion for a kill,
      // a smaller impact flash otherwise.
      if (hit.isDying) {
        game.spawnExplosionEffect(hit.position.clone());
      } else {
        game.spawnImpactEffect(hit.position.clone());
      }
      removeFromParent();
    }
  }
}
