import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/game_rules.dart';
import '../../core/meta_progression.dart';
import '../../core/sfx_player.dart';
import '../arena_game.dart';

/// A breakable gem vase (DECISIONS D-002 — "when character runs through,
/// play a 'card chosen' sound, vase breaks, gems fly out of the vase left
/// and right"). The original sparkle VFX (D-002) was removed by D-006
/// ("remove the vfx for when we break the vase"); D-007 then added a
/// different, smaller VFX in its place — a scaled-down copy of
/// `WardenSlamAttack`'s own explosion shockwave ("add an explosion vfx
/// like the 4th character has... make the explosion not that big"), via
/// the same `explosionAnimation` sheet and `ArenaGame.spawnEffect` — not
/// `ArenaGame.spawnExplosionEffect`, which also plays the explosion SFX;
/// the developer's ask was explicit that "the sound can remain the
/// current" (the card-chosen SFX below), not gain a second one. `gem-
/// vase.png` has no distinct shatter frames of its own — its 16 frames are
/// the same intact pose with just a subtle shimmer sweep across it, not a
/// break sequence — so "breaking" is this component vanishing at the same
/// instant the SFX/explosion VFX/gem burst all fire together.
class VaseComponent extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  VaseComponent({required Vector2 startPosition, required SpriteAnimation animation})
    : super(
        animation: animation,
        position: startPosition,
        size: Vector2.all(16 * kVaseRenderScale),
        anchor: Anchor.center,
        paint: Paint()..filterQuality = FilterQuality.none, // D-011
        priority: ArenaPriority.pickup,
      );

  @override
  void update(double dt) {
    super.update(dt);

    final player = game.player;
    // MAGNET (DECISIONS D-069) widens every pickup's own collect radius,
    // same as every other pickup in this project.
    final radius = kVasePickupRadiusPx *
        magnetPickupRadiusMultiplier(game.metaLevel(MetaStat.magnet));
    if (player.isAlive && position.distanceTo(player.position) < radius) {
      SfxPlayer.instance.playChestCardChosen(); // D-002: "a card chosen sound"
      // D-007: VFX only, no SFX -- spawnExplosionEffect plays the boom
      // sound too, which isn't wanted here (see class doc).
      game.spawnEffect(
        game.gameAssets.explosionAnimation,
        position.clone(),
        size: Vector2(kVaseExplosionWidthPx, kVaseExplosionWidthPx * kSpiralExplosionAspect),
      );
      game.breakVase(this); // removes self + starts the staggered gem burst
    }
  }
}
