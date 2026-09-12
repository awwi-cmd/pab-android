import 'dart:math';

import 'game_config.dart';

/// In-round leveling system (not persisted, resets every round — see
/// DECISIONS D-025). Kills grant XP directly (no drops); levelling up
/// pauses the round and offers 3 of these 4 placeholder upgrades. Pure
/// Dart, no Flame dependency, so it's unit-testable without a `GameWidget`
/// (the D-019/D-024 pattern).

/// Flat XP granted per kill. Every enemy grants the same amount regardless
/// of skin (DECISIONS D-022 — skins are visual only). `GameConfig`-backed
/// (DECISIONS D-090) instead of a raw `const`.
double get kXpPerKill => GameConfig.instance.xpPerKill;

/// The boss (DECISIONS D-042) is worth a flat multiple of a grunt kill —
/// it's meant to feel like a real milestone, not just another kill.
double get kBossXpReward => kXpPerKill * 10;

/// XP-to-next-level curve: grows by [kXpGrowthFactor] every level, so
/// levelling deliberately slows down rather than staying linear
/// (developer's call: the default pace read as too fast). `GameConfig`-
/// backed (DECISIONS D-090).
double get kBaseXpToNextLevel => GameConfig.instance.baseXpToNextLevel;
double get kXpGrowthFactor => GameConfig.instance.xpGrowthFactor;

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
///
/// The 4 newest (DECISIONS D-049) are all real skills like `aura`, not
/// stat bumps: `ultimateMirror` (a turret that spawns on screen and fires
/// both ways, more mirrors per level), `projectileRay` (a second,
/// independently-cooling piercing beam, faster per level),
/// `projectileThunder` (strikes down on random enemies, more damage/targets
/// and a shrinking cooldown per level), `defenceCrystal` (a single-pick
/// passive — damage resistance + a small HP regen, no further levels).
enum UpgradeKind {
  vit,
  dex,
  str,
  intellect,
  aura,
  knifeMastery,
  ultimateMirror,
  projectileRay,
  projectileThunder,
  defenceCrystal,
}

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
      case UpgradeKind.ultimateMirror:
        return 'Ultimate Mirror';
      case UpgradeKind.projectileRay:
        return 'Ray Beam';
      case UpgradeKind.projectileThunder:
        return 'Thunder Strike';
      case UpgradeKind.defenceCrystal:
        return 'Defence Crystal';
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
      case UpgradeKind.ultimateMirror:
        return 'A mirror appears on screen and fires bolts from both sides '
            '(max ${UpgradeAmounts.mirrorMaxStacks} mirrors)';
      case UpgradeKind.projectileRay:
        return 'A piercing beam fires every few seconds '
            '(higher levels attack faster, max ${UpgradeAmounts.rayMaxStacks} levels)';
      case UpgradeKind.projectileThunder:
        return 'Lightning strikes random enemies on a shrinking cooldown '
            '(max ${UpgradeAmounts.thunderMaxStacks} levels)';
      case UpgradeKind.defenceCrystal:
        return 'An orbiting crystal grants damage resistance and a small HP regen';
    }
  }

  /// Short category badge for the LevelUp card (DECISIONS D-072) — purely a
  /// display grouping, no gameplay weight of its own.
  String get tag {
    switch (this) {
      case UpgradeKind.vit:
      case UpgradeKind.dex:
      case UpgradeKind.str:
      case UpgradeKind.intellect:
        return 'STAT';
      case UpgradeKind.defenceCrystal:
        return 'PASSIVE';
      case UpgradeKind.aura:
      case UpgradeKind.knifeMastery:
      case UpgradeKind.ultimateMirror:
      case UpgradeKind.projectileRay:
      case UpgradeKind.projectileThunder:
        return 'SKILL';
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
  // 2026-09-10 tune (DECISIONS D-059, developer's call: "make aura shield
  // 25% smaller"): -25% (was 85) -- this is the shield's damage radius too
  // (`AuraComponent` sizes its visual to it exactly, D-027), so the hitbox
  // shrinks along with the visual, not just the art.
  static const double auraRadiusPx = 85 * 0.75;
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

  // Ultimate Mirror (DECISIONS D-049/D-050) — a turret
  // (`game/components/mirror.dart`) that spawns somewhere on screen and
  // fires a bolt out each side on a fast, fixed timer. Levels increase how
  // many mirrors can be up at once (`ArenaGame._syncMirrors` adds the
  // difference on each new pick, never removes); a mirror's own bolt
  // damage/pace doesn't scale per stack, matching "levels increase number
  // of mirrors" and nothing else in the spec.
  // 2026-09-09 (D-050): the turret never used to go away, which read as
  // "never de-spawns" — now cycles active/hidden: visible and firing for
  // `mirrorActiveDurationSec`, then hidden for `mirrorCooldownDurationSec`
  // ("that's the cooldown," developer's exact words) before reappearing at
  // a fresh on-screen spot.
  static const int mirrorMaxStacks = 3;
  static const double mirrorFireIntervalSec = 0.5;
  static const double mirrorActiveDurationSec = 3.0;
  static const double mirrorCooldownDurationSec = 3.0;

  /// 2026-09-10 (DECISIONS D-059, developer's call: "spawn not in sync, by
  /// 0.5 seconds delay") — every mirror ran the exact same
  /// active/cooldown cycle from the same t=0, so 2-3 stacked mirrors always
  /// flipped visible/hidden in lockstep. `ArenaGame._syncMirrors` multiplies
  /// this by each new mirror's spawn order for its one-time initial phase
  /// offset (`MirrorComponent`'s `staggerDelaySec` constructor param).
  static const double mirrorStaggerDelaySec = 0.5;
  static const double mirrorBoltDamage = 8;
  static const double mirrorBoltKnockback = 50;
  static const double mirrorBoltSpeedPxPerS = 260;
  static const double mirrorBoltRangePx = 260;

  // Projectile Ray (DECISIONS D-049) — a second, independently-cooling
  // attack owned directly by `ArenaGame` (not a `CharacterDef.attackBehavior`
  // — every character can pick this): a piercing beam along the line to the
  // nearest target in range, base cooldown 3s. Levels increase attack speed
  // (shorter cooldown); damage rises per tier too, so a faster ray isn't
  // strictly worse per hit than a slower one.
  static const int rayMaxStacks = 3;
  static const double rayRangeMultiplier = 1.3; // vs. the shared attackRangePx
  static const double rayHalfWidthPx = 18; // beam hit-test thickness
  static const List<double> _rayCooldownSecByStack = [3.0, 2.2, 1.5];
  static const List<double> _rayDamageByStack = [24, 32, 42];

  static double rayCooldownSec(int stacks) =>
      _rayCooldownSecByStack[stacks.clamp(1, rayMaxStacks) - 1];
  static double rayDamage(int stacks) =>
      _rayDamageByStack[stacks.clamp(1, rayMaxStacks) - 1];

  // Projectile Thunder (DECISIONS D-049) — strikes down on
  // `thunderTargetCount(stacks)` random enemies on a cooldown that shrinks
  // from 4s to 1s over its 4 levels (the developer's literal spec — that's
  // why this one caps at 4 stacks, not the usual 3); each level also raises
  // per-strike damage.
  static const int thunderMaxStacks = 4;
  static const List<double> _thunderCooldownSecByStack = [4.0, 3.0, 2.0, 1.0];
  static const List<double> _thunderDamageByStack = [10, 16, 24, 34];
  static const List<int> _thunderTargetCountByStack = [1, 2, 3, 4];

  static double thunderCooldownSec(int stacks) =>
      _thunderCooldownSecByStack[stacks.clamp(1, thunderMaxStacks) - 1];
  static double thunderDamage(int stacks) =>
      _thunderDamageByStack[stacks.clamp(1, thunderMaxStacks) - 1];
  static int thunderTargetCount(int stacks) =>
      _thunderTargetCountByStack[stacks.clamp(1, thunderMaxStacks) - 1];

  // Defence Crystal (DECISIONS D-049) — unlike the 3 skills above, the
  // developer's spec never says "levels increase" anything for this one
  // ("if the user picks this power, he has higher damage resistance and low
  // hp regen") — a single-pick passive, capped at 1 stack rather than the
  // usual 3, applied as flat bonuses on `PlayerUpgrades` the same way
  // vit/dex/str/intellect are (DECISIONS D-025 #2), not read live off
  // `pickCounts` like the 3 skills above.
  static const int defenceCrystalMaxStacks = 1;
  static const double defenceCrystalDamageResistance = 0.2; // 20% less damage taken
  static const double defenceCrystalBonusHpRegenPerSec = 1.0;
  // 2026-09-09 tune (D-050, developer's call: "make the 8 ... bigger") --
  // +60% on both axes (was 50/30).
  static const double defenceCrystalOrbitRadiusXPx = 80;
  static const double defenceCrystalOrbitRadiusYPx = 48;
  static const double defenceCrystalOrbitSpeedRadPerSec = 2.5;
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
  UpgradeKind.ultimateMirror: 1,
  UpgradeKind.projectileRay: 1,
  UpgradeKind.projectileThunder: 1,
  UpgradeKind.defenceCrystal: 1,
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
  UpgradeKind.ultimateMirror: UpgradeAmounts.mirrorMaxStacks,
  UpgradeKind.projectileRay: UpgradeAmounts.rayMaxStacks,
  UpgradeKind.projectileThunder: UpgradeAmounts.thunderMaxStacks,
  UpgradeKind.defenceCrystal: UpgradeAmounts.defenceCrystalMaxStacks,
};

/// Which `CharacterDef.id` an upgrade is restricted to, if any (DECISIONS
/// D-031) — an upgrade not listed here is offered to everyone. `knifeMastery`
/// only makes sense for whoever actually has a knife.
const Map<UpgradeKind, String> kCharacterLockedUpgrades = {
  UpgradeKind.knifeMastery: 'bruiser',
};

/// Mutually-exclusive skill *pairs* (DECISIONS D-072, generalized by D-078
/// — developer's call: "too much to have only one exclusive, we need to
/// pair them, have at least 2-3 exclusives") — D-072 originally locked all
/// 4 of the independent screen-clearing damage skills (a DOT ring, a
/// turret squad, a piercing beam, and a random-target strike) into one
/// all-or-nothing clique: pick any one, lose the other 3. That read as too
/// restrictive for one design decision to own, so it's now 3 separate
/// pairwise exclusions instead — each pair still has *some* real
/// "redundant together" justification (see below), but a kind only loses
/// its *paired* partner(s), not the whole roster:
/// - **Aura ⟷ Ultimate Mirror** — both are always-on, zero-further-input
///   area damage (a DOT ring vs. a turret squad); together they clear a
///   room with no active play at all.
/// - **Ultimate Mirror ⟷ Projectile Thunder** — a turret squad plus a
///   shrinking-cooldown multi-target nuke both scale toward "hits
///   everything, constantly," with little reason to ever pick just one.
/// - **Projectile Thunder ⟷ Projectile Ray** — both are the character's
///   *second* independently-cooling attack; stacking two of those is a
///   second and third attack rotation on top of the base one.
///
/// This chains all 4 kinds together (Aura—Mirror—Thunder—Ray) without
/// making any single pick block the *other* two: e.g. Aura + Projectile
/// Ray is a perfectly valid combo (they don't share a pair), same for
/// Ultimate Mirror + Projectile Ray, or Aura + Projectile Thunder. Stat
/// bumps (vit/dex/str/intellect), `knifeMastery` (a modifier on an
/// existing base attack, not a 5th independent damage source), and
/// `defenceCrystal` (pure survivability, not damage) still aren't in any
/// pair — they keep stacking freely regardless of which of these 4 gets
/// picked. A kind *can* appear in more than one pair (Ultimate Mirror does,
/// deliberately) — [lockedOutByExclusiveGroups] unions across every pair a
/// picked kind belongs to, so that's not a special case.
const List<Set<UpgradeKind>> kExclusiveUpgradeGroups = [
  {UpgradeKind.aura, UpgradeKind.ultimateMirror},
  {UpgradeKind.ultimateMirror, UpgradeKind.projectileThunder},
  {UpgradeKind.projectileThunder, UpgradeKind.projectileRay},
];

/// True if [kind] is in at least one exclusive pair — drives the LevelUp
/// card's "EXCLUSIVE" badge (`arena_screen.dart`) so the tradeoff is
/// visible before picking, not just discovered by its absence next
/// level-up.
bool isExclusiveUpgrade(UpgradeKind kind) =>
    kExclusiveUpgradeGroups.any((group) => group.contains(kind));

/// Every kind locked out of the roll because [pickCounts] already has a
/// pick in a *different* member of the same exclusive group — the one
/// already being picked stays eligible (so it can keep leveling toward its
/// own [kUpgradeMaxPicks] cap), every paired partner does not.
Set<UpgradeKind> lockedOutByExclusiveGroups(Map<UpgradeKind, int> pickCounts) {
  final locked = <UpgradeKind>{};
  for (final group in kExclusiveUpgradeGroups) {
    final alreadyPicked = group.where((kind) => (pickCounts[kind] ?? 0) > 0);
    if (alreadyPicked.isEmpty) continue;
    for (final kind in group) {
      if (!alreadyPicked.contains(kind)) locked.add(kind);
    }
  }
  return locked;
}

/// What picking [kind] *right now* (with no other picks yet) would lock
/// out — the LevelUp card's own "Locks out: X" line reads this directly
/// (`arena_screen.dart`) so it always names the real paired partner(s)
/// instead of a hardcoded, now-inaccurate "the other 3" from D-072's
/// original single-clique design.
Set<UpgradeKind> exclusiveLockTargets(UpgradeKind kind) =>
    lockedOutByExclusiveGroups({kind: 1});

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
/// excluding anything already at its [kUpgradeMaxPicks] cap, or locked out
/// by [kExclusiveUpgradeGroups] (DECISIONS D-072) — both read off the
/// round's current `PlayerUpgrades.pickCounts`; omit it where neither
/// matters, e.g. tests. [candidates] narrows the pool before any of
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
  final lockedOut = lockedOutByExclusiveGroups(pickCounts);
  final eligible = candidates.where((kind) {
    if (lockedOut.contains(kind)) return false;
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

  /// Defence Crystal only (DECISIONS D-049) — a flat multiplier
  /// (`PlayerComponent.takeDamage` does `amount * (1 - damageResistance)`)
  /// and a flat regen add-on (`PlayerComponent`'s hp-regen line), same
  /// additive-layer pattern as the 3 fields above.
  double damageResistance = 0;
  double bonusHpRegenPerSec = 0;

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
      case UpgradeKind.ultimateMirror:
        // No direct stat bonus -- ArenaGame reads pickCounts[ultimateMirror]
        // to size the mirror squad (game/components/mirror.dart, D-049).
        return 0;
      case UpgradeKind.projectileRay:
        // No direct stat bonus -- ArenaGame's own ray-beam cooldown timer
        // reads pickCounts[projectileRay] every trigger (D-049).
        return 0;
      case UpgradeKind.projectileThunder:
        // Same pattern -- ArenaGame's thunder timer reads the stack count
        // live (D-049).
        return 0;
      case UpgradeKind.defenceCrystal:
        damageResistance += UpgradeAmounts.defenceCrystalDamageResistance;
        bonusHpRegenPerSec += UpgradeAmounts.defenceCrystalBonusHpRegenPerSec;
        return 0;
    }
  }

  void reset() {
    bonusMaxHp = 0;
    bonusMoveSpeed = 0;
    bonusDamage = 0;
    damageResistance = 0;
    bonusHpRegenPerSec = 0;
    for (final kind in UpgradeKind.values) {
      pickCounts[kind] = 0;
    }
  }
}
