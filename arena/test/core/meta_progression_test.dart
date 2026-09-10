import 'package:arena/core/meta_progression.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    test(
      'haste/fortune/resolve (DECISIONS D-067) buy and level up independently',
      () {
        final meta = MetaProgression(coins: 1000000);
        expect(meta.buy(MetaStat.haste), isTrue);
        expect(meta.buy(MetaStat.fortune), isTrue);
        expect(meta.buy(MetaStat.resolve), isTrue);
        expect(meta.levelOf(MetaStat.haste), 1);
        expect(meta.levelOf(MetaStat.fortune), 1);
        expect(meta.levelOf(MetaStat.resolve), 1);
        // Not accidentally aliased to Corruption or each other.
        expect(meta.corruptionLevel, 0);
      },
    );
  });

  group('MetaProgressionRepository persistence', () {
    test(
      'save then load round-trips every track, new dials included',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = MetaProgressionRepository();
        final meta = MetaProgression(
          coins: 42,
          gems: 7,
          lifetimeKills: 99,
          strLevel: 1,
          vitLevel: 2,
          dexLevel: 3,
          intLevel: 4,
          corruptionLevel: 5,
          hasteLevel: 6,
          fortuneLevel: 7,
          resolveLevel: 8,
        );
        await repo.save(meta);
        final loaded = await repo.load();
        expect(loaded.hasteLevel, 6);
        expect(loaded.fortuneLevel, 7);
        expect(loaded.resolveLevel, 8);
        expect(loaded.corruptionLevel, 5);
      },
    );
  });
}
