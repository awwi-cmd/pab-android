import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_scaffold.dart';
import 'arena_screen.dart';

/// Stub for Phase 1 — proves the flow (Main Menu -> Character Select ->
/// Arena) end to end. The real 2x2 grid, stat bars and derived readout
/// (PRD §4.4) land in Phase 2 (TASKS 2.4-2.7), reading from `CharacterDef`.
class CharacterSelectScreen extends StatelessWidget {
  const CharacterSelectScreen({super.key});

  static const route = '/character-select';

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'CHARACTER SELECT',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The Apprentice',
                style: TextStyle(
                  color: ArenaColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Stat bars + derived readout: Phase 2 (TASKS 2.4-2.7).',
                textAlign: TextAlign.center,
                style: TextStyle(color: ArenaColors.textDim),
              ),
              const SizedBox(height: 32),
              PixelButton(
                label: 'ENTER ARENA',
                onPressed: () => Navigator.of(context)
                    .pushNamed(ArenaScreen.route),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
