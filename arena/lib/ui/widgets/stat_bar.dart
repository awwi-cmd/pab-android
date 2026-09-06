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
          SizedBox(
            width: 36,
            child: Text(
              label,
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
