import 'package:flutter/material.dart';

import '../../core/constants.dart';
import 'tap_sfx.dart';

/// Shared chrome for every non-arena screen: dark background, a title, and
/// an optional back button. Keeps the menu screens visually consistent
/// without a shared base class. The back button plays the shared tap SFX
/// (DECISIONS D-076) via an explicit `BackButton` instead of
/// `automaticallyImplyLeading`'s default one, which has no hook to play a
/// sound from.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showBackButton = true,
  });

  final String title;
  final Widget child;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArenaColors.background,
      appBar: AppBar(
        backgroundColor: ArenaColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: showBackButton
            ? BackButton(onPressed: withTapSfx(() => Navigator.maybePop(context)))
            : null,
        title: Text(
          title,
          style: const TextStyle(
            color: ArenaColors.textPrimary,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}
