import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/meta_progression.dart';
import '../widgets/coin_icon.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/stat_bar.dart';

/// The character-select screen's "UPGRADES" tab (DECISIONS D-047, developer's
/// spec): persistent, cross-round purchases funded by coins earned finishing
/// rounds (`ArenaGame.coinsEarned` → `MetaProgressionRepository.addCoins`,
/// credited once at round-over). Five tracks, 10 levels each, increasing
/// cost per level (`metaUpgradeCost`) — STR/VIT/DEX/INT are +1 attribute
/// point per level (`ArenaGame.effectiveStats`); CORRUPTION is the trade-off
/// lever (`core/game_rules.dart`'s corruption* multipliers): tougher, faster
/// enemies for bigger rewards.
///
/// Loads/saves its own `MetaProgression` copy (no state-management library,
/// CLAUDE.md §4.9) — same pattern as `SettingsScreen`.
class UpgradesScreen extends StatefulWidget {
  const UpgradesScreen({super.key});

  static const route = '/upgrades';

  @override
  State<UpgradesScreen> createState() => _UpgradesScreenState();
}

class _UpgradesScreenState extends State<UpgradesScreen> {
  final _repo = MetaProgressionRepository();
  MetaProgression? _meta;

  @override
  void initState() {
    super.initState();
    _repo.load().then((meta) {
      if (!mounted) return;
      setState(() => _meta = meta);
    });
  }

  void _buy(MetaStat stat) {
    final meta = _meta;
    if (meta == null) return;
    if (!meta.buy(stat)) return; // not enough coins, or already maxed
    setState(() {}); // meta is mutated in place, just re-render
    _repo.save(meta);
  }

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    return ScreenScaffold(
      title: 'UPGRADES',
      child: meta == null
          ? const Center(
              child: CircularProgressIndicator(color: ArenaColors.accent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WalletRow(coins: meta.coins),
                  const SizedBox(height: 20),
                  for (final stat in MetaStat.values) ...[
                    _UpgradeRow(stat: stat, meta: meta, onBuy: () => _buy(stat)),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
    );
  }
}

class _WalletRow extends StatelessWidget {
  const _WalletRow({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CoinIcon(size: 40),
        const SizedBox(width: 10),
        Text(
          '$coins',
          style: const TextStyle(
            color: ArenaColors.accent,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.stat,
    required this.meta,
    required this.onBuy,
  });

  final MetaStat stat;
  final MetaProgression meta;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final level = meta.levelOf(stat);
    final maxed = level >= kMetaMaxLevel;
    final cost = maxed ? null : metaUpgradeCost(level);
    final affordable = cost != null && meta.coins >= cost;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ArenaColors.surface,
        border: Border.all(color: ArenaColors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatBar(label: stat.label, value: level, max: kMetaMaxLevel),
          const SizedBox(height: 4),
          Text(
            stat.description,
            style: const TextStyle(color: ArenaColors.textDim, fontSize: 12),
          ),
          const SizedBox(height: 8),
          PixelButton(
            label: maxed ? 'MAXED' : 'BUY — $cost coins',
            enabled: !maxed && affordable,
            onPressed: onBuy,
          ),
        ],
      ),
    );
  }
}
