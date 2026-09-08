import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import '../../core/constants.dart';
import '../arena_game.dart';

/// Endless tiled floor (DECISIONS D-041, Phase 9.3 — closes the D-040 gap):
/// renders whatever floor tiles overlap the camera's current view, computed
/// fresh from `game.camera.visibleWorldRect` every frame, rather than a
/// fixed pattern baked into one `game.size` patch at the world origin (the
/// old D-007-era design). No border tiles any more — an infinite world has
/// no edge to put one on; the border was the "still there visually" bug
/// once the camera could scroll past where it used to sit.
class ArenaFloor extends PositionComponent with HasGameReference<ArenaGame> {
  ArenaFloor() : super(priority: ArenaPriority.floor);

  static const _tileSize = 32.0;
  static const _scaledTile = _tileSize * kFloorTileRenderScale;

  final _pixelPaint = Paint()..filterQuality = FilterQuality.none; // D-011

  // Rolled once per round -- the per-cell variant pick below is otherwise
  // fully deterministic (same cell always renders the same tile, so the
  // floor doesn't change if you leave and come back), so without this every
  // round would tile the exact same pattern from the same seed.
  final int _seed = Random().nextInt(1 << 20);

  List<Sprite>? _floorVariants;

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
  }

  @override
  void render(Canvas canvas) {
    final variants = _floorVariants;
    if (variants == null) return; // still loading (first frame or two only)

    // Inflated by one tile so a tile fully covers the view's edge instead
    // of popping in right as its corner crosses into frame.
    final visible = game.camera.visibleWorldRect.inflate(_scaledTile);
    final colStart = (visible.left / _scaledTile).floor();
    final colEnd = (visible.right / _scaledTile).ceil();
    final rowStart = (visible.top / _scaledTile).floor();
    final rowEnd = (visible.bottom / _scaledTile).ceil();

    for (var row = rowStart; row < rowEnd; row++) {
      for (var col = colStart; col < colEnd; col++) {
        variants[_variantFor(col, row, variants.length)].render(
          canvas,
          position: Vector2(col * _scaledTile, row * _scaledTile),
          size: Vector2.all(_scaledTile),
          overridePaint: _pixelPaint,
        );
      }
    }
  }

  /// Deterministic per-cell variant pick — the same (col, row) always
  /// resolves to the same tile index. A per-frame `Random()` pick (the old
  /// approach, viable only because the pattern was generated once for a
  /// fixed-size grid) would make the floor re-roll every time a cell
  /// re-enters view.
  int _variantFor(int col, int row, int variantCount) {
    var h = _seed;
    h = 0x1fffffff & (h + col * 0x1f1f1f1f);
    h = 0x1fffffff & (h + row * 0x2545f491);
    h = 0x1fffffff & (h ^ (h >> 6));
    return h % variantCount;
  }
}
