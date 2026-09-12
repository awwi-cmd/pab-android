import 'package:flutter/foundation.dart' show VoidCallback;

import '../../core/sfx_player.dart';

/// Wraps [onPressed] so the button also plays the shared tap SFX
/// (DECISIONS D-076, developer's spec verbatim: "basically all buttons
/// should have that sound") — used at every raw button call site
/// (`OutlinedButton`/`TextButton`/`IconButton`/a bare `InkWell`) that isn't
/// already covered by a shared widget playing it internally
/// (`PixelButton`, `CarouselArrow`, `ScreenScaffold`'s own back button).
///
/// `null` in, `null` out — a disabled button's `onPressed` is already
/// `null`, so wrapping it here can't turn a silent, inert button into one
/// that plays a tap sound for a press that never actually fires.
VoidCallback? withTapSfx(VoidCallback? onPressed) {
  if (onPressed == null) return null;
  return () {
    SfxPlayer.instance.playTap();
    onPressed();
  };
}
