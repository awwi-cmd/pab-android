import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistent, cross-round meta-progression (DECISIONS D-047) — the
/// character-select screen's new "UPGRADES" tab, developer's spec verbatim:
/// STR/VIT/DEX/INT/CORRUPTION, 10 levels each, bought with coins earned
/// finishing rounds. This is a *different* wallet from `ArenaGame.
/// coinsEarned` (that one is round-scoped loot, reset every round per
/// CLAUDE.md §4.5) — [MetaProgressionRepository.addCoins] is the one place
/// a round's earnings cross over into this persistent one, called once from
/// `ArenaGame._endRound`.
///
/// Corruption is the odd one out — it doesn't buy a playable stat, it turns
/// a difficulty/reward dial (`core/game_rules.dart`'s
/// `corruptionSpawnIntervalMultiplier`/`corruptionEnemyStatMultiplier`/
/// `corruptionRewardMultiplier` read the level straight off this).
enum MetaStat { str, vit, dex, intellect, corruption }

extension MetaStatLabels on MetaStat {
  String get label {
    switch (this) {
      case MetaStat.str:
        return 'STR';
      case MetaStat.vit:
        return 'VIT';
      case MetaStat.dex:
        return 'DEX';
      case MetaStat.intellect:
        return 'INT';
      case MetaStat.corruption:
        return 'CORRUPTION';
    }
  }

  String get description {
    switch (this) {
      case MetaStat.str:
      case MetaStat.vit:
      case MetaStat.dex:
      case MetaStat.intellect:
        return '+1 $label per level, every run.';
      case MetaStat.corruption:
        return 'Tougher, faster enemies. Bigger rewards.';
    }
  }
}

/// Every track tops out at 10 (developer's spec: "everything in upgrades
/// has 10 levels").
const int kMetaMaxLevel = 10;

/// Cost to go from [currentLevel] to currentLevel + 1 (0-based, so the very
/// first purchase costs `metaUpgradeCost(0)`) — same growth-curve shape as
/// the in-round XP curve (`progression.dart`'s
/// kBaseXpToNextLevel/kXpGrowthFactor), deliberately steep so maxing one
/// track is a real long-term goal. First-guess placeholder, not tuned.
const double kMetaBaseCost = 50;
const double kMetaCostGrowth = 1.35;

int metaUpgradeCost(int currentLevel) {
  return (kMetaBaseCost * pow(kMetaCostGrowth, currentLevel)).round();
}

/// A snapshot of the shop's state — loaded fresh at character-select and at
/// arena entry, saved back on every purchase (same "screens own their own
/// copy, persist on every change" pattern as `Settings`, CLAUDE.md §4.9: no
/// state-management library).
class MetaProgression {
  MetaProgression({
    this.coins = 0,
    this.gems = 0,
    this.lifetimeKills = 0,
    this.strLevel = 0,
    this.vitLevel = 0,
    this.dexLevel = 0,
    this.intLevel = 0,
    this.corruptionLevel = 0,
  });

  int coins;

  /// A second, separate persistent currency (DECISIONS D-055) — gems
  /// dropped by enemies and found in chests, credited at round-over exactly
  /// like [coins] (`ArenaGame._endRound`), from the same round-scoped
  /// `ArenaGame.gemsCollected` count Round Over already displays. Not
  /// spendable on anything yet (no gem-priced item exists) — the wallet
  /// exists so the number is real and persists, same as `ShopScreen`
  /// shipping empty on purpose (D-047).
  int gems;

  /// Lifetime kills across every round ever played (DECISIONS D-055) — the
  /// character-unlock metric (`CharacterDef.unlockKillThreshold`). Credited
  /// at round-over from `ArenaGame.kills`, alongside coins/gems.
  int lifetimeKills;

  int strLevel;
  int vitLevel;
  int dexLevel;
  int intLevel;
  int corruptionLevel;

  int levelOf(MetaStat stat) {
    switch (stat) {
      case MetaStat.str:
        return strLevel;
      case MetaStat.vit:
        return vitLevel;
      case MetaStat.dex:
        return dexLevel;
      case MetaStat.intellect:
        return intLevel;
      case MetaStat.corruption:
        return corruptionLevel;
    }
  }

  void _setLevel(MetaStat stat, int value) {
    switch (stat) {
      case MetaStat.str:
        strLevel = value;
        return;
      case MetaStat.vit:
        vitLevel = value;
        return;
      case MetaStat.dex:
        dexLevel = value;
        return;
      case MetaStat.intellect:
        intLevel = value;
        return;
      case MetaStat.corruption:
        corruptionLevel = value;
        return;
    }
  }

  /// Buys the next level of [stat] if there's a level left and enough coins
  /// on hand. Returns whether the purchase went through — callers use this
  /// to decide whether to bother persisting/re-rendering.
  bool buy(MetaStat stat) {
    final current = levelOf(stat);
    if (current >= kMetaMaxLevel) return false;
    final cost = metaUpgradeCost(current);
    if (coins < cost) return false;
    coins -= cost;
    _setLevel(stat, current + 1);
    return true;
  }

  // +1 attribute point per level — lands directly on `StatBlock`'s own
  // integer str/vit/dex/intellect scale (core/stats.dart), so a level
  // bought here is worth exactly what a level of the base attribute is
  // worth in every derived combat formula, for free.
  int get bonusStr => strLevel;
  int get bonusVit => vitLevel;
  int get bonusDex => dexLevel;
  int get bonusIntellect => intLevel;
}

/// Reads/writes [MetaProgression] to `SharedPreferences` — same shape as
/// `SettingsRepository` (`core/settings.dart`).
class MetaProgressionRepository {
  static const _kCoins = 'meta.coins';
  static const _kGems = 'meta.gems';
  static const _kLifetimeKills = 'meta.lifetimeKills';
  static const _kStr = 'meta.str';
  static const _kVit = 'meta.vit';
  static const _kDex = 'meta.dex';
  static const _kInt = 'meta.int';
  static const _kCorruption = 'meta.corruption';

  Future<MetaProgression> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MetaProgression(
      coins: prefs.getInt(_kCoins) ?? 0,
      gems: prefs.getInt(_kGems) ?? 0,
      lifetimeKills: prefs.getInt(_kLifetimeKills) ?? 0,
      strLevel: prefs.getInt(_kStr) ?? 0,
      vitLevel: prefs.getInt(_kVit) ?? 0,
      dexLevel: prefs.getInt(_kDex) ?? 0,
      intLevel: prefs.getInt(_kInt) ?? 0,
      corruptionLevel: prefs.getInt(_kCorruption) ?? 0,
    );
  }

  Future<void> save(MetaProgression meta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCoins, meta.coins);
    await prefs.setInt(_kGems, meta.gems);
    await prefs.setInt(_kLifetimeKills, meta.lifetimeKills);
    await prefs.setInt(_kStr, meta.strLevel);
    await prefs.setInt(_kVit, meta.vitLevel);
    await prefs.setInt(_kDex, meta.dexLevel);
    await prefs.setInt(_kInt, meta.intLevel);
    await prefs.setInt(_kCorruption, meta.corruptionLevel);
  }

  /// Round-over credit (DECISIONS D-047) — read-modify-write against
  /// whatever's currently saved, rather than trusting a copy the caller
  /// might have loaded a while ago, so this can't clobber a purchase made
  /// in another screen since that copy was loaded.
  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    final current = await load();
    current.coins += amount;
    await save(current);
  }

  /// Same shape as [addCoins] (DECISIONS D-055) — gems earned this round
  /// (`ArenaGame.gemsCollected`, enemy drops + chests together) crossing
  /// over into the persistent wallet.
  Future<void> addGems(int amount) async {
    if (amount <= 0) return;
    final current = await load();
    current.gems += amount;
    await save(current);
  }

  /// Same shape again (DECISIONS D-055) — this round's kill count
  /// (`ArenaGame.kills`) crossing over into the lifetime total that gates
  /// character unlocks.
  Future<void> addLifetimeKills(int amount) async {
    if (amount <= 0) return;
    final current = await load();
    current.lifetimeKills += amount;
    await save(current);
  }

  /// Debug-only direct wallet edits (Settings' DEBUG section, DECISIONS
  /// D-059) — unlike [addCoins]/[addGems] above (round-over credits, which
  /// ignore a non-positive amount since a zero-kill round has nothing to
  /// add), these take any delta including negative, clamped so the wallet
  /// can't go below zero, and work with no live `ArenaGame` at all — reached
  /// from Settings off the main menu, not just the arena's Pause Menu.
  Future<void> debugAdjustCoins(int delta) async {
    final current = await load();
    current.coins = (current.coins + delta).clamp(0, 1 << 30);
    await save(current);
  }

  Future<void> debugAdjustGems(int delta) async {
    final current = await load();
    current.gems = (current.gems + delta).clamp(0, 1 << 30);
    await save(current);
  }

  /// Zeroes coins/gems only (DECISIONS D-059) — `lifetimeKills` (the
  /// character-unlock metric) and the STR/VIT/DEX/INT/CORRUPTION levels
  /// already bought are progress, not spendable currency, so a "reset
  /// wallet" debug tool leaves both alone.
  Future<void> debugResetWallet() async {
    final current = await load();
    current.coins = 0;
    current.gems = 0;
    await save(current);
  }
}
