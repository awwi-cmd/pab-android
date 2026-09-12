import 'package:shared_preferences/shared_preferences.dart';

/// Whether the player has ever seen `TutorialScreen` (DECISIONS D-084,
/// "first time user experience, booting the game with fresh saves, should
/// have a 3 slide tutorial"). One flag, one key — same minimal shape as
/// every other tiny persisted flag in this project (`Settings`,
/// `MetaProgression`), not a full repository class since there's only ever
/// this one value to read/write.
class TutorialState {
  TutorialState._();

  /// Public so tests can seed/inspect it directly via
  /// `SharedPreferences.setMockInitialValues` without duplicating the
  /// literal string.
  static const kHasSeenIntroKey = 'tutorial.hasSeenIntro';

  /// `false` on a genuinely fresh install/save — nothing has written this
  /// key yet — which is exactly "fresh saves" from the developer's spec.
  static Future<bool> hasSeenIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kHasSeenIntroKey) ?? false;
  }

  /// Called once the player reaches the end of `TutorialScreen` (or skips
  /// it) — never shown automatically again after that, only reachable from
  /// then on via the main menu's own "?" button.
  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHasSeenIntroKey, true);
  }
}
