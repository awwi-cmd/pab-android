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
    final hits = allWithinRange(position, positions, _radiusPx);
    if (hits.isEmpty) return;

    for (final index in hits) {
      final enemy = enemies[index];
      if (enemy.isDying) continue;
      enemy.takeDamage(damage);
      game.onProjectileHit(enemy.position.clone(), damage);
    }
    // A brief full-disk flash on every tick that actually connects -- the
    // orbiting sparks only ever sit at the boundary, so on their own they
    // read as a ring-shaped effect. This proves (and looks like) the whole
    // disk is live, not just its edge -- replaces the static debug outline
    // from the first on-device pass, which is no longer needed once this
    // fires every tick on its own.
    game.add(_AuraPulseComponent(center: position.clone(), radius: _radiusPx));
  }
}

/// One-shot fading flash across the whole aura disk, spawned per successful
/// tick (see `AuraComponent._dealDamage`). Filled, not stroked -- the point
/// is to visually prove the *entire* radius just hit, not trace its edge.
class _AuraPulseComponent extends CircleComponent {
  _AuraPulseComponent({required Vector2 center, required double radius})
    : super(
        radius: radius,
        position: center,
        anchor: Anchor.center,
        priority: ArenaPriority.hitEffects,
        paint: Paint()..color = const Color(0x556CE0B8), // ArenaColors.accent
      );

  double _age = 0;
  static const _lifespanSec = 0.18;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _lifespanSec) {
      removeFromParent();
      return;
    }
    final fade = 1 - (_age / _lifespanSec);
    paint.color = paint.color.withAlpha((0x55 * fade).round());
  }
}
