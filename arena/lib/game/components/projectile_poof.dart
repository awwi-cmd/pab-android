import 'dart:ui';

import 'package:flame/components.dart';

/// A generic "poof" despawn flourish (DECISIONS D-053) — shrinks whatever
/// sprite/animation a projectile was showing at the moment it expires from
/// 100% to 0% size while drifting downward, then removes itself. Every
/// projectile type in the game (`ProjectileComponent` — the bolt, Ultimate
/// Mirror's bolts, and the boss's bolt all share it — `KnifeProjectileComponent`,
/// `SpiralFireProjectileComponent`) hands off to one of these when it
/// despawns *without* hitting anything (ran out of range/bounces, or left
/// the screen) instead of just vanishing. Deliberately **not** used on a
/// hit — a hit already has its own feedback
/// (`ArenaGame.onProjectileHit`'s spark + damage number, or Spiral Fire's
/// impact/explosion flourish), so layering this on top there would be
/// noise, not clarity.
///
/// Takes exactly one of [animation] (looping sheets — the bolt, Spiral
/// Fire) or [sprite] (the knife's static clean/bloody image) — whichever
/// the expiring projectile was actually showing, [paint] included, so the
/// poof reads as *that projectile* shrinking away, not a generic stand-in
/// effect.
class ProjectilePoofComponent extends PositionComponent {
  ProjectilePoofComponent({
    required Vector2 startPosition,
    required Vector2 startSize,
    SpriteAnimation? animation,
    Sprite? sprite,
    Paint? paint,
    double angle = 0,
  }) : assert(
         (animation == null) != (sprite == null),
         'pass exactly one of animation or sprite',
       ),
       super(
         position: startPosition,
         size: startSize.clone(),
         angle: angle, // keeps a spinning knife's last orientation, not a snap to 0
         anchor: Anchor.center,
       ) {
    _visual = animation != null
        ? SpriteAnimationComponent(
            animation: animation,
            size: size.clone(),
            anchor: Anchor.center,
            paint: paint,
          )
        : SpriteComponent(
            sprite: sprite,
            size: size.clone(),
            anchor: Anchor.center,
            paint: paint,
          );
    add(_visual);
  }

  static const _durationSec = 0.35;
  static const _dropSpeedPxPerS = 40.0;

  // `late` -- deferred to first use in update(), by which point `size` (set
  // by the super() call above) is already the real starting size, not the
  // zero-vector PositionComponent briefly starts with mid-construction.
  late final Vector2 _startSize = size.clone();
  late final PositionComponent _visual;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    final t = (_elapsed / _durationSec).clamp(0.0, 1.0);
    size
      ..x = _startSize.x * (1 - t)
      ..y = _startSize.y * (1 - t);
    _visual.size.setFrom(size); // the child doesn't auto-track the parent's size
    position.y += _dropSpeedPxPerS * dt;
    if (t >= 1.0) removeFromParent();
  }
}
