import 'package:flutter/material.dart';

import '../../core/achievements.dart';
import '../../core/constants.dart';
import '../../core/meta_progression.dart';
import '../widgets/coin_icon.dart';
import '../widgets/gem_icon.dart';
import '../widgets/screen_scaffold.dart';

/// The main menu's "ACHIEVEMENTS" screen (DECISIONS D-091, developer's spec
/// verbatim: a main-menu button "in between start and settings," a
/// scrollable list of the 20 `core/achievements.dart` entries). Rewards are
/// granted automatically the moment a round-end crosses a threshold
/// (`MetaProgressionRepository.recordRoundEnd`) — there's no "claim"
/// button here on purpose, this screen is read-only progress + history,
/// the same way Character Select's locked-slot panel shows progress toward
/// an unlock without a button to press either.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  static const route = '/achievements';

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _repo = MetaProgressionRepository();
  MetaProgression? _meta;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final meta = await _repo.load();
    if (!mounted) return;
    setState(() => _meta = meta);
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    if (meta == null) {
      return const ScreenScaffold(
        title: 'ACHIEVEMENTS',
        child: Center(
          child: CircularProgressIndicator(color: ArenaColors.accent),
        ),
      );
    }

    final statValues = buildStatValues(
      lifetimeKills: meta.lifetimeKills,
      lifetimeBossKills: meta.lifetimeBossKills,
      lifetimeGemsCollected: meta.lifetimeGemsCollected,
      lifetimeCoinsEarned: meta.lifetimeCoinsEarned,
      lifetimeChestsOpened: meta.lifetimeChestsOpened,
      lifetimePotionsCollected: meta.lifetimePotionsCollected,
      highestLevelReached: meta.highestLevelReached,
      longestSurvivalTimeSec: meta.longestSurvivalTimeSec,
    );
    final claimedCount = kAchievements
        .where((a) => meta.claimedAchievementIds.contains(a.id))
        .length;

    return ScreenScaffold(
      title: 'ACHIEVEMENTS',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Text(
              '$claimedCount / ${kAchievements.length} unlocked',
              style: const TextStyle(
                color: ArenaColors.textDim,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: kAchievements.length,
              itemBuilder: (context, i) {
                final achievement = kAchievements[i];
                final claimed =
                    meta.claimedAchievementIds.contains(achievement.id);
                final current = statValueOf(achievement.stat, statValues);
                return _AchievementCard(
                  achievement: achievement,
                  claimed: claimed,
                  current: current,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.claimed,
    required this.current,
  });

  final Achievement achievement;
  final bool claimed;
  final num current;

  @override
  Widget build(BuildContext context) {
    final fraction =
        (current / achievement.threshold).clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ArenaColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: claimed ? ArenaColors.accent : ArenaColors.surfaceAlt,
          width: claimed ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RewardBadge(achievement: achievement, claimed: claimed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.name,
                        style: TextStyle(
                          color: claimed
                              ? ArenaColors.textPrimary
                              : ArenaColors.textDim,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (claimed)
                      const Icon(
                        Icons.check_circle,
                        color: ArenaColors.accent,
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: const TextStyle(
                    color: ArenaColors.textDim,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    Container(height: 8, color: ArenaColors.surfaceAlt),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(
                        height: 8,
                        color: claimed
                            ? ArenaColors.accent
                            : ArenaColors.textDim,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${current.clamp(0, achievement.threshold).toInt()} / '
                  '${achievement.threshold.toInt()}',
                  style: const TextStyle(
                    color: ArenaColors.textDim,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The reward icon + amount, dimmed until [claimed] — same "greyed out
/// until you have it" language `CharacterSelectScreen`'s locked-slot panel
/// already uses.
class _RewardBadge extends StatelessWidget {
  const _RewardBadge({required this.achievement, required this.claimed});

  final Achievement achievement;
  final bool claimed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: claimed ? 1.0 : 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          switch (achievement.reward) {
            AchievementReward.coins => const CoinIcon(size: 28),
            AchievementReward.gems => const GemIcon(size: 26),
          },
          const SizedBox(height: 2),
          Text(
            '+${achievement.rewardAmount}',
            style: const TextStyle(
              color: ArenaColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
