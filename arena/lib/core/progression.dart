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

/// The placeholder upgrades (developer's spec, exact wording for the
/// original 4): VIT increases HP, DEX increases move speed, STR increases
/// half of each, INT increases projectile damage. `aura` is the first real
/// skill rather than a flat stat bump (DECISIONS D-027) — a damaging ring
/// that orbits the player, capped at `UpgradeAmounts.auraMaxStacks` picks
/// (see `kUpgradeMaxPicks` below), unlike the other four which stack
/// unlimited times. `knifeMastery` (DECISIONS D-031) is the first
/// **character-locked** upgrade — see `kCharacterLockedUpgrades`/
/// `upgradeKindsFor` below, it's only ever offered to the Bruiser. Adding
/// another upgrade is still just a data change here (`UpgradeAmounts`,
/// `kUpgradeWeights`, `PlayerUpgrades.apply`), not a rewrite of the
/// level-up flow.
enum UpgradeKind { vit, dex, str, intellect, aura, knifeMastery }

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
      case UpgradeKind.aura:
        return 'Aura';
      case UpgradeKind.knifeMastery:
        return 'Knife Mastery';
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
      case UpgradeKind.aura:
        return 'Orbiting spark aura, damages nearby enemies '
            '(max ${UpgradeAmounts.auraMaxStacks} stacks)';
      case UpgradeKind.knifeMastery:
        return 'Bruiser only. Lvl1: +${((UpgradeAmounts.knifeMasteryTier1DamageMultiplier - 1) * 100).round()}% '
            'knife damage. Lvl2: throws a second knife from behind. '
            'Lvl3: throws 4 knives at once, one to every side '
            '(max ${UpgradeAmounts.knifeMasteryMaxStacks} levels)';
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

  // Aura skill (DECISIONS D-027) — a ring of `projectile-spark.png` copies
  // orbiting the player, ticking damage to everything caught inside
  // `auraRadiusPx` every `auraTickIntervalSec`. Damage scales per stack,
  // capped at `auraMaxStacks` (unlike the flat stat upgrades above, which
  // stack unlimited times) — matches the developer's "max 3 levels" spec.
  static const int auraMaxStacks = 3;
  // Retuned 2026-09-08 after the first on-device pass read as doing
  // "barely any damage" (radius 70 / 0.5s / [4,8,14] originally) -- up
  // ~25-50% across the board. Still a guess, not a final balance pass.
  static const double auraRadiusPx = 85;
  static const double auraTickIntervalSec = 0.4;
  static const List<double> _auraDamagePerTickByStack = [6, 12, 20];

  /// Damage per tick for the given stack count (1-based, clamped into
  /// range so a caller can't index out of bounds on a future stack change).
  static double auraDamagePerTick(int stacks) {
    final index = stacks.clamp(1, auraMaxStacks) - 1;
    return _auraDamagePerTickByStack[index];
  }

  // Knife Mastery (DECISIONS D-031) — Bruiser-only, 3 levels: lvl1 is a flat
  // damage buff on the existing single knife, lvl2 adds a second knife
  // thrown behind the player, lvl3 goes to 4 knives thrown at once (one to
  // every side). `game/attack_behavior.dart`'s `KnifeAttack` reads the stack
  // count directly off `PlayerUpgrades.pickCounts` the same way Aura does —
  // no flat bonus lives on `PlayerUpgrades` itself.
  static const int knifeMasteryMaxStacks = 3;
  static const double knifeMasteryTier1DamageMultiplier = 1.2;
}

/// Relative weights for the level-up roll — placeholder, all equal for now
/// (developer's call: real tuning happens later in config). Edit this map,
/// nothing else, to bias which upgrades come up more or less often.
const Map<UpgradeKind, double> kUpgradeWeights = {
  UpgradeKind.vit: 1,
  UpgradeKind.dex: 1,
  UpgradeKind.str: 1,
  UpgradeKind.intellect: 1,
  UpgradeKind.aura: 1,
  UpgradeKind.knifeMastery: 1,
};

/// How many times each upgrade may be picked in a round — `null` means
/// unlimited (the original 4 flat stat upgrades). Aura caps at
/// `UpgradeAmounts.auraMaxStacks`; once a kind hits its cap,
/// [rollUpgradeChoices] stops offering it.
const Map<UpgradeKind, int?> kUpgradeMaxPicks = {
  UpgradeKind.vit: null,
  UpgradeKind.dex: null,
  UpgradeKind.str: null,
  UpgradeKind.intellect: null,
  UpgradeKind.aura: UpgradeAmounts.auraMaxStacks,
  UpgradeKind.knifeMastery: UpgradeAmounts.knifeMasteryMaxStacks,
};

/// Which `CharacterDef.id` an upgrade is restricted to, if any (DECISIONS
/// D-031) — an upgrade not listed here is offered to everyone. `knifeMastery`
/// only makes sense for whoever actually has a knife.
const Map<UpgradeKind, String> kCharacterLockedUpgrades = {
  UpgradeKind.knifeMastery: 'bruiser',
};

/// The upgrade kinds eligible for [characterId] this round — everything
/// except another character's locked upgrades (`kCharacterLockedUpgrades`).
/// Pass the result as [rollUpgradeChoices]'s `candidates`.
List<UpgradeKind> upgradeKindsFor(String characterId) {
  return [
    for (final kind in UpgradeKind.values)
      if (kCharacterLockedUpgrades[kind] == null ||
          kCharacterLockedUpgrades[kind] == characterId)
        kind,
  ];
}

/// Picks [count] distinct upgrade kinds, weighted by [kUpgradeWeights] and
/// excluding anything already at its [kUpgradeMaxPicks] cap (pass the
/// round's current `PlayerUpgrades.pickCounts`; omit it where the cap
/// doesn't matter, e.g. tests). [candidates] narrows the pool before any of
/// that — pass `upgradeKindsFor(character.id)` to respect character-locked
/// upgrades (DECISIONS D-031); defaults to every kind. Weighted sampling
/// without replacement via the Efraimidis-Spirakis key trick: draw
/// `random()^(1/weight)` per candidate and keep the top [count] keys —
/// higher weight means a key closer to 1, so it's more likely to survive
/// the cut.
/// Pure function of the [Random] passed in — seed it in a test for a
/// deterministic roll.
List<UpgradeKind> rollUpgradeChoices(
  Random random, {
  Map<UpgradeKind, int> pickCounts = const {},
  int count = 3,
  Iterable<UpgradeKind> candidates = UpgradeKind.values,
}) {
  final eligible = candidates.where((kind) {
    final max = kUpgradeMaxPicks[kind];
    return max == null || (pickCounts[kind] ?? 0) < max;
  });

  final keyed = [
    for (final kind in eligible)
      (kind, pow(random.nextDouble(), 1 / kUpgradeWeights[kind]!)),
  ]..sort((a, b) => b.$2.compareTo(a.$2));

  return [for (final entry in keyed.take(count)) entry.$1];
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
      case UpgradeKind.aura:
        // No direct stat bonus -- ArenaGame reads pickCounts[aura] to
        // spawn/scale the AuraComponent (game/components/aura.dart, D-027).
        // Rolls stop offering this kind once it hits auraMaxStacks, so
        // pickCounts should never exceed it in practice.
        return 0;
      case UpgradeKind.knifeMastery:
        // No direct stat bonus -- KnifeAttack reads pickCounts[knifeMastery]
        // itself every throw (game/attack_behavior.dart, D-031), same
        // pattern as aura above.
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
