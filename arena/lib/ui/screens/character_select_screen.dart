import 'package:flame/components.dart' show SpriteAnimationData, Vector2;
import 'package:flame/widgets.dart' show SpriteAnimationWidget;
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/last_character.dart';
import '../../core/meta_progression.dart';
import '../../core/shop.dart';
import '../../core/stats.dart';
import '../../data/characters.dart';
import '../widgets/carousel_arrow.dart';
import '../widgets/coin_icon.dart';
import '../widgets/gem_icon.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/stat_bar.dart';
import '../widgets/tap_sfx.dart';
import 'arena_screen.dart';
import 'character_upgrades_screen.dart';
import 'shop_screen.dart';

/// A one-character-at-a-time swipe carousel (DECISIONS D-055) — replaces
/// the old 2x2 grid, which had all 4 characters idle-animating at once
/// (developer's call: "looks silly"). Swipe left/right through
/// `kCharacters`; the current page's stats/descriptor/ENTER ARENA sit below
/// it. Locked slots (`CharacterDef.isUnlockedFor`) show a progress panel
/// (bar-empty/bar-filling + star-empty, "X / Y kills") instead of the
/// button — real progression-gated unlocking (TASKS 8.4), not the old
/// flat "everyone's unlocked" placeholder from D-028.
class CharacterSelectScreen extends StatefulWidget {
  const CharacterSelectScreen({super.key});

  static const route = '/character-select';

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  final _pageController = PageController();
  int _pageIndex = 0;

  // Wallet/progress display only (DECISIONS D-047/D-055) -- reloaded every
  // time we come back from SHOP/CHARACTER UPGRADES or the arena itself (a
  // round just played may have moved the lifetime-kills needle past a
  // threshold, or spent coins on a stat). Held as the whole `MetaProgression`
  // (not just a few flat ints) since DECISIONS D-003's per-character stat
  // bars and the global-dial summary both need more of it than the old
  // 3-int shape did.
  MetaProgression? _meta;

  @override
  void initState() {
    super.initState();
    _loadMeta();
    _jumpToLastCharacter();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final meta = await MetaProgressionRepository().load();
    if (!mounted) return;
    setState(() => _meta = meta);
  }

  /// DECISIONS D-009 ("save last character played for next round") — a
  /// one-time jump on the very first frame this screen exists, not part of
  /// [_loadMeta] (which also re-runs every time we come back from SHOP/
  /// CHARACTER UPGRADES/the arena — re-jumping on every one of those would
  /// yank the player back to their last-*played* character even while
  /// they're mid-swipe looking at a different one).
  Future<void> _jumpToLastCharacter() async {
    final lastId = await LastCharacterState.load();
    if (!mounted || lastId == null) return;
    final index = kCharacters.indexWhere((c) => c.id == lastId);
    if (index < 0) return; // an unknown/removed id -- fall back to slot 0
    setState(() => _pageIndex = index);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
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
    if (_pageIndex >= kCharacters.length - 1) return;
    _pageController.nextPage(
      duration: _pageAnimDuration,
      curve: Curves.easeOut,
    );
  }

  /// Shared by the BONUSES SHOP button and the "Shop Bonuses:" panel's own
  /// "VIEW ALL" link (DECISIONS D-003 follow-up) — both open the exact same
  /// screen and need the exact same reload-on-return, so there's only one
  /// place that logic can drift.
  Future<void> _openBonusesShop() async {
    await Navigator.of(context).pushNamed(ShopScreen.route);
    _loadMeta();
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return ScreenScaffold(
      title: 'CHARACTER SELECT',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: _WalletRow(coins: meta?.coins ?? 0, gems: meta?.gems ?? 0),
          ),
          const SizedBox(height: 12),
          // Developer's ask: "a little bit more wide to the left and
          // right" -- its own smaller 16px side margin, not the 24px every
          // other row above/below uses, so these two buttons alone read
          // wider without touching any other row's margin or the 12px gap
          // between them. (A negative `Padding` outset past the ambient
          // 24px would be the more surgical way to widen just this row,
          // but `RenderPadding` asserts `padding.isNonNegative` -- this
          // needs its own smaller-but-still-non-negative margin instead.)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: PixelButton(
                    // DECISIONS D-003: renamed from bare "SHOP" -- see
                    // ShopScreen's own title for why.
                    label: 'BONUSES SHOP',
                    onPressed: _openBonusesShop,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PixelButton(
                    // DECISIONS D-003: renamed from "UPGRADES" -- makes the
                    // per-character scope visible in the label itself, not
                    // just in the screen it opens.
                    label: 'CHARACTER UPGRADES',
                    onPressed: () async {
                      await Navigator.of(context).pushNamed(
                        CharacterUpgradesScreen.route,
                        // Which character's own wallet to open (DECISIONS
                        // D-003) -- same route-argument pattern
                        // `ArenaScreen` already uses.
                        arguments: kCharacters[_pageIndex],
                      );
                      _loadMeta();
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 12),
            child: PageDots(count: kCharacters.length, index: _pageIndex),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: kCharacters.length,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              itemBuilder: (context, i) => _CharacterPage(
                character: kCharacters[i],
                meta: meta ?? MetaProgression(),
                onEnterArena: () {
                  // Fire-and-forget, same "nothing on screen is waiting on
                  // this write landing" reasoning ArenaGame's own round-end
                  // persistence already uses (DECISIONS D-009).
                  LastCharacterState.save(kCharacters[i].id);
                  Navigator.of(context)
                      .pushNamed(ArenaScreen.route, arguments: kCharacters[i]);
                },
                onViewShopBonuses: _openBonusesShop,
              ),
            ),
          ),
          // Fixed row under the page (below ENTER ARENA, not floating over
          // the character art anymore) -- sits in the same thumb-reach band
          // as the joystick/HUD controls in the arena itself.
          CarouselArrowRow(
            canGoPrev: _pageIndex > 0,
            canGoNext: _pageIndex < kCharacters.length - 1,
            onPrev: _goPrev,
            onNext: _goNext,
          ),
        ],
      ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.coins, required this.gems});

  final int coins;
  final int gems;

  // TASKS 35.3: gems buy SHOP items and coins buy UPGRADES levels, so each
  // currency now centers directly above the button it actually spends on
  // (mirroring the SHOP/UPGRADES `Row` right below, same `Expanded` split
  // and the same 12px gap) instead of floating as one centered group above
  // both buttons regardless of which currency spends where.
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // DECISIONS D-069: the real gem asset (legendary tier), not
                // the star-full.png placeholder this used to borrow.
                const GemIcon(size: 24),
                const SizedBox(width: 6),
                Text(
                  '$gems',
                  style: const TextStyle(
                    color: ArenaColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 28),
                const SizedBox(width: 8),
                Text(
                  '$coins',
                  style: const TextStyle(
                    color: ArenaColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CharacterPage extends StatelessWidget {
  const _CharacterPage({
    required this.character,
    required this.meta,
    required this.onEnterArena,
    required this.onViewShopBonuses,
  });

  final CharacterDef character;
  final MetaProgression meta;
  final VoidCallback onEnterArena;
  final VoidCallback onViewShopBonuses;

  @override
  Widget build(BuildContext context) {
    final stats = character.stats;
    final lifetimeKills = meta.lifetimeKills;
    final unlocked = character.isUnlockedFor(lifetimeKills);
    // DECISIONS D-003: this character's own Character Upgrades purchases
    // (never another character's) layered onto its base stats -- the exact
    // same combination `ArenaGame.effectiveStats` does at arena entry, so
    // what's shown here is what the round actually starts with.
    final levels = meta.levelsFor(character.id);
    final effectiveStats = StatBlock(
      str: stats.str + levels.str,
      vit: stats.vit + levels.vit,
      dex: stats.dex + levels.dex,
      intellect: stats.intellect + levels.intellect,
    );
    // DECISIONS D-005 ("make sure there is no scrolling in character
    // select"): a plain, non-scrolling `Column` — every gap/size below was
    // tightened from the original scrolling layout's numbers specifically
    // so the whole page (portrait, name/descriptor, 4 bars, the HP/DMG
    // line, ENTER ARENA/locked panel, and both summary panels) fits inside
    // the fixed height `PageView` actually gives this page without ever
    // needing `SingleChildScrollView`. First-guess sizes, like everything
    // else in this project — needs an on-device check on a real small
    // screen, not just the 800x600 test harness.
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            height: 84,
            child: Center(
              child: Opacity(
                // Dimmed, not hidden -- still shows what you're working
                // toward, same reasoning as the stats staying visible below.
                opacity: unlocked ? 1.0 : 0.35,
                child: _CharacterPortrait(character: character),
              ),
            ),
          ),
          Text(
            character.name,
            style: const TextStyle(
              color: ArenaColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            character.descriptor,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ArenaColors.textDim, fontSize: 12),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // DECISIONS D-003: each bar's own red "+N" chip is this
              // character's Character Upgrades bonus, the bar fills toward
              // base+kMetaMaxLevel (the purchasable ceiling) and turns gold
              // once that bonus is fully bought, and the number at the end
              // is the total (base+bonus) -- not the raw purchase level the
              // Character Upgrades screen's own bars show.
              StatBar(
                label: 'STR',
                value: effectiveStats.str,
                max: stats.str + kMetaMaxLevel,
                bonus: levels.str,
                bonusMax: kMetaMaxLevel,
              ),
              StatBar(
                label: 'VIT',
                value: effectiveStats.vit,
                max: stats.vit + kMetaMaxLevel,
                bonus: levels.vit,
                bonusMax: kMetaMaxLevel,
              ),
              StatBar(
                label: 'DEX',
                value: effectiveStats.dex,
                max: stats.dex + kMetaMaxLevel,
                bonus: levels.dex,
                bonusMax: kMetaMaxLevel,
              ),
              StatBar(
                label: 'INT',
                value: effectiveStats.intellect,
                max: stats.intellect + kMetaMaxLevel,
                bonus: levels.intellect,
                bonusMax: kMetaMaxLevel,
              ),
            ],
          ),
          Text(
            'HP ${effectiveStats.maxHp.round()} · '
            'DMG ${effectiveStats.damagePerHit.round()} · '
            '${effectiveStats.attacksPerSec.toStringAsFixed(1)} shots/s · '
            '${effectiveStats.moveSpeedPxPerS.round()}spd',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ArenaColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (unlocked)
            PixelButton(label: 'ENTER ARENA', onPressed: onEnterArena)
          else
            _LockedPanel(character: character, lifetimeKills: lifetimeKills),
          // DECISIONS D-003 ("below the ARENA, add a panel for Stat
          // Upgrades: and one for Shop Bonuses:") -- Stat Upgrades is this
          // character's own (every dial is per-character now); Shop
          // Bonuses is global -- same purchases regardless of which
          // character's page this is.
          _StatUpgradesPanel(character: character, meta: meta),
          _ShopBonusesPanel(meta: meta, onViewAll: onViewShopBonuses),
        ],
      ),
    );
  }
}

/// A locked slot's unlock progress — star-empty badge + a bar-empty/
/// bar-filling bar clipped to the fraction of the way there (DECISIONS
/// D-055). Sits where ENTER ARENA would be, same footprint.
class _LockedPanel extends StatelessWidget {
  const _LockedPanel({required this.character, required this.lifetimeKills});

  final CharacterDef character;
  final int lifetimeKills;

  @override
  Widget build(BuildContext context) {
    final threshold = character.unlockKillThreshold ?? 0;
    // DECISIONS D-068 (developer's call): the bar-empty/bar-filling
    // progress bar is gone -- just the hollow star plus the raw kill count
    // now carries "how far along am I."
    return Column(
      children: [
        Image.asset(
          'assets/images/ui/star-empty.png',
          height: 40,
          filterQuality: FilterQuality.none,
        ),
        const SizedBox(height: 8),
        Text(
          '$lifetimeKills / $threshold kills to unlock',
          style: const TextStyle(color: ArenaColors.textDim, fontSize: 12),
        ),
      ],
    );
  }
}

/// Shared look for both panels below (DECISIONS D-003) — a titled bordered
/// box, same "surface + surfaceAlt border" language `_UpgradeRow`
/// (`character_upgrades_screen.dart`) already uses for one purchasable
/// stat, just holding a read-only summary instead of a buy button.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ArenaColors.surface,
        border: Border.all(color: ArenaColors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ArenaColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// The 8 non-attribute Character Upgrades dials' current levels for *this*
/// character (DECISIONS D-003 — every dial is per-character now, "chaos
/// haste luck everything from character upgrades should be specific to
/// character"). A compact wrap of chips rather than 8 more full `StatBar`s
/// — this is a reminder of what's active on this character, not something
/// to buy from here (that's still Character Upgrades' own pages 2/3).
/// `MetaStat.values.skip(4)` (STR/VIT/DEX/INT are the first 4, already
/// shown as full bars above) keeps this in the same declaration order as
/// those pages, same "enum order is display order" convention the whole
/// file already leans on.
class _StatUpgradesPanel extends StatelessWidget {
  const _StatUpgradesPanel({required this.character, required this.meta});

  final CharacterDef character;
  final MetaProgression meta;

  @override
  Widget build(BuildContext context) {
    final dials = MetaStat.values.skip(4);
    return _SummaryPanel(
      title: 'Stat Upgrades:',
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          for (final stat in dials)
            Text(
              '${stat.label} ${meta.levelOfFor(character.id, stat)}',
              style: const TextStyle(
                color: ArenaColors.textDim,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

/// Owned BONUSES SHOP items (DECISIONS D-003, D-069) — global, same count
/// regardless of which character's page this is (SHOP was never made
/// per-character; the developer's explicit ask was to confirm it "remains
/// the same, permanent bonuses FOR ALL characters").
///
/// A compact "N / 15 owned" count plus a "VIEW ALL" link, not a list of
/// every owned item's label — DECISIONS D-003 follow-up: with up to 15
/// possible items, listing them all by name pushed the whole Character
/// Select page tall enough to need scrolling ("the shop bonuses run out of
/// screen"). This panel's own height is now fixed regardless of how many
/// are owned; BONUSES SHOP itself (already its own scrollable-by-page
/// carousel) is still where the actual list lives — [onViewAll] just
/// opens it, same screen the button above already does.
class _ShopBonusesPanel extends StatelessWidget {
  const _ShopBonusesPanel({required this.meta, required this.onViewAll});

  final MetaProgression meta;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final ownedCount = kShopItems.where((item) => meta.ownsItem(item.id)).length;
    return _SummaryPanel(
      title: 'Shop Bonuses:',
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$ownedCount / ${kShopItems.length} owned',
              style: const TextStyle(
                color: ArenaColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: withTapSfx(onViewAll), // D-076: every button taps the shared SFX
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'VIEW ALL >',
              style: TextStyle(
                color: ArenaColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plays `idle` on loop (PRD §4.4, TASKS 5.13) — Flame's
/// `SpriteAnimationWidget` directly, no `GameWidget`/game loop needed for a
/// single looping animation outside the arena. Only ever one of these is
/// on screen at a time now (the current carousel page), which is what
/// actually answers "characters looking silly" — not a new mechanism, just
/// one fewer of the old grid's four playing at once.
class _CharacterPortrait extends StatelessWidget {
  const _CharacterPortrait({required this.character});

  final CharacterDef character;

  static const _cellWidth = 16.0;
  static const _cellHeight = 24.0;
  static const _scale = 5.0;

  // The Apprentice's `<prefix>-idle.png` is a known 4-frame delivery
  // (DECISIONS D-015). Unlike the in-arena loader, this widget needs a
  // frame count up front (before the sheet is decoded), so it isn't
  // computed from image width — update this if a future unlocked
  // character's idle sheet has a different frame count.
  static const _idleFrameCount = 4;

  @override
  Widget build(BuildContext context) {
    final root = character.spriteFolder.replaceFirst('assets/images/', '');
    final path = '$root/${character.spritePrefix}-idle.png';
    return SizedBox(
      width: _cellWidth * _scale,
      height: _cellHeight * _scale,
      child: SpriteAnimationWidget.asset(
        // Keyed by character id so swiping to a new page doesn't reuse the
        // previous character's already-loaded animation state/element.
        key: ValueKey(character.id),
        path: path,
        data: SpriteAnimationData.sequenced(
          amount: _idleFrameCount,
          stepTime: 0.1,
          textureSize: Vector2(_cellWidth, _cellHeight),
        ),
        paint: Paint()..filterQuality = FilterQuality.none, // D-011
      ),
    );
  }
}
