import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../arena_game.dart';

/// Fixed bar at the top of the screen (DECISIONS D-020 — not floating above
/// the player). Added to `camera.viewport`, not `world` (DECISIONS D-040 —
/// superseded D-007's "world size equals screen size" assumption, since the
/// camera now follows the player through a world bigger than the screen) —
/// the viewport is screen-space by construction, so this stays fixed
/// on-screen regardless of where the camera pans.
///
/// Spans the full screen width and sits directly above `XpBarComponent`
/// (DECISIONS D-091, "make XP bar and hp bar both at the top, as long as
/// the screen") — was a small fixed `160x14` box; width now comes from
/// `onGameResize` (same reasoning `XpBarComponent`'s own bottom-position
/// calc already needed one for: the real viewport size isn't known at
/// construction time).
class HpBarComponent extends PositionComponent
    with HasGameReference<ArenaGame> {
  HpBarComponent()
    : super(
        position: Vector2(kHudBarSideMarginPx, kHudBarTopMarginPx),
        size: Vector2(0, kHudBarHeightPx), // x is set for real in onGameResize
        priority: ArenaPriority.hud,
      );

  final _background = Paint()..color = ArenaColors.surfaceAlt;
  final _fill = Paint()..color = ArenaColors.danger; // DECISIONS D-091: "make hp bar red"
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
    final fraction =
        (game.player.hp / game.player.effectiveMaxHp).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x * fraction, size.y), _fill);
    canvas.drawRect(size.toRect(), _border);
  }
}
