import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../arena_game.dart';
import 'damageable.dart';

/// Straight-line, constant speed, one enemy per projectile, no pierce, no
/// homing/leading (PRD §6.3 / DECISIONS D-005). Also the boss's bolt
/// (DECISIONS D-042) via [tint] — same shape, sprite recoloured green
/// rather than a whole second component class.
class ProjectileComponent extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  ProjectileComponent({
    required Vector2 startPosition,
    required Vector2 direction,
    required this.damage,
    required this.knockback,
    required this.speedPxPerS,
    required this.maxRangePx,
    required SpriteAnimation animation,
    Color? tint,
    this.excludeSelf,
  }) : _direction = direction.normalized(),
       super(
         animation: animation,
         position: startPosition,
         size: Vector2.all(16 * kProjectileRenderScale),
         anchor: Anchor.center,
         paint: Paint()
           ..filterQuality = FilterQuality.none // D-011
           ..colorFilter = tint == null
               ? null
               : ColorFilter.mode(tint, BlendMode.srcIn),
         priority: ArenaPriority.projectile,
       );

  final double damage;
  final double knockback;
  final double speedPxPerS;
  final double maxRangePx;
  final Vector2 _direction;
  // The boss fires this same component at itself, position-wise, at spawn
  // (`BossComponent._fire` starts the bolt at `position.clone()`, and the
  // boss is itself in `game.damageableTargets`) -- without this, the very
  // first update() call after spawn found the boss "touching" its own bolt
  // at distance 0 and destroyed it before it ever traveled anywhere,
  // reported on-device as "boss does the animation but I never see a
  // projectile" (2026-09-09).
  final Damageable? excludeSelf;

  double _traveled = 0;
  final Vector2 _scratch = Vector2.zero(); // reused every frame

  @override
  void update(double dt) {
    super.update(dt);

    final step = speedPxPerS * dt;
    _scratch
      ..setFrom(_direction)
      ..scale(step);
    position.add(_scratch);
    _traveled += step;

    if (_traveled >= maxRangePx || _outOfBounds()) {
      removeFromParent();
      return;
    }

    final targets = game.damageableTargets;
    Damageable? hit;
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      if (identical(target, excludeSelf)) continue;
      if (target.isDying) continue; // already dead, let the shot pass through
      final touching = position.distanceTo(target.position) <
          (size.x / 2 + target.size.x / 2);
      if (touching) {
        hit = target;
        break;
      }
    }

    if (hit != null) {
      // Resolve the hit only after the search loop ends -- takeDamage() can
      // remove `hit` from game.enemies, which must not happen mid-iteration.
      hit.applyKnockback(_direction, knockback);
      hit.takeDamage(damage);
      game.onProjectileHit(position.clone(), damage);
      removeFromParent();
    }
  }

  /// Off the camera's current view (DECISIONS D-040) — not a fixed
  /// `0..game.size` rect, which only ever meant "off screen" back when the
  /// camera was pinned to the world origin (D-007). Since the camera now
  /// follows the player anywhere in the world, "on screen" has to be
  /// computed relative to wherever the camera actually is right now.
  bool _outOfBounds() {
    return !game.camera.visibleWorldRect.contains(position.toOffset());
  }
}
