import 'package:flame/components.dart';

import '../arena_game.dart';

/// A VFX that stays glued to a moving [target] component for as long as it
/// plays (DECISIONS D-033/D-034/D-035) — unlike `ArenaGame.spawnEffect` (a
/// one-shot at a fixed point, e.g. a hit flash where the target may already
/// be gone), this is for effects tied to a still-living character's body:
/// the Skirmisher's cast sparkle (follows the player), an elite enemy's
/// fire glow (follows that enemy, persists for its whole lifetime).
///
/// Self-removes the frame after [target] leaves the tree (dies/despawns) —
/// simpler than every spawn site having to wire a cross-reference to clean
/// this up itself.
class TrackingSpriteEffect extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  TrackingSpriteEffect({
    required this.target,
    Vector2? offset,
    required SpriteAnimation animation,
    required Vector2 size,
    Anchor anchor = Anchor.center,
    super.paint,
    int priority = 0,
    super.removeOnFinish = true,
  }) : offset = offset ?? Vector2.zero(),
       super(
         animation: animation,
         position: target.position + (offset ?? Vector2.zero()),
         size: size,
         anchor: anchor,
         priority: priority,
       );

  final PositionComponent target;
  final Vector2 offset;

  @override
  void update(double dt) {
    super.update(dt);
    if (!target.isMounted) {
      removeFromParent();
      return;
    }
    position
      ..setFrom(target.position)
      ..add(offset);
  }
}
