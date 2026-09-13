import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/game_rules.dart';
import '../../core/meta_progression.dart';
import '../../core/sfx_player.dart';
import '../arena_game.dart';

/// A breakable gem vase (DECISIONS D-002 — "when character runs through,
/// play a 'card chosen' sound, vase breaks, play vfx from when we choose a
/// card, gems fly out of the vase left and right"). `gem-vase.png` has no
/// distinct shatter frames of its own — its 16 frames are the same intact
/// pose with just a subtle shimmer sweep across it, not a break sequence —
/// so "breaking" is entirely this component vanishing at the same instant
/// the SFX/VFX/gem burst fire around it, the same "the VFX sells the beat,
/// not a missing sprite frame" shape `ChestComponent`'s own explosion beat
/// already leans on.
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
      game.spawnCardChosenBurst(position.clone()); // D-002: "vfx from when we choose a card"
      game.breakVase(this); // removes self + scatters gems left/right
    }
  }
}
