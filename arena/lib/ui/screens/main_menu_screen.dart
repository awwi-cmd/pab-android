import 'package:flutter/material.dart';

import '../../core/achievements.dart';
import '../../core/constants.dart';
import '../../core/meta_progression.dart';
import '../../core/tutorial_state.dart';
import '../widgets/pixel_button.dart';
import '../widgets/tap_sfx.dart';
import 'achievements_screen.dart';
import 'character_select_screen.dart';
import 'credits_screen.dart';
import 'settings_screen.dart';
import 'tutorial_screen.dart';

/// DECISIONS D-082/D-084: `splash_bg.png` is both the native launch-screen
/// art (`android/app/src/main/res/drawable*/launch_background.xml`) and,
/// here, the main menu's own full-bleed background — "background only in
/// the main menu," nowhere else. The image already bakes in the game's
/// title lockup, so the plain `Text('ARENA')` title this screen used to
/// draw on top of a flat background is gone; the art itself is the title
/// now.
///
/// Stateful (was stateless) only to run the one-time first-boot check:
/// `TutorialState.hasSeenIntro()` — on a genuinely fresh save, this pushes
/// `TutorialScreen` automatically once, right after the first frame.
/// `TutorialScreen` is also reachable any time via the circular "?" button
/// top-right (DECISIONS D-084, developer's spec verbatim) — same
/// push-then-pop route either way.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  static const route = '/';

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  // DECISIONS D-008: "have a pip on achievements button... when anything is
  // pending to claim." Reloaded every time we come back from ACHIEVEMENTS
  // (claiming something there clears its pip) or START (a round just
  // played may have crossed a new threshold) -- same "reload on return"
  // pattern `CharacterSelectScreen` already uses for its own wallet.
  bool _hasPendingAchievements = false;

  @override
  void initState() {
    super.initState();
    _maybeShowTutorial();
    _loadPendingAchievements();
  }

  Future<void> _maybeShowTutorial() async {
    final hasSeenIntro = await TutorialState.hasSeenIntro();
    if (hasSeenIntro || !mounted) return;
    await Navigator.of(context).pushNamed(TutorialScreen.route);
  }

  Future<void> _loadPendingAchievements() async {
    final meta = await MetaProgressionRepository().load();
    if (!mounted) return;
    final statValues = buildStatValues(
      lifetimeKills: meta.lifetimeKills,
      lifetimeBossKills: meta.lifetimeBossKills,
      lifetimeGemsCollected: meta.lifetimeGemsCollected,
      lifetimeCoinsEarned: meta.lifetimeCoinsEarned,
      lifetimeChestsOpened: meta.lifetimeChestsOpened,
      lifetimePotionsCollected: meta.lifetimePotionsCollected,
      highestLevelReached: meta.highestLevelReached,
      longestSurvivalTimeSec: meta.longestSurvivalTimeSec,
    );
    setState(() {
      _hasPendingAchievements =
          anyAchievementPending(statValues, meta.claimedAchievementIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArenaColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg/splash_bg.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none, // D-011
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _HelpButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(TutorialScreen.route),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 5),
                  PixelButton(
                    label: 'START',
                    onPressed: () async {
                      await Navigator.of(
                        context,
                      ).pushNamed(CharacterSelectScreen.route);
                      // A round just played may have crossed a new
                      // achievement threshold (DECISIONS D-008).
                      _loadPendingAchievements();
                    },
                  ),
                  const SizedBox(height: 16),
                  // DECISIONS D-091: "in between start and settings."
                  // DECISIONS D-008: the pip badge -- only built at all
                  // while something's actually pending, same "don't reserve
                  // space for a badge that isn't there" shape the rest of
                  // this project's optional-UI elements use.
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PixelButton(
                        label: 'ACHIEVEMENTS',
                        onPressed: () async {
                          await Navigator.of(
                            context,
                          ).pushNamed(AchievementsScreen.route);
                          // Claiming something there clears its own pip.
                          _loadPendingAchievements();
                        },
                      ),
                      if (_hasPendingAchievements)
                        const Positioned(
                          top: -4,
                          right: -4,
                          child: _PendingPip(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PixelButton(
                    label: 'SETTINGS',
                    onPressed: () =>
                        Navigator.of(context).pushNamed(SettingsScreen.route),
                  ),
                  const SizedBox(height: 16),
                  PixelButton(
                    label: 'CREDITS',
                    onPressed: () =>
                        Navigator.of(context).pushNamed(CreditsScreen.route),
                  ),
                  const Spacer(flex: 2),
                  // DECISIONS D-001: rebrand -- was 'v0.1.0 (debug)'.
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'PAB Alpha 1.0.0',
                      style: TextStyle(color: ArenaColors.textDim, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small solid dot marking "something's waiting for you" (DECISIONS
/// D-008) — the ACHIEVEMENTS button's own pending-claim indicator. Plain
/// `danger` red (same "notice this" role that color already plays
/// elsewhere, e.g. the debug DIE button) rather than a new color, no
/// number/count — this is a "go look," not a badge that needs to convey
/// how many.
class _PendingPip extends StatelessWidget {
  const _PendingPip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: ArenaColors.danger,
        shape: BoxShape.circle,
        border: Border.all(color: ArenaColors.background, width: 2),
      ),
    );
  }
}

/// The main menu's circular "?" tutorial button (DECISIONS D-084,
/// developer's spec verbatim: "a circular ? button" top-right).
class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: ArenaColors.surfaceAlt.withValues(alpha: 0.7),
        shape: const CircleBorder(side: BorderSide(color: ArenaColors.accent)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: withTapSfx(onPressed),
          child: const Center(
            child: Text(
              '?',
              style: TextStyle(
                color: ArenaColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
