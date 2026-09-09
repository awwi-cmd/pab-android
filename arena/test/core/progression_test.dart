import 'dart:math';

import 'package:arena/core/progression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('xpThresholdForLevel', () {
    test('level 1 threshold is the base amount', () {
      expect(xpThresholdForLevel(1), kBaseXpToNextLevel);
    });

    test('grows by the growth factor each level', () {
      expect(
        xpThresholdForLevel(2),
        closeTo(kBaseXpToNextLevel * kXpGrowthFactor, 1e-9),
      );
      expect(
        xpThresholdForLevel(3),
        closeTo(kBaseXpToNextLevel * kXpGrowthFactor * kXpGrowthFactor, 1e-9),
      );
    });

    test('is strictly increasing, never flattens or drops', () {
      var previous = xpThresholdForLevel(1);
      for (var level = 2; level <= 20; level++) {
        final next = xpThresholdForLevel(level);
        expect(next, greaterThan(previous));
        previous = next;
      }
    });
  });

  group('rollUpgradeChoices', () {
    test('returns the requested count with no duplicates', () {
      final choices = rollUpgradeChoices(Random(1), count: 3);
      expect(choices.length, 3);
      expect(choices.toSet().length, 3);
    });

    test('every choice comes from the real enum', () {
      final choices = rollUpgradeChoices(Random(42), count: 3);
      for (final kind in choices) {
        expect(UpgradeKind.values, contains(kind));
      }
    });

    test('is deterministic for a given seed', () {
      expect(
        rollUpgradeChoices(Random(7), count: 3),
        rollUpgradeChoices(Random(7), count: 3),
      );
    });

    test('stops offering a kind once its max-picks cap is reached', () {
      final maxedOut = {UpgradeKind.aura: UpgradeAmounts.auraMaxStacks};
      for (var seed = 0; seed < 50; seed++) {
        final choices = rollUpgradeChoices(
          Random(seed),
          pickCounts: maxedOut,
          count: 3,
        );
        expect(choices, isNot(contains(UpgradeKind.aura)));
      }
    });

    test('a kind below its cap can still be offered', () {
      final belowCap = {UpgradeKind.aura: UpgradeAmounts.auraMaxStacks - 1};
      var sawAura = false;
      for (var seed = 0; seed < 50; seed++) {
        final choices = rollUpgradeChoices(
          Random(seed),
          pickCounts: belowCap,
          count: 3,
        );
        if (choices.contains(UpgradeKind.aura)) sawAura = true;
      }
      expect(sawAura, isTrue);
    });

    test('never offers a kind outside the given candidates', () {
      for (var seed = 0; seed < 50; seed++) {
        final choices = rollUpgradeChoices(
          Random(seed),
          count: 3,
          candidates: const [UpgradeKind.vit, UpgradeKind.dex],
        );
        for (final kind in choices) {
          expect(kind, anyOf(UpgradeKind.vit, UpgradeKind.dex));
        }
      }
    });
  });

  group('upgradeKindsFor (DECISIONS D-031)', () {
    test('bruiser gets knifeMastery in the pool', () {
      expect(upgradeKindsFor('bruiser'), contains(UpgradeKind.knifeMastery));
    });

    test('every other character does not get knifeMastery', () {
      for (final id in ['apprentice', 'skirmisher', 'warden']) {
        expect(upgradeKindsFor(id), isNot(contains(UpgradeKind.knifeMastery)));
      }
    });

    test('everyone gets the unrestricted kinds', () {
      for (final id in ['apprentice', 'bruiser', 'skirmisher', 'warden']) {
        final pool = upgradeKindsFor(id);
        expect(pool, containsAll([
          UpgradeKind.vit,
          UpgradeKind.dex,
          UpgradeKind.str,
          UpgradeKind.intellect,
          UpgradeKind.aura,
        ]));
      }
    });
  });

  group('UpgradeAmounts.auraDamagePerTick', () {
    test('increases with stack count, capped at auraMaxStacks tiers', () {
      final tiers = [
        for (var s = 1; s <= UpgradeAmounts.auraMaxStacks; s++)
          UpgradeAmounts.auraDamagePerTick(s),
      ];
      for (var i = 1; i < tiers.length; i++) {
        expect(tiers[i], greaterThan(tiers[i - 1]));
      }
    });

    test('clamps stack counts above the cap to the top tier', () {
      expect(
        UpgradeAmounts.auraDamagePerTick(UpgradeAmounts.auraMaxStacks + 5),
        UpgradeAmounts.auraDamagePerTick(UpgradeAmounts.auraMaxStacks),
      );
    });
  });

  group('UpgradeAmounts tier tables (DECISIONS D-049)', () {
    test('rayCooldownSec shrinks with stacks, clamped to rayMaxStacks', () {
      final tiers = [
        for (var s = 1; s <= UpgradeAmounts.rayMaxStacks; s++) UpgradeAmounts.rayCooldownSec(s),
      ];
      for (var i = 1; i < tiers.length; i++) {
        expect(tiers[i], lessThan(tiers[i - 1]));
      }
      expect(
        UpgradeAmounts.rayCooldownSec(UpgradeAmounts.rayMaxStacks + 5),
        UpgradeAmounts.rayCooldownSec(UpgradeAmounts.rayMaxStacks),
      );
    });

    test('rayDamage grows with stacks', () {
      final tiers = [
        for (var s = 1; s <= UpgradeAmounts.rayMaxStacks; s++) UpgradeAmounts.rayDamage(s),
      ];
      for (var i = 1; i < tiers.length; i++) {
        expect(tiers[i], greaterThan(tiers[i - 1]));
      }
    });

    test('thunder cooldown runs 4s down to 1s over its 4 levels', () {
      expect(UpgradeAmounts.thunderCooldownSec(1), 4.0);
      expect(UpgradeAmounts.thunderCooldownSec(UpgradeAmounts.thunderMaxStacks), 1.0);
      final tiers = [
        for (var s = 1; s <= UpgradeAmounts.thunderMaxStacks; s++)
          UpgradeAmounts.thunderCooldownSec(s),
      ];
      for (var i = 1; i < tiers.length; i++) {
        expect(tiers[i], lessThan(tiers[i - 1]));
      }
    });

    test('thunder damage and target count both grow with stacks', () {
      final damageTiers = [
        for (var s = 1; s <= UpgradeAmounts.thunderMaxStacks; s++)
          UpgradeAmounts.thunderDamage(s),
      ];
      final countTiers = [
        for (var s = 1; s <= UpgradeAmounts.thunderMaxStacks; s++)
          UpgradeAmounts.thunderTargetCount(s),
      ];
      for (var i = 1; i < damageTiers.length; i++) {
        expect(damageTiers[i], greaterThan(damageTiers[i - 1]));
        expect(countTiers[i], greaterThan(countTiers[i - 1]));
      }
    });
  });

  group('kUpgradeMaxPicks (DECISIONS D-049)', () {
    test('the 4 new skills all have a cap -- none stacks unlimited', () {
      expect(kUpgradeMaxPicks[UpgradeKind.ultimateMirror], UpgradeAmounts.mirrorMaxStacks);
      expect(kUpgradeMaxPicks[UpgradeKind.projectileRay], UpgradeAmounts.rayMaxStacks);
      expect(kUpgradeMaxPicks[UpgradeKind.projectileThunder], UpgradeAmounts.thunderMaxStacks);
      expect(kUpgradeMaxPicks[UpgradeKind.defenceCrystal], 1);
    });
  });

  group('PlayerUpgrades', () {
    test('vit adds max HP and reports the delta for healing', () {
      final upgrades = PlayerUpgrades();
      final healed = upgrades.apply(UpgradeKind.vit);
      expect(upgrades.bonusMaxHp, UpgradeAmounts.vitBonusMaxHp);
      expect(healed, UpgradeAmounts.vitBonusMaxHp);
    });

    test('dex adds move speed and grants no heal', () {
      final upgrades = PlayerUpgrades();
      final healed = upgrades.apply(UpgradeKind.dex);
      expect(upgrades.bonusMoveSpeed, UpgradeAmounts.dexBonusMoveSpeed);
      expect(healed, 0);
    });

    test('str adds half of each -- exactly half, not an independent value', () {
      final upgrades = PlayerUpgrades();
      upgrades.apply(UpgradeKind.str);
      expect(upgrades.bonusMaxHp, UpgradeAmounts.vitBonusMaxHp / 2);
      expect(upgrades.bonusMoveSpeed, UpgradeAmounts.dexBonusMoveSpeed / 2);
    });

    test('intellect adds damage only', () {
      final upgrades = PlayerUpgrades();
      upgrades.apply(UpgradeKind.intellect);
      expect(upgrades.bonusDamage, UpgradeAmounts.intellectBonusDamage);
      expect(upgrades.bonusMaxHp, 0);
      expect(upgrades.bonusMoveSpeed, 0);
    });

    test('aura adds no stat bonus, only tracks its pick count', () {
      final upgrades = PlayerUpgrades();
      final healed = upgrades.apply(UpgradeKind.aura);
      expect(healed, 0);
      expect(upgrades.bonusMaxHp, 0);
      expect(upgrades.bonusMoveSpeed, 0);
      expect(upgrades.bonusDamage, 0);
      expect(upgrades.pickCounts[UpgradeKind.aura], 1);
    });

    test('picks accumulate across multiple applies', () {
      final upgrades = PlayerUpgrades();
      upgrades.apply(UpgradeKind.vit);
      upgrades.apply(UpgradeKind.vit);
      expect(upgrades.bonusMaxHp, UpgradeAmounts.vitBonusMaxHp * 2);
      expect(upgrades.pickCounts[UpgradeKind.vit], 2);
    });

    test('knifeMastery adds no stat bonus, only tracks its pick count', () {
      final upgrades = PlayerUpgrades();
      final healed = upgrades.apply(UpgradeKind.knifeMastery);
      expect(healed, 0);
      expect(upgrades.bonusMaxHp, 0);
      expect(upgrades.bonusMoveSpeed, 0);
      expect(upgrades.bonusDamage, 0);
      expect(upgrades.pickCounts[UpgradeKind.knifeMastery], 1);
    });

    test('the 3 new timer/count skills add no stat bonus, only pick counts', () {
      for (final kind in [
        UpgradeKind.ultimateMirror,
        UpgradeKind.projectileRay,
        UpgradeKind.projectileThunder,
      ]) {
        final upgrades = PlayerUpgrades();
        final healed = upgrades.apply(kind);
        expect(healed, 0);
        expect(upgrades.bonusMaxHp, 0);
        expect(upgrades.bonusMoveSpeed, 0);
        expect(upgrades.bonusDamage, 0);
        expect(upgrades.damageResistance, 0);
        expect(upgrades.bonusHpRegenPerSec, 0);
        expect(upgrades.pickCounts[kind], 1);
      }
    });

    test('defenceCrystal adds damage resistance and hp regen directly', () {
      final upgrades = PlayerUpgrades();
      final healed = upgrades.apply(UpgradeKind.defenceCrystal);
      expect(healed, 0);
      expect(upgrades.damageResistance, UpgradeAmounts.defenceCrystalDamageResistance);
      expect(upgrades.bonusHpRegenPerSec, UpgradeAmounts.defenceCrystalBonusHpRegenPerSec);
      expect(upgrades.bonusMaxHp, 0);
      expect(upgrades.bonusMoveSpeed, 0);
      expect(upgrades.bonusDamage, 0);
    });

    test('reset clears bonuses and pick counts', () {
      final upgrades = PlayerUpgrades();
      upgrades.apply(UpgradeKind.vit);
      upgrades.apply(UpgradeKind.intellect);
      upgrades.apply(UpgradeKind.defenceCrystal);
      upgrades.reset();
      expect(upgrades.bonusMaxHp, 0);
      expect(upgrades.bonusMoveSpeed, 0);
      expect(upgrades.bonusDamage, 0);
      expect(upgrades.damageResistance, 0);
      expect(upgrades.bonusHpRegenPerSec, 0);
      expect(upgrades.pickCounts.values.every((c) => c == 0), isTrue);
    });
  });
}
