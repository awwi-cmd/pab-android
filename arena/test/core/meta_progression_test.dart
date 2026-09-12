import 'package:arena/core/meta_progression.dart';
import 'package:arena/core/shop.dart';
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

  group('MetaProgression.buyItem (SHOP, DECISIONS D-069)', () {
    final item = kShopItems.first;

    test('fails and spends nothing without enough gems', () {
      final meta = MetaProgression(gems: 0);
      expect(meta.buyItem(item), isFalse);
      expect(meta.ownsItem(item.id), isFalse);
      expect(meta.gems, 0);
    });

    test('succeeds and deducts the exact cost with enough gems', () {
      final meta = MetaProgression(gems: item.costGems + 10);
      expect(meta.buyItem(item), isTrue);
      expect(meta.ownsItem(item.id), isTrue);
      expect(meta.gems, 10);
    });

    test('refuses a second purchase of an already-owned item', () {
      final meta = MetaProgression(gems: 1000000);
      expect(meta.buyItem(item), isTrue);
      final gemsAfterFirstBuy = meta.gems;
      expect(meta.buyItem(item), isFalse);
      expect(meta.gems, gemsAfterFirstBuy); // second attempt spent nothing
    });

    test('bonus getters are neutral until owned', () {
      final meta = MetaProgression();
      expect(meta.bonusMaxHpFromShop, 0);
      expect(meta.bonusMoveSpeedFromShop, 0);
      expect(meta.damageMultiplierFromShop, 1.0);
      expect(meta.damageResistanceFromShop, 0.0);
      expect(meta.ownsSecondWind, isFalse);
      // Page 2/3 (DECISIONS D-070) getters -- same neutral-until-owned shape.
      expect(meta.attackSpeedMultiplierFromShop, 1.0);
      expect(meta.potionHealMultiplierFromShop, 1.0);
      expect(meta.eliteChanceMultiplierFromShop, 1.0);
      expect(meta.vampiricHealPerKillFromShop, 0.0);
      expect(meta.chestGemMultiplierFromShop, 1.0);
      expect(meta.xpMultiplierFromShop, 1.0);
      expect(meta.coinMultiplierFromShop, 1.0);
      expect(meta.gemDropBonusFromShop, 0.0);
      expect(meta.ownsBossHunter, isFalse);
    });

    test('bonus getters reflect ownership once bought', () {
      final meta = MetaProgression(gems: 1000000);
      for (final item in kShopItems) {
        meta.buyItem(item);
      }
      expect(meta.bonusMaxHpFromShop, kVitalityCharmBonusMaxHp);
      expect(meta.bonusMoveSpeedFromShop, kSwiftBootsBonusMoveSpeed);
      expect(meta.damageMultiplierFromShop, kSharpEdgeDamageMultiplier);
      expect(meta.damageResistanceFromShop, kIronWillDamageResistance);
      expect(meta.ownsSecondWind, isTrue);
      expect(meta.attackSpeedMultiplierFromShop, kQuickHandsAttackSpeedMultiplier);
      expect(meta.potionHealMultiplierFromShop, kPotionMasterHealMultiplier);
      expect(meta.eliteChanceMultiplierFromShop, kSteelNervesEliteChanceMultiplier);
      expect(meta.vampiricHealPerKillFromShop, kVampiricTouchHealPerKill);
      expect(meta.chestGemMultiplierFromShop, kTreasureHunterGemRewardMultiplier);
      expect(meta.xpMultiplierFromShop, kScholarsInsightXpMultiplier);
      expect(meta.coinMultiplierFromShop, kGoldenTouchCoinMultiplier);
      expect(meta.gemDropBonusFromShop, kGemHoarderDropBonus);
      expect(meta.ownsBossHunter, isTrue);
    });

    test('kShopPages flattens to kShopItems, 3 pages of 5', () {
      expect(kShopPages, hasLength(3));
      for (final page in kShopPages) {
        expect(page, hasLength(5));
      }
      expect(kShopItems, hasLength(15));
      expect(kShopItems, [for (final page in kShopPages) ...page]);
    });
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
          magnetLevel: 9,
          luckLevel: 10,
          regenLevel: 1,
          critLevel: 2,
          ownedItemIds: {ShopItemId.secondWind.name},
        );
        await repo.save(meta);
        final loaded = await repo.load();
        expect(loaded.hasteLevel, 6);
        expect(loaded.fortuneLevel, 7);
        expect(loaded.resolveLevel, 8);
        expect(loaded.corruptionLevel, 5);
        expect(loaded.magnetLevel, 9);
        expect(loaded.luckLevel, 10);
        expect(loaded.regenLevel, 1);
        expect(loaded.critLevel, 2);
        expect(loaded.ownsSecondWind, isTrue);
        expect(loaded.ownsItem(ShopItemId.vitalityCharm), isFalse);
      },
    );
  });
}
