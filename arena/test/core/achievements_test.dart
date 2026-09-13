import 'package:arena/core/achievements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kAchievements (DECISIONS D-091)', () {
    test('has exactly 20 entries', () {
      expect(kAchievements, hasLength(20));
    });

    test('every id is unique', () {
      final ids = kAchievements.map((a) => a.id).toSet();
      expect(ids, hasLength(kAchievements.length));
    });

    test('every threshold and reward amount is positive', () {
      for (final achievement in kAchievements) {
        expect(
          achievement.threshold,
          greaterThan(0),
          reason: achievement.id,
        );
        expect(
          achievement.rewardAmount,
          greaterThan(0),
          reason: achievement.id,
        );
      }
    });

    test('every AchievementStat is used by at least one achievement', () {
      final usedStats = kAchievements.map((a) => a.stat).toSet();
      expect(usedStats, AchievementStat.values.toSet());
    });
  });

  group('isAchievementMet', () {
    final achievement = kAchievements.first;

    test('false below the threshold', () {
      final values = buildStatValues(
        lifetimeKills: 0,
        lifetimeBossKills: 0,
        lifetimeGemsCollected: 0,
        lifetimeCoinsEarned: 0,
        lifetimeChestsOpened: 0,
        lifetimePotionsCollected: 0,
        highestLevelReached: 1,
        longestSurvivalTimeSec: 0,
      );
      expect(isAchievementMet(achievement, values), isFalse);
    });

    test('true at and above the threshold', () {
      final atThreshold = buildStatValues(
        lifetimeKills: achievement.threshold.toInt(),
        lifetimeBossKills: 0,
        lifetimeGemsCollected: 0,
        lifetimeCoinsEarned: 0,
        lifetimeChestsOpened: 0,
        lifetimePotionsCollected: 0,
        highestLevelReached: 1,
        longestSurvivalTimeSec: 0,
      );
      expect(isAchievementMet(achievement, atThreshold), isTrue);
    });

    test('an unset stat in the map reads as 0, not a crash', () {
      expect(statValueOf(AchievementStat.lifetimeKills, const {}), 0);
    });
  });

  group('anyAchievementPending (DECISIONS D-008)', () {
    final zeroValues = buildStatValues(
      lifetimeKills: 0,
      lifetimeBossKills: 0,
      lifetimeGemsCollected: 0,
      lifetimeCoinsEarned: 0,
      lifetimeChestsOpened: 0,
      lifetimePotionsCollected: 0,
      highestLevelReached: 1,
      longestSurvivalTimeSec: 0,
    );

    test('false when nothing has met its threshold yet', () {
      expect(anyAchievementPending(zeroValues, const {}), isFalse);
    });

    test('true once a threshold is met and not yet claimed', () {
      final firstBlood = kAchievements.firstWhere(
        (a) => a.id == 'first_blood',
      );
      final values = buildStatValues(
        lifetimeKills: firstBlood.threshold.toInt(),
        lifetimeBossKills: 0,
        lifetimeGemsCollected: 0,
        lifetimeCoinsEarned: 0,
        lifetimeChestsOpened: 0,
        lifetimePotionsCollected: 0,
        highestLevelReached: 1,
        longestSurvivalTimeSec: 0,
      );
      expect(anyAchievementPending(values, const {}), isTrue);
    });

    test('false again once every met achievement is already claimed', () {
      final firstBlood = kAchievements.firstWhere(
        (a) => a.id == 'first_blood',
      );
      final values = buildStatValues(
        lifetimeKills: firstBlood.threshold.toInt(),
        lifetimeBossKills: 0,
        lifetimeGemsCollected: 0,
        lifetimeCoinsEarned: 0,
        lifetimeChestsOpened: 0,
        lifetimePotionsCollected: 0,
        highestLevelReached: 1,
        longestSurvivalTimeSec: 0,
      );
      expect(anyAchievementPending(values, {'first_blood'}), isFalse);
    });
  });
}
