import 'package:flutter/material.dart';

/// The real in-game gem asset (`consumables/gems.png`, 5 rarity-tier
/// columns x 9 animation-frame rows, each cell 16x16 — DECISIONS D-043)
/// cropped to the legendary column's first frame — the highest-rarity gem
/// sprite in the sheet, used wherever a gem *currency* count is shown
/// (character select, round-over — DECISIONS D-069), same "crop one real
/// frame out of the actual sheet" approach `CoinIcon` already uses for
/// coins, rather than a separate placeholder icon (the old `star-full.png`
/// stand-in this replaces).
class GemIcon extends StatelessWidget {
  const GemIcon({super.key, required this.size});

  final double size;

  static const _sheetWidth = 80.0; // 5 columns x 16
  static const _sheetHeight = 144.0; // 9 rows x 16
  static const _cellSize = 16.0;

  /// Column index of the legendary tier — `ItemRarity.values` is
  /// common/uncommon/rare/epic/legendary, left to right in the sheet
  /// (`core/economy.dart`), so the highest tier is the last column.
  static const _legendaryColumn = 4;

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
          // Frame 0 (top row) of the legendary column (rightmost) — same
          // alignment math `_SpriteCell` (`arena_screen.dart`) uses to crop
          // one cell out of a multi-row/column sheet.
          alignment: const Alignment(
            2 * (_legendaryColumn * _cellSize) / (_sheetWidth - _cellSize) - 1,
            -1,
          ),
          child: Image.asset(
            'assets/images/consumables/gems.png',
            width: _sheetWidth * scale,
            height: _sheetHeight * scale,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }
}
