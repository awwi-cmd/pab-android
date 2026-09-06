import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../data/characters.dart';
import '../arena_game.dart';
import '../input/movement_input.dart';

/// Placeholder box until the real sprite lands (Phase 5, TASKS 5.5). Stats
/// come from the selected [CharacterDef] (CLAUDE.md §3.3) — no combat
/// number is computed here; everything reads off `StatBlock`
/// (DECISIONS D-008).
class PlayerComponent extends RectangleComponent
    with HasGameReference<ArenaGame> {
  PlayerComponent({required this.character, required this.input})
      : super(
          size: Vector2(28, 40),
          anchor: Anchor.center,
          paint: Paint()..color = ArenaColors.accent,
          priority: ArenaPriority.player,
        );

  final CharacterDef character;
  final MovementInput input;

  final Vector2 _velocity = Vector2.zero(); // scratch, reused every frame

  @override
  void update(double dt) {
    super.update(dt);

    if (!input.direction.isZero()) {
      _velocity
        ..setFrom(input.direction)
        ..scale(character.stats.moveSpeedPxPerS * dt);
      position.add(_velocity);

      // Horizontal-flip-only facing (PRD §6.2) — no 8-way sprite set.
      if (input.direction.x != 0) {
        scale.x = input.direction.x < 0 ? -1 : 1;
      }
    }

    _clampToSafeArea();
  }

  /// Screen inset by 24px + system safe-area insets (PRD §6.1). Clamping
  /// each axis independently — rather than the whole vector — is what
  /// makes the player slide along the boundary instead of sticking when
  /// moving diagonally into it.
  void _clampToSafeArea() {
    final bounds = game.safeAreaBounds;
    final halfW = size.x / 2;
    final halfH = size.y / 2;
    position.x = position.x.clamp(bounds.left + halfW, bounds.right - halfW);
    position.y = position.y.clamp(bounds.top + halfH, bounds.bottom - halfH);
  }
}
