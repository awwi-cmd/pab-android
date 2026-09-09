import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../arena_game.dart';
import 'damageable.dart';
import 'projectile_poof.dart';

/// One half of the Skirmisher's Spiral Fire skill (DECISIONS D-034/D-039):
/// two of these are always launched together, [phase] apart by pi radians,
/// so they orbit a shared advancing center point on opposite sides of it —
/// a yin-yang pair rather than two independent shots. The orbit radius
/// shrinks to 0 right as the projectile reaches [targetPoint] (converging
/// instead of still circling), then it keeps flying dead straight — like
/// the Bruiser's knife (D-030), it never despawns on its own; the only exit
/// is hitting an enemy or leaving the arena.
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

    if (_outOfBounds()) {
      _expire();
      return;
    }

    // Orbit radius shrinks to 0 right as the projectile reaches its target
    // point, then stays 0 (progress clamped at 1) for the rest of the
    // flight -- the spiral converges once, then it's just a straight shot
    // continuing on toward the screen edge (DECISIONS D-039).
    final progress = (_totalDistance == 0)
        ? 1.0
        : (_traveled / _totalDistance).clamp(0.0, 1.0);
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

    final targets = game.damageableTargets;
    Damageable? hit;
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      if (target.isDying) continue;
      final touching = position.distanceTo(target.position) <
          (size.x / 2 + target.size.x / 2);
      if (touching) {
        hit = target;
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

  /// Margin past the true edge of what's visible before this counts as
  /// "gone" — [_orbitRadiusPx] so the orbit's own sideways wobble alone can
  /// never trip an early despawn near the target/edge (the exact bug D-038
  /// fixed a different way, before this component grew its own
  /// out-of-bounds check back for the "fly to the edge" requirement), plus
  /// [kProjectileDespawnMarginFactor] times this projectile's own width
  /// (DECISIONS D-061, developer's call: despawn only once "way out outside
  /// of screen", not the instant it crosses the bare edge).
  static const _boundsMargin = _orbitRadiusPx;

  /// Off the camera's current view, not a fixed `0..game.size` rect
  /// (DECISIONS D-040 — see the identical note on
  /// `ProjectileComponent._outOfBounds`).
  bool _outOfBounds() {
    final visible = game.camera.visibleWorldRect
        .inflate(_boundsMargin + size.x * kProjectileDespawnMarginFactor);
    return !visible.contains(position.toOffset());
  }

  /// Left the screen without ever converging on a target — DECISIONS
  /// D-053. A hit ends this component a different way entirely (the
  /// `removeFromParent()` right after `spawnExplosionEffect`/
  /// `spawnImpactEffect` above), so this only ever fires for the
  /// out-of-bounds case.
  void _expire() {
    game.addToWorld(
      ProjectilePoofComponent(
        startPosition: position.clone(),
        startSize: size.clone(),
        animation: animation,
        paint: paint,
        angle: angle,
      ),
    );
    removeFromParent();
  }
}
