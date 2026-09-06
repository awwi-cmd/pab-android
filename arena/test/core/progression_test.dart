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

    test('picks accumulate across multiple applies', () {
      final upgrades = PlayerUpgrades();
      upgrades.apply(UpgradeKind.vit);
      upgrades.apply(UpgradeKind.vit);
      expect(upgrades.bonusMaxHp, UpgradeAmounts.vitBonusMaxHp * 2);
      expect(upgrades.pickCounts[UpgradeKind.vit], 2);
    });

    test('reset clears bonuses and pick counts', () {
      final upgrades = PlayerUpgrades();
      upgrades.apply(UpgradeKind.vit);
      upgrades.apply(UpgradeKind.intellect);
      upgrades.reset();
      expect(upgrades.bonusMaxHp, 0);
      expect(upgrades.bonusMoveSpeed, 0);
      expect(upgrades.bonusDamage, 0);
      expect(upgrades.pickCounts.values.every((c) => c == 0), isTrue);
    });
  });
}
