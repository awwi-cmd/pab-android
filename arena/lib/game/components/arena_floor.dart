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

    // Flush-aligned positions along each axis: every tile after the first
    // is exactly one tile-width on from the last, EXCEPT the final one,
    // which is forced to sit flush against the true far edge (size.x/y -
    // scaledTile) even if that means a hair of overlap with its neighbour.
    // Plain index math (col * scaledTile for every tile) left a gap of
    // varying size before the far edge whenever size wasn't an exact
    // multiple of scaledTile -- which it never is -- and that gap differed
    // between the x and y axes, which is why only one of the four corners
    // ever happened to line up.
    final xPositions = _edgePositions(size.x);
    final yPositions = _edgePositions(size.y);

    // Straight runs only -- corners (first/last position on each axis) are
    // handled separately below with an actual join instead of either the
    // wrong-orientation tile or an empty gap.
    for (var i = 1; i < xPositions.length - 1; i++) {
      border.render(
        canvas,
        position: Vector2(xPositions[i], 0),
        size: Vector2.all(_scaledTile),
        overridePaint: _borderPaint,
      );
      border.render(
        canvas,
        position: Vector2(xPositions[i], size.y - _scaledTile),
        size: Vector2.all(_scaledTile),
        overridePaint: _borderPaint,
      );
    }
    for (var i = 1; i < yPositions.length - 1; i++) {
      _renderRotatedTile(canvas, border, Vector2(0, yPositions[i]), pi / 2);
      _renderRotatedTile(
        canvas,
        border,
        Vector2(size.x - _scaledTile, yPositions[i]),
        pi / 2,
      );
    }

    _renderCorner(canvas, border, Vector2.zero(), fromRight: false, fromTop: false);
    _renderCorner(
      canvas,
      border,
      Vector2(size.x - _scaledTile, 0),
      fromRight: true,
      fromTop: false,
    );
    _renderCorner(
      canvas,
      border,
      Vector2(0, size.y - _scaledTile),
      fromRight: false,
      fromTop: true,
    );
    _renderCorner(
      canvas,
      border,
      Vector2(size.x - _scaledTile, size.y - _scaledTile),
      fromRight: true,
      fromTop: true,
    );
  }

  /// Positions along one axis for a row of flush-tiled sprites: every
  /// position after the first is one tile-width further along, except the
  /// last, which is pinned to `total - scaledTile` so the run always ends
  /// exactly flush with the far edge.
  List<double> _edgePositions(double total) {
    final positions = <double>[];
    var pos = 0.0;
    while (pos < total - _scaledTile) {
      positions.add(pos);
      pos += _scaledTile;
    }
    positions.add(total - _scaledTile);
    return positions;
  }

  /// No dedicated corner asset exists — the source art is a straight dash.
  /// Approximate a join by drawing the horizontal tile clipped to whichever
  /// half faces the straight run it's continuing, and the vertical
  /// (rotated) tile clipped the same way, so the two contribute three of
  /// the corner cell's four quadrants between them. The one quadrant
  /// nobody draws is the tile's very outer tip — a much smaller and less
  /// noticeable gap than an empty corner or the two tiles overlapping.
  void _renderCorner(
    Canvas canvas,
    Sprite sprite,
    Vector2 topLeft, {
    required bool fromRight,
    required bool fromTop,
  }) {
    final half = _scaledTile / 2;
    final horizontalClip = fromRight
        ? Rect.fromLTWH(topLeft.x, topLeft.y, half, _scaledTile)
        : Rect.fromLTWH(topLeft.x + half, topLeft.y, half, _scaledTile);
    final verticalClip = fromTop
        ? Rect.fromLTWH(topLeft.x, topLeft.y, _scaledTile, half)
        : Rect.fromLTWH(topLeft.x, topLeft.y + half, _scaledTile, half);

    canvas.save();
    canvas.clipRect(horizontalClip);
    sprite.render(
      canvas,
      position: topLeft,
      size: Vector2.all(_scaledTile),
      overridePaint: _borderPaint,
    );
    canvas.restore();

    canvas.save();
    canvas.clipRect(verticalClip);
    _renderRotatedTile(canvas, sprite, topLeft, pi / 2);
    canvas.restore();
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
