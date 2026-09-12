import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../arena_game.dart';

/// Fixed bar at the top of the screen, directly under `HpBarComponent`
/// (DECISIONS D-091 — "make XP bar and hp bar both at the top, as long as
/// the screen"; was its own small bottom-of-screen box, DECISIONS D-076).
/// Same shape as `HpBarComponent` (background/fill/border, added to
/// `camera.viewport` not `world`, full-width via `onGameResize` since the
/// real viewport size isn't known at construction time) — just stacked
/// under it instead of mirrored to the opposite edge.
class XpBarComponent extends PositionComponent
    with HasGameReference<ArenaGame> {
  XpBarComponent()
    : super(
        position: Vector2(
          kHudBarSideMarginPx,
          kHudBarTopMarginPx + kHudBarHeightPx + kHudBarGapPx,
        ),
        size: Vector2(0, kHudBarHeightPx), // x is set for real in onGameResize
        priority: ArenaPriority.hud,
      );

  final _background = Paint()..color = ArenaColors.surfaceAlt;
  final _fill = Paint()..color = ArenaColors.xp; // DECISIONS D-091: "make xp bar yellow"
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
    this.size.x = size.x - kHudBarSideMarginPx * 2;
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
