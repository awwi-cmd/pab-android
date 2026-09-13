import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// A labelled stat bar plus its raw number (PRD §4.4 — character select
/// shows both, never just one or the other).
///
/// [bonus]/[bonusMax] (DECISIONS D-003) are optional and only meaningful
/// together: Character Select's own per-character bars pass the purchased
/// Character Upgrades delta (e.g. "+7") and its ceiling (`kMetaMaxLevel`) so
/// this can show that delta as a red chip next to [label] and switch the
/// bar's own fill color once it's maxed — every other call site (Character
/// Upgrades' own rows, the locked-unlock panel) leaves both null and gets
/// the exact same plain bar as before.
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.bonus,
    this.bonusMax,
  });

  final String label;
  final int value;
  final int max;
  final int? bonus;
  final int? bonusMax;

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    final bonusMaxed =
        bonus != null && bonusMax != null && bonus! >= bonusMax!;
    final fillColor = bonusMaxed ? ArenaColors.xp : ArenaColors.accent;
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
          // multi-letter labels (HASTE/FORTUNE/RESOLVE) were added. A bit
          // wider when [bonus] is in play (Character Select) to fit the
          // "+N" chip alongside the label without it ever wrapping either.
          SizedBox(
            width: bonus == null ? 80 : 104,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ArenaColors.textDim,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (bonus != null && bonus! > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '+$bonus',
                    style: const TextStyle(
                      color: ArenaColors.danger,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(height: 10, color: ArenaColors.surfaceAlt),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: 10, color: fillColor),
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
