import 'package:arena/core/achievements.dart';
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

    test(
      'save then load round-trips the achievement lifetime counters too (DECISIONS D-091)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = MetaProgressionRepository();
        final meta = MetaProgression(
          lifetimeBossKills: 3,
          lifetimeGemsCollected: 120,
          lifetimeCoinsEarned: 900,
          lifetimeChestsOpened: 6,
          lifetimePotionsCollected: 11,
          highestLevelReached: 14,
          longestSurvivalTimeSec: 420.5,
          claimedAchievementIds: {'first_blood', 'exterminator_1'},
        );
        await repo.save(meta);
        final loaded = await repo.load();
        expect(loaded.lifetimeBossKills, 3);
        expect(loaded.lifetimeGemsCollected, 120);
        expect(loaded.lifetimeCoinsEarned, 900);
        expect(loaded.lifetimeChestsOpened, 6);
        expect(loaded.lifetimePotionsCollected, 11);
        expect(loaded.highestLevelReached, 14);
        expect(loaded.longestSurvivalTimeSec, 420.5);
        expect(
          loaded.claimedAchievementIds,
          {'first_blood', 'exterminator_1'},
        );
      },
    );

    test('a fresh save defaults highestLevelReached to 1, not 0', () async {
      SharedPreferences.setMockInitialValues({});
      final loaded = await MetaProgressionRepository().load();
      expect(loaded.highestLevelReached, 1);
    });
  });

  group('MetaProgressionRepository.recordRoundEnd (DECISIONS D-091)', () {
    test('credits coins/gems/kills same as the old addX calls did', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = MetaProgressionRepository();
      // kills: 0 here on purpose -- any nonzero kill count crosses
      // 'first_blood' (threshold 1) and adds its reward on top, which is
      // exactly what the dedicated achievement-claiming test below checks;
      // this test is only about the plain crediting mechanism.
      await repo.recordRoundEnd(
        coins: 40,
        gems: 5,
        kills: 0,
        bossKills: 0,
        chestsOpened: 0,
        potionsCollected: 0,
        levelReached: 3,
        survivalTimeSec: 90,
      );
      final loaded = await repo.load();
      expect(loaded.coins, 40);
      expect(loaded.gems, 5);
      expect(loaded.lifetimeKills, 0);
    });

    test('credits every new lifetime counter in one call', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = MetaProgressionRepository();
      await repo.recordRoundEnd(
        coins: 10,
        gems: 2,
        kills: 5,
        bossKills: 1,
        chestsOpened: 2,
        potionsCollected: 3,
        levelReached: 7,
        survivalTimeSec: 200,
      );
      final loaded = await repo.load();
      expect(loaded.lifetimeBossKills, 1);
      expect(loaded.lifetimeGemsCollected, 2);
      expect(loaded.lifetimeCoinsEarned, 10);
      expect(loaded.lifetimeChestsOpened, 2);
      expect(loaded.lifetimePotionsCollected, 3);
      expect(loaded.highestLevelReached, 7);
      expect(loaded.longestSurvivalTimeSec, 200);
    });

    test(
      'highestLevelReached/longestSurvivalTimeSec only ever go up',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = MetaProgressionRepository();
        await repo.recordRoundEnd(
          coins: 0,
          gems: 0,
          kills: 0,
          bossKills: 0,
          chestsOpened: 0,
          potionsCollected: 0,
          levelReached: 10,
          survivalTimeSec: 500,
        );
        // A worse round afterward shouldn't lower either high-water mark.
        await repo.recordRoundEnd(
          coins: 0,
          gems: 0,
          kills: 0,
          bossKills: 0,
          chestsOpened: 0,
          potionsCollected: 0,
          levelReached: 4,
          survivalTimeSec: 50,
        );
        final loaded = await repo.load();
        expect(loaded.highestLevelReached, 10);
        expect(loaded.longestSurvivalTimeSec, 500);
      },
    );

    test(
      'crossing an achievement threshold claims it and grants its reward, exactly once',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = MetaProgressionRepository();
        final firstBlood = kAchievements.firstWhere(
          (a) => a.id == 'first_blood',
        );
        final newlyUnlocked = await repo.recordRoundEnd(
          coins: 0,
          gems: 0,
          kills: 1, // crosses first_blood's threshold of 1
          bossKills: 0,
          chestsOpened: 0,
          potionsCollected: 0,
          levelReached: 1,
          survivalTimeSec: 1,
        );
        expect(newlyUnlocked.map((a) => a.id), contains('first_blood'));
        final loaded = await repo.load();
        expect(loaded.claimedAchievementIds, contains('first_blood'));
        expect(
          loaded.coins,
          firstBlood.reward == AchievementReward.coins
              ? firstBlood.rewardAmount
              : 0,
        );

        // A second round that still satisfies the same threshold must not
        // grant the reward a second time.
        final secondCall = await repo.recordRoundEnd(
          coins: 0,
          gems: 0,
          kills: 1,
          bossKills: 0,
          chestsOpened: 0,
          potionsCollected: 0,
          levelReached: 1,
          survivalTimeSec: 1,
        );
        expect(secondCall.map((a) => a.id), isNot(contains('first_blood')));
        final reloaded = await repo.load();
        expect(
          reloaded.coins,
          firstBlood.reward == AchievementReward.coins
              ? firstBlood.rewardAmount // unchanged -- not doubled
              : 0,
        );
      },
    );

    test('a zero-progress round claims nothing', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = MetaProgressionRepository();
      final newlyUnlocked = await repo.recordRoundEnd(
        coins: 0,
        gems: 0,
        kills: 0,
        bossKills: 0,
        chestsOpened: 0,
        potionsCollected: 0,
        levelReached: 1,
        survivalTimeSec: 0,
      );
      expect(newlyUnlocked, isEmpty);
    });
  });
}
