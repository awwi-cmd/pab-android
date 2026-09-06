import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';

/// Flat floor + arena border (PRD §6.1 — world size equals screen size, no
/// camera scroll, DECISIONS D-007). No tile art exists yet: flat fill +
/// border stroke stand in for it. Swapping to a tiled `SpriteComponent`
/// later (with nearest-neighbour filtering, D-011/D-015) is a one-file
/// change — nothing else references this class's internals.
class ArenaFloor extends PositionComponent {
  ArenaFloor() : super(priority: ArenaPriority.floor);

  final _fill = Paint()..color = ArenaColors.surface;
  final _border = Paint()
    ..color = ArenaColors.surfaceAlt
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size.setFrom(size);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _fill);
    canvas.drawRect(size.toRect(), _border);
  }
}
