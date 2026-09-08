import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/economy.dart';
import '../arena_game.dart';

/// A dropped gem (DECISIONS D-043) — spawned at an enemy's death position
/// when `rollGemDrop` hits, auto-collected when the player walks close
/// enough (no manual pickup input, matching how nothing else in this
/// project asks for a button press). [rarity] only picks which of the 5
/// `gems.png` columns this looks like (`ArenaGame.gemAnimationFor`) — no
/// gameplay difference between tiers yet.
class GemComponent extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  GemComponent({
    required Vector2 startPosition,
    required this.rarity,
    required SpriteAnimation animation,
  }) : super(
         animation: animation,
         position: startPosition,
         size: Vector2.all(16 * kItemRenderScale),
         anchor: Anchor.center,
         priority: ArenaPriority.pickup,
       );

  final ItemRarity rarity;

  @override
  void update(double dt) {
    super.update(dt);
    final player = game.player;
    if (player.isAlive &&
        position.distanceTo(player.position) < kItemPickupRadiusPx) {
      game.collectGem(rarity);
      removeFromParent();
    }
  }
}
