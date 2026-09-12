import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/progression.dart';
import '../../core/tutorial_state.dart';
import '../widgets/carousel_arrow.dart';
import '../widgets/coin_icon.dart';
import '../widgets/gem_icon.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/skill_icon.dart';

/// First-time-user tutorial (DECISIONS D-084, developer's spec verbatim:
/// "first time user experience, booting the game with fresh saves, should
/// have a 3 slide tutorial explaining the game... can also be accessed
/// from the top right in the main menu, a circular ? button"). Shown
/// automatically once (`MainMenuScreen` checks `TutorialState.
/// hasSeenIntro` and pushes this route if it's `false`), and reachable
/// again any time from the main menu's own "?" button — same push-then-pop
/// flow either way, so there's only one code path to get right.
///
/// A fixed, non-scrolling 3-page `PageView` — same carousel chrome
/// (`CarouselArrowRow`/`PageDots`) every other multi-page screen in this
/// app already uses (Character Select, Upgrades, Shop) — built entirely
/// out of the game's own real assets (`SkillIcon`/`CoinIcon`/`GemIcon`,
/// the actual chest sprite) rather than new illustration, so it stays
/// accurate as those systems change instead of drifting into stale marketing
/// art.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  static const route = '/tutorial';

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pageController = PageController();
  int _pageIndex = 0;

  static const _slideCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
    if (_pageIndex >= _slideCount - 1) return;
    _pageController.nextPage(
      duration: _pageAnimDuration,
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    await TutorialState.markSeen();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final onLastPage = _pageIndex >= _slideCount - 1;
    return ScreenScaffold(
      title: 'HOW TO PLAY',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: PageDots(count: _slideCount, index: _pageIndex),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              children: const [
                _MoveAndSurviveSlide(),
                _LevelUpSlide(),
                _LootAndShopSlide(),
              ],
            ),
          ),
          CarouselArrowRow(
            canGoPrev: _pageIndex > 0,
            canGoNext: !onLastPage,
            onPrev: _goPrev,
            onNext: _goNext,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: PixelButton(
              label: onLastPage ? 'GET STARTED' : 'SKIP',
              onPressed: _finish,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared layout every slide uses — title, a fixed-height art band, then
/// body copy — so the 3 slides read as one consistent format rather than
/// 3 differently-laid-out screens.
class _TutorialSlide extends StatelessWidget {
  const _TutorialSlide({
    required this.title,
    required this.art,
    required this.body,
  });

  final String title;
  final Widget art;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ArenaColors.accent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(height: 96, child: Center(child: art)),
          const SizedBox(height: 24),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ArenaColors.textDim,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// One icon in a slide's art band — a bordered square (same language
/// `SkillIcon` already established) around a plain glyph, for the 2 slides
/// that don't have dedicated game art for a concept (movement, survival).
class _ConceptIcon extends StatelessWidget {
  const _ConceptIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ArenaColors.surface,
        border: Border.all(color: ArenaColors.accent),
      ),
      child: Icon(icon, color: ArenaColors.textPrimary, size: 32),
    );
  }
}

class _MoveAndSurviveSlide extends StatelessWidget {
  const _MoveAndSurviveSlide();

  @override
  Widget build(BuildContext context) {
    return const _TutorialSlide(
      title: 'MOVE & SURVIVE',
      art: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ConceptIcon(Icons.control_camera),
          SizedBox(width: 16),
          _ConceptIcon(Icons.gps_fixed),
          SizedBox(width: 16),
          _ConceptIcon(Icons.timer),
        ],
      ),
      body:
          'Move your character with the on-screen controls — it auto-attacks '
          'the nearest enemy on its own. Enemies keep streaming in from every '
          'side. Survive as long as you can.',
    );
  }
}

class _LevelUpSlide extends StatelessWidget {
  const _LevelUpSlide();

  @override
  Widget build(BuildContext context) {
    return const _TutorialSlide(
      title: 'LEVEL UP & CHOOSE POWERS',
      art: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          SkillIcon(kind: UpgradeKind.aura, accent: ArenaColors.accent),
          SkillIcon(kind: UpgradeKind.ultimateMirror, accent: ArenaColors.accent),
          SkillIcon(kind: UpgradeKind.projectileThunder, accent: ArenaColors.accent),
          SkillIcon(kind: UpgradeKind.projectileRay, accent: ArenaColors.accent),
          SkillIcon(kind: UpgradeKind.defenceCrystal, accent: ArenaColors.accent),
        ],
      ),
      body:
          'Kills grant XP — level up to pick a new power or a permanent stat '
          'boost. A few of the strongest powers are marked EXCLUSIVE: '
          'picking one locks out a paired rival for that round, so choose '
          'your build with intent.',
    );
  }
}

class _LootAndShopSlide extends StatelessWidget {
  const _LootAndShopSlide();

  @override
  Widget build(BuildContext context) {
    return _TutorialSlide(
      title: 'LOOT, SHOP & UPGRADE',
      art: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CoinIcon(size: 40),
          const SizedBox(width: 16),
          const GemIcon(size: 40),
          const SizedBox(width: 16),
          Image.asset(
            'assets/images/consumables/chest_01.png',
            width: 48,
            height: 48,
            filterQuality: FilterQuality.none,
          ),
        ],
      ),
      body:
          'Kills and chests drop coins and gems — beating the boss always '
          'drops a chest of its own. Spend them between rounds in SHOP and '
          'UPGRADES, back at character select, for permanent boosts that '
          'carry into every future run.',
    );
  }
}
