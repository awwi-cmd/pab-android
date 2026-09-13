import 'package:flutter/material.dart';

/// The real in-game coin asset (`consumables/coin-icon.png`, a single-row
/// 15-frame spin sheet, each frame 16x16) — animated through all 15 frames
/// on a loop, the coin icon shown wherever a coin count is displayed
/// (character select, upgrades, round-over), replacing the earlier
/// placeholder plaque (`ui/currency-counter.png`, D-064: "modify the
/// coin-icon with our actual coin asset"). Started static (frame 0 only);
/// animated per developer follow-up ("coin-icon.png is not animating, this
/// is a spritesheet") since the sheet exists specifically to spin.
class CoinIcon extends StatefulWidget {
  const CoinIcon({super.key, required this.size});

  final double size;

  @override
  State<CoinIcon> createState() => _CoinIconState();
}

class _CoinIconState extends State<CoinIcon> with SingleTickerProviderStateMixin {
  static const _sheetWidth = 240.0;
  static const _sheetHeight = 16.0;
  static const _cellSize = 16.0;
  static const _frameCount = 15; // _sheetWidth / _cellSize
  static const _stepTime = Duration(milliseconds: 60); // matches game_assets.dart's typical stepTime range

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _stepTime * _frameCount,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.size / _cellSize;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final frame = (_controller.value * _frameCount).floor().clamp(0, _frameCount - 1);
            return OverflowBox(
              maxWidth: _sheetWidth * scale,
              maxHeight: _sheetHeight * scale,
              // Same crop-one-cell-via-Alignment approach as `_SpriteCell`
              // (arena_screen.dart) and `GemIcon`, just re-picked every
              // frame instead of pinned to column 0 -- the sheet is a
              // single row, so only the horizontal term varies.
              alignment: Alignment(
                2 * (frame * _cellSize) / (_sheetWidth - _cellSize) - 1,
                0,
              ),
              child: child,
            );
          },
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
