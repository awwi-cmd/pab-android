import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import '../../core/constants.dart';

/// Tiled floor + border (PRD §6.1 — world size equals screen size, no
/// camera scroll, DECISIONS D-007). Real tile art:
/// `assets/images/scenes/arena_floor_tiles.png` (3 variants, 32×32 each,
/// laid out left-to-right — same "uniform cell" convention as the
/// character sheets, D-015) and `arena_border_tile.png` (32×32, tiled
/// along the perimeter, rotated 90° on the left/right edges).
class ArenaFloor extends PositionComponent {
  ArenaFloor() : super(priority: ArenaPriority.floor);

  static const _tileSize = 32.0;
  static const _scaledTile = _tileSize * kFloorTileRenderScale;

  final _random = Random();
  final _pixelPaint = Paint()..filterQuality = FilterQuality.none; // D-011

  // Border at 60% opacity (developer's call: full opacity read too heavy
  // against the floor). Alpha on the paint's colour is what Skia uses to
  // scale an image draw's opacity -- the RGB channels are unused here.
  final _borderPaint = Paint()
    ..filterQuality = FilterQuality.none
    ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.6);

  List<Sprite>? _floorVariants;
  Sprite? _borderTile;
  List<List<int>>? _floorPattern; // [row][col] -> variant index

  @override
  Future<void> onLoad() async {
    final floorImage = await Flame.images.load(
      'scenes/arena_floor_tiles.png',
    );
    final variantCount = (floorImage.width / _tileSize).round();
    _floorVariants = List.generate(
      variantCount,
      (i) => Sprite(
        floorImage,
        srcPosition: Vector2(i * _tileSize, 0),
        srcSize: Vector2.all(_tileSize),
      ),
    );
    _borderTile = Sprite(
      await Flame.images.load('scenes/arena_border_tile.png'),
    );
    if (size.x > 0 && size.y > 0) {
      _generatePattern();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size.setFrom(size);
    if (_floorVariants != null) {
      _generatePattern();
    }
  }

  /// Randomised once per arena entry so the floor isn't a visibly repeating
  /// grid, but stable for the rest of the round (not regenerated per frame).
  void _generatePattern() {
    final cols = (size.x / _scaledTile).ceil();
    final rows = (size.y / _scaledTile).ceil();
    _floorPattern = List.generate(
      rows,
      (_) => List.generate(cols, (_) => _random.nextInt(_floorVariants!.length)),
    );
  }

  @override
  void render(Canvas canvas) {
    final variants = _floorVariants;
    final pattern = _floorPattern;
    final border = _borderTile;
    if (variants == null || pattern == null || border == null) {
      return; // still loading (first frame or two only)
    }

    for (var row = 0; row < pattern.length; row++) {
      for (var col = 0; col < pattern[row].length; col++) {
        variants[pattern[row][col]].render(
          canvas,
          position: Vector2(col * _scaledTile, row * _scaledTile),
          size: Vector2.all(_scaledTile),
          overridePaint: _pixelPaint,
        );
      }
    }

    final cols = (size.x / _scaledTile).ceil();
    final rows = (size.y / _scaledTile).ceil();
    // Corner cells (col 0/cols-1, row 0/rows-1) are left empty on purpose:
    // the source art is a straight dash, there's no dedicated corner
    // piece, and a horizontal dash sitting where a vertical run of dashes
    // meets it reads as a broken seam rather than a turn. A small gap at
    // each corner looks cleaner than either the mismatched tile or the
    // doubled-up overlap this used to have.
    for (var col = 1; col < cols - 1; col++) {
      border.render(
        canvas,
        position: Vector2(col * _scaledTile, 0),
        size: Vector2.all(_scaledTile),
        overridePaint: _borderPaint,
      );
      border.render(
        canvas,
        position: Vector2(col * _scaledTile, size.y - _scaledTile),
        size: Vector2.all(_scaledTile),
        overridePaint: _borderPaint,
      );
    }
    for (var row = 1; row < rows - 1; row++) {
      _renderRotatedTile(
        canvas,
        border,
        Vector2(0, row * _scaledTile),
        pi / 2,
      );
      _renderRotatedTile(
        canvas,
        border,
        Vector2(size.x - _scaledTile, row * _scaledTile),
        pi / 2,
      );
    }
  }

  void _renderRotatedTile(
    Canvas canvas,
    Sprite sprite,
    Vector2 topLeft,
    double angle,
  ) {
    final centerX = topLeft.x + _scaledTile / 2;
    final centerY = topLeft.y + _scaledTile / 2;
    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(angle);
    canvas.translate(-centerX, -centerY);
    sprite.render(
      canvas,
      position: topLeft,
      size: Vector2.all(_scaledTile),
      overridePaint: _borderPaint,
    );
    canvas.restore();
  }
}
