import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/progression.dart';
import '../../core/settings.dart';
import '../../data/characters.dart';
import '../../game/arena_game.dart';
import '../../game/input/joystick_overlay.dart';
import 'settings_screen.dart';

/// Hosts the single `GameWidget` for the arena (CLAUDE.md §4.1 — Flame owns
/// the arena, Flutter owns everything else). The movement-input overlay,
/// debug-die button and pause button are the deliberate exceptions: plain
/// Flutter widgets drawn on top of the canvas, not gameplay.
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
              'RoundOver': (context, game) => _RoundOverOverlay(game: game),
              'LevelUp': (context, game) => _LevelUpOverlay(game: game),
              'PauseMenu': (context, game) => _PauseMenuOverlay(game: game),
            },
          ),
          // Hidden once the round ends OR a menu/popup owns the screen
          // (DECISIONS D-025) -- neither the joystick nor these buttons
          // should be reachable underneath an overlay.
          ValueListenableBuilder<bool>(
            valueListenable: game.roundOver,
            builder: (context, isOver, _) {
              if (isOver) return const SizedBox.shrink();
              return ValueListenableBuilder<bool>(
                valueListenable: game.menuOpen,
                builder: (context, isMenuOpen, _) {
                  if (isMenuOpen) return const SizedBox.shrink();
                  return Stack(
                    children: [
                      MovementInputOverlay(
                        input: game.input,
                        scheme: game.settings.controlScheme,
                        joystickSide: game.settings.joystickSide,
                      ),
                      _DebugDieButton(game: game),
                      _PauseButton(game: game),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// PRD §3: the arena has no other exit besides death; this is the debug
/// stand-in until real combat reliably kills the player.
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

/// Top-right pause button (developer's spec). Opens the Pause Menu overlay.
class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.game});

  final ArenaGame game;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: SafeArea(
        child: IconButton(
          onPressed: game.openPauseMenu,
          icon: const Icon(Icons.pause_circle_outline),
          color: ArenaColors.textPrimary,
          iconSize: 28,
        ),
      ),
    );
  }
}

/// A Flame overlay, not a Flutter route (DECISIONS D-010) — the death frame
/// stays visible, dimmed, behind it. Real round state (TASKS 4.12).
class _RoundOverOverlay extends StatelessWidget {
  const _RoundOverOverlay({required this.game});

  final ArenaGame game;

  static String _formatElapsed(double seconds) {
    final whole = seconds.floor();
    final minutes = whole ~/ 60;
    final secs = whole % 60;
    final millis = ((seconds - whole) * 1000).round();
    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }

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
              _StatRow(
                label: 'Time survived',
                value: _formatElapsed(game.elapsed),
              ),
              _StatRow(label: 'Enemies killed', value: '${game.kills}'),
              _StatRow(
                label: 'Damage dealt',
                value: '${game.damageDealt.round()}',
              ),
              _StatRow(label: 'Level reached', value: '${game.level}'),
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

/// Level-up popup (DECISIONS D-025): game is paused, pick 1 of 3, with a
/// way to check what's been picked so far and go back to the choice.
class _LevelUpOverlay extends StatefulWidget {
  const _LevelUpOverlay({required this.game});

  final ArenaGame game;

  @override
  State<_LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<_LevelUpOverlay> {
  bool _showingUpgrades = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _showingUpgrades ? _buildUpgradeList() : _buildChoices(),
        ),
      ),
    );
  }

  Widget _buildChoices() {
    final game = widget.game;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'LEVEL UP!',
          style: TextStyle(
            color: ArenaColors.accent,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose 1 of 3',
          style: TextStyle(color: ArenaColors.textDim),
        ),
        const SizedBox(height: 24),
        for (final kind in game.currentLevelUpChoices) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ArenaColors.accent),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => game.resolveLevelUpChoice(kind),
              child: Column(
                children: [
                  Text(
                    kind.label,
                    style: const TextStyle(
                      color: ArenaColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kind.description,
                    style: const TextStyle(
                      color: ArenaColors.textDim,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextButton(
          onPressed: () => setState(() => _showingUpgrades = true),
          child: const Text(
            'VIEW YOUR UPGRADES',
            style: TextStyle(color: ArenaColors.textDim),
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeList() {
    final counts = widget.game.upgrades.pickCounts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'YOUR UPGRADES',
          style: TextStyle(
            color: ArenaColors.accent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        for (final kind in UpgradeKind.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  kind.label,
                  style: const TextStyle(color: ArenaColors.textPrimary),
                ),
                Text(
                  'x${counts[kind] ?? 0}',
                  style: const TextStyle(color: ArenaColors.textDim),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: ArenaColors.accent),
            ),
            onPressed: () => setState(() => _showingUpgrades = false),
            child: const Text(
              'BACK',
              style: TextStyle(color: ArenaColors.accent),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pause menu (developer's spec): Resume, Settings, Main Menu. Settings
/// opened from here carries the live `ArenaGame` so it can show debug
/// tools that don't exist when Settings is opened from the main menu.
class _PauseMenuOverlay extends StatelessWidget {
  const _PauseMenuOverlay({required this.game});

  final ArenaGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'PAUSED',
                style: TextStyle(
                  color: ArenaColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 24),
              _menuButton(
                context,
                label: 'RESUME',
                onPressed: game.closePauseMenu,
              ),
              const SizedBox(height: 12),
              _menuButton(
                context,
                label: 'SETTINGS',
                onPressed: () => Navigator.of(context).pushNamed(
                  SettingsScreen.route,
                  arguments: SettingsScreenArgs(debugGame: game),
                ),
              ),
              const SizedBox(height: 12),
              _menuButton(
                context,
                label: 'MAIN MENU',
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: ArenaColors.accent),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(color: ArenaColors.accent)),
      ),
    );
  }
}
