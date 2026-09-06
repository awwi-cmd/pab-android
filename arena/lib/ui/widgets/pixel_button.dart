import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Flat, hard-edged button matching the pixel-art look — no rounded corners,
/// no gradients, no shadow blur. A pressed state is the only feedback.
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

  @override
  Widget build(BuildContext context) {
    final bg = enabled ? ArenaColors.surfaceAlt : ArenaColors.locked;
    final fg = enabled ? ArenaColors.textPrimary : ArenaColors.textDim;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: enabled ? ArenaColors.accent : ArenaColors.textDim),
          borderRadius: BorderRadius.zero,
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
