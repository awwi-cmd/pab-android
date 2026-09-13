import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/game_rules.dart';
import '../../core/meta_progression.dart';
import '../../core/sfx_player.dart';
import '../arena_game.dart';

/// A breakable gem vase (DECISIONS D-002 — "when character runs through,
/// play a 'card chosen' sound, vase breaks, gems fly out of the vase left
/// and right"; the sparkle VFX D-002 originally added here was removed by
/// D-006, "remove the vfx for when we break the vase" — the SFX plus the
/// gem burst itself is the whole break moment now). `gem-vase.png` has no
/// distinct shatter frames of its own — its 16 frames are the same intact
/// pose with just a subtle shimmer sweep across it, not a break sequence —
/// so "breaking" is entirely this component vanishing at the same instant
/// the SFX/gem burst fire.
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
      game.breakVase(this); // removes self + starts the staggered gem burst
    }
  }
}
