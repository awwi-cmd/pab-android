import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/economy.dart';
import '../../core/meta_progression.dart';
import '../../core/progression.dart';
import '../../core/settings.dart';
import '../../core/sfx_player.dart';
import '../../data/characters.dart';
import '../../game/arena_game.dart';
import '../../game/input/joystick_overlay.dart';
import '../widgets/coin_icon.dart';
import '../widgets/gem_icon.dart';
import '../widgets/skill_icon.dart';
import '../widgets/tap_sfx.dart';
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

  /// Android back / edge-swipe used to pop `ArenaScreen` straight off the
  /// Navigator mid-round -- `_endRound` (the only place coins/gems/lifetime
  /// kills get credited, DECISIONS D-047/D-055) never got a chance to run,
  /// so a round in progress could be exited with zero reward, no
  /// confirmation, from a single accidental back press (developer report).
  /// `canPop: false` blocks that default pop; back is redirected to
  /// whatever the deliberate exit path already is for the current state,
  /// same as a tap would do:
  /// - round already over (RoundOver overlay showing, rewards already
  ///   banked) -- back leaves, exactly like its own MAIN MENU button.
  /// - Pause Menu open -- back resumes (mirrors RESUME), doesn't leave.
  /// - LevelUp/ChestReveal open -- back does nothing; those need an
  ///   explicit choice, there's nothing safe to redirect it to.
  /// - actively playing -- back opens the Pause Menu instead of exiting,
  ///   same as tapping the pause button; leaving from there is still one
  ///   deliberate MAIN MENU tap away, just never a bare back press.
  void _handleBack() {
    final game = _game;
    if (game == null) return;
    if (game.roundOver.value) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    if (game.overlays.isActive('PauseMenu')) {
      game.closePauseMenu();
      return;
    }
    if (game.overlays.isActive('LevelUp') ||
        game.overlays.isActive('ChestReveal')) {
      return;
    }
    game.openPauseMenu();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) {
      return const Scaffold(backgroundColor: ArenaColors.background);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: ArenaColors.background,
        body: Stack(
          children: [
            GameWidget<ArenaGame>(
              game: game,
              overlayBuilderMap: {
                'RoundOver': (context, game) => _RoundOverOverlay(game: game),
                'LevelUp': (context, game) => _LevelUpOverlay(game: game),
                'PauseMenu': (context, game) => _PauseMenuOverlay(game: game),
                'ChestReveal': (context, game) =>
                    _ChestRevealOverlay(game: game),
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
          onPressed: withTapSfx(game.debugDie),
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
          onPressed: withTapSfx(game.openPauseMenu),
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
              _StatRow(
                label: 'Damage dealt',
                value: '${game.damageDealt.round()}',
              ),
              _StatRow(label: 'Level reached', value: '${game.level}'),
              const SizedBox(height: 16),
              // DECISIONS D-069/D-071: coins/gems/kills all get the same
              // real-asset icon+counting treatment instead of a plain text
              // stat row. Stacked (not side-by-side) so `_CoinCounter`'s own
              // `LayoutBuilder` still resolves against a real bounded width
              // from the Column, not an unbounded `Row` main axis.
              _CoinCounter(total: game.coinsEarned),
              _GemCounter(total: game.gemsCollected),
              _KillCounter(total: game.kills),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ArenaColors.accent),
                  ),
                  onPressed: withTapSfx(() {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }),
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

/// Round Over's money reveal (DECISIONS D-043, icon swapped to the real
/// coin asset by D-064) — the real coin icon (`CoinIcon`) with the round's
/// total counting up from 0 next to it, while a handful of small coins fly
/// in from outside the widget and shrink to nothing right as they reach it
/// (developer's explicit vision: "jumping in the big red coin, with this
/// size reducing like fade out... right exactly when they would hit the
/// coin"). Purely decorative — [ArenaGame.coinsEarned] is already final by
/// the time this builds (round state stops changing once `RoundOver` is
/// showing).
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
    _count = IntTween(
      begin: 0,
      end: widget.total,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final random = Random();
    // Capped regardless of the real total -- a big round shouldn't try to
    // animate hundreds of individual coins.
    final coinCount = widget.total > 0 ? _maxFlyingCoins : 0;
    _flyingCoins = List.generate(coinCount, (i) {
      final startDelay = i / coinCount * 0.5; // staggered, not simultaneous
      return _FlyingCoinSpec(
        fromLeft: random.nextBool(),
        startDistance:
            1.2 + random.nextDouble() * 0.8, // x half-width, off-widget
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
                // D-064: the old placeholder was a plaque asset with the
                // count stacked inside it; the real coin icon is just a
                // coin, so this is an icon+text row like every other
                // wallet display (character select, upgrades) instead.
                SizedBox(
                  width: 128,
                  height: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CoinIcon(size: 48),
                      const SizedBox(width: 10),
                      Text(
                        '${_count.value}',
                        style: const TextStyle(
                          color: ArenaColors.accent,
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
            // D-064: the real coin icon asset, not the generic tier-0
            // money sprite -- same single-row sheet `CoinIcon` crops.
            asset: 'assets/images/consumables/coin-icon.png',
            sheetWidth: 240,
            sheetHeight: 16,
            cellSize: 16,
            column: 0,
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

/// Round Over's gem reveal (DECISIONS D-069, flying pieces + sparkle VFX
/// added D-070 — "same animation gems in end of match screen that coins
/// have... add more VFX to them") — the real gem icon (`GemIcon`, legendary
/// tier) with the round's `gemsCollected` total counting up from 0, small
/// gem sprites flying in and shrinking exactly like `_CoinCounter`'s coins,
/// plus a looping twinkle burst (`_GemSparkleSpec`) orbiting the icon that
/// coins don't get — gems are the premium currency, so this reveal reads a
/// notch fancier than the coin one rather than an identical reskin.
class _GemCounter extends StatefulWidget {
  const _GemCounter({required this.total});

  final int total;

  @override
  State<_GemCounter> createState() => _GemCounterState();
}

class _GemCounterState extends State<_GemCounter>
    with TickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1600);
  static const _maxFlyingGems = 10;

  late final AnimationController _controller;
  late final Animation<int> _count;
  late final List<_FlyingCoinSpec> _flyingGems;

  /// The extra VFX coins don't have — a handful of sparkle glints looping
  /// around the gem icon for as long as the overlay is up, independent of
  /// the count-up (which finishes and stops).
  static const _sparkleDuration = Duration(milliseconds: 2400);
  late final AnimationController _sparkleController;
  late final List<_GemSparkleSpec> _sparkles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..forward();
    _count = IntTween(
      begin: 0,
      end: widget.total,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final random = Random();
    // Capped regardless of the real total, same reasoning as _CoinCounter.
    final gemCount = widget.total > 0 ? _maxFlyingGems : 0;
    _flyingGems = List.generate(gemCount, (i) {
      final startDelay = i / gemCount * 0.5; // staggered, not simultaneous
      return _FlyingCoinSpec(
        fromLeft: random.nextBool(),
        startDistance:
            1.2 + random.nextDouble() * 0.8, // x half-width, off-widget
        startYOffset: (random.nextDouble() - 0.5) * 72,
        interval: Interval(
          startDelay,
          (startDelay + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeIn,
        ),
      );
    });

    _sparkleController = AnimationController(
      vsync: this,
      duration: _sparkleDuration,
    )..repeat();
    _sparkles = List.generate(6, (i) {
      final angle = i / 6 * 2 * pi;
      return _GemSparkleSpec(
        dx: cos(angle) * (30 + random.nextDouble() * 10),
        dy: sin(angle) * (18 + random.nextDouble() * 8),
        phase: random.nextDouble(),
        size: 12 + random.nextDouble() * 8,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _sparkleController]),
            builder: (context, _) => Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                for (final gem in _flyingGems)
                  _buildFlyingGem(gem, constraints.maxWidth),
                SizedBox(
                  width: 128,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final sparkle in _sparkles) _buildSparkle(sparkle),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const GemIcon(size: 40),
                          const SizedBox(width: 10),
                          Text(
                            '${_count.value}',
                            style: const TextStyle(
                              color: ArenaColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

  /// Same flight math `_CoinCounterState._buildFlyingCoin` uses, rendering
  /// the legendary-tier gem cell instead of the coin cell.
  Widget _buildFlyingGem(_FlyingCoinSpec gem, double width) {
    final t = gem.interval.transform(_controller.value);
    final startX = (gem.fromLeft ? -1 : 1) * gem.startDistance * width / 2;
    final remaining = 1 - t;
    return Transform.translate(
      offset: Offset(startX * remaining, gem.startYOffset * remaining),
      child: Opacity(
        opacity: remaining,
        child: Transform.scale(
          scale: remaining,
          child: const _SpriteCell(
            asset: 'assets/images/consumables/gems.png',
            sheetWidth: 80,
            sheetHeight: 144,
            cellSize: 16,
            column: 4, // legendary -- same tier GemIcon crops
            row: 0,
            displaySize: 26,
          ),
        ),
      ),
    );
  }

  /// One twinkle glint — fades and grows in, then back out, on its own
  /// looping local timeline (`_sparkleController` + [_GemSparkleSpec.phase]
  /// staggers each one so they don't all pulse in lockstep).
  Widget _buildSparkle(_GemSparkleSpec sparkle) {
    final t = (_sparkleController.value + sparkle.phase) % 1.0;
    final opacity = (t < 0.5 ? t / 0.5 : 1 - (t - 0.5) / 0.5).clamp(0.0, 1.0);
    return Positioned(
      left: 64 + sparkle.dx - sparkle.size / 2,
      top: 32 + sparkle.dy - sparkle.size / 2,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: 0.6 + 0.4 * opacity,
          child: Icon(
            Icons.auto_awesome,
            size: sparkle.size,
            color: ArenaColors.accent,
          ),
        ),
      ),
    );
  }
}

class _GemSparkleSpec {
  const _GemSparkleSpec({
    required this.dx,
    required this.dy,
    required this.phase,
    required this.size,
  });

  /// Fixed offset from the gem icon's own center — the sparkle orbits
  /// nowhere, it just blinks in place at this spot (cheaper, and reads fine
  /// for a small twinkle burst).
  final double dx;
  final double dy;

  /// Where in the shared [AnimationController]'s loop this piece starts its
  /// own fade in/out cycle, so the 6 sparkles don't pulse in lockstep.
  final double phase;
  final double size;
}

/// Round Over's kill-count reveal (DECISIONS D-071, "add the kills in end
/// of match screen as well, use the hollow star... turn it a golden star
/// with the same jump and land animation the card has") — the hollow star
/// (`star-empty.png`) with `game.kills` counting up, small golden stars
/// (`star-full.png`) flying in exactly like `_CoinCounter`'s coins, and the
/// instant the count finishes, the center icon itself swaps to the golden
/// star and plays the *exact* jump/land bounce `_ChestRevealOverlay`'s card
/// landing uses (same tween weights/curves/duration) — reused directly
/// rather than a second hand-tuned bounce.
class _KillCounter extends StatefulWidget {
  const _KillCounter({required this.total});

  final int total;

  @override
  State<_KillCounter> createState() => _KillCounterState();
}

class _KillCounterState extends State<_KillCounter>
    with TickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1600);
  static const _maxFlyingStars = 10;

  static const _starEmptyAsset = 'assets/images/ui/star-empty.png';
  static const _starFullAsset = 'assets/images/ui/star-full.png';

  late final AnimationController _controller;
  late final Animation<int> _count;
  late final List<_FlyingCoinSpec> _flyingStars;

  /// The landing bounce — identical shape to `_ChestRevealOverlayState`'s
  /// own `_landController`/`_jumpOffset` (same 520ms duration, same 35/65
  /// easeOut-then-bounceOut weights) so a star "landing" reads as the same
  /// physical event a card landing does, not a different one that happens
  /// to look similar.
  late final AnimationController _landController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _jumpOffset = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: -22.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: -22.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.bounceOut)),
      weight: 65,
    ),
  ]).animate(_landController);

  /// Flips from the hollow star to the golden one the instant the count-up
  /// finishes, in lockstep with [_landController] firing.
  bool _golden = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        setState(() => _golden = true);
        _landController.forward(from: 0);
      })
      ..forward();
    _count = IntTween(
      begin: 0,
      end: widget.total,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final random = Random();
    final starCount = widget.total > 0 ? _maxFlyingStars : 0;
    _flyingStars = List.generate(starCount, (i) {
      final startDelay = i / starCount * 0.5;
      return _FlyingCoinSpec(
        fromLeft: random.nextBool(),
        startDistance: 1.2 + random.nextDouble() * 0.8,
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
    _landController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: Listenable.merge([_controller, _landController]),
            builder: (context, _) => Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                for (final star in _flyingStars)
                  _buildFlyingStar(star, constraints.maxWidth),
                Transform.translate(
                  offset: Offset(0, _jumpOffset.value),
                  child: SizedBox(
                    width: 128,
                    height: 64,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          _golden ? _starFullAsset : _starEmptyAsset,
                          height: 40,
                          filterQuality: FilterQuality.none,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_count.value}',
                          style: const TextStyle(
                            color: ArenaColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Same flight math `_CoinCounterState._buildFlyingCoin` uses, rendering
  /// the golden star sprite directly (a standalone image, not a sheet, so
  /// no `_SpriteCell` crop needed).
  Widget _buildFlyingStar(_FlyingCoinSpec star, double width) {
    final t = star.interval.transform(_controller.value);
    final startX = (star.fromLeft ? -1 : 1) * star.startDistance * width / 2;
    final remaining = 1 - t;
    return Transform.translate(
      offset: Offset(startX * remaining, star.startYOffset * remaining),
      child: Opacity(
        opacity: remaining,
        child: Transform.scale(
          scale: remaining,
          child: Image.asset(
            _starFullAsset,
            height: 26,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }
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
          // A single-row or single-column sheet (D-064's coin-icon.png:
          // one row) makes the denominator 0 -- there's nothing to
          // interpolate between when there's only one cell along that
          // axis, and any alignment value crops the same pixels, so pin
          // it to 0 instead of dividing by 0 (NaN, a broken Alignment).
          alignment: Alignment(
            sheetWidth == cellSize
                ? 0
                : 2 * (column * cellSize) / (sheetWidth - cellSize) - 1,
            sheetHeight == cellSize
                ? 0
                : 2 * (row * cellSize) / (sheetHeight - cellSize) - 1,
          ),
          child: Image.asset(
            asset,
            width: sheetWidth * scale,
            height: sheetHeight * scale,
            // D-064: without an explicit fit, `Image`'s default
            // (`BoxFit.scaleDown`) never scales UP -- since every sheet
            // here is smaller than this scaled-up box, it drew at native
            // pixel size centered in it, nowhere near the small cropped
            // window this widget actually shows through (the coin/gem/
            // potion cell rendered invisible this whole time, D-043
            // onward). `fill` stretches it to exactly width/height,
            // matching the `scale` this crop math assumes.
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }
}

/// Level-up popup (DECISIONS D-025, redesigned D-072): game is paused, pick
/// 1 of 3, with a way to check what's been picked so far and go back to the
/// choice. The choice list is `_LevelUpCard`s now, not bare
/// `OutlinedButton`s — bordered panels with a category tag and (for the 4
/// mutually-exclusive skills, DECISIONS D-072) a visible "EXCLUSIVE"
/// warning, wrapped in a `SingleChildScrollView` so a long description can
/// never overflow the popup regardless of screen height (same fix
/// `_ChestRevealOverlay` already uses, D-058).
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
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: _showingUpgrades ? _buildUpgradeList() : _buildChoices(),
        ),
      ),
    );
  }

  Widget _buildChoices() {
    final game = widget.game;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'LEVEL UP!',
          textAlign: TextAlign.center,
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
          textAlign: TextAlign.center,
          style: TextStyle(color: ArenaColors.textDim),
        ),
        const SizedBox(height: 20),
        for (final kind in game.currentLevelUpChoices) ...[
          _LevelUpCard(kind: kind, onTap: () => game.resolveLevelUpChoice(kind)),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        TextButton(
          onPressed: withTapSfx(() => setState(() => _showingUpgrades = true)),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'YOUR UPGRADES',
          textAlign: TextAlign.center,
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
                Expanded(
                  child: Text(
                    kind.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ArenaColors.textPrimary),
                  ),
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
            onPressed: withTapSfx(() => setState(() => _showingUpgrades = false)),
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

/// One LevelUp choice (DECISIONS D-072) — a bordered panel with a left
/// accent stripe, an icon badge (DECISIONS D-078 — the real skill's own
/// game art, not just text, was the missing "doesn't look cheap" piece),
/// a label + category tag row, and the *full* description underneath with
/// no truncation. Replaces the old bare `OutlinedButton` (fixed vertical
/// padding, no wrap guarantees), which is what let a long description
/// overflow the popup on a short screen. Exclusive skills
/// (`isExclusiveUpgrade`) swap the accent stripe/tag to danger-red and add
/// a "Locks out: X" line naming the real paired partner(s) (D-072/D-078),
/// so the tradeoff is visible before tapping, not discovered by their
/// absence next level. A soft drop shadow (DECISIONS D-078) gives the flat
/// bordered panel some real depth instead of reading as a plain outline.
class _LevelUpCard extends StatelessWidget {
  const _LevelUpCard({required this.kind, required this.onTap});

  final UpgradeKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final exclusive = isExclusiveUpgrade(kind);
    final accent = exclusive ? ArenaColors.warning : ArenaColors.accent;
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: ArenaColors.surface,
        child: InkWell(
          onTap: withTapSfx(onTap),
          child: Container(
            // A double border (outer dim, inner accent) reads as a carved
            // panel edge rather than a single flat outline.
            decoration: BoxDecoration(
              border: Border.all(color: ArenaColors.textDim),
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: accent)),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 5, color: accent),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: SkillIcon(kind: kind, accent: accent),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    kind.label,
                                    style: const TextStyle(
                                      color: ArenaColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _Tag(
                                  text: exclusive ? 'EXCLUSIVE' : kind.tag,
                                  color: accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              kind.description,
                              style: const TextStyle(
                                color: ArenaColors.textDim,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            if (exclusive) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Locks out: ${exclusiveLockTargets(kind).map((k) => k.label).join(', ')}.',
                                style: const TextStyle(
                                  color: ArenaColors.warning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Small bordered category badge — `STAT`/`SKILL`/`PASSIVE`
/// (`UpgradeKindLabels.tag`) or `EXCLUSIVE` for the 4 grouped skills.
class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Chest opening's "fancy popup and reveal of gems & gem count" (DECISIONS
/// D-057/D-058, superseding D-055's flat gem-group reward) — a Flame overlay
/// like LevelUp/PauseMenu, so the world stays visible (dimmed) behind it and
/// the round is genuinely paused for the reveal. The actual reward
/// (`ArenaGame.pendingChestCard`) is already rolled by the time this opens
/// (`ChestComponent`/`ArenaGame.onChestOpened`); what this widget owns is
/// purely the reveal *animation*: a quick card-back shuffle, transitioning
/// into flicker through random face-up cards from the deck really fast,
/// easing out to a stop on the real card, which then does a little jump/land
/// (DECISIONS D-058) before showing what it actually pays.
class _ChestRevealOverlay extends StatefulWidget {
  const _ChestRevealOverlay({required this.game});

  final ArenaGame game;

  @override
  State<_ChestRevealOverlay> createState() => _ChestRevealOverlayState();
}

class _ChestRevealOverlayState extends State<_ChestRevealOverlay>
    with TickerProviderStateMixin {
  static final Random _random = Random();

  /// DECISIONS D-058: "add another animation before the current one, that
  /// goes between back cards, and after that transition to this one" — a
  /// short shuffle through the 2 card backs before the real face-card spin
  /// ever starts, same flat-rate flicker the face spin's own fastest steps
  /// use (no ease-out here, it's a lead-in beat, not the landing).
  static const _shuffleSteps = 8;
  static const _shuffleStepMs = 70;
  static const _backAssetPaths = [
    'assets/images/cards/Back Cards/Blue.png',
    'assets/images/cards/Back Cards/Red.png',
  ];

  /// DECISIONS D-057: "change really fast randomly, stop on one at the
  /// end" — [_spinSteps] flicker steps through a random deck card each,
  /// the per-step delay ramping from [_minStepMs] up to [_maxStepMs] (an
  /// ease-out quadratic, not a flat rate) so it reads as a slot-reel
  /// genuinely slowing down into its landing rather than just stopping
  /// abruptly. The real result is never shown mid-flicker — only the very
  /// last step lands on [_finalCard].
  static const _spinSteps = 22;
  static const _minStepMs = 45;
  static const _maxStepMs = 260;

  late final ChestCard _finalCard = widget.game.pendingChestCard!;
  String _displayedAsset = _backAssetPaths.first;
  bool _shuffling = true;
  bool _spinning = true;
  int _step = 0;
  Timer? _timer;

  /// DECISIONS D-058: a small jump-then-land bounce plays once the spin
  /// actually lands on [_finalCard] — a quick hop up (`Curves.easeOut`)
  /// followed by a bouncy drop back to rest (`Curves.bounceOut`), not a
  /// symmetric tween, so it reads as landing rather than floating.
  late final AnimationController _landController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _jumpOffset = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: -22.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: -22.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.bounceOut)),
      weight: 65,
    ),
  ]).animate(_landController);

  /// DECISIONS D-072 ("the confetti for the chests is not it... come up
  /// with a different VFX when the card is chosen, remove the confetti") —
  /// replaces the old rotated-rect confetti burst (D-061/D-063) with a
  /// radial sparkle burst, reusing the exact same `Icons.auto_awesome`
  /// glint look the gem counter's own sparkle VFX already established
  /// (D-070) rather than inventing a third visual language for "something
  /// good just landed." Fires alongside [_landController] the instant the
  /// spin lands, once (not looping like the gem counter's).
  static const _burstCount = 14;
  static const _burstDurationMs = 750;

  late final AnimationController _burstController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _burstDurationMs),
  );
  late final List<_CardLandSparkleSpec> _landSparkles = _buildLandSparkles();

  /// Every sparkle radiates outward from the card's own center at a random
  /// angle/distance, each with its own [_CardLandSparkleSpec.delay] so the
  /// burst reads as individual glints firing outward over a beat rather
  /// than one uniform ring expanding in lockstep.
  List<_CardLandSparkleSpec> _buildLandSparkles() {
    return [
      for (var i = 0; i < _burstCount; i++)
        _CardLandSparkleSpec(
          angle: _random.nextDouble() * 2 * pi,
          distancePx: 60 + _random.nextDouble() * 70,
          size: 14 + _random.nextDouble() * 12,
          delay: _random.nextDouble() * 0.25,
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _scheduleShuffleStep();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _landController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  ChestCard _randomFlickerCard() =>
      kChestDeck[_random.nextInt(kChestDeck.length)];

  void _scheduleShuffleStep() {
    _step++;
    if (_step > _shuffleSteps) {
      // Shuffle's done -- transition straight into the real face-card spin.
      _shuffling = false;
      _displayedAsset = _randomFlickerCard().assetPath;
      _step = 0;
      SfxPlayer.instance.playChestCardSelect();
      _scheduleNextStep();
      return;
    }
    _timer = Timer(const Duration(milliseconds: _shuffleStepMs), () {
      if (!mounted) return;
      setState(
        () => _displayedAsset = _backAssetPaths[_step % _backAssetPaths.length],
      );
      // DECISIONS D-076: "play it once with every card swap and change its
      // pitch each time" -- every shuffle/spin step is a swap.
      SfxPlayer.instance.playChestCardSelect();
      _scheduleShuffleStep();
    });
  }

  void _scheduleNextStep() {
    _step++;
    if (_step >= _spinSteps) {
      _timer = Timer(const Duration(milliseconds: _maxStepMs), () {
        if (!mounted) return;
        setState(() {
          _displayedAsset = _finalCard.assetPath;
          _spinning = false;
        });
        // DECISIONS D-076: the landing payoff, not another select swap.
        SfxPlayer.instance.playChestCardChosen();
        _landController.forward(from: 0);
        _burstController.forward(from: 0);
      });
      return;
    }
    final t = _step / _spinSteps;
    final delayMs = _minStepMs + ((_maxStepMs - _minStepMs) * t * t).round();
    _timer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      setState(() => _displayedAsset = _randomFlickerCard().assetPath);
      SfxPlayer.instance.playChestCardSelect();
      _scheduleNextStep();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      // The sparkle burst sits in its own full-screen layer on top of the
      // card content, same reasoning confetti used to have (DECISIONS
      // D-061): it radiates well past the card's own bounds, and the
      // scrollable content Column below would clip anything positioned
      // outside its own viewport.
      child: Stack(
        children: [
          _buildContent(),
          // DECISIONS D-074 bugfix: only mounted once the spin has actually
          // landed. Every sparkle's fade-envelope reads as fully opaque and
          // un-offset at the controller's own rest value (0, before
          // `.forward()` is ever called) -- with no gate here, that meant a
          // clump of 14 fully-visible glints sitting dead-center on the
          // card for the *entire* shuffle+spin, before the reveal ever
          // fired ("we can see where we're storing them before we choose
          // the card").
          if (!_shuffling && !_spinning)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _burstController,
                  builder: (context, _) => Stack(
                    children: [
                      for (final sparkle in _landSparkles)
                        _buildLandSparkle(sparkle),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// One glint of the landing burst — same fade/scale envelope
  /// `_GemCounterState._buildSparkle` uses, but firing outward from the
  /// center once instead of blinking in place on a loop.
  Widget _buildLandSparkle(_CardLandSparkleSpec sparkle) {
    final raw = ((_burstController.value - sparkle.delay) / (1 - sparkle.delay))
        .clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(raw);
    final opacity = (1 - raw).clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox.shrink();
    final offset = Offset(cos(sparkle.angle), sin(sparkle.angle)) *
        sparkle.distancePx *
        eased;
    return Align(
      alignment: Alignment.center,
      child: Transform.translate(
        offset: offset,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: 0.6 + 0.4 * (1 - raw),
            child: Icon(
              Icons.auto_awesome,
              size: sparkle.size,
              color: ArenaColors.accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Center(
      // DECISIONS D-058 bugfix: on a short screen the fixed-height reward
      // slot below pushed the total past the available height ("bottom
      // overflowed by 4.0 pixels") -- scrollable so it never can again,
      // while still centering normally whenever it already fits.
      child: SingleChildScrollView(
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
            // DECISIONS D-078 ("I can still see the sparkles of the card
            // being on screen, before the card is chosen") — the D-074
            // ambient corner-sparkle idea read as exactly that complaint in
            // practice regardless of being "behind" the card, so it's gone
            // outright: no sparkle VFX at all until the spin actually
            // lands (the burst layer below already only mounts then).
            AnimatedBuilder(
              animation: _jumpOffset,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _jumpOffset.value),
                child: child,
              ),
              child: _PlayingCardImage(assetPath: _displayedAsset),
            ),
            const SizedBox(height: 12),
            // A *minimum* height so the "..." placeholder doesn't leave a
            // jarring gap while still spinning/shuffling -- DECISIONS
            // D-060 bugfix: this used to be a fixed `SizedBox(height: 46)`
            // clipping its child, which the 2-line reward text (label +
            // "+N gems", each with real font line-height) was a few
            // pixels taller than -- "BOTTOM OVERFLOWED BY 4.0 PIXELS",
            // reproducing every time regardless of the outer
            // SingleChildScrollView (that fixes the *overlay* overflowing
            // its screen; this was a separate, smaller `RenderFlex`
            // overflowing its own fixed box further down the tree).
            // `minHeight` can only grow this box to fit its real content,
            // never clip it, so it can't overflow again even if the copy
            // or font changes later.
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 46),
              child: Center(
                child: (_shuffling || _spinning)
                    ? const Text(
                        '...',
                        style: TextStyle(
                          color: ArenaColors.textDim,
                          fontSize: 18,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _finalCard.label,
                            style: const TextStyle(
                              color: ArenaColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+${_finalCard.gemReward} gems',
                            style: const TextStyle(
                              color: ArenaColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ArenaColors.accent),
                ),
                // Disabled mid-shuffle/spin so the popup can't be dismissed
                // before the real card (and its payout) has actually landed.
                onPressed: (_shuffling || _spinning)
                    ? null
                    : withTapSfx(widget.game.closeChestReveal),
                child: Text(
                  'CONTINUE',
                  style: TextStyle(
                    color: (_shuffling || _spinning)
                        ? ArenaColors.textDim
                        : ArenaColors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One glint of the chest-landing sparkle burst (DECISIONS D-072) — fires
/// outward from the card's own center at [angle] for [distancePx], staggered
/// by [delay] so the burst reads as individual glints over a beat rather
/// than one ring expanding in lockstep.
class _CardLandSparkleSpec {
  const _CardLandSparkleSpec({
    required this.angle,
    required this.distancePx,
    required this.size,
    required this.delay,
  });

  final double angle;
  final double distancePx;
  final double size;
  final double delay;
}

/// One playing-card image (`assets/images/cards`, DECISIONS D-057/D-058),
/// native 61x93 px, rendered flat (no flip/3D) since the spin itself is what
/// sells the slot-machine feel — a flip animation on top of an already-fast
/// flicker would just read as noisy. Takes a raw asset path rather than a
/// [ChestCard] so the same widget renders both the shuffle phase's card
/// backs and the spin phase's faces.
class _PlayingCardImage extends StatelessWidget {
  const _PlayingCardImage({required this.assetPath});

  final String assetPath;

  static const _width = 110.0;
  static const _aspect = 93 / 61;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _width * _aspect,
      child: Image.asset(
        assetPath,
        filterQuality: FilterQuality.none, // D-011
        fit: BoxFit.fill,
      ),
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
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
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
        onPressed: withTapSfx(onPressed),
        child: Text(label, style: const TextStyle(color: ArenaColors.accent)),
      ),
    );
  }
}
