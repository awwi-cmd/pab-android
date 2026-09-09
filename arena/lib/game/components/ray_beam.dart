import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../arena_game.dart';

/// The visual half of the Projectile Ray skill (DECISIONS D-049) — hit
/// detection (`alongLineWithinRange`, `core/game_rules.dart`) happens once in
/// `ArenaGame._fireRayBeam`, this just draws the beam sprite stretched from
/// [origin] to `origin + direction * lengthPx` and rotated to face
/// [direction]. `Anchor.centerLeft` so the sprite's own left edge sits at the
/// player rather than the beam's midpoint — a one-shot, non-looping
/// animation (loaded with `loop: false`) that removes itself when done.
class RayBeamEffectComponent extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  RayBeamEffectComponent({
    required Vector2 origin,
    required Vector2 direction,
    required double lengthPx,
    required SpriteAnimation animation,
  }) : super(
         animation: animation,
         position: origin,
         size: Vector2(lengthPx, kRayBeamThicknessPx),
         anchor: Anchor.centerLeft,
         angle: atan2(direction.y, direction.x),
         paint: Paint()..filterQuality = FilterQuality.none, // D-011
         priority: ArenaPriority.hitEffects,
         removeOnFinish: true,
       );
}
