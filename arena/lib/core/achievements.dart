// The achievements list, its evaluation logic, and nothing else -- this
// file deliberately has zero imports of `meta_progression.dart` (DECISIONS
// D-091), even though every achievement's progress is ultimately read off
// a `MetaProgression`. Evaluation here works against a plain
// `Map<AchievementStat, num>` (`buildStatValues` builds one from named
// values) instead of the `MetaProgression` type directly, so
// `core/meta_progression.dart` can import *this* file (to grant rewards at
// round-end) without the reverse import ever needing to exist -- a real
// two-file cycle, avoided by keeping this one a leaf.

/// Every lifetime stat an achievement can be gated on. `lifetimeKills`
/// mirrors `MetaProgression.lifetimeKills` (the character-unlock metric,
/// DECISIONS D-055); the rest are new counters `MetaProgressionRepository.
/// recordRoundEnd` credits alongside it.
enum AchievementStat {
  lifetimeKills,
  lifetimeBossKills,
  lifetimeGemsCollected,
  lifetimeCoinsEarned,
  lifetimeChestsOpened,
  lifetimePotionsCollected,
  highestLevelReached,
  longestSurvivalTimeSec,
}

enum AchievementReward { coins, gems }

/// One achievement: reach [threshold] on [stat] (lifetime, monotonically
/// increasing — never re-locks) and earn [rewardAmount] of [reward] into
/// the wallet, once. `threshold` is `num` rather than `int` — every stat
/// here is actually an int except `longestSurvivalTimeSec`.
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.stat,
    required this.threshold,
    required this.reward,
    required this.rewardAmount,
  });

  /// Stable, persisted key (`MetaProgression.claimedAchievementIds`) — never
  /// rename an existing one, or a player's already-claimed achievement
  /// looks unclaimed again and could double-grant its reward.
  final String id;
  final String name;
  final String description;
  final AchievementStat stat;
  final num threshold;
  final AchievementReward reward;
  final int rewardAmount;
}

/// Builds the value map [isAchievementMet]/evaluation reads — one place
/// that maps `AchievementStat` to the field it actually means, called by
/// both `MetaProgressionRepository.recordRoundEnd` (to grant rewards) and
/// `AchievementsScreen` (to render progress), so the two can never read a
/// stat differently from each other.
Map<AchievementStat, num> buildStatValues({
  required int lifetimeKills,
  required int lifetimeBossKills,
  required int lifetimeGemsCollected,
  required int lifetimeCoinsEarned,
  required int lifetimeChestsOpened,
  required int lifetimePotionsCollected,
  required int highestLevelReached,
  required double longestSurvivalTimeSec,
}) {
  return {
    AchievementStat.lifetimeKills: lifetimeKills,
    AchievementStat.lifetimeBossKills: lifetimeBossKills,
    AchievementStat.lifetimeGemsCollected: lifetimeGemsCollected,
    AchievementStat.lifetimeCoinsEarned: lifetimeCoinsEarned,
    AchievementStat.lifetimeChestsOpened: lifetimeChestsOpened,
    AchievementStat.lifetimePotionsCollected: lifetimePotionsCollected,
    AchievementStat.highestLevelReached: highestLevelReached,
    AchievementStat.longestSurvivalTimeSec: longestSurvivalTimeSec,
  };
}

num statValueOf(AchievementStat stat, Map<AchievementStat, num> values) =>
    values[stat] ?? 0;

bool isAchievementMet(
  Achievement achievement,
  Map<AchievementStat, num> values,
) =>
    statValueOf(achievement.stat, values) >= achievement.threshold;

/// The 20 achievements (DECISIONS D-091, developer's ask verbatim: "Create
/// a list of 20 achievements that give rewards to your wallet"). Tiered
/// across every lifetime stat the round-end flow already has real numbers
/// for — kills, bosses, gems, coins, chests, potions — plus two per-round
/// high-water marks (level reached, survival time) rather than another
/// lifetime total, since those two are naturally "best run," not
/// "cumulative." Reward sizes roughly track `SHOP`'s own gem-cost scale and
/// the meta-upgrade coin-cost curve (`kMetaBaseCost`/`kMetaCostGrowth`) so
/// an achievement payout is a real dent in an upgrade's cost, not
/// negligible — first-guess placeholders, not tuned on-device yet, same as
/// most of this project's first-pass numbers.
const List<Achievement> kAchievements = [
  Achievement(
    id: 'first_blood',
    name: 'First Blood',
    description: 'Get your first kill.',
    stat: AchievementStat.lifetimeKills,
    threshold: 1,
    reward: AchievementReward.coins,
    rewardAmount: 10,
  ),
  Achievement(
    id: 'exterminator_1',
    name: 'Exterminator I',
    description: 'Kill 100 enemies, lifetime.',
    stat: AchievementStat.lifetimeKills,
    threshold: 100,
    reward: AchievementReward.coins,
    rewardAmount: 50,
  ),
  Achievement(
    id: 'exterminator_2',
    name: 'Exterminator II',
    description: 'Kill 500 enemies, lifetime.',
    stat: AchievementStat.lifetimeKills,
    threshold: 500,
    reward: AchievementReward.coins,
    rewardAmount: 150,
  ),
  Achievement(
    id: 'exterminator_3',
    name: 'Exterminator III',
    description: 'Kill 2,000 enemies, lifetime.',
    stat: AchievementStat.lifetimeKills,
    threshold: 2000,
    reward: AchievementReward.coins,
    rewardAmount: 500,
  ),
  Achievement(
    id: 'boss_slayer_1',
    name: 'Boss Slayer I',
    description: 'Defeat your first boss.',
    stat: AchievementStat.lifetimeBossKills,
    threshold: 1,
    reward: AchievementReward.gems,
    rewardAmount: 25,
  ),
  Achievement(
    id: 'boss_slayer_2',
    name: 'Boss Slayer II',
    description: 'Defeat 10 bosses, lifetime.',
    stat: AchievementStat.lifetimeBossKills,
    threshold: 10,
    reward: AchievementReward.gems,
    rewardAmount: 100,
  ),
  Achievement(
    id: 'boss_slayer_3',
    name: 'Boss Slayer III',
    description: 'Defeat 50 bosses, lifetime.',
    stat: AchievementStat.lifetimeBossKills,
    threshold: 50,
    reward: AchievementReward.gems,
    rewardAmount: 400,
  ),
  Achievement(
    id: 'gem_collector_1',
    name: 'Gem Collector I',
    description: 'Collect 50 gems, lifetime.',
    stat: AchievementStat.lifetimeGemsCollected,
    threshold: 50,
    reward: AchievementReward.gems,
    rewardAmount: 20,
  ),
  Achievement(
    id: 'gem_collector_2',
    name: 'Gem Collector II',
    description: 'Collect 250 gems, lifetime.',
    stat: AchievementStat.lifetimeGemsCollected,
    threshold: 250,
    reward: AchievementReward.gems,
    rewardAmount: 75,
  ),
  Achievement(
    id: 'gem_collector_3',
    name: 'Gem Collector III',
    description: 'Collect 1,000 gems, lifetime.',
    stat: AchievementStat.lifetimeGemsCollected,
    threshold: 1000,
    reward: AchievementReward.gems,
    rewardAmount: 300,
  ),
  Achievement(
    id: 'coin_hoarder_1',
    name: 'Coin Hoarder I',
    description: 'Earn 500 coins, lifetime.',
    stat: AchievementStat.lifetimeCoinsEarned,
    threshold: 500,
    reward: AchievementReward.coins,
    rewardAmount: 100,
  ),
  Achievement(
    id: 'coin_hoarder_2',
    name: 'Coin Hoarder II',
    description: 'Earn 2,500 coins, lifetime.',
    stat: AchievementStat.lifetimeCoinsEarned,
    threshold: 2500,
    reward: AchievementReward.coins,
    rewardAmount: 400,
  ),
  Achievement(
    id: 'coin_hoarder_3',
    name: 'Coin Hoarder III',
    description: 'Earn 10,000 coins, lifetime.',
    stat: AchievementStat.lifetimeCoinsEarned,
    threshold: 10000,
    reward: AchievementReward.coins,
    rewardAmount: 1500,
  ),
  Achievement(
    id: 'chest_opener_1',
    name: 'Chest Opener I',
    description: 'Open 5 chests, lifetime.',
    stat: AchievementStat.lifetimeChestsOpened,
    threshold: 5,
    reward: AchievementReward.gems,
    rewardAmount: 15,
  ),
  Achievement(
    id: 'chest_opener_2',
    name: 'Chest Opener II',
    description: 'Open 25 chests, lifetime.',
    stat: AchievementStat.lifetimeChestsOpened,
    threshold: 25,
    reward: AchievementReward.gems,
    rewardAmount: 60,
  ),
  Achievement(
    id: 'potion_sipper',
    name: 'Potion Sipper',
    description: 'Collect 25 potions, lifetime.',
    stat: AchievementStat.lifetimePotionsCollected,
    threshold: 25,
    reward: AchievementReward.coins,
    rewardAmount: 60,
  ),
  Achievement(
    id: 'level_10',
    name: 'Rising Star',
    description: 'Reach level 10 in a single round.',
    stat: AchievementStat.highestLevelReached,
    threshold: 10,
    reward: AchievementReward.coins,
    rewardAmount: 50,
  ),
  Achievement(
    id: 'level_20',
    name: 'Ascendant',
    description: 'Reach level 20 in a single round.',
    stat: AchievementStat.highestLevelReached,
    threshold: 20,
    reward: AchievementReward.coins,
    rewardAmount: 200,
  ),
  Achievement(
    id: 'survivor_5',
    name: 'Survivor',
    description: 'Survive 5 minutes in a single round.',
    stat: AchievementStat.longestSurvivalTimeSec,
    threshold: 300,
    reward: AchievementReward.coins,
    rewardAmount: 100,
  ),
  Achievement(
    id: 'marathon_10',
    name: 'Marathon',
    description: 'Survive 10 minutes in a single round.',
    stat: AchievementStat.longestSurvivalTimeSec,
    threshold: 600,
    reward: AchievementReward.coins,
    rewardAmount: 300,
  ),
];
