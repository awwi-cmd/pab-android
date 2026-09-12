import 'package:flutter/material.dart';

import '../../core/constants.dart';
import 'tap_sfx.dart';

enum ArrowDirection { left, right }

/// Tap alternative to swiping a `PageView` carousel (developer request,
/// DECISIONS D-065) — first built for the character-select screen, shared
/// with the Upgrades screen's own page carousel (D-067) so both use the
/// exact same control, not two near-identical copies. A fixed row under the
/// page content (below whatever the page's own "primary action" is), not
/// floating over it — sits in the same thumb-reach band as the arena's own
/// HUD controls. A small semi-transparent circle rather than a square
/// panel, so it still reads as an overlay-style control. No dedicated
/// pixel-art asset for this exists yet.
class CarouselArrow extends StatelessWidget {
  const CarouselArrow({
    super.key,
    required this.direction,
    required this.enabled,
    required this.onPressed,
  });

  final ArrowDirection direction;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? ArenaColors.textPrimary : ArenaColors.textDim;
    // +15% over the original 44/28 floating-button sizing (developer ask).
    return SizedBox(
      width: 51,
      height: 51,
      child: Material(
        color: ArenaColors.surfaceAlt.withValues(alpha: enabled ? 0.55 : 0.3),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? withTapSfx(onPressed) : null,
          child: Center(
            child: Icon(
              direction == ArrowDirection.left
                  ? Icons.chevron_left
                  : Icons.chevron_right,
              color: fg,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of `CarouselArrow`s flanking nothing in particular — the common
/// "prev / gap / next" pairing every `PageView` carousel in this app wants,
/// so a screen only has to supply the enabled state and callbacks.
class CarouselArrowRow extends StatelessWidget {
  const CarouselArrowRow({
    super.key,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CarouselArrow(
            direction: ArrowDirection.left,
            enabled: canGoPrev,
            onPressed: onPrev,
          ),
          const SizedBox(width: 40),
          CarouselArrow(
            direction: ArrowDirection.right,
            enabled: canGoNext,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// One dot per page, filled for the current one — a lightweight position
/// indicator for a `PageView` carousel (shared by character select and
/// Upgrades, DECISIONS D-055/D-067).
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            color: i == index ? ArenaColors.accent : ArenaColors.surfaceAlt,
          ),
      ],
    );
  }
}
