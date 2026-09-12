import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/meta_progression.dart';
import '../../core/shop.dart';
import '../widgets/carousel_arrow.dart';
import '../widgets/gem_icon.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_scaffold.dart';

/// The character-select screen's "SHOP" tab (DECISIONS D-069/D-070,
/// superseding D-047's deliberate empty placeholder — "buys you items or
/// powers, nothing yet"). Gem-priced, permanent one-time purchases
/// (`core/shop.dart`'s `kShopPages`) — bought once, applied every run
/// forever after, distinct from the leveled coin dials on the UPGRADES
/// screen.
///
/// Paged like `UpgradesScreen` (DECISIONS D-070, "no scrolling, add 2 more
/// pages of items") — a fixed, non-scrolling `PageView` over `kShopPages`,
/// same `CarouselArrowRow`/`PageDots` carousel chrome, each page laying its
/// rows out with `Expanded` rather than a scroll view so it can't overflow
/// regardless of screen height. Same "load/save its own `MetaProgression`
/// copy" pattern as `UpgradesScreen`.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  static const route = '/shop';

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _repo = MetaProgressionRepository();
  final _pageController = PageController();
  MetaProgression? _meta;
  int _pageIndex = 0;

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

  void _buy(ShopItem item) {
    final meta = _meta;
    if (meta == null) return;
    if (!meta.buyItem(item)) return; // not enough gems, or already owned
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
    if (_pageIndex >= kShopPages.length - 1) return;
    _pageController.nextPage(
      duration: _pageAnimDuration,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return ScreenScaffold(
      title: 'SHOP',
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
                      _WalletRow(gems: meta.gems),
                      const SizedBox(height: 12),
                      PageDots(count: kShopPages.length, index: _pageIndex),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: kShopPages.length,
                    onPageChanged: (i) => setState(() => _pageIndex = i),
                    itemBuilder: (context, i) => _ShopPage(
                      items: kShopPages[i],
                      meta: meta,
                      onBuy: _buy,
                    ),
                  ),
                ),
                CarouselArrowRow(
                  canGoPrev: _pageIndex > 0,
                  canGoNext: _pageIndex < kShopPages.length - 1,
                  onPrev: _goPrev,
                  onNext: _goNext,
                ),
              ],
            ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.gems});

  final int gems;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const GemIcon(size: 32),
        const SizedBox(width: 10),
        Text(
          '$gems',
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

/// One page of `_ShopItemRow`s, each getting an equal share of the page's
/// height via `Expanded` — same "no scroll view anywhere" shape as
/// `UpgradesScreen`'s `_StatPage` (DECISIONS D-070).
class _ShopPage extends StatelessWidget {
  const _ShopPage({required this.items, required this.meta, required this.onBuy});

  final List<ShopItem> items;
  final MetaProgression meta;
  final ValueChanged<ShopItem> onBuy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        children: [
          for (final item in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _ShopItemRow(
                  item: item,
                  meta: meta,
                  onBuy: () => onBuy(item),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShopItemRow extends StatelessWidget {
  const _ShopItemRow({
    required this.item,
    required this.meta,
    required this.onBuy,
  });

  final ShopItem item;
  final MetaProgression meta;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final owned = meta.ownsItem(item.id);
    final affordable = meta.gems >= item.costGems;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ArenaColors.surface,
        border: Border.all(color: ArenaColors.surfaceAlt),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ArenaColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ArenaColors.textDim, fontSize: 11),
          ),
          PixelButton(
            label: owned ? 'OWNED' : 'BUY — ${item.costGems} gems',
            enabled: !owned && affordable,
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}
