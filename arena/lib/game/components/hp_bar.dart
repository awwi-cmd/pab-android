import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../arena_game.dart';

/// Fixed bar at the top of the screen (DECISIONS D-020 — not floating above
/// the player). World size equals screen size with no camera scroll
/// (D-007), so a fixed world position is already a fixed screen position;
/// no separate HUD/viewport plumbing needed.
class HpBarComponent extends PositionComponent
    with HasGameReference<ArenaGame> {
  HpBarComponent()
    : super(
        position: Vector2(24, 24),
        size: Vector2(160, 14),
        priority: ArenaPriority.hud,
      );

  final _background = Paint()..color = ArenaColors.surfaceAlt;
  final _fill = Paint()..color = ArenaColors.accent;
  final _border = Paint()
    ..color = ArenaColors.textDim
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _background);
    final fraction =
        (game.player.hp / game.player.effectiveMaxHp).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x * fraction, size.y), _fill);
    canvas.drawRect(size.toRect(), _border);
  }
}
