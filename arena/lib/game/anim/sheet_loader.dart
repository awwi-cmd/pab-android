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
/// [texturePosition] pulls one slice out of a sheet shared by several
/// animations (DECISIONS D-042 — `boss_map1.png` is one 4-cols × 8-rows
/// sheet holding idle/walk/fire/death back to back, in that reading order,
/// not one image per state like every character sheet before it). Must be
/// the pixel origin of a whole row (`x: 0`, `y` a multiple of [cellHeight])
/// — the underlying frame-index math wraps correctly onto the next row
/// down from there, but not onto a sub-row horizontal offset.
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
  Vector2? texturePosition,
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
      texturePosition: texturePosition,
      loop: loop,
    ),
  );
}

/// Loads one vertical animation strip out of a sheet arranged as [column]s
/// of item types side by side, each [rows] animation frames tall (DECISIONS
/// D-043 — `gems.png`/`money.png`/`potions.png`: rarity tiers are columns
/// left-to-right, each column's own frames stacked downward. The opposite
/// arrangement from [loadSheetAnimation]'s row-major sheets, so it needs
/// its own loader rather than a texturePosition trick — a column offset
/// can't be expressed as a whole-row pixel origin.
Future<SpriteAnimation> loadColumnAnimation(
  String path, {
  required double cellSize,
  required int column,
  required int rows,
  double stepTime = 0.1,
  bool loop = true,
}) async {
  final image = await Flame.images.load(path);
  final frames = [
    for (var row = 0; row < rows; row++)
      SpriteAnimationFrame(
        Sprite(
          image,
          srcPosition: Vector2(column * cellSize, row * cellSize),
          srcSize: Vector2.all(cellSize),
        ),
        stepTime,
      ),
  ];
  return SpriteAnimation(frames, loop: loop);
}

/// Loads one [SpriteAnimation] out of a *sequence of separate files*, one
/// frame per file, in the given order (DECISIONS D-055 — the chest-opening
/// sequence, `consumables/chest_01.png`..`chest_12.png`: 12 whole images,
/// not one sheet sliced into cells like every other loader in this file).
/// [path]s are relative to Flame's default image root (`assets/images/`),
/// same as [loadSheetAnimation].
Future<SpriteAnimation> loadFileSequenceAnimation(
  List<String> paths, {
  double stepTime = 0.1,
  bool loop = true,
}) async {
  final frames = [
    for (final path in paths)
      SpriteAnimationFrame(Sprite(await Flame.images.load(path)), stepTime),
  ];
  return SpriteAnimation(frames, loop: loop);
}
