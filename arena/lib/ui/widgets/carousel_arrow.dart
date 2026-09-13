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
/// HUD controls.
///
/// DECISIONS D-011: the real medieval UI kit's own "play" button
/// (`assets/images/ui/button_play.png`, cropped from `UI_medieval.png`) —
/// a right-pointing triangle already drawn as its own wood button, so
/// "next" uses it as-is and "prev" just flips it horizontally
/// (`Transform.flip`) rather than needing a second mirrored asset. Was a
/// plain semi-transparent circle + Material `Icon` before this (no
/// dedicated pixel-art asset existed yet); disabled state is a plain
/// opacity dim, same language `_RewardBadge`/`_LockedPanel` etc. already
/// use elsewhere for "greyed out until available."
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

  // +15% over the original 44/28 floating-button sizing (developer ask,
  // still honored — the wood button art fills the same footprint).
  static const _size = 51.0;

  @override
  Widget build(BuildContext context) {
    // DECISIONS D-013 ("make the arrow asset as big as the hitbox"): the
    // image no longer declares its own width/height -- `SizedBox.expand`
    // forces it to fill whatever box the tight `_size` `SizedBox` below
    // hands it, so the art and the tappable area are structurally the
    // same size (one number, `_size`, instead of two call sites that
    // merely happened to agree).
    final icon = SizedBox.expand(
      child: Image.asset(
        'assets/images/ui/button_play.png',
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
      ),
    );
    return SizedBox(
      width: _size,
      height: _size,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? withTapSfx(onPressed) : null,
            child: direction == ArrowDirection.left
                ? Transform.flip(flipX: true, child: icon)
                : icon,
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
