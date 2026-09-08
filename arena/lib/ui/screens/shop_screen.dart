import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../widgets/screen_scaffold.dart';

/// The character-select screen's "SHOP" tab (DECISIONS D-047, developer's
/// spec): "buys you items or powers (nothing yet, empty just back button to
/// go back)" — deliberately just the empty state. Real content is a
/// separate future ask, not implied by this one.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  static const route = '/shop';

  @override
  Widget build(BuildContext context) {
    return const ScreenScaffold(
      title: 'SHOP',
      child: Center(
        child: Text(
          'Nothing for sale yet.',
          style: TextStyle(color: ArenaColors.textDim),
        ),
      ),
    );
  }
}
