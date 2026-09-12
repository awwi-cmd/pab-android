import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../arena_game.dart';

/// Fixed bar at the bottom of the screen (DECISIONS D-076, "like the HP bar
/// up top, add an XP bar at the bottom") — same shape as `HpBarComponent`
/// (background/fill/border, added to `camera.viewport` not `world`), just
/// mirrored to the opposite edge. Unlike the HP bar's fixed `(24, 24)`
/// (size-independent — top-left is top-left on any screen), a *bottom*
/// position needs the actual viewport height, which isn't known at
/// construction time — `onGameResize` (Flame calls this on every mounted
/// component whenever the game resizes, including once on first mount)
/// is what actually places it.
class XpBarComponent extends PositionComponent
    with HasGameReference<ArenaGame> {
  XpBarComponent()
    : super(
        position: Vector2(24, 0), // y is set for real in onGameResize
        size: Vector2(160, 14),
        priority: ArenaPriority.hud,
      );

  static const _bottomMarginPx = 24.0;

  final _background = Paint()..color = ArenaColors.surfaceAlt;
  final _fill = Paint()..color = ArenaColors.accent;
  final _border = Paint()
    ..color = ArenaColors.textDim
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // `size` here is the game's own viewport size (shadowing this
    // component's own `size` field, hence `this.size` below) -- Flame's own
    // base signature names the param this way.
    position.y = size.y - _bottomMarginPx - this.size.y;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _background);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x * game.xpFraction, size.y),
      _fill,
    );
    canvas.drawRect(size.toRect(), _border);
  }
}
