import 'dart:math';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/economy.dart';
import '../../core/game_rules.dart';
import '../../core/meta_progression.dart';
import '../arena_game.dart';

/// A dropped gem (DECISIONS D-043) — spawned at an enemy's death position
/// when `rollGemDrop` hits, auto-collected when the player walks close
/// enough (no manual pickup input, matching how nothing else in this
/// project asks for a button press). [rarity] only picks which of the 5
/// `gems.png` columns this looks like (`ArenaGame.gemAnimationFor`) — no
/// gameplay difference between tiers yet. Floats up and down in place same
/// as `PotionComponent` (DECISIONS D-059, developer's literal ask: "make it
/// like the potion one") — same shared `kItemFloatAmplitudePx`/
/// `kItemFloatPeriodSec` constants, not a second set of numbers.
class GemComponent extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  GemComponent({
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
      game.collectGem(rarity);
      removeFromParent();
    }
  }
}
