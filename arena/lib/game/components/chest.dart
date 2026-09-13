import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/economy.dart';
import '../../core/game_rules.dart';
import '../../core/meta_progression.dart';
import '../../core/sfx_player.dart';
import '../arena_game.dart';

/// A world chest (DECISIONS D-055) — sits closed
/// (`GameAssets.chestIdleAnimation`, `chest_01.png`) until the player walks
/// within [kChestPickupRadiusPx], then runs a short fixed sequence: the
/// boss's teleport flourish (`ArenaGame.animaAnimation`) plays first, then
/// `ArenaGame.spawnExplosionEffect` (also the explosion SFX, for free), then
/// the chest itself swaps to the real 12-frame opening animation
/// (`GameAssets.chestOpeningAnimation`) — "we can use anima + explosion
/// before chest opens," the developer's literal spec. Once that finishes,
/// it rolls a reward card (`rollChestCard`, DECISIONS D-057) and hands off
/// to `ArenaGame.onChestOpened` for the card-spin reveal popup, then removes
/// itself.
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
      // MAGNET (DECISIONS D-069) widens every pickup's own collect radius.
      final radius = kChestPickupRadiusPx *
          magnetPickupRadiusMultiplier(game.metaLevel(MetaStat.magnet));
      if (player.isAlive && position.distanceTo(player.position) < radius) {
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
    SfxPlayer.instance.playPickup(); // DECISIONS D-091 -- the touch itself, distinct from the explosion beat below
    // DECISIONS D-071: sized relative to this chest's own rendered width
    // ("smaller a bit than the chest"), not the flat, much-bigger
    // kAnimaWidthPx every other anima flourish shares -- plus a reduced
    // contrast tune ("wayy too big... reduce contrast").
    final animaWidth = size.x * kChestAnimaSizeFactor;
    game.spawnEffect(
      game.animaAnimation,
      position.clone(),
      size: Vector2(animaWidth, animaWidth * kAnimaAspect),
      contrast: kChestAnimaContrast,
      // DECISIONS D-074 ("needs to be behind the chest asset"): spawnEffect's
      // own default (ArenaPriority.hitEffects, 25) sits above the chest's
      // own priority (ArenaPriority.pickup, 7).
      priority: ArenaPriority.groundEffects,
    );
  }

  void _finishOpening() {
    game.onChestOpened(rollChestCard(_random));
    removeFromParent();
  }
}
