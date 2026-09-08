import 'package:arena/core/meta_progression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('metaUpgradeCost', () {
    test('is the base cost at level 0', () {
      expect(metaUpgradeCost(0), kMetaBaseCost.round());
    });

    test('grows with level, not flat', () {
      expect(metaUpgradeCost(5), greaterThan(metaUpgradeCost(0)));
      expect(metaUpgradeCost(9), greaterThan(metaUpgradeCost(5)));
    });
  });

  group('MetaProgression.buy', () {
    test('fails and spends nothing without enough coins', () {
      final meta = MetaProgression(coins: 0);
      expect(meta.buy(MetaStat.str), isFalse);
      expect(meta.strLevel, 0);
      expect(meta.coins, 0);
    });

    test('succeeds and deducts the exact cost with enough coins', () {
      final cost = metaUpgradeCost(0);
      final meta = MetaProgression(coins: cost);
      expect(meta.buy(MetaStat.vit), isTrue);
      expect(meta.vitLevel, 1);
      expect(meta.coins, 0);
    });

    test('refuses past the max level even with unlimited coins', () {
      final meta = MetaProgression(coins: 1000000, dexLevel: kMetaMaxLevel);
      expect(meta.buy(MetaStat.dex), isFalse);
      expect(meta.dexLevel, kMetaMaxLevel);
    });

    test('bonus getters mirror the level 1:1', () {
      final meta = MetaProgression(coins: 1000000);
      meta.buy(MetaStat.str);
      meta.buy(MetaStat.str);
      expect(meta.bonusStr, 2);
      expect(meta.bonusVit, 0);
    });
  });
}
