import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../arena_game.dart';
import 'damageable.dart';
import 'projectile_poof.dart';

/// The Bruiser's knife (DECISIONS D-029): straight-line, constant speed,
/// same as [ProjectileComponent] except it **pierces** — it keeps flying and
/// damaging every enemy it touches instead of despawning on the first hit —
/// and its sprite flips from clean to bloody the moment it draws blood.
/// Unlike [ProjectileComponent] it has no max-range despawn at all (D-030) —
/// it flies until it leaves the arena, full stop.
///
/// Each enemy can only be hit once per throw ([_hitEnemies]), so hovering
/// near an already-hit enemy doesn't tick damage every frame.
class KnifeProjectileComponent extends SpriteComponent
    with HasGameReference<ArenaGame> {
  KnifeProjectileComponent({
    required Vector2 startPosition,
    required Vector2 direction,
    required this.damage,
    required this.knockback,
    required this.speedPxPerS,
    required this.bloodySprite,
    required Sprite cleanSprite,
  }) : _direction = direction.normalized(),
       super(
         sprite: cleanSprite,
         position: startPosition,
         size: Vector2.all(32 * kKnifeRenderScale),
         anchor: Anchor.center,
         paint: Paint()..filterQuality = FilterQuality.none, // D-011
         priority: ArenaPriority.projectile,
       );

  final double damage;
  final double knockback;
  final double speedPxPerS;
  final Sprite bloodySprite;
  final Vector2 _direction;

  // Cosmetic spin, not a stat. 14.0 base +10% tune (2026-09-08).
  static const _rotationSpeedRadPerSec = 15.4;

  final Vector2 _scratch = Vector2.zero(); // reused every frame
  final Set<Damageable> _hitEnemies = {};
  bool _bloodied = false;

  @override
  void update(double dt) {
    super.update(dt);

    final step = speedPxPerS * dt;
    _scratch
      ..setFrom(_direction)
      ..scale(step);
    position.add(_scratch);
    angle += _rotationSpeedRadPerSec * dt;

    if (_outOfBounds()) {
      _expire();
      return;
    }

    // Snapshot first -- takeDamage() can remove a target from
    // game.damageableTargets, which must not happen mid-iteration (same
    // rule as ProjectileComponent).
    final touching = <Damageable>[];
    for (final target in List<Damageable>.of(game.damageableTargets)) {
      if (target.isDying || _hitEnemies.contains(target)) continue;
      final isTouching = position.distanceTo(target.position) <
          (size.x / 2 + target.size.x / 2);
      if (isTouching) touching.add(target);
    }

    for (final target in touching) {
      _hitEnemies.add(target);
      target.applyKnockback(_direction, knockback);
      target.takeDamage(damage);
      game.onProjectileHit(target.position.clone(), damage);
    }

    if (touching.isNotEmpty && !_bloodied) {
      _bloodied = true;
      sprite = bloodySprite;
    }
  }

  /// Off the camera's current view, not a fixed `0..game.size` rect
  /// (DECISIONS D-040 — the world/camera can move now; see the identical
  /// note on `ProjectileComponent._outOfBounds`). This one matters more
  /// than the bolt's: since D-030 this is the knife's *only* despawn
  /// condition, so getting it wrong means every knife thrown more than a
  /// screen's width from the world origin would vanish on its first frame.
  ///
  /// Inflated by [kProjectileDespawnMarginFactor] times the knife's own
  /// width (DECISIONS D-061, developer's call: "knives spawn [the poof]
  /// right when they hit the outside border") — the knife has no bounce to
  /// wait for like a boss/mirror bolt does, so this margin is the only
  /// thing standing between "despawns at the bare edge, still half
  /// visible" and "actually gone off-screen first."
  bool _outOfBounds() {
    return !game.camera.visibleWorldRect
        .inflate(size.x * kProjectileDespawnMarginFactor)
        .contains(position.toOffset());
  }

  /// Left the screen without ever piercing anything on this exact frame
  /// (or its last pierce already happened earlier in its flight) —
  /// DECISIONS D-053. Whichever sprite it was showing (clean or bloody,
  /// [_bloodied]) is what the poof shrinks away.
  void _expire() {
    game.addToWorld(
      ProjectilePoofComponent(
        startPosition: position.clone(),
        startSize: size.clone(),
        sprite: sprite,
        paint: paint,
        angle: angle,
      ),
    );
    removeFromParent();
  }
}
