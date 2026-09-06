import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/settings.dart';
import '../../data/characters.dart';
import '../../game/arena_game.dart';
import '../../game/input/joystick_overlay.dart';

/// Hosts the single `GameWidget` for the arena (CLAUDE.md §4.1 — Flame owns
/// the arena, Flutter owns everything else). The movement-input overlay is
/// the one deliberate exception: it's Flutter-side touch capture drawn on
/// top of the canvas, not gameplay.
class ArenaScreen extends StatefulWidget {
  const ArenaScreen({super.key});

  static const route = '/arena';

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> {
  ArenaGame? _game;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game == null) {
      final character =
          ModalRoute.of(context)?.settings.arguments as CharacterDef? ??
              kCharacters.first;
      _load(character);
    }
  }

  Future<void> _load(CharacterDef character) async {
    // Control scheme is read once at arena entry, never live-switched
    // mid-round (DECISIONS D-006).
    final settings = await SettingsRepository().load();
    if (!mounted) return;
    setState(() {
      _game = ArenaGame(
        character: character,
        settings: settings,
        systemInsets: MediaQuery.of(context).padding,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) {
      return const Scaffold(backgroundColor: ArenaColors.background);
    }
    return Scaffold(
      backgroundColor: ArenaColors.background,
      body: Stack(
        children: [
          GameWidget<ArenaGame>(
            game: game,
            overlayBuilderMap: {
              'DebugDie': (context, game) => _DebugDieButton(game: game),
              'RoundOver': (context, game) => _RoundOverOverlay(game: game),
            },
            initialActiveOverlays: const ['DebugDie'],
          ),
          // Stop capturing touches once the round ends, so Round Over's
          // Main Menu button (drawn beneath this in the stack, via the
          // GameWidget's own overlay) is still tappable.
          ValueListenableBuilder<bool>(
            valueListenable: game.roundOver,
            builder: (context, isOver, _) {
              if (isOver) return const SizedBox.shrink();
              return MovementInputOverlay(
                input: game.input,
                scheme: game.settings.controlScheme,
                joystickSide: game.settings.joystickSide,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// PRD §3: the arena has no other exit besides death; this is the debug
/// stand-in until Phase 4 wires HP <= 0 into `ArenaGame.debugDie()`.
class _DebugDieButton extends StatelessWidget {
  const _DebugDieButton({required this.game});

  final ArenaGame game;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: TextButton(
          onPressed: game.debugDie,
          child: const Text(
            'DIE (debug)',
            style: TextStyle(color: ArenaColors.danger, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

/// A Flame overlay, not a Flutter route (DECISIONS D-010) — the death frame
/// stays visible, dimmed, behind it. Numbers are still dummy zeros; real
/// round state lands with `ArenaGame`'s round tracking in Phase 4.12.
class _RoundOverOverlay extends StatelessWidget {
  const _RoundOverOverlay({required this.game});

  final ArenaGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ROUND OVER',
                style: TextStyle(
                  color: ArenaColors.danger,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 24),
              const _StatRow(label: 'Time survived', value: '00:00.000'),
              const _StatRow(label: 'Enemies killed', value: '0'),
              const _StatRow(label: 'Damage dealt', value: '0'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ArenaColors.accent),
                  ),
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text(
                    'MAIN MENU',
                    style: TextStyle(color: ArenaColors.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: ArenaColors.textDim)),
          Text(value, style: const TextStyle(color: ArenaColors.textPrimary)),
        ],
      ),
    );
  }
}
