import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/economy.dart';
import '../arena_game.dart';

/// A world chest (DECISIONS D-055) — sits closed
/// (`GameAssets.chestIdleAnimation`, `chest_01.png`) until the player walks
/// within [kChestPickupRadiusPx], then runs a short fixed sequence: the
/// boss's teleport flourish (`ArenaGame.animaAnimation`) plays first, then
/// `ArenaGame.spawnExplosionEffect` (also the explosion SFX, for free), then
/// the chest itself swaps to the real 12-frame opening animation
/// (`GameAssets.chestOpeningAnimation`) — "we can use anima + explosion
/// before chest opens," the developer's literal spec. Once that finishes,
/// it rolls gems (`rollChestGems`) and hands off to
/// `ArenaGame.onChestOpened` for the reveal popup, then removes itself.
class ChestComponent extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  ChestComponent({required Vector2 startPosition, required SpriteAnimation idleAnimation})
    : super(
        animation: idleAnimation,
        position: startPosition,
        size: Vector2.all(32 * kChestRenderScale),
        anchor: Anchor.center,
        paint: Paint()..filterQuality = FilterQuality.none, // D-011
        priority: ArenaPriority.pickup,
      );

  /// How long after triggering before the explosion (and the visual swap to
  /// the real opening frames) fires — gives the anima flourish above a beat
  /// to read on its own first, instead of everything landing on one frame.
  static const _explosionDelaySec = 0.35;

  bool _opening = false;
  double _elapsedSinceOpen = 0;
  bool _explosionFired = false;
  final Random _random = Random();

  @override
  void update(double dt) {
    super.update(dt);

    if (!_opening) {
      final player = game.player;
      if (player.isAlive &&
          position.distanceTo(player.position) < kChestPickupRadiusPx) {
        _startOpening();
      }
      return;
    }

    _elapsedSinceOpen += dt;
    if (!_explosionFired && _elapsedSinceOpen >= _explosionDelaySec) {
      _explosionFired = true;
      game.spawnExplosionEffect(position.clone());
      animation = game.gameAssets.chestOpeningAnimation;
    }
    if (_explosionFired && (animationTicker?.done() ?? false)) {
      _finishOpening();
    }
  }

  void _startOpening() {
    _opening = true;
    game.spawnEffect(
      game.animaAnimation,
      position.clone(),
      size: Vector2(kAnimaWidthPx, kAnimaWidthPx * kAnimaAspect),
    );
  }

  void _finishOpening() {
    game.onChestOpened(rollChestGems(_random));
    removeFromParent();
  }
}
