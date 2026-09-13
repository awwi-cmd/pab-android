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

  group('MetaProgression.buyFor / levelOfFor (every dial is per-character, DECISIONS D-003)', () {
    test('a character with no purchases yet reads every stat as 0', () {
      final meta = MetaProgression();
      expect(meta.levelOfFor('apprentice', MetaStat.str), 0);
      expect(meta.levelOfFor('apprentice', MetaStat.haste), 0);
      expect(meta.levelsFor('apprentice').str, 0);
    });

    test('buying for one character never touches another', () {
      final meta = MetaProgression(coins: 1000000);
      expect(meta.buyFor('apprentice', MetaStat.str), isTrue);
      expect(meta.buyFor('apprentice', MetaStat.str), isTrue);
      expect(meta.levelOfFor('apprentice', MetaStat.str), 2);
      expect(meta.levelOfFor('bruiser', MetaStat.str), 0); // untouched
    });

    test(
      'CHAOS/HASTE/FORTUNE/RESOLVE/MAGNET/LUCK/REGEN/CRIT are per-character too',
      () {
        final meta = MetaProgression(coins: 1000000);
        expect(meta.buyFor('apprentice', MetaStat.haste), isTrue);
        expect(meta.buyFor('apprentice', MetaStat.corruption), isTrue);
        expect(meta.levelOfFor('apprentice', MetaStat.haste), 1);
        expect(meta.levelOfFor('apprentice', MetaStat.corruption), 1);
        // Not accidentally shared with another character.
        expect(meta.levelOfFor('bruiser', MetaStat.haste), 0);
        expect(meta.levelOfFor('bruiser', MetaStat.corruption), 0);
      },
    );

    test('fails and spends nothing without enough coins', () {
      final meta = MetaProgression(coins: 0);
      expect(meta.buyFor('apprentice', MetaStat.dex), isFalse);
      expect(meta.levelOfFor('apprentice', MetaStat.dex), 0);
      expect(meta.coins, 0);
    });

    test('succeeds and deducts the exact cost with enough coins', () {
      final cost = metaUpgradeCost(0);
      final meta = MetaProgression(coins: cost);
      expect(meta.buyFor('apprentice', MetaStat.fortune), isTrue);
      expect(meta.levelOfFor('apprentice', MetaStat.fortune), 1);
      expect(meta.coins, 0);
    });

    test('refuses past the max level even with unlimited coins', () {
      final meta = MetaProgression(
        coins: 1000000,
        characterUpgradeLevels: {
          'apprentice': CharacterUpgradeLevels(resolve: kMetaMaxLevel),
        },
      );
      expect(meta.buyFor('apprentice', MetaStat.resolve), isFalse);
      expect(meta.levelOfFor('apprentice', MetaStat.resolve), kMetaMaxLevel);
    });
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
          characterUpgradeLevels: {
            'apprentice': CharacterUpgradeLevels(
              str: 1,
              vit: 2,
              dex: 3,
              intellect: 4,
              corruption: 5,
              haste: 6,
              fortune: 7,
              resolve: 8,
              magnet: 9,
              luck: 10,
              regen: 1,
              crit: 2,
            ),
            'bruiser': CharacterUpgradeLevels(str: 5, haste: 3),
          },
          ownedItemIds: {ShopItemId.secondWind.name},
        );
        await repo.save(meta);
        final loaded = await repo.load();
        expect(loaded.ownsSecondWind, isTrue);
        expect(loaded.ownsItem(ShopItemId.vitalityCharm), isFalse);
        // DECISIONS D-003 -- every dial round-trips per-character, and
        // stays separated by character id.
        expect(loaded.levelOfFor('apprentice', MetaStat.str), 1);
        expect(loaded.levelOfFor('apprentice', MetaStat.vit), 2);
        expect(loaded.levelOfFor('apprentice', MetaStat.dex), 3);
        expect(loaded.levelOfFor('apprentice', MetaStat.intellect), 4);
        expect(loaded.levelOfFor('apprentice', MetaStat.corruption), 5);
        expect(loaded.levelOfFor('apprentice', MetaStat.haste), 6);
        expect(loaded.levelOfFor('apprentice', MetaStat.fortune), 7);
        expect(loaded.levelOfFor('apprentice', MetaStat.resolve), 8);
        expect(loaded.levelOfFor('apprentice', MetaStat.magnet), 9);
        expect(loaded.levelOfFor('apprentice', MetaStat.luck), 10);
        expect(loaded.levelOfFor('apprentice', MetaStat.regen), 1);
        expect(loaded.levelOfFor('apprentice', MetaStat.crit), 2);
        expect(loaded.levelOfFor('bruiser', MetaStat.str), 5);
        expect(loaded.levelOfFor('bruiser', MetaStat.haste), 3);
        expect(loaded.levelOfFor('bruiser', MetaStat.vit), 0);
        expect(loaded.levelOfFor('bruiser', MetaStat.corruption), 0);
        expect(loaded.levelOfFor('skirmisher', MetaStat.str), 0); // never bought
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
      'crossing a threshold reports it as newly eligible but does NOT '
      'auto-grant/auto-claim (DECISIONS D-008)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final repo = MetaProgressionRepository();
        final newlyEligible = await repo.recordRoundEnd(
          coins: 0,
          gems: 0,
          kills: 1, // crosses first_blood's threshold of 1
          bossKills: 0,
          chestsOpened: 0,
          potionsCollected: 0,
          levelReached: 1,
          survivalTimeSec: 1,
        );
        expect(newlyEligible.map((a) => a.id), contains('first_blood'));
        final loaded = await repo.load();
        // Not claimed, no reward granted -- the player has to claim it by
        // hand (`claimAchievement`, its own test group below).
        expect(loaded.claimedAchievementIds, isNot(contains('first_blood')));
        expect(loaded.coins, 0);

        // A second round that still satisfies the same threshold must not
        // report it as "newly" eligible again -- it was already eligible
        // going into this call.
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
      },
    );

    test('a zero-progress round reports nothing newly eligible', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = MetaProgressionRepository();
      final newlyEligible = await repo.recordRoundEnd(
        coins: 0,
        gems: 0,
        kills: 0,
        bossKills: 0,
        chestsOpened: 0,
        potionsCollected: 0,
        levelReached: 1,
        survivalTimeSec: 0,
      );
      expect(newlyEligible, isEmpty);
    });
  });

  group('MetaProgressionRepository.claimAchievement (DECISIONS D-008)', () {
    test('fails and grants nothing if the threshold isn\'t met yet', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = MetaProgressionRepository();
      expect(await repo.claimAchievement('first_blood'), isFalse);
      final loaded = await repo.load();
      expect(loaded.claimedAchievementIds, isEmpty);
      expect(loaded.coins, 0);
    });

    test('succeeds once the threshold is met, granting the real reward',
        () async {
      SharedPreferences.setMockInitialValues({});
      final repo = MetaProgressionRepository();
      final firstBlood = kAchievements.firstWhere(
        (a) => a.id == 'first_blood',
      );
      await repo.recordRoundEnd(
        coins: 0,
        gems: 0,
        kills: 1,
        bossKills: 0,
        chestsOpened: 0,
        potionsCollected: 0,
        levelReached: 1,
        survivalTimeSec: 1,
      );
      expect(await repo.claimAchievement('first_blood'), isTrue);
      final loaded = await repo.load();
      expect(loaded.claimedAchievementIds, contains('first_blood'));
      expect(
        loaded.coins,
        firstBlood.reward == AchievementReward.coins
            ? firstBlood.rewardAmount
            : 0,
      );
    });

    test('refuses a second claim of an already-claimed achievement', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = MetaProgressionRepository();
      await repo.recordRoundEnd(
        coins: 0,
        gems: 0,
        kills: 1,
        bossKills: 0,
        chestsOpened: 0,
        potionsCollected: 0,
        levelReached: 1,
        survivalTimeSec: 1,
      );
      expect(await repo.claimAchievement('first_blood'), isTrue);
      expect(await repo.claimAchievement('first_blood'), isFalse);
      final loaded = await repo.load();
      final firstBlood = kAchievements.firstWhere(
        (a) => a.id == 'first_blood',
      );
      expect(
        loaded.coins,
        firstBlood.reward == AchievementReward.coins
            ? firstBlood.rewardAmount // unchanged -- not doubled
            : 0,
      );
    });

    test('an unknown achievement id fails harmlessly', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = MetaProgressionRepository();
      expect(await repo.claimAchievement('does_not_exist'), isFalse);
    });
  });
}
