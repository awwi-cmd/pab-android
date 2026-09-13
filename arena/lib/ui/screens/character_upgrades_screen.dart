import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/meta_progression.dart';
import '../../data/characters.dart';
import '../widgets/carousel_arrow.dart';
import '../widgets/coin_icon.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/stat_bar.dart';

/// The character-select screen's "CHARACTER UPGRADES" tab (DECISIONS D-047,
/// renamed + made fully per-character by D-003 — developer's spec verbatim:
/// "all of character upgrades must be SPECIFIC to character... chaos haste
/// luck everything from character upgrades should be specific to
/// character"): persistent, cross-round purchases funded by coins earned
/// finishing rounds (`ArenaGame.coinsEarned` → `MetaProgressionRepository.
/// addCoins`, credited once at round-over).
///
/// Same tap/swipe page carousel as Character Select (`CarouselArrowRow`/
/// `PageDots`, `ui/widgets/carousel_arrow.dart`) — a fixed, non-scrolling
/// `PageView` of 3 pages, all 3 scoped to whichever [CharacterDef] launched
/// this screen (passed as this route's `arguments`, same `ModalRoute.
/// of(context).settings.arguments` pattern `ArenaScreen` already uses):
/// page 1 is STR/VIT/DEX/INT (`ArenaGame.effectiveStats`), page 2 is
/// CORRUPTION/HASTE/FORTUNE/RESOLVE, page 3 is MAGNET/LUCK/REGEN/CRIT —
/// buying on any page only ever raises *this* character's own
/// `MetaProgression.characterUpgradeLevels` entry, read via `levelOfFor`/
/// `buyFor`. The row order on every page still comes straight from
/// `MetaStat.values`' own declaration order (see that enum's doc comment).
///
/// Loads/saves its own `MetaProgression` copy (no state-management library,
/// CLAUDE.md §4.9) — same pattern as `SettingsScreen`.
class CharacterUpgradesScreen extends StatefulWidget {
  const CharacterUpgradesScreen({super.key});

  static const route = '/character-upgrades';

  @override
  State<CharacterUpgradesScreen> createState() =>
      _CharacterUpgradesScreenState();
}

class _CharacterUpgradesScreenState extends State<CharacterUpgradesScreen> {
  final _repo = MetaProgressionRepository();
  final _pageController = PageController();
  MetaProgression? _meta;
  int _pageIndex = 0;

  /// Set once in [didChangeDependencies] — same "read the route argument
  /// exactly once" shape `ArenaScreen` already uses for its own
  /// `CharacterDef` argument.
  late final CharacterDef character;
  bool _characterResolved = false;

  /// Row-order source of truth (see class doc) — page 1 is the 4 raw
  /// attributes (per-character, DECISIONS D-003), page 2 is Corruption plus
  /// the 3 dials that share its shape, page 3 (DECISIONS D-069) is 4 more in
  /// the same spirit. A future page is one more entry here, not a change to
  /// how paging itself works.
  static const _statPages = [
    [MetaStat.str, MetaStat.vit, MetaStat.dex, MetaStat.intellect],
    [MetaStat.corruption, MetaStat.haste, MetaStat.fortune, MetaStat.resolve],
    [MetaStat.magnet, MetaStat.luck, MetaStat.regen, MetaStat.crit],
  ];
  static final _pageCount = _statPages.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_characterResolved) {
      _characterResolved = true;
      character =
          ModalRoute.of(context)?.settings.arguments as CharacterDef? ??
          kCharacters.first;
    }
  }

  @override
  void initState() {
    super.initState();
    _repo.load().then((meta) {
      if (!mounted) return;
      setState(() => _meta = meta);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _buy(MetaStat stat) {
    final meta = _meta;
    if (meta == null) return;
    if (!meta.buyFor(character.id, stat)) return; // not enough coins, or maxed
    setState(() {}); // meta is mutated in place, just re-render
    _repo.save(meta);
  }

  static const _pageAnimDuration = Duration(milliseconds: 250);

  void _goPrev() {
    if (_pageIndex <= 0) return;
    _pageController.previousPage(
      duration: _pageAnimDuration,
      curve: Curves.easeOut,
    );
  }

  void _goNext() {
    if (_pageIndex >= _pageCount - 1) return;
    _pageController.nextPage(
      duration: _pageAnimDuration,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return ScreenScaffold(
      title: 'CHARACTER UPGRADES',
      child: meta == null
          ? const Center(
              child: CircularProgressIndicator(color: ArenaColors.accent),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    children: [
                      Text(
                        character.name,
                        style: const TextStyle(
                          color: ArenaColors.accent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _WalletRow(coins: meta.coins),
                      const SizedBox(height: 12),
                      PageDots(count: _pageCount, index: _pageIndex),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pageCount,
                    onPageChanged: (i) => setState(() => _pageIndex = i),
                    itemBuilder: (context, i) => _StatPage(
                      stats: _statPages[i],
                      meta: meta,
                      character: character,
                      onBuy: _buy,
                    ),
                  ),
                ),
                CarouselArrowRow(
                  canGoPrev: _pageIndex > 0,
                  canGoNext: _pageIndex < _pageCount - 1,
                  onPrev: _goPrev,
                  onNext: _goNext,
                ),
              ],
            ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CoinIcon(size: 32),
        const SizedBox(width: 10),
        Text(
          '$coins',
          // TASKS 35.2: matches the gem count's color everywhere a gem
          // count renders instead of ArenaColors.accent (green/teal).
          style: const TextStyle(
            color: ArenaColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// One page of 4 `_UpgradeRow`s, each getting an equal share of the page's
/// height via `Expanded` — no scrolling, the whole page always fits
/// whatever vertical space the carousel gives it (DECISIONS D-067,
/// developer's explicit ask: "must not allow scrolling").
class _StatPage extends StatelessWidget {
  const _StatPage({
    required this.stats,
    required this.meta,
    required this.character,
    required this.onBuy,
  });

  final List<MetaStat> stats;
  final MetaProgression meta;
  final CharacterDef character;
  final ValueChanged<MetaStat> onBuy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        children: [
          for (final stat in stats)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _UpgradeRow(
                  stat: stat,
                  meta: meta,
                  character: character,
                  onBuy: () => onBuy(stat),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.stat,
    required this.meta,
    required this.character,
    required this.onBuy,
  });

  final MetaStat stat;
  final MetaProgression meta;
  final CharacterDef character;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final level = meta.levelOfFor(character.id, stat);
    final maxed = level >= kMetaMaxLevel;
    final cost = maxed ? null : metaUpgradeCost(level);
    final affordable = cost != null && meta.coins >= cost;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ArenaColors.surface,
        border: Border.all(color: ArenaColors.surfaceAlt),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatBar(label: stat.label, value: level, max: kMetaMaxLevel),
          Text(
            stat.description,
            style: const TextStyle(color: ArenaColors.textDim, fontSize: 12),
          ),
          PixelButton(
            label: maxed ? 'MAXED' : 'BUY — $cost coins',
            enabled: !maxed && affordable,
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}
