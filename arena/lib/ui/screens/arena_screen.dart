import 'dart:async';
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

  /// DECISIONS D-061 ("throw some confetti from outside the screen, from
  /// left and right, landing in front and in the back of the card when we
  /// land it") — fires alongside [_landController] the instant the spin
  /// lands. Built from scratch with a `CustomPainter` rather than a
  /// confetti package (CLAUDE.md §4.9: no new dependencies) — plain
  /// rotated rects are enough for a short burst, no image asset exists for
  /// this either.
  static const _confettiCount = 26;
  static const _confettiDurationMs = 950;
  static const _confettiColors = [
    Color(0xFFE0526C), // ArenaColors.danger
    Color(0xFFF5C542), // amber
    Color(0xFF6CE0B8), // ArenaColors.accent
    Color(0xFF4FA8E0), // blue
    Color(0xFFE07BE0), // pink
  ];

  late final AnimationController _confettiController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _confettiDurationMs),
  );
  late final List<_ConfettiParticle> _confettiParticles = _buildConfetti();

  /// Half the particles start off-screen left, half off-screen right
  /// (`Alignment` values beyond ±1 resolve outside the box, exactly what
  /// "from outside the screen" needs); independently, half are [front]
  /// (painted on top of the card) and half aren't (painted behind it) —
  /// "landing in front and in the back of the card."
  List<_ConfettiParticle> _buildConfetti() {
    return [
      for (var i = 0; i < _confettiCount; i++)
        _ConfettiParticle(
          startAlign: Alignment(
            (i.isEven ? -1 : 1) * (1.4 + _random.nextDouble() * 0.9),
            -0.4 + _random.nextDouble() * 0.8,
          ),
          endAlign: Alignment(
            -0.4 + _random.nextDouble() * 0.8,
            -0.2 + _random.nextDouble() * 0.6,
          ),
          color: _confettiColors[_random.nextInt(_confettiColors.length)],
          size: 7 + _random.nextDouble() * 6,
          rotationTurns: 1 + _random.nextDouble() * 2.5,
          arcHeight: 0.12 + _random.nextDouble() * 0.18,
          front: i.isOdd,
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
    _confettiController.dispose();
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
      _scheduleNextStep();
      return;
    }
    _timer = Timer(const Duration(milliseconds: _shuffleStepMs), () {
      if (!mounted) return;
      setState(
        () => _displayedAsset = _backAssetPaths[_step % _backAssetPaths.length],
      );
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
        _landController.forward(from: 0);
        _confettiController.forward(from: 0);
      });
      return;
    }
    final t = _step / _spinSteps;
    final delayMs = _minStepMs + ((_maxStepMs - _minStepMs) * t * t).round();
    _timer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      setState(() => _displayedAsset = _randomFlickerCard().assetPath);
      _scheduleNextStep();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      // Confetti sits in its own full-screen Stack layers, not inside the
      // scrollable content Column below -- it has to fly in from genuinely
      // off-screen (DECISIONS D-061), and the SingleChildScrollView would
      // clip anything positioned outside its own viewport.
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _ConfettiLayer(
                controller: _confettiController,
                particles: _confettiParticles,
                front: false,
              ),
            ),
          ),
          _buildContent(),
          Positioned.fill(
            child: IgnorePointer(
              child: _ConfettiLayer(
                controller: _confettiController,
                particles: _confettiParticles,
                front: true,
              ),
            ),
          ),
        ],
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
                    : widget.game.closeChestReveal,
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

class _ConfettiParticle {
  const _ConfettiParticle({
    required this.startAlign,
    required this.endAlign,
    required this.color,
    required this.size,
    required this.rotationTurns,
    required this.arcHeight,
    required this.front,
  });

  final Alignment startAlign;
  final Alignment endAlign;
  final Color color;
  final double size;
  final double rotationTurns;
  final double arcHeight;
  final bool front;
}

/// One side of the chest reveal's confetti burst (DECISIONS D-061) — [front]
/// picks whether this layer paints the particles that land in front of the
/// card or behind it; two of these (one each) sandwich the actual card
/// content in `_ChestRevealOverlayState.build`. Repaints every tick off
/// [controller] via `CustomPainter`, not per-particle widgets — cheap for
/// ~13 particles per layer and gives direct, explicit control over
/// position/rotation/opacity that `Transform`/`Align` widgets would need a
/// lot more boilerplate to match.
class _ConfettiLayer extends StatelessWidget {
  const _ConfettiLayer({
    required this.controller,
    required this.particles,
    required this.front,
  });

  final Animation<double> controller;
  final List<_ConfettiParticle> particles;
  final bool front;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        painter: _ConfettiPainter(
          particles: particles,
          t: controller.value,
          front: front,
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.t,
    required this.front,
  });

  final List<_ConfettiParticle> particles;
  final double t;
  final bool front;

  /// The flight itself finishes by 60% of the way through the controller
  /// (`Curves.easeOut`, so it decelerates into arrival) -- the remaining
  /// 40% is the particles sitting at rest before [_fadeStart] starts
  /// fading them out, rather than the burst just cutting off abruptly.
  static const _flightFraction = 0.6;
  static const _fadeStart = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    final flightT = Curves.easeOut.transform(
      (t / _flightFraction).clamp(0.0, 1.0),
    );
    final opacity = t < _fadeStart
        ? 1.0
        : (1 - (t - _fadeStart) / (1 - _fadeStart)).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    for (final p in particles) {
      if (p.front != front) continue;
      final start = _toOffset(p.startAlign, size);
      final end = _toOffset(p.endAlign, size);
      final pos = Offset.lerp(start, end, flightT)!;
      final arc = p.arcHeight * size.height * sin(pi * flightT);
      final rotation = p.rotationTurns * 2 * pi * flightT;

      canvas.save();
      canvas.translate(pos.dx, pos.dy - arc);
      canvas.rotate(rotation);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.4,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  Offset _toOffset(Alignment align, Size size) {
    return Offset(
      (align.x + 1) / 2 * size.width,
      (align.y + 1) / 2 * size.height,
    );
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
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
