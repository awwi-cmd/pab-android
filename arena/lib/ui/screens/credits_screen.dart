import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../widgets/screen_scaffold.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static const route = '/credits';

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'CREDITS',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text(
            'ARENA',
            style: TextStyle(
              color: ArenaColors.accent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'A top-down arena survival demo.',
            style: TextStyle(color: ArenaColors.textPrimary),
          ),
          SizedBox(height: 24),
          Text(
            'ENGINE',
            style: TextStyle(color: ArenaColors.textDim, letterSpacing: 2),
          ),
          SizedBox(height: 4),
          Text(
            'Flutter + Flame',
            style: TextStyle(color: ArenaColors.textPrimary),
          ),
          SizedBox(height: 24),
          Text(
            'ART',
            style: TextStyle(color: ArenaColors.textDim, letterSpacing: 2),
          ),
          SizedBox(height: 4),
          Text(
            'Character sprites: placeholder set, "main" — see '
            'DECISIONS.md D-015 for asset provenance.',
            style: TextStyle(color: ArenaColors.textPrimary),
          ),
          SizedBox(height: 24),
          Text(
            'Placeholder credits block — expand before any public build.',
            style: TextStyle(color: ArenaColors.textDim, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
