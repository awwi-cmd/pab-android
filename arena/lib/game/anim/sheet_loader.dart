import 'package:flame/components.dart';
import 'package:flame/flame.dart';

/// Loads a single sheet as a [SpriteAnimation] — frames left-to-right,
/// uniform cell, frame count = image width / [cellWidth] (DECISIONS D-015).
/// Shared by [CharacterAnimations] (per-state character sheets) and one-off
/// VFX sheets (projectile bolt / hit-spark) alike.
///
/// [path] is relative to Flame's default image root (`assets/images/`).
Future<SpriteAnimation> loadSheetAnimation(
  String path, {
  required double cellWidth,
  required double cellHeight,
  double stepTime = 0.1,
  bool loop = true,
}) async {
  final image = await Flame.images.load(path);
  final frameCount = (image.width / cellWidth).round();
  return SpriteAnimation.fromFrameData(
    image,
    SpriteAnimationData.sequenced(
      amount: frameCount,
      stepTime: stepTime,
      textureSize: Vector2(cellWidth, cellHeight),
      loop: loop,
    ),
  );
}
