import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/widgets.dart' show TextStyle, FontWeight;

import '../../core/constants.dart';
import '../arena_game.dart';

/// "Lv N" label (DECISIONS D-009 — the player's level wasn't shown
/// anywhere on screen during a round at all). Overlaid on the HP bar's own
/// left edge rather than a new HUD row of its own — `ArenaGame.resetRound`
/// adds this to the HUD right after `HpBarComponent`, so same-priority
/// (`ArenaPriority.hud`) draw order puts it on top of the bar's fill, not
/// underneath it.
class LevelTextComponent extends TextComponent with HasGameReference<ArenaGame> {
  LevelTextComponent()
    : super(
        position: Vector2(
          kHudBarSideMarginPx + 6,
          kHudBarTopMarginPx + kHudBarHeightPx / 2,
        ),
        anchor: Anchor.centerLeft,
        priority: ArenaPriority.hud,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: ArenaColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );

  @override
  void update(double dt) {
    super.update(dt);
    // Cheap to just re-set every frame rather than diffing against the
    // last-rendered value -- this is one short string, not a hot loop over
    // many entities (CLAUDE.md §4.4's "no allocation in hot loops" is about
    // per-enemy/per-projectile work, not a single HUD label).
    text = 'Lv ${game.level}';
  }
}
