import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'achievements.dart';
import 'shop.dart';

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
///
/// `haste`/`fortune`/`resolve` (DECISIONS D-067) are 3 more of that same
/// "dial," not raw attribute adds like STR/VIT/DEX/INT — each reads
/// straight off `core/game_rules.dart`'s own per-level formula
/// (`hasteAttackSpeedMultiplier`/`fortuneRewardMultiplier`/
/// `resolveDamageResistance`+`resolveHpRegenPerSec`), same shape as
/// Corruption's own multipliers. The Upgrades screen's page 2
/// (`UpgradesScreen`) is exactly `[corruption, haste, fortune, resolve]` —
/// this enum's declaration order *is* that page's row order, so a future
/// 4th dial on that page is an enum member here, not a separate list
/// somewhere else.
/// `magnet`/`luck`/`regen`/`crit` (DECISIONS D-069) are the Upgrades
/// screen's 3rd page — same "pure dial, not a raw attribute add" shape as
/// haste/fortune/resolve, each reading straight off `core/game_rules.dart`'s
/// own per-level formula (`magnetPickupRadiusMultiplier`/
/// `luckGemDropBonus`/`regenHpPerSec`/`critChance`). This enum's declaration
/// order is that page's row order, same as page 2's own doc comment above
/// already established.
enum MetaStat {
  str,
  vit,
  dex,
  intellect,
  corruption,
  haste,
  fortune,
  resolve,
  magnet,
  luck,
  regen,
  crit,
}

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
        // DECISIONS D-071: displayed name only, shortened ("CORRUPTION" ->
        // "CHAOS") -- the enum member, field names, and every multiplier
        // function in game_rules.dart stay `corruption*`, same
        // functionality end to end, just a shorter label on the row.
        return 'CHAOS';
      case MetaStat.haste:
        return 'HASTE';
      case MetaStat.fortune:
        return 'FORTUNE';
      case MetaStat.resolve:
        return 'RESOLVE';
      case MetaStat.magnet:
        return 'MAGNET';
      case MetaStat.luck:
        return 'LUCK';
      case MetaStat.regen:
        return 'REGEN';
      case MetaStat.crit:
        return 'CRIT';
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
      case MetaStat.haste:
        return '+5% attack speed per level, every run.';
      case MetaStat.fortune:
        return '+10% coin value per level, every run.';
      case MetaStat.resolve:
        return 'Less damage taken, faster HP regen, every run.';
      case MetaStat.magnet:
        return '+15% pickup radius per level, every run.';
      case MetaStat.luck:
        return '+1% gem drop chance per level, every run.';
      case MetaStat.regen:
        return '+HP regen per level, every run.';
      case MetaStat.crit:
        return '+3% crit chance per level, every run.';
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
    this.hasteLevel = 0,
    this.fortuneLevel = 0,
    this.resolveLevel = 0,
    this.magnetLevel = 0,
    this.luckLevel = 0,
    this.regenLevel = 0,
    this.critLevel = 0,
    Set<String>? ownedItemIds,
    this.lifetimeBossKills = 0,
    this.lifetimeGemsCollected = 0,
    this.lifetimeCoinsEarned = 0,
    this.lifetimeChestsOpened = 0,
    this.lifetimePotionsCollected = 0,
    this.highestLevelReached = 1,
    this.longestSurvivalTimeSec = 0,
    Set<String>? claimedAchievementIds,
  }) : ownedItemIds = ownedItemIds ?? {},
       claimedAchievementIds = claimedAchievementIds ?? {};

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
  int hasteLevel;
  int fortuneLevel;
  int resolveLevel;
  int magnetLevel;
  int luckLevel;
  int regenLevel;
  int critLevel;

  /// SHOP's owned items (DECISIONS D-069) — `ShopItemId.name` strings rather
  /// than the enum itself, so `SharedPreferences.getStringList` can store it
  /// directly (same reasoning as every other primitive-only field here).
  final Set<String> ownedItemIds;

  // ACHIEVEMENTS (DECISIONS D-091) -- lifetime counters distinct from the
  // *spendable* `coins`/`gems` balances above, which go down when the
  // player buys something: an achievement like "earn 10,000 coins" needs a
  // total that only ever goes up, the same way `lifetimeKills` already does
  // for the kill-count unlock gate. Each is credited once per round from
  // `MetaProgressionRepository.recordRoundEnd` (`ArenaGame._persistRoundRewards`),
  // reading a matching round-scoped counter on `ArenaGame`.
  int lifetimeBossKills;
  int lifetimeGemsCollected;
  int lifetimeCoinsEarned;
  int lifetimeChestsOpened;
  int lifetimePotionsCollected;

  /// The highest in-round level ever reached, across every round —
  /// `ArenaGame.level` is round-scoped (resets every round, CLAUDE.md
  /// §4.5), this is `max(this, that)` credited at round-over.
  int highestLevelReached;

  /// The longest single round's survival time in seconds — `ArenaGame.
  /// elapsed`'s own high-water mark, same `max()` treatment as
  /// [highestLevelReached].
  double longestSurvivalTimeSec;

  /// `Achievement.id` strings already granted their one-time reward
  /// (`core/achievements.dart`) — same "own it or don't, no re-granting"
  /// shape [ownedItemIds] already has for SHOP.
  final Set<String> claimedAchievementIds;

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
      case MetaStat.haste:
        return hasteLevel;
      case MetaStat.fortune:
        return fortuneLevel;
      case MetaStat.resolve:
        return resolveLevel;
      case MetaStat.magnet:
        return magnetLevel;
      case MetaStat.luck:
        return luckLevel;
      case MetaStat.regen:
        return regenLevel;
      case MetaStat.crit:
        return critLevel;
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
      case MetaStat.haste:
        hasteLevel = value;
        return;
      case MetaStat.fortune:
        fortuneLevel = value;
        return;
      case MetaStat.resolve:
        resolveLevel = value;
        return;
      case MetaStat.magnet:
        magnetLevel = value;
        return;
      case MetaStat.luck:
        luckLevel = value;
        return;
      case MetaStat.regen:
        regenLevel = value;
        return;
      case MetaStat.crit:
        critLevel = value;
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

  // SHOP (DECISIONS D-069) -- permanent one-time purchases, priced in gems,
  // distinct from the leveled coin dials above.
  bool ownsItem(ShopItemId id) => ownedItemIds.contains(id.name);

  /// Buys [item] if not already owned and enough gems are on hand. Same
  /// afford/cap-check-then-deduct shape as [buy] above.
  bool buyItem(ShopItem item) {
    if (ownsItem(item.id)) return false;
    if (gems < item.costGems) return false;
    gems -= item.costGems;
    ownedItemIds.add(item.id.name);
    return true;
  }

  double get bonusMaxHpFromShop =>
      ownsItem(ShopItemId.vitalityCharm) ? kVitalityCharmBonusMaxHp : 0;
  double get bonusMoveSpeedFromShop =>
      ownsItem(ShopItemId.swiftBoots) ? kSwiftBootsBonusMoveSpeed : 0;
  double get damageMultiplierFromShop =>
      ownsItem(ShopItemId.sharpEdge) ? kSharpEdgeDamageMultiplier : 1.0;
  double get damageResistanceFromShop =>
      ownsItem(ShopItemId.ironWill) ? kIronWillDamageResistance : 0.0;
  bool get ownsSecondWind => ownsItem(ShopItemId.secondWind);

  // SHOP page 2/3 (DECISIONS D-070) -- same "owned or not, magnitude lives
  // in shop.dart" shape as page 1's getters above. Battle Fury's own
  // conditional (only below half HP) needs the live player, so it's just an
  // `ownsItem` check here -- `ArenaGame.resolveAttackDamage` applies the
  // threshold itself, this isn't a bare magnitude getter like the others.
  double get attackSpeedMultiplierFromShop =>
      ownsItem(ShopItemId.quickHands) ? kQuickHandsAttackSpeedMultiplier : 1.0;
  double get potionHealMultiplierFromShop =>
      ownsItem(ShopItemId.potionMaster) ? kPotionMasterHealMultiplier : 1.0;
  double get eliteChanceMultiplierFromShop =>
      ownsItem(ShopItemId.steelNerves) ? kSteelNervesEliteChanceMultiplier : 1.0;
  double get vampiricHealPerKillFromShop =>
      ownsItem(ShopItemId.vampiricTouch) ? kVampiricTouchHealPerKill : 0.0;
  double get chestGemMultiplierFromShop =>
      ownsItem(ShopItemId.treasureHunter)
          ? kTreasureHunterGemRewardMultiplier
          : 1.0;
  double get xpMultiplierFromShop =>
      ownsItem(ShopItemId.scholarsInsight) ? kScholarsInsightXpMultiplier : 1.0;
  double get coinMultiplierFromShop =>
      ownsItem(ShopItemId.goldenTouch) ? kGoldenTouchCoinMultiplier : 1.0;
  double get gemDropBonusFromShop =>
      ownsItem(ShopItemId.gemHoarder) ? kGemHoarderDropBonus : 0.0;
  bool get ownsBossHunter => ownsItem(ShopItemId.bossHunter);
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
  static const _kHaste = 'meta.haste';
  static const _kFortune = 'meta.fortune';
  static const _kResolve = 'meta.resolve';
  static const _kMagnet = 'meta.magnet';
  static const _kLuck = 'meta.luck';
  static const _kRegen = 'meta.regen';
  static const _kCrit = 'meta.crit';
  static const _kOwnedItems = 'meta.ownedItems';
  static const _kLifetimeBossKills = 'meta.lifetimeBossKills';
  static const _kLifetimeGemsCollected = 'meta.lifetimeGemsCollected';
  static const _kLifetimeCoinsEarned = 'meta.lifetimeCoinsEarned';
  static const _kLifetimeChestsOpened = 'meta.lifetimeChestsOpened';
  static const _kLifetimePotionsCollected = 'meta.lifetimePotionsCollected';
  static const _kHighestLevelReached = 'meta.highestLevelReached';
  static const _kLongestSurvivalTimeSec = 'meta.longestSurvivalTimeSec';
  static const _kClaimedAchievements = 'meta.claimedAchievements';

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
      hasteLevel: prefs.getInt(_kHaste) ?? 0,
      fortuneLevel: prefs.getInt(_kFortune) ?? 0,
      resolveLevel: prefs.getInt(_kResolve) ?? 0,
      magnetLevel: prefs.getInt(_kMagnet) ?? 0,
      luckLevel: prefs.getInt(_kLuck) ?? 0,
      regenLevel: prefs.getInt(_kRegen) ?? 0,
      critLevel: prefs.getInt(_kCrit) ?? 0,
      ownedItemIds: (prefs.getStringList(_kOwnedItems) ?? const []).toSet(),
      lifetimeBossKills: prefs.getInt(_kLifetimeBossKills) ?? 0,
      lifetimeGemsCollected: prefs.getInt(_kLifetimeGemsCollected) ?? 0,
      lifetimeCoinsEarned: prefs.getInt(_kLifetimeCoinsEarned) ?? 0,
      lifetimeChestsOpened: prefs.getInt(_kLifetimeChestsOpened) ?? 0,
      lifetimePotionsCollected: prefs.getInt(_kLifetimePotionsCollected) ?? 0,
      highestLevelReached: prefs.getInt(_kHighestLevelReached) ?? 1,
      longestSurvivalTimeSec: prefs.getDouble(_kLongestSurvivalTimeSec) ?? 0,
      claimedAchievementIds:
          (prefs.getStringList(_kClaimedAchievements) ?? const []).toSet(),
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
    await prefs.setInt(_kHaste, meta.hasteLevel);
    await prefs.setInt(_kFortune, meta.fortuneLevel);
    await prefs.setInt(_kResolve, meta.resolveLevel);
    await prefs.setInt(_kMagnet, meta.magnetLevel);
    await prefs.setInt(_kLuck, meta.luckLevel);
    await prefs.setInt(_kRegen, meta.regenLevel);
    await prefs.setInt(_kCrit, meta.critLevel);
    await prefs.setStringList(_kOwnedItems, meta.ownedItemIds.toList());
    await prefs.setInt(_kLifetimeBossKills, meta.lifetimeBossKills);
    await prefs.setInt(_kLifetimeGemsCollected, meta.lifetimeGemsCollected);
    await prefs.setInt(_kLifetimeCoinsEarned, meta.lifetimeCoinsEarned);
    await prefs.setInt(_kLifetimeChestsOpened, meta.lifetimeChestsOpened);
    await prefs.setInt(
      _kLifetimePotionsCollected,
      meta.lifetimePotionsCollected,
    );
    await prefs.setInt(_kHighestLevelReached, meta.highestLevelReached);
    await prefs.setDouble(
      _kLongestSurvivalTimeSec,
      meta.longestSurvivalTimeSec,
    );
    await prefs.setStringList(
      _kClaimedAchievements,
      meta.claimedAchievementIds.toList(),
    );
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

  /// The single round-over write (DECISIONS D-091) — supersedes calling
  /// [addCoins]/[addGems]/[addLifetimeKills] separately for this call site
  /// (they stay available for any other future single-field bump): one
  /// load, every lifetime counter updated in memory, achievements evaluated
  /// and claimed against the *updated* totals (so a round that both earns
  /// its 500th lifetime coin and its 10,000th claims both in the same
  /// write), one save. Sequential in-memory updates, not concurrent
  /// separate load-modify-saves — DECISIONS D-089 found that shape racing
  /// itself and silently dropping updates; this method's whole point is to
  /// not repeat that mistake for the new counters. Returns the achievements
  /// newly claimed by this call, if a future UI wants to celebrate them.
  Future<List<Achievement>> recordRoundEnd({
    required int coins,
    required int gems,
    required int kills,
    required int bossKills,
    required int chestsOpened,
    required int potionsCollected,
    required int levelReached,
    required double survivalTimeSec,
  }) async {
    final current = await load();
    if (coins > 0) {
      current.coins += coins;
      current.lifetimeCoinsEarned += coins;
    }
    if (gems > 0) {
      current.gems += gems;
      current.lifetimeGemsCollected += gems;
    }
    if (kills > 0) current.lifetimeKills += kills;
    if (bossKills > 0) current.lifetimeBossKills += bossKills;
    if (chestsOpened > 0) current.lifetimeChestsOpened += chestsOpened;
    if (potionsCollected > 0) {
      current.lifetimePotionsCollected += potionsCollected;
    }
    if (levelReached > current.highestLevelReached) {
      current.highestLevelReached = levelReached;
    }
    if (survivalTimeSec > current.longestSurvivalTimeSec) {
      current.longestSurvivalTimeSec = survivalTimeSec;
    }

    final statValues = buildStatValues(
      lifetimeKills: current.lifetimeKills,
      lifetimeBossKills: current.lifetimeBossKills,
      lifetimeGemsCollected: current.lifetimeGemsCollected,
      lifetimeCoinsEarned: current.lifetimeCoinsEarned,
      lifetimeChestsOpened: current.lifetimeChestsOpened,
      lifetimePotionsCollected: current.lifetimePotionsCollected,
      highestLevelReached: current.highestLevelReached,
      longestSurvivalTimeSec: current.longestSurvivalTimeSec,
    );

    final newlyUnlocked = <Achievement>[];
    for (final achievement in kAchievements) {
      if (current.claimedAchievementIds.contains(achievement.id)) continue;
      if (!isAchievementMet(achievement, statValues)) continue;
      current.claimedAchievementIds.add(achievement.id);
      switch (achievement.reward) {
        case AchievementReward.coins:
          current.coins += achievement.rewardAmount;
        case AchievementReward.gems:
          current.gems += achievement.rewardAmount;
      }
      newlyUnlocked.add(achievement);
    }

    await save(current);
    return newlyUnlocked;
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

  /// Debug-only direct override of the character-unlock metric — sets
  /// `lifetimeKills` to at least [value] (never lowers it, so this can't be
  /// used to accidentally re-lock a character that real play already
  /// unlocked). Settings' caller passes the highest `unlockKillThreshold`
  /// across `kCharacters` to unlock everything in one tap.
  Future<void> debugSetLifetimeKills(int value) async {
    final current = await load();
    if (value > current.lifetimeKills) {
      current.lifetimeKills = value;
      await save(current);
    }
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
