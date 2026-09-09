import 'package:flutter/material.dart';

import 'core/bgm_controller.dart';
import 'core/constants.dart';
import 'core/settings.dart';
import 'ui/screens/arena_screen.dart';
import 'ui/screens/character_select_screen.dart';
import 'ui/screens/credits_screen.dart';
import 'ui/screens/main_menu_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/shop_screen.dart';
import 'ui/screens/upgrades_screen.dart';

class ArenaApp extends StatefulWidget {
  const ArenaApp({super.key});

  @override
  State<ArenaApp> createState() => _ArenaAppState();
}

class _ArenaAppState extends State<ArenaApp> {
  @override
  void initState() {
    super.initState();
    // DECISIONS D-062: the base BGM layer starts once, here, for the whole
    // app's lifetime -- "2.wav... playing everywhere" (menus and the arena
    // alike), not something any one screen owns.
    _startBgm();
  }

  Future<void> _startBgm() async {
    final settings = await SettingsRepository().load();
    BgmController.instance.setMasterVolume(settings.musicVolume);
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
        SettingsScreen.route: (_) => const SettingsScreen(),
        CreditsScreen.route: (_) => const CreditsScreen(),
        CharacterSelectScreen.route: (_) => const CharacterSelectScreen(),
        ShopScreen.route: (_) => const ShopScreen(),
        UpgradesScreen.route: (_) => const UpgradesScreen(),
        ArenaScreen.route: (_) => const ArenaScreen(),
      },
    );
  }
}

final ThemeData _theme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: ArenaColors.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: ArenaColors.accent,
    brightness: Brightness.dark,
    surface: ArenaColors.surface,
  ),
);
