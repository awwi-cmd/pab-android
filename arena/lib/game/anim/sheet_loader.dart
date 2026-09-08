import 'package:flame/components.dart';
import 'package:flame/flame.dart';

/// Loads a single sheet as a [SpriteAnimation] — frames left-to-right,
/// uniform cell, frame count = image width / [cellWidth] by default
/// (DECISIONS D-015). Shared by [CharacterAnimations] (per-state character
/// sheets) and one-off VFX sheets (projectile bolt / hit-spark / Aura's
/// shield, D-032) alike.
///
/// [frameCount]/[amountPerRow] are for a multi-row grid sheet (D-032's
/// `effect_electric-shield.png` is 9 cols × 7 rows, 60 real frames padded
/// out to a 63-cell rectangle) — leave both null for the single-row-strip
/// default every other sheet in this project uses.
///
/// [path] is relative to Flame's default image root (`assets/images/`).
Future<SpriteAnimation> loadSheetAnimation(
  String path, {
  required double cellWidth,
  required double cellHeight,
  double stepTime = 0.1,
  bool loop = true,
  int? frameCount,
  int? amountPerRow,
}) async {
  final image = await Flame.images.load(path);
  final amount = frameCount ?? (image.width / cellWidth).round();
  return SpriteAnimation.fromFrameData(
    image,
    SpriteAnimationData.sequenced(
      amount: amount,
      stepTime: stepTime,
      textureSize: Vector2(cellWidth, cellHeight),
      amountPerRow: amountPerRow,
      loop: loop,
    ),
  );
}
