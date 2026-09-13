import 'package:flutter/material.dart';

import '../../core/achievements.dart';
import '../../core/constants.dart';
import '../../core/meta_progression.dart';
import '../widgets/coin_icon.dart';
import '../widgets/gem_icon.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_scaffold.dart';

/// The main menu's "ACHIEVEMENTS" screen (DECISIONS D-091, developer's spec
/// verbatim: a main-menu button "in between start and settings," a
/// scrollable list of the 20 `core/achievements.dart` entries).
///
/// DECISIONS D-008: rewards are no longer granted automatically the moment
/// a round-end crosses a threshold — the player has to open this screen and
/// tap CLAIM themselves (`MetaProgressionRepository.claimAchievement`). Each
/// card is one of 3 states now, not the old binary claimed/not: locked (below
/// threshold), pending (threshold met, a CLAIM button shows), claimed (its
/// reward already collected). The main menu's own ACHIEVEMENTS button gets a
/// pip badge whenever anything here is pending (`MainMenuScreen`,
/// `anyAchievementPending`).
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

  Future<void> _claim(Achievement achievement) async {
    final claimed = await _repo.claimAchievement(achievement.id);
    if (!claimed || !mounted) return;
    await _load(); // re-read the real persisted coins/gems/claimed set
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
                final pending = !claimed &&
                    isAchievementMet(achievement, statValues);
                return _AchievementCard(
                  achievement: achievement,
                  claimed: claimed,
                  pending: pending,
                  current: current,
                  onClaim: pending ? () => _claim(achievement) : null,
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
    required this.pending,
    required this.current,
    required this.onClaim,
  });

  final Achievement achievement;
  final bool claimed;
  final bool pending;
  final num current;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final fraction =
        (current / achievement.threshold).clamp(0.0, 1.0).toDouble();
    // Pending reads like claimed (full-brightness accent border) -- it's
    // "yours, go get it," not "still locked" -- only claimed also gets the
    // checkmark.
    final unlockedLook = claimed || pending;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ArenaColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: unlockedLook ? ArenaColors.accent : ArenaColors.surfaceAlt,
          width: unlockedLook ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RewardBadge(achievement: achievement, unlockedLook: unlockedLook),
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
                          color: unlockedLook
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
                        color: unlockedLook
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
                // DECISIONS D-008: the actual claim action -- only pending
                // achievements get this row at all.
                if (pending) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: PixelButton(label: 'CLAIM', onPressed: onClaim),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The reward icon + amount, dimmed until [unlockedLook] (claimed or
/// pending) — same "greyed out until you have it" language
/// `CharacterSelectScreen`'s locked-slot panel already uses.
class _RewardBadge extends StatelessWidget {
  const _RewardBadge({required this.achievement, required this.unlockedLook});

  final Achievement achievement;
  final bool unlockedLook;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: unlockedLook ? 1.0 : 0.4,
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
