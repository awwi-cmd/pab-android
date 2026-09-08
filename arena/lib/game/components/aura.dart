import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/game_rules.dart';
import '../../core/progression.dart';
import '../arena_game.dart';

/// The Aura skill (DECISIONS D-027) — a shield ring centered on the player,
/// ticking damage to everything caught inside [_radiusPx] every
/// `UpgradeAmounts.auraTickIntervalSec`. Visual is
/// `vfx/vfx/effect_electric-shield.png`, a pre-animated spinning ring sheet
/// (DECISIONS D-032) swapped in for the original orbiting-sparks look — the
/// radius/damage logic below is untouched by that swap, only the child
/// component that renders it changed.
///
/// Spawned once by `ArenaGame` on the first Aura pick and left alone after
/// that (DECISIONS D-025 pattern: `ArenaGame` owns round state, this
/// component just reads the current stack count every tick rather than
/// being rebuilt per pick) — damage scales with
/// `upgrades.pickCounts[UpgradeKind.aura]`, capped at
/// `UpgradeAmounts.auraMaxStacks` by `rollUpgradeChoices` refusing to offer
/// it again past that.
class AuraComponent extends PositionComponent with HasGameReference<ArenaGame> {
  AuraComponent({required SpriteAnimation shieldAnimation})
    : super(anchor: Anchor.center, priority: ArenaPriority.hitEffects) {
    // Sized to the damage diameter exactly, never larger -- the ring art
    // has its own inset padding inside the frame, so the actual visible
    // ring ends up a bit inside the hit circle rather than overselling it.
    add(
      SpriteAnimationComponent(
        animation: shieldAnimation,
        size: Vector2.all(_radiusPx * 2),
        anchor: Anchor.center,
        paint: Paint()..filterQuality = FilterQuality.none, // D-011
      ),
    );
  }

  static const _radiusPx = UpgradeAmounts.auraRadiusPx;

  double _tickTimer = UpgradeAmounts.auraTickIntervalSec;

  @override
  void update(double dt) {
    super.update(dt);

    position.setFrom(game.player.position); // follows the player every frame

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
