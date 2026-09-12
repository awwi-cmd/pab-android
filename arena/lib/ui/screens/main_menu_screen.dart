import 'package:flutter/material.dart';

import '../../core/constants.dart';
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
  @override
  void initState() {
    super.initState();
    _maybeShowTutorial();
  }

  Future<void> _maybeShowTutorial() async {
    final hasSeenIntro = await TutorialState.hasSeenIntro();
    if (hasSeenIntro || !mounted) return;
    await Navigator.of(context).pushNamed(TutorialScreen.route);
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
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed(CharacterSelectScreen.route),
                  ),
                  const SizedBox(height: 16),
                  // DECISIONS D-091: "in between start and settings."
                  PixelButton(
                    label: 'ACHIEVEMENTS',
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed(AchievementsScreen.route),
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
