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
        paint: Paint()
          ..filterQuality = FilterQuality.none // D-011
          ..color = const Color.fromRGBO(255, 255, 255, _opacity)
          ..colorFilter = ColorFilter.matrix(_contrastMatrix(_contrast)),
      ),
    );
  }

  static const _radiusPx = UpgradeAmounts.auraRadiusPx;

  // 2026-09-09 tune (developer's call): the raw asset read "too bright,
  // in-your-face" on-device -- -20% opacity, -20% contrast.
  static const _opacity = 0.8;
  static const _contrast = 0.8;

  /// Standard contrast-scaling color matrix: scales every channel toward
  /// (away from, if [factor] > 1) the 50% grey midpoint by [factor], alpha
  /// untouched (last row `0 0 0 1 0`). `Color.fromRGBO`'s own alpha above
  /// handles opacity separately -- this only pulls the ring's own colors
  /// closer together, it doesn't fade it out.
  static List<double> _contrastMatrix(double factor) {
    final translate = (1 - factor) * 255 / 2;
    return [
      factor, 0, 0, 0, translate,
      0, factor, 0, 0, translate,
      0, 0, factor, 0, translate,
      0, 0, 0, 1, 0,
    ];
  }

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

    final targets = game.damageableTargets;
    final positions = [for (final target in targets) target.position];
    for (final index in allWithinRange(position, positions, _radiusPx)) {
      final target = targets[index];
      if (target.isDying) continue;
      target.takeDamage(damage);
      game.onProjectileHit(target.position.clone(), damage);
    }
  }
}
