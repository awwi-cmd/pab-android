import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// A labelled stat bar plus its raw number (PRD §4.4 — character select
/// shows both, never just one or the other).
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
  });

  final String label;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Wide enough for the longest real label ("CORRUPTION") plus the
          // explicit single-line/no-wrap/ellipsis guard -- at the old fixed
          // 36px width, anything past a 3-4 char label (CORRUPTION being
          // the worst case, D-047) wrapped into a stack of single letters
          // instead of clipping or shrinking, a real bug on-device the
          // Upgrades redesign (DECISIONS D-067) surfaced when 3 more
          // multi-letter labels (HASTE/FORTUNE/RESOLVE) were added.
          SizedBox(
            width: 80,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ArenaColors.textDim,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(height: 10, color: ArenaColors.surfaceAlt),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: 10, color: ArenaColors.accent),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: const TextStyle(color: ArenaColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
