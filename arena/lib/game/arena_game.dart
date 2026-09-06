import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/widgets.dart' show EdgeInsets;

import '../core/constants.dart';
import '../core/settings.dart';
import '../data/characters.dart';
import 'components/arena_floor.dart';
import 'components/player.dart';
import 'input/movement_input.dart';

/// Owns round state end to end (CLAUDE.md §4.5) and resets it in
/// `onLoad`/`resetRound` — a fresh arena entry must look exactly like the
/// first one. Elapsed time / kills / damage land here in Phase 4; for now
/// this is just the movement sandbox (Phase 3).
class ArenaGame extends FlameGame {
  ArenaGame({
    required this.character,
    required this.settings,
    this.systemInsets = EdgeInsets.zero,
  });

  final CharacterDef character;
  final Settings settings;

  /// Captured once at arena entry (device notch / gesture-bar insets).
  /// The app is portrait-locked, so this doesn't need to track rotation.
  final EdgeInsets systemInsets;

  static const double kSafeAreaInset = 24;

  /// Read at arena entry, never live-switched mid-round (DECISIONS D-006).
  final MovementInput input = MovementInput();

  late PlayerComponent player;

  /// Flutter-observable mirror of round-over state, so the movement-input
  /// overlay (a Flutter widget, not a Flame overlay) knows to stop
  /// capturing touches once the round has ended.
  final ValueNotifier<bool> roundOver = ValueNotifier(false);

  @override
  Color backgroundColor() => ArenaColors.background;

  /// Screen inset by 24px on all sides plus system safe-area insets
  /// (PRD §6.1). Enemies are not clamped to this — only the player.
  Rect get safeAreaBounds => Rect.fromLTRB(
        kSafeAreaInset + systemInsets.left,
        kSafeAreaInset + systemInsets.top,
        size.x - kSafeAreaInset - systemInsets.right,
        size.y - kSafeAreaInset - systemInsets.bottom,
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    resetRound();
  }

  /// Never carry state across rounds via globals/singletons (CLAUDE.md
  /// §4.5) — this rebuilds the round from a clean slate every time.
  void resetRound() {
    roundOver.value = false;
    input.clear();
    removeAll(children.toList());
    overlays.remove('RoundOver');
    overlays.add('DebugDie');

    add(ArenaFloor());
    player = PlayerComponent(character: character, input: input)
      ..position = size / 2;
    add(player);

    if (settings.showFps) {
      add(FpsTextComponent(position: Vector2(8, 8)));
    }

    resumeEngine();
  }

  /// Debug-only stand-in for HP <= 0 (PRD §3: the arena's only real exit is
  /// death) until Phase 4 wires actual combat into this.
  void debugDie() {
    if (roundOver.value) return;
    roundOver.value = true;
    overlays.remove('DebugDie');
    overlays.add('RoundOver');
    pauseEngine();
  }
}
