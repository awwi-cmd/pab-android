import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../widgets/pixel_button.dart';
import 'character_select_screen.dart';
import 'credits_screen.dart';
import 'settings_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  static const route = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArenaColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const Text(
                'ARENA',
                style: TextStyle(
                  color: ArenaColors.accent,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
              const Spacer(flex: 3),
              PixelButton(
                label: 'START',
                onPressed: () => Navigator.of(context)
                    .pushNamed(CharacterSelectScreen.route),
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
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'v0.1.0 (debug)',
                  style: TextStyle(color: ArenaColors.textDim, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
