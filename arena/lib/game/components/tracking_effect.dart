import 'package:flame/components.dart';

import '../arena_game.dart';

/// A VFX that stays glued to a moving [target] component for as long as it
/// plays (DECISIONS D-033/D-034/D-035) — unlike `ArenaGame.spawnEffect` (a
/// one-shot at a fixed point, e.g. a hit flash where the target may already
/// be gone), this is for effects tied to a still-living character's body:
/// the Skirmisher's always-on cast sparkle (follows the player), an elite
/// enemy's fire glow (follows that enemy, persists for its whole lifetime).
///
/// Self-removes the frame after [target] leaves the tree (dies/despawns) —
/// simpler than every spawn site having to wire a cross-reference to clean
/// this up itself. [fadeOutWhen], if given, is polled every frame once
/// [target] is still mounted; the first time it returns true this fades its
/// own opacity to 0 over [fadeOutDurationSec] and removes itself at the end
/// of that fade, rather than waiting for/snapping to the frame [target]
/// actually leaves the tree (DECISIONS D-036 — an elite's fire glow should
/// start dying the instant the enemy does, not linger at full brightness
/// through the whole death animation then vanish abruptly).
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
    this.fadeOutWhen,
    this.fadeOutDurationSec = 0.4,
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
  final bool Function()? fadeOutWhen;
  final double fadeOutDurationSec;

  bool _fading = false;
  double _fadeRemainingSec = 0;

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

    if (!_fading && (fadeOutWhen?.call() ?? false)) {
      _fading = true;
      _fadeRemainingSec = fadeOutDurationSec;
    }
    if (_fading) {
      _fadeRemainingSec -= dt;
      opacity = (_fadeRemainingSec / fadeOutDurationSec).clamp(0, 1);
      if (_fadeRemainingSec <= 0) {
        removeFromParent();
      }
    }
  }
}
