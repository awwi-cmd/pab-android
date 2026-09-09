import 'package:flame/components.dart' show SpriteAnimationData, Vector2;
import 'package:flame/widgets.dart' show SpriteAnimationWidget;
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/meta_progression.dart';
import '../../data/characters.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/stat_bar.dart';
import 'arena_screen.dart';
import 'shop_screen.dart';
import 'upgrades_screen.dart';

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
  // time we come back from SHOP/UPGRADES or the arena itself (a round just
  // played may have moved the lifetime-kills needle past a threshold).
  int _coins = 0;
  int _gems = 0;
  int _lifetimeKills = 0;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    final meta = await MetaProgressionRepository().load();
    if (!mounted) return;
    setState(() {
      _coins = meta.coins;
      _gems = meta.gems;
      _lifetimeKills = meta.lifetimeKills;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'CHARACTER SELECT',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                _WalletRow(coins: _coins, gems: _gems),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PixelButton(
                        label: 'SHOP',
                        onPressed: () async {
                          await Navigator.of(context).pushNamed(ShopScreen.route);
                          _loadMeta();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PixelButton(
                        label: 'UPGRADES',
                        onPressed: () async {
                          await Navigator.of(context).pushNamed(UpgradesScreen.route);
                          _loadMeta();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _PageDots(count: kCharacters.length, index: _pageIndex),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: kCharacters.length,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              itemBuilder: (context, i) => _CharacterPage(
                character: kCharacters[i],
                lifetimeKills: _lifetimeKills,
                onEnterArena: () => Navigator.of(context).pushNamed(
                  ArenaScreen.route,
                  arguments: kCharacters[i],
                ),
              ),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/ui/currency-counter.png',
          height: 28,
          filterQuality: FilterQuality.none,
        ),
        const SizedBox(width: 8),
        Text(
          '$coins',
          style: const TextStyle(
            color: ArenaColors.accent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 20),
        Image.asset(
          'assets/images/ui/star-full.png',
          height: 24,
          filterQuality: FilterQuality.none,
        ),
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
    );
  }
}

/// One dot per character, filled for the current page — a lightweight
/// position indicator now that the grid (which doubled as one) is gone.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            color: i == index ? ArenaColors.accent : ArenaColors.surfaceAlt,
          ),
      ],
    );
  }
}

class _CharacterPage extends StatelessWidget {
  const _CharacterPage({
    required this.character,
    required this.lifetimeKills,
    required this.onEnterArena,
  });

  final CharacterDef character;
  final int lifetimeKills;
  final VoidCallback onEnterArena;

  @override
  Widget build(BuildContext context) {
    final stats = character.stats;
    final unlocked = character.isUnlockedFor(lifetimeKills);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Center(
              child: Opacity(
                // Dimmed, not hidden -- still shows what you're working
                // toward, same reasoning as the stats staying visible below.
                opacity: unlocked ? 1.0 : 0.35,
                child: _CharacterPortrait(character: character),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            character.name,
            style: const TextStyle(
              color: ArenaColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            character.descriptor,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ArenaColors.textDim),
          ),
          const SizedBox(height: 16),
          StatBar(label: 'STR', value: stats.str, max: 10),
          StatBar(label: 'VIT', value: stats.vit, max: 10),
          StatBar(label: 'DEX', value: stats.dex, max: 10),
          StatBar(label: 'INT', value: stats.intellect, max: 10),
          const SizedBox(height: 12),
          Text(
            'HP ${stats.maxHp.round()} · '
            'DMG ${stats.damagePerHit.round()} · '
            '${stats.attacksPerSec.toStringAsFixed(1)} shots/s · '
            '${stats.moveSpeedPxPerS.round()} speed',
            style: const TextStyle(
              color: ArenaColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          if (unlocked)
            PixelButton(label: 'ENTER ARENA', onPressed: onEnterArena)
          else
            _LockedPanel(character: character, lifetimeKills: lifetimeKills),
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
    final fraction = threshold <= 0 ? 0.0 : (lifetimeKills / threshold).clamp(0.0, 1.0);
    return Column(
      children: [
        Image.asset(
          'assets/images/ui/star-empty.png',
          height: 40,
          filterQuality: FilterQuality.none,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 22,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Image.asset(
                'assets/images/ui/bar-empty.png',
                fit: BoxFit.fill,
                width: double.infinity,
                filterQuality: FilterQuality.none,
              ),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Image.asset(
                  'assets/images/ui/bar-filling.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ],
          ),
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
