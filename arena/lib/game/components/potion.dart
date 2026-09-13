import 'dart:math';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/economy.dart';
import '../../core/game_rules.dart';
import '../../core/meta_progression.dart';
import '../arena_game.dart';

/// A potion sitting on the ground (DECISIONS D-043) — spawns randomly
/// around the player at intervals, floats up and down in place (developer's
/// explicit ask, layered on top of its own looping sprite animation, not a
/// second spritesheet), heals the player by `potionHealAmount(rarity)` on
/// touch. "We will add more logic later" per the developer — healing
/// on contact is deliberately the whole mechanic for now.
class PotionComponent extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  PotionComponent({
    required Vector2 startPosition,
    required this.rarity,
    required SpriteAnimation animation,
  }) : _basePosition = startPosition.clone(),
       super(
         animation: animation,
         position: startPosition,
         size: Vector2.all(16 * kItemRenderScale),
         anchor: Anchor.center,
         priority: ArenaPriority.pickup,
       );

  final ItemRarity rarity;
  final Vector2 _basePosition;
  double _floatTime = 0;

  @override
  void update(double dt) {
    super.update(dt);

    _floatTime += dt;
    position.x = _basePosition.x;
    position.y = _basePosition.y +
        sin(_floatTime * 2 * pi / kItemFloatPeriodSec) *
            kItemFloatAmplitudePx;

    final player = game.player;
    // MAGNET (DECISIONS D-069) widens every pickup's own collect radius.
    final radius = kItemPickupRadiusPx *
        magnetPickupRadiusMultiplier(game.metaLevel(MetaStat.magnet));
    if (player.isAlive && position.distanceTo(player.position) < radius) {
      game.collectPotion(rarity);
      removeFromParent();
    }
  }
}
