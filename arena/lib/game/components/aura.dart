import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/game_rules.dart';
import '../../core/progression.dart';
import '../arena_game.dart';

/// The Aura skill (DECISIONS D-027) — a ring of `projectile-spark.png`
/// copies orbiting the player, ticking damage to everything caught inside
/// [_radiusPx] every `UpgradeAmounts.auraTickIntervalSec`. Built from the
/// existing hit-spark sheet rather than new art: it's a left-to-right
/// flash animation (DECISIONS D-015), not a ring, so the ring comes from
/// placing several copies of it around a circle and rotating the whole
/// group — not from the sprite itself being circular.
///
/// Spawned once by `ArenaGame` on the first Aura pick and left alone after
/// that (DECISIONS D-025 pattern: `ArenaGame` owns round state, this
/// component just reads the current stack count every tick rather than
/// being rebuilt per pick) — damage scales with
/// `upgrades.pickCounts[UpgradeKind.aura]`, capped at
/// `UpgradeAmounts.auraMaxStacks` by `rollUpgradeChoices` refusing to offer
/// it again past that.
class AuraComponent extends PositionComponent with HasGameReference<ArenaGame> {
  AuraComponent({required SpriteAnimation sparkAnimation})
    : super(anchor: Anchor.center, priority: ArenaPriority.hitEffects) {
    // Traces the exact damage radius `_dealDamage` checks against, not just
    // a decorative guess -- the orbiting sparks alone don't communicate
    // where the boundary actually is (developer ask: "check hitbox
    // location"). Outline only, so it doesn't obscure enemies underneath.
    add(
      CircleComponent(
        radius: _radiusPx,
        anchor: Anchor.center,
        paint: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x806CE0B8), // ArenaColors.accent @ ~50%
      ),
    );
    for (var i = 0; i < _sparkCount; i++) {
      final theta = (i / _sparkCount) * 2 * pi;
      add(
        SpriteAnimationComponent(
          animation: sparkAnimation,
          size: Vector2.all(16 * kProjectileRenderScale),
          anchor: Anchor.center,
          position: Vector2(cos(theta), sin(theta)) * _radiusPx,
          paint: Paint()..filterQuality = FilterQuality.none, // D-011
        ),
      );
    }
  }

  static const _sparkCount = 6;
  static const _radiusPx = UpgradeAmounts.auraRadiusPx;
  static const _rotationSpeedRadPerSec = 1.4;

  double _tickTimer = UpgradeAmounts.auraTickIntervalSec;

  @override
  void update(double dt) {
    super.update(dt);

    position.setFrom(game.player.position); // follows the player every frame
    angle += _rotationSpeedRadPerSec * dt;

    _tickTimer -= dt;
    if (_tickTimer <= 0) {
      _tickTimer += UpgradeAmounts.auraTickIntervalSec;
      _dealDamage();
    }
  }

  void _dealDamage() {
    final stacks = game.upgrades.pickCounts[UpgradeKind.aura] ?? 0;
    if (stacks <= 0) return; // shouldn't happen once spawned, guard anyway
    final damage = UpgradeAmounts.auraDamagePerTick(stacks);

    final enemies = game.enemies;
    final positions = [for (final enemy in enemies) enemy.position];
    for (final index in allWithinRange(position, positions, _radiusPx)) {
      final enemy = enemies[index];
      if (enemy.isDying) continue;
      enemy.takeDamage(damage);
      game.onProjectileHit(enemy.position.clone(), damage);
    }
  }
}
