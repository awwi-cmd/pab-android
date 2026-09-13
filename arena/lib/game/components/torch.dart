import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';

/// A standing torch (DECISIONS D-002) — a solid world obstacle scattered
/// randomly by [TorchSpawner]. Purely decorative on its own (a looping
/// flame-flicker animation); the actual collision against the player/
/// enemies is resolved every frame in their own `update()` via
/// `core/game_rules.dart`'s `resolveCircleObstacle`, reading [collisionRadius]
/// and [position] off this component — this class doesn't push anything
/// itself, it only reports where it is and how big a circle to keep clear.
class TorchComponent extends SpriteAnimationComponent {
  TorchComponent({required Vector2 startPosition, required SpriteAnimation animation})
    : super(
        animation: animation,
        position: startPosition,
        size: Vector2.all(16 * kTorchRenderScale),
        anchor: Anchor.center,
        paint: Paint()..filterQuality = FilterQuality.none, // D-011
        priority: ArenaPriority.obstacle,
      );

  double get collisionRadius => kTorchCollisionRadiusPx;
}
