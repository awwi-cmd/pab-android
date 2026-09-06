import 'dart:math';

/// In-round leveling system (not persisted, resets every round — see
/// DECISIONS D-025). Kills grant XP directly (no drops); levelling up
/// pauses the round and offers 3 of these 4 placeholder upgrades. Pure
/// Dart, no Flame dependency, so it's unit-testable without a `GameWidget`
/// (the D-019/D-024 pattern).

/// Flat XP granted per kill. Every enemy grants the same amount regardless
/// of skin (DECISIONS D-022 — skins are visual only).
const double kXpPerKill = 10;

/// XP-to-next-level curve: grows by [kXpGrowthFactor] every level, so
/// levelling deliberately slows down rather than staying linear
/// (developer's call: the default pace read as too fast).
const double kBaseXpToNextLevel = 150;
const double kXpGrowthFactor = 1.3;

/// XP required to go from [level] - 1 to [level].
double xpThresholdForLevel(int level) {
  return kBaseXpToNextLevel * pow(kXpGrowthFactor, level - 1);
}

/// The 4 placeholder upgrades (developer's spec, exact wording): VIT
/// increases HP, DEX increases move speed, STR increases half of each,
/// INT increases projectile damage. More power-ups land later — this enum
/// is deliberately small so adding one is a data change (`PlayerUpgrades`
/// below), not a rewrite of the level-up flow.
enum UpgradeKind { vit, dex, str, intellect }

extension UpgradeKindLabels on UpgradeKind {
  String get label {
    switch (this) {
      case UpgradeKind.vit:
        return 'Vitality';
      case UpgradeKind.dex:
        return 'Dexterity';
      case UpgradeKind.str:
        return 'Strength';
      case UpgradeKind.intellect:
        return 'Intellect';
    }
  }

  String get description {
    switch (this) {
      case UpgradeKind.vit:
        return '+${UpgradeAmounts.vitBonusMaxHp.round()} max HP';
      case UpgradeKind.dex:
        return '+${UpgradeAmounts.dexBonusMoveSpeed.round()} move speed';
      case UpgradeKind.str:
        return '+${UpgradeAmounts.strBonusMaxHp.round()} max HP, '
            '+${UpgradeAmounts.strBonusMoveSpeed.round()} move speed';
      case UpgradeKind.intellect:
        return '+${UpgradeAmounts.intellectBonusDamage.round()} projectile damage';
    }
  }
}

/// Placeholder per-pick bonus amounts — named and centralised the same way
/// `EnemyStats`/`StatBlock` are (CLAUDE.md §4.3), so tuning is one edit.
class UpgradeAmounts {
  UpgradeAmounts._();

  static const double vitBonusMaxHp = 15;
  static const double dexBonusMoveSpeed = 12;
  // STR is explicitly "half of each" per spec, not an independently tuned
  // number -- kept as a derived expression so it can't drift from that.
  static const double strBonusMaxHp = vitBonusMaxHp / 2;
  static const double strBonusMoveSpeed = dexBonusMoveSpeed / 2;
  static const double intellectBonusDamage = 3;
}

/// Picks [count] distinct upgrade kinds at random, out of the full pool.
/// Pure function of the [Random] passed in — seed it in a test for a
/// deterministic roll.
List<UpgradeKind> rollUpgradeChoices(Random random, {int count = 3}) {
  final pool = List<UpgradeKind>.from(UpgradeKind.values)..shuffle(random);
  return pool.take(count).toList();
}

/// Accumulated level-up bonuses for the current round. Deliberately a flat
/// additive layer on top of `StatBlock`, not a re-derivation of it — the
/// spec is "VIT increases HP" (a direct effect), not "increases the VIT
/// attribute" (which would need re-running the derived-stat formulas).
class PlayerUpgrades {
  double bonusMaxHp = 0;
  double bonusMoveSpeed = 0;
  double bonusDamage = 0;

  final Map<UpgradeKind, int> pickCounts = {
    for (final kind in UpgradeKind.values) kind: 0,
  };

  /// Returns how much max HP this pick just added, so the caller can heal
  /// the player by the same amount (a level-up shouldn't just raise the
  /// ceiling and leave the player relatively worse off).
  double apply(UpgradeKind kind) {
    pickCounts[kind] = (pickCounts[kind] ?? 0) + 1;
    switch (kind) {
      case UpgradeKind.vit:
        bonusMaxHp += UpgradeAmounts.vitBonusMaxHp;
        return UpgradeAmounts.vitBonusMaxHp;
      case UpgradeKind.dex:
        bonusMoveSpeed += UpgradeAmounts.dexBonusMoveSpeed;
        return 0;
      case UpgradeKind.str:
        bonusMaxHp += UpgradeAmounts.strBonusMaxHp;
        bonusMoveSpeed += UpgradeAmounts.strBonusMoveSpeed;
        return UpgradeAmounts.strBonusMaxHp;
      case UpgradeKind.intellect:
        bonusDamage += UpgradeAmounts.intellectBonusDamage;
        return 0;
    }
  }

  void reset() {
    bonusMaxHp = 0;
    bonusMoveSpeed = 0;
    bonusDamage = 0;
    for (final kind in UpgradeKind.values) {
      pickCounts[kind] = 0;
    }
  }
}
