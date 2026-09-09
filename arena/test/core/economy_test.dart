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

  group('kChestDeck (DECISIONS D-057)', () {
    test('is a full 52-card deck plus 2 Jokers', () {
      expect(kChestDeck.length, 54);
    });

    test('every entry has a positive gem reward and a real asset path', () {
      for (final card in kChestDeck) {
        expect(card.gemReward, greaterThan(0));
        expect(card.assetPath, startsWith('assets/images/cards/'));
      }
    });

    test('number cards pay their face value', () {
      final two = kChestDeck.firstWhere((c) => c.label == '2 of Clubs');
      final ten = kChestDeck.firstWhere((c) => c.label == '10 of Spades');
      expect(two.gemReward, 2);
      expect(ten.gemReward, 10);
    });

    test('an Ace pays more than any number card, a Joker pays the most', () {
      final ace = kChestDeck.firstWhere((c) => c.label == 'Ace of Hearts');
      final numberCards = kChestDeck.where((c) => c.label.startsWith(RegExp(r'[0-9]')));
      for (final card in numberCards) {
        expect(ace.gemReward, greaterThan(card.gemReward));
      }
      final jokers = kChestDeck.where((c) => c.label == 'Joker');
      expect(jokers, hasLength(2));
      for (final joker in jokers) {
        expect(joker.gemReward, greaterThan(ace.gemReward));
      }
    });
  });

  group('rollChestCard (DECISIONS D-057)', () {
    test('always returns a card from the deck', () {
      final random = Random(3);
      for (var i = 0; i < 500; i++) {
        expect(kChestDeck, contains(rollChestCard(random)));
      }
    });

    test('is deterministic for a given seed', () {
      expect(rollChestCard(Random(12)), rollChestCard(Random(12)));
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
