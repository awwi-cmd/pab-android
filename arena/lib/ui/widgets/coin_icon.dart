import 'package:flutter/material.dart';

/// The real in-game coin asset (`consumables/coin-icon.png`, a single-row
/// 15-frame spin sheet, each frame 16x16) cropped to its first frame — the
/// coin icon shown wherever a coin count is displayed (character select,
/// upgrades, round-over), replacing the earlier placeholder plaque
/// (`ui/currency-counter.png`, D-064: "modify the coin-icon with our actual
/// coin asset").
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, required this.size});

  final double size;

  static const _sheetWidth = 240.0;
  static const _sheetHeight = 16.0;
  static const _cellSize = 16.0;

  @override
  Widget build(BuildContext context) {
    final scale = size / _cellSize;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: _sheetWidth * scale,
          maxHeight: _sheetHeight * scale,
          // Frame 0 (leftmost cell) -- the sheet is a single row exactly
          // `_cellSize` tall, so any vertical alignment crops the same
          // pixels; only the horizontal alignment picks which frame shows.
          alignment: Alignment.centerLeft,
          child: Image.asset(
            'assets/images/consumables/coin-icon.png',
            width: _sheetWidth * scale,
            height: _sheetHeight * scale,
            // Without an explicit fit, `Image`'s default is `BoxFit.
            // scaleDown` (never scales UP) -- since the sheet is smaller
            // than this scaled-up box, it drew at native pixel size,
            // centered, nowhere near the small cropped window this widget
            // actually shows. `fill` stretches it to exactly width/height,
            // matching the `scale` this crop math assumes.
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }
}
