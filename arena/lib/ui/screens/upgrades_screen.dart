import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/meta_progression.dart';
import '../widgets/carousel_arrow.dart';
import '../widgets/coin_icon.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/stat_bar.dart';

/// The character-select screen's "UPGRADES" tab (DECISIONS D-047, developer's
/// spec): persistent, cross-round purchases funded by coins earned finishing
/// rounds (`ArenaGame.coinsEarned` → `MetaProgressionRepository.addCoins`,
/// credited once at round-over).
///
/// Redesigned (DECISIONS D-067) into the same tap/swipe page carousel as
/// Character Select (`CarouselArrowRow`/`PageDots`, `ui/widgets/
/// carousel_arrow.dart`) instead of one long scrolling list — a fixed,
/// non-scrolling `PageView` of 3 pages: STR/VIT/DEX/INT (raw attribute
/// adds, `ArenaGame.effectiveStats`), CORRUPTION plus 3 more per-level
/// dials in the same spirit (HASTE/FORTUNE/RESOLVE, `core/game_rules.dart`),
/// and a placeholder third page for whatever comes next. Each page lays its
/// rows out with `Expanded`, not a scroll view — the row order per page
/// comes straight from `MetaStat.values`' own declaration order (see that
/// enum's doc comment), not a separate list here.
///
/// Loads/saves its own `MetaProgression` copy (no state-management library,
/// CLAUDE.md §4.9) — same pattern as `SettingsScreen`.
class UpgradesScreen extends StatefulWidget {
  const UpgradesScreen({super.key});

  static const route = '/upgrades';

  @override
  State<UpgradesScreen> createState() => _UpgradesScreenState();
}

class _UpgradesScreenState extends State<UpgradesScreen> {
  final _repo = MetaProgressionRepository();
  final _pageController = PageController();
  MetaProgression? _meta;
  int _pageIndex = 0;

  /// Row-order source of truth (see class doc) — page 1 is the 4 raw
  /// attributes, page 2 is Corruption plus the 3 new dials that share its
  /// shape. A 3rd real page (not the COMING SOON placeholder) is a new
  /// entry in this list, not a change to how paging itself works.
  static const _statPages = [
    [MetaStat.str, MetaStat.vit, MetaStat.dex, MetaStat.intellect],
    [MetaStat.corruption, MetaStat.haste, MetaStat.fortune, MetaStat.resolve],
  ];
  static final _pageCount = _statPages.length + 1; // +1 for COMING SOON

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
    if (!meta.buy(stat)) return; // not enough coins, or already maxed
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
      title: 'UPGRADES',
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
                    itemBuilder: (context, i) => i < _statPages.length
                        ? _StatPage(
                            stats: _statPages[i],
                            meta: meta,
                            onBuy: _buy,
                          )
                        : const _ComingSoonPage(),
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
          style: const TextStyle(
            color: ArenaColors.accent,
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
    required this.onBuy,
  });

  final List<MetaStat> stats;
  final MetaProgression meta;
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
    required this.onBuy,
  });

  final MetaStat stat;
  final MetaProgression meta;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final level = meta.levelOf(stat);
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

/// Placeholder 3rd page (developer's explicit spec) — same empty-state
/// pattern as `ShopScreen`, not a new one.
class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'COMING SOON',
        style: TextStyle(
          color: ArenaColors.textDim,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
