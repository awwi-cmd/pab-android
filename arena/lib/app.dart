import 'package:flutter/material.dart';

import 'core/bgm_controller.dart';
import 'core/constants.dart';
import 'core/settings.dart';
import 'core/sfx_player.dart';
import 'ui/screens/achievements_screen.dart';
import 'ui/screens/arena_screen.dart';
import 'ui/screens/character_select_screen.dart';
import 'ui/screens/credits_screen.dart';
import 'ui/screens/main_menu_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/shop_screen.dart';
import 'ui/screens/character_upgrades_screen.dart';
import 'ui/screens/tutorial_screen.dart';

class ArenaApp extends StatefulWidget {
  const ArenaApp({super.key});

  @override
  State<ArenaApp> createState() => _ArenaAppState();
}

class _ArenaAppState extends State<ArenaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // DECISIONS D-062: the base BGM layer starts once, here, for the whole
    // app's lifetime -- "2.wav... playing everywhere" (menus and the arena
    // alike), not something any one screen owns.
    _startBgm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// DECISIONS D-086: "music kept playing on device when minimizing the
  /// game" -- `paused`/`hidden` are the two states that actually mean "not
  /// visible anymore" (minimized, task-switched away, screen locked);
  /// `inactive` is deliberately left alone -- it also fires for transient
  /// foreground interruptions (a permission dialog, the notification
  /// shade, an incoming call banner) where cutting the music would be a
  /// worse experience than leaving it playing through a half-second
  /// interruption. `resumed` undoes whichever of the two actually fired.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        BgmController.instance.pause();
      case AppLifecycleState.resumed:
        BgmController.instance.resume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _startBgm() async {
    final settings = await SettingsRepository().load();
    BgmController.instance.setMasterVolume(settings.musicVolume);
    // DECISIONS D-076: SfxPlayer (button taps and every other one-shot SFX)
    // needs its own volume read at boot too -- same reasoning as BGM, it
    // has to work on the very first menu screen, before Settings is ever
    // opened once.
    SfxPlayer.instance.setVolumeMultiplier(settings.sfxVolume);
    // DECISIONS D-079: warms every pooled SFX's players up front so the
    // very first tap/footstep/shot in a session doesn't pay the one-time
    // pool-creation cost itself.
    SfxPlayer.instance.preload();
    await BgmController.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARENA',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      initialRoute: MainMenuScreen.route,
      routes: {
        MainMenuScreen.route: (_) => const MainMenuScreen(),
        AchievementsScreen.route: (_) => const AchievementsScreen(),
        SettingsScreen.route: (_) => const SettingsScreen(),
        CreditsScreen.route: (_) => const CreditsScreen(),
        CharacterSelectScreen.route: (_) => const CharacterSelectScreen(),
        ShopScreen.route: (_) => const ShopScreen(),
        CharacterUpgradesScreen.route: (_) => const CharacterUpgradesScreen(),
        TutorialScreen.route: (_) => const TutorialScreen(),
        ArenaScreen.route: (_) => const ArenaScreen(),
      },
      // DECISIONS D-080 ("the font is too big, reduce it by 25%") — a flat
      // app-wide text scale rather than touching every one of the ~40
      // existing `TextStyle`'s own `fontSize`. Deliberately overrides
      // (doesn't compose with) the platform's own accessibility text-scale
      // setting: this is a pixel-art game with hand-fitted panel layouts,
      // not a text-heavy app, so a user's system font-scaling setting
      // stacking on top would just as easily break those layouts the
      // other way.
      // DECISIONS D-012: was `0.75` (D-080, tuned specifically for the old
      // PixelFont's own oversized metrics) -- back to `1.0` now that the
      // font itself is gone, plus the developer's own separate "bump the
      // size" ask on top of just reverting the shrink.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.0)),
        child: child!,
      ),
    );
  }
}

final ThemeData _theme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: ArenaColors.background,
  // DECISIONS D-077/D-009/D-012: no custom `fontFamily` at all now --
  // D-009's `HomeVideo` swap-in was reverted outright ("the font is
  // horrendous... change it back to a normal one"), back to Flutter's own
  // platform default (Roboto on Android) rather than a 3rd custom font.
  // `FontWeight.bold` (used throughout, e.g. every `PixelButton` label)
  // still resolves correctly -- the default font has its own bold face,
  // nothing else needed to change.
  colorScheme: ColorScheme.fromSeed(
    seedColor: ArenaColors.accent,
    brightness: Brightness.dark,
    surface: ArenaColors.surface,
  ),
);
