import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../arena_game.dart';
import 'enemy.dart';

/// The Bruiser's knife (DECISIONS D-029): straight-line, constant speed,
/// same as [ProjectileComponent] except it **pierces** — it keeps flying and
/// damaging every enemy it touches instead of despawning on the first hit —
/// and its sprite flips from clean to bloody the moment it draws blood.
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
    required this.maxRangePx,
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
  final double maxRangePx;
  final Sprite bloodySprite;
  final Vector2 _direction;

  // Cosmetic spin, not a stat. 14.0 base +10% tune (2026-09-08).
  static const _rotationSpeedRadPerSec = 15.4;

  double _traveled = 0;
  final Vector2 _scratch = Vector2.zero(); // reused every frame
  final Set<EnemyComponent> _hitEnemies = {};
  bool _bloodied = false;

  @override
  void update(double dt) {
    super.update(dt);

    final step = speedPxPerS * dt;
    _scratch
      ..setFrom(_direction)
      ..scale(step);
    position.add(_scratch);
    _traveled += step;
    angle += _rotationSpeedRadPerSec * dt;

    if (_traveled >= maxRangePx || _outOfBounds()) {
      removeFromParent();
      return;
    }

    // Snapshot first -- takeDamage() can remove an enemy from game.enemies,
    // which must not happen mid-iteration (same rule as ProjectileComponent).
    final touching = <EnemyComponent>[];
    for (final enemy in List<EnemyComponent>.of(game.enemies)) {
      if (enemy.isDying || _hitEnemies.contains(enemy)) continue;
      final isTouching = position.distanceTo(enemy.position) <
          (size.x / 2 + enemy.size.x / 2);
      if (isTouching) touching.add(enemy);
    }

    for (final enemy in touching) {
      _hitEnemies.add(enemy);
      enemy.applyKnockback(_direction, knockback);
      enemy.takeDamage(damage);
      game.onProjectileHit(enemy.position.clone(), damage);
    }

    if (touching.isNotEmpty && !_bloodied) {
      _bloodied = true;
      sprite = bloodySprite;
    }
  }

  bool _outOfBounds() {
    final worldSize = game.size;
    return position.x < 0 ||
        position.y < 0 ||
        position.x > worldSize.x ||
        position.y > worldSize.y;
  }
}
