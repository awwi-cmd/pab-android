import 'dart:math';

import 'package:arena/core/economy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rollRarity', () {
    test('is deterministic for a given seed', () {
      expect(rollRarity(Random(5)), rollRarity(Random(5)));
    });

    test('distribution roughly matches kRarityWeights over many trials', () {
      const trials = 50000;
      final counts = {for (final tier in ItemRarity.values) tier: 0};
      final random = Random(2);
      for (var i = 0; i < trials; i++) {
        final tier = rollRarity(random);
        counts[tier] = counts[tier]! + 1;
      }
      final totalWeight = kRarityWeights.values.reduce((a, b) => a + b);
      for (final tier in ItemRarity.values) {
        final expected = kRarityWeights[tier]! / totalWeight;
        // Loose tolerance -- this is a distribution check, not exact math.
        expect(counts[tier]! / trials, closeTo(expected, 0.02));
      }
    });

    test('common is more frequent than legendary (sanity on direction)', () {
      var commonCount = 0;
      var legendaryCount = 0;
      final random = Random(11);
      for (var i = 0; i < 5000; i++) {
        switch (rollRarity(random)) {
          case ItemRarity.common:
            commonCount++;
          case ItemRarity.legendary:
            legendaryCount++;
          default:
            break;
        }
      }
      expect(commonCount, greaterThan(legendaryCount));
    });
  });

  group('gemDropChance', () {
    test('is the base chance at level 1', () {
      expect(gemDropChance(1), kGemBaseDropChance);
    });

    test('grows with level', () {
      expect(gemDropChance(10), greaterThan(gemDropChance(1)));
    });

    test('never exceeds 1.0', () {
      expect(gemDropChance(1000), 1.0);
    });
  });

  group('rollGemDrop', () {
    test('always drops at 100% chance', () {
      final random = Random(4);
      for (var i = 0; i < 100; i++) {
        expect(rollGemDrop(random, 1000), isTrue);
      }
    });
  });

  group('rollCoinValue', () {
    test('always returns one of the tabled values', () {
      final random = Random(6);
      for (var i = 0; i < 200; i++) {
        expect(kCoinValueByRarity.values, contains(rollCoinValue(random)));
      }
    });
  });

  group('potionHealAmount', () {
    test('increases with rarity', () {
      var previous = 0.0;
      for (final tier in ItemRarity.values) {
        final amount = potionHealAmount(tier);
        expect(amount, greaterThan(previous));
        previous = amount;
      }
    });
  });
}
