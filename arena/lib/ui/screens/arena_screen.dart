import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/economy.dart';
import '../../core/meta_progression.dart';
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
    // mid-round (DECISIONS D-006). The Upgrades shop's purchases (D-047)
    // are read the same way — the shop itself is only reachable from
    // character-select, never mid-round, so a fresh read here is enough.
    final settings = await SettingsRepository().load();
    final meta = await MetaProgressionRepository().load();
    if (!mounted) return;
    setState(() {
      _game = ArenaGame(
        character: character,
        settings: settings,
        meta: meta,
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
              'ChestReveal': (context, game) => _ChestRevealOverlay(game: game),
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
              _StatRow(label: 'Gems collected', value: '${game.gemsCollected}'),
              const SizedBox(height: 16),
              _CoinCounter(total: game.coinsEarned),
              const SizedBox(height: 16),
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

/// Round Over's money reveal (DECISIONS D-043) — a big red coin
/// (`ui/currency-counter.png`) with the round's total counting up from 0
/// next to it, while a handful of small coins fly in from outside the
/// widget and shrink to nothing right as they reach it (developer's
/// explicit vision: "jumping in the big red coin, with this size reducing
/// like fade out... right exactly when they would hit the coin"). Purely
/// decorative — [ArenaGame.coinsEarned] is already final by the time this
/// builds (round state stops changing once `RoundOver` is showing).
class _CoinCounter extends StatefulWidget {
  const _CoinCounter({required this.total});

  final int total;

  @override
  State<_CoinCounter> createState() => _CoinCounterState();
}

class _CoinCounterState extends State<_CoinCounter>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1600);
  static const _maxFlyingCoins = 10;

  late final AnimationController _controller;
  late final Animation<int> _count;
  late final List<_FlyingCoinSpec> _flyingCoins;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..forward();
    _count = IntTween(begin: 0, end: widget.total).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    final random = Random();
    // Capped regardless of the real total -- a big round shouldn't try to
    // animate hundreds of individual coins.
    final coinCount = widget.total > 0 ? _maxFlyingCoins : 0;
    _flyingCoins = List.generate(coinCount, (i) {
      final startDelay = i / coinCount * 0.5; // staggered, not simultaneous
      return _FlyingCoinSpec(
        fromLeft: random.nextBool(),
        startDistance: 1.2 + random.nextDouble() * 0.8, // x half-width, off-widget
        startYOffset: (random.nextDouble() - 0.5) * 72,
        interval: Interval(
          startDelay,
          (startDelay + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeIn,
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                for (final coin in _flyingCoins)
                  _buildFlyingCoin(coin, constraints.maxWidth),
                // The asset itself reads as a badge/plaque meant to hold a
                // number, not a standalone icon next to one -- the earlier
                // Image+Text Row put the count beside it, which on-device
                // read as "the number is outside the UI panel for it"
                // (2026-09-09). Stacked and centered instead, so the count
                // sits inside the plaque like the art implies.
                SizedBox(
                  width: 128,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/ui/currency-counter.png',
                        width: 128,
                        height: 64,
                        filterQuality: FilterQuality.none,
                      ),
                      Text(
                        '${_count.value}',
                        style: const TextStyle(
                          color: Color(0xFF6B2E00),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlyingCoin(_FlyingCoinSpec coin, double width) {
    // t: 0 at its own start (off-widget, full size), 1 at arrival (at the
    // coin icon, shrunk to nothing) -- exactly the developer's spec.
    final t = coin.interval.transform(_controller.value);
    final startX = (coin.fromLeft ? -1 : 1) * coin.startDistance * width / 2;
    final remaining = 1 - t;
    return Transform.translate(
      offset: Offset(startX * remaining, coin.startYOffset * remaining),
      child: Opacity(
        opacity: remaining,
        child: Transform.scale(
          scale: remaining,
          child: const _SpriteCell(
            asset: 'assets/images/consumables/money.png',
            sheetWidth: 80,
            sheetHeight: 192,
            cellSize: 16,
            column: 0, // tier 0 (common) -- just a generic flying coin
            row: 0,
            displaySize: 26, // bumped from 20 -- too small to notice on-device

          ),
        ),
      ),
    );
  }
}

class _FlyingCoinSpec {
  const _FlyingCoinSpec({
    required this.fromLeft,
    required this.startDistance,
    required this.startYOffset,
    required this.interval,
  });

  final bool fromLeft;
  final double startDistance;
  final double startYOffset;
  final Interval interval;
}

/// Crops one cell out of a sprite sheet for a plain Flutter `Image.asset`
/// (DECISIONS D-043) — used for the flying coins above, since they're a
/// Flutter widget animation (Round Over is a Flutter overlay, D-010), not a
/// Flame component. `OverflowBox` renders the whole sheet at [displaySize]-
/// relative scale and `ClipRect` keeps only the one cell visible; the
/// [Alignment] math positions that cell's pixels at the box's origin.
class _SpriteCell extends StatelessWidget {
  const _SpriteCell({
    required this.asset,
    required this.sheetWidth,
    required this.sheetHeight,
    required this.cellSize,
    required this.column,
    required this.row,
    required this.displaySize,
  });

  final String asset;
  final double sheetWidth;
  final double sheetHeight;
  final double cellSize;
  final int column;
  final int row;
  final double displaySize;

  @override
  Widget build(BuildContext context) {
    final scale = displaySize / cellSize;
    return SizedBox(
      width: displaySize,
      height: displaySize,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: sheetWidth * scale,
          maxHeight: sheetHeight * scale,
          alignment: Alignment(
            2 * (column * cellSize) / (sheetWidth - cellSize) - 1,
            2 * (row * cellSize) / (sheetHeight - cellSize) - 1,
          ),
          child: Image.asset(
            asset,
            width: sheetWidth * scale,
            height: sheetHeight * scale,
            filterQuality: FilterQuality.none,
          ),
        ),
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

/// Chest opening's "fancy popup and reveal of gems & gem count" (DECISIONS
/// D-055, developer's literal spec) — a Flame overlay like LevelUp/
/// PauseMenu, so the world stays visible (dimmed) behind it and the round
/// is genuinely paused for the reveal, not just a floating text. Groups
/// `ArenaGame.pendingChestGems` by rarity so "3 common, 1 rare" reads as a
/// breakdown, not a flat list.
class _ChestRevealOverlay extends StatelessWidget {
  const _ChestRevealOverlay({required this.game});

  final ArenaGame game;

  @override
  Widget build(BuildContext context) {
    final gems = game.pendingChestGems ?? const <ItemRarity>[];
    final counts = <ItemRarity, int>{};
    for (final rarity in gems) {
      counts[rarity] = (counts[rarity] ?? 0) + 1;
    }
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CHEST OPENED!',
                style: TextStyle(
                  color: ArenaColors.accent,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (final rarity in ItemRarity.values)
                    if (counts[rarity] != null) _GemCount(rarity: rarity, count: counts[rarity]!),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '+${gems.length} gems',
                style: const TextStyle(
                  color: ArenaColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ArenaColors.accent),
                  ),
                  onPressed: game.closeChestReveal,
                  child: const Text(
                    'CONTINUE',
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

class _GemCount extends StatelessWidget {
  const _GemCount({required this.rarity, required this.count});

  final ItemRarity rarity;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SpriteCell(
          asset: 'assets/images/consumables/gems.png',
          sheetWidth: 80,
          sheetHeight: 144,
          cellSize: 16,
          column: rarity.index,
          row: 0,
          displaySize: 32,
        ),
        const SizedBox(height: 4),
        Text('x$count', style: const TextStyle(color: ArenaColors.textDim)),
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
