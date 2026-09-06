import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'ui/screens/arena_screen.dart';
import 'ui/screens/character_select_screen.dart';
import 'ui/screens/credits_screen.dart';
import 'ui/screens/main_menu_screen.dart';
import 'ui/screens/settings_screen.dart';

class ArenaApp extends StatelessWidget {
  const ArenaApp({super.key});

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
