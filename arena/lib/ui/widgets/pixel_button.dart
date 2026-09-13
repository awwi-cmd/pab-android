import 'package:flutter/material.dart';

import '../../core/constants.dart';
import 'tap_sfx.dart';

/// The app's main button (DECISIONS D-010/D-011 — was flat, zero corner
/// radius, no depth: developer feedback "the buttons are very sharp
/// compared to the text," then "use the real [medieval UI kit] sprite
/// sheet" once one turned up in the assets). Background is the kit's own
/// glyph-free wood-plank swatch (`assets/images/ui/wood_panel_tile.png`,
/// cropped from `UI_medieval.png`'s cols14-15/rows2-3 — the one cell in
/// the whole sheet with no icon baked in, since every other button cell
/// there already has one and can't double as a blank label-button
/// background), stretched via `centerSlice` (Flutter's built-in nine-patch
/// support) rather than a plain `BoxFit.fill` — that keeps the swatch's own
/// corner rivets a fixed size while only the middle band stretches, so a
/// wide button doesn't visibly warp them into ellipses. Rounded corners
/// (`kPanelCornerRadiusPx`) and a soft drop shadow stay from the first
/// (code-only) pass. Still just a pressed-state ripple for feedback, still
/// plays the shared tap SFX (DECISIONS D-076) — this is the single
/// most-used button in the app, so wiring it here covers most screens for
/// free.
class PixelButton extends StatelessWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;

  static const _woodAsset = 'assets/images/ui/wood_panel_tile.png';
  // The swatch is 32x32 with an 8px rivet/edge margin on every side --
  // centerSlice coordinates are in the source image's own pixel space.
  static const _centerSlice = Rect.fromLTRB(8, 8, 24, 24);

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? ArenaColors.textPrimary : ArenaColors.textDim;
    final radius = BorderRadius.circular(kPanelCornerRadiusPx);

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: ArenaColors.background.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  _woodAsset,
                  centerSlice: _centerSlice,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                  // Desaturated + dimmed when disabled -- same swatch, not
                  // a second asset, so there's only ever one texture to
                  // keep in sync with the palette. `BlendMode.saturation`
                  // blended against plain grey is the standard "desaturate
                  // an image" trick (it pulls saturation from the blend
                  // color, which grey has none of).
                  color: enabled ? null : Colors.grey,
                  colorBlendMode: enabled ? null : BlendMode.saturation,
                  opacity: enabled
                      ? null
                      : const AlwaysStoppedAnimation(0.55),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: enabled ? withTapSfx(onPressed) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
