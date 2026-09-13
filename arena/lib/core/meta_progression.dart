import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'achievements.dart';
import 'shop.dart';

/// Persistent, cross-round meta-progression (DECISIONS D-047) — the
/// character-select screen's "CHARACTER UPGRADES" tab (DECISIONS D-003:
/// renamed from "UPGRADES"), developer's spec verbatim: STR/VIT/DEX/INT/
/// CORRUPTION, 10 levels each, bought with coins earned finishing rounds.
/// This is a *different* wallet from `ArenaGame.coinsEarned` (that one is
/// round-scoped loot, reset every round per CLAUDE.md §4.5) —
/// [MetaProgressionRepository.addCoins] is the one place a round's earnings
/// cross over into this persistent one, called once from `ArenaGame._endRound`.
///
/// **DECISIONS D-003 (revised):** every single one of these 12 dials is
/// *per-character* — "all of character upgrades must be SPECIFIC to
/// character... chaos haste luck everything from character upgrades should
/// be specific to character," the developer's literal follow-up correction
/// to this decision's first pass (which only split STR/VIT/DEX/INT). There
/// is no more global/shared dial at all — [CharacterUpgradeLevels] holds all
/// 12, one instance per `CharacterDef.id`, and [MetaProgression] itself has
/// no bare `corruptionLevel`-style fields left to accidentally read instead.
///
/// Corruption is the odd one out among the 12 — it doesn't buy a playable
/// stat, it turns a difficulty/reward dial (`core/game_rules.dart`'s
/// `corruptionSpawnIntervalMultiplier`/`corruptionEnemyStatMultiplier`/
/// `corruptionRewardMultiplier` read the level straight off it).
///
/// `haste`/`fortune`/`resolve` (DECISIONS D-067) are 3 more of that same
/// "dial," not raw attribute adds like STR/VIT/DEX/INT — each reads
/// straight off `core/game_rules.dart`'s own per-level formula
/// (`hasteAttackSpeedMultiplier`/`fortuneRewardMultiplier`/
/// `resolveDamageResistance`+`resolveHpRegenPerSec`), same shape as
/// Corruption's own multipliers. The Character Upgrades screen's page 2
/// (`CharacterUpgradesScreen`) is exactly `[corruption, haste, fortune,
/// resolve]` — this enum's declaration order *is* that page's row order, so
/// a future 4th dial on that page is an enum member here, not a separate
/// list somewhere else.
/// `magnet`/`luck`/`regen`/`crit` (DECISIONS D-069) are the Character
/// Upgrades screen's 3rd page — same "pure dial, not a raw attribute add"
/// shape as haste/fortune/resolve, each reading straight off
/// `core/game_rules.dart`'s own per-level formula
/// (`magnetPickupRadiusMultiplier`/`luckGemDropBonus`/`regenHpPerSec`/
/// `critChance`). This enum's declaration order is that page's row order,
/// same as page 2's own doc comment above already established.
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
        // DECISIONS D-003: per-character, not "every run" unqualified --
        // this is this character's own bonus, bought and spent per-character.
        return '+1 $label per level, with this character.';
      case MetaStat.corruption:
        return 'Tougher, faster enemies. Bigger rewards. This character only.';
      case MetaStat.haste:
        return '+5% attack speed per level, with this character.';
      case MetaStat.fortune:
        return '+10% coin value per level, with this character.';
      case MetaStat.resolve:
        return 'Less damage taken, faster HP regen, with this character.';
      case MetaStat.magnet:
        return '+15% pickup radius per level, with this character.';
      case MetaStat.luck:
        return '+1% gem drop chance per level, with this character.';
      case MetaStat.regen:
        return '+HP regen per level, with this character.';
      case MetaStat.crit:
        return '+3% crit chance per level, with this character.';
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

/// One character's own Character Upgrades levels, all 12 `MetaStat` dials
/// (DECISIONS D-003) — `MetaProgression.characterUpgradeLevels` holds one of
/// these per `CharacterDef.id`; a character with none yet (never bought
/// anything, or never played) is represented by a fresh
/// `CharacterUpgradeLevels()`, every field 0, rather than an entry existing
/// in the map at all. STR/VIT/DEX/INT's field names mirror `core/stats.dart`'s
/// `StatBlock` (not `MetaStat`'s own names) since those 4 are added directly
/// onto a `StatBlock` at `ArenaGame.effectiveStats`; the other 8 mirror
/// `MetaStat`'s own member names since nothing combines them with a
/// `StatBlock` the same way.
class CharacterUpgradeLevels {
  CharacterUpgradeLevels({
    this.str = 0,
    this.vit = 0,
    this.dex = 0,
    this.intellect = 0,
    this.corruption = 0,
    this.haste = 0,
    this.fortune = 0,
    this.resolve = 0,
    this.magnet = 0,
    this.luck = 0,
    this.regen = 0,
    this.crit = 0,
  });

  int str;
  int vit;
  int dex;
  int intellect;
  int corruption;
  int haste;
  int fortune;
  int resolve;
  int magnet;
  int luck;
  int regen;
  int crit;

  int levelOf(MetaStat stat) {
    switch (stat) {
      case MetaStat.str:
        return str;
      case MetaStat.vit:
        return vit;
      case MetaStat.dex:
        return dex;
      case MetaStat.intellect:
        return intellect;
      case MetaStat.corruption:
        return corruption;
      case MetaStat.haste:
        return haste;
      case MetaStat.fortune:
        return fortune;
      case MetaStat.resolve:
        return resolve;
      case MetaStat.magnet:
        return magnet;
      case MetaStat.luck:
        return luck;
      case MetaStat.regen:
        return regen;
      case MetaStat.crit:
        return crit;
    }
  }

  void setLevel(MetaStat stat, int value) {
    switch (stat) {
      case MetaStat.str:
        str = value;
      case MetaStat.vit:
        vit = value;
      case MetaStat.dex:
        dex = value;
      case MetaStat.intellect:
        intellect = value;
      case MetaStat.corruption:
        corruption = value;
      case MetaStat.haste:
        haste = value;
      case MetaStat.fortune:
        fortune = value;
      case MetaStat.resolve:
        resolve = value;
      case MetaStat.magnet:
        magnet = value;
      case MetaStat.luck:
        luck = value;
      case MetaStat.regen:
        regen = value;
      case MetaStat.crit:
        crit = value;
    }
  }
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
    Map<String, CharacterUpgradeLevels>? characterUpgradeLevels,
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
       characterUpgradeLevels = characterUpgradeLevels ?? {},
       claimedAchievementIds = claimedAchievementIds ?? {};

  int coins;

  /// A second, separate persistent currency (DECISIONS D-055) — gems
  /// dropped by enemies and found in chests, credited at round-over exactly
  /// like [coins] (`ArenaGame._endRound`), from the same round-scoped
  /// `ArenaGame.gemsCollected` count Round Over already displays. Spent on
  /// SHOP items — DECISIONS D-003: unlike every Character Upgrades dial,
  /// SHOP stays global, one purchase applies to every character.
  int gems;

  /// Lifetime kills across every round ever played (DECISIONS D-055) — the
  /// character-unlock metric (`CharacterDef.unlockKillThreshold`). Credited
  /// at round-over from `ArenaGame.kills`, alongside coins/gems.
  int lifetimeKills;

  /// All 12 Character Upgrades levels, per `CharacterDef.id` (DECISIONS
  /// D-003) — see [CharacterUpgradeLevels]'s own doc comment. Use
  /// [levelsFor]/[levelOfFor]/[buyFor] rather than reading this map
  /// directly; those handle the "never bought anything for this character
  /// yet" case.
  final Map<String, CharacterUpgradeLevels> characterUpgradeLevels;

  /// SHOP's owned items (DECISIONS D-069) — `ShopItemId.name` strings rather
  /// than the enum itself, so `SharedPreferences.getStringList` can store it
  /// directly (same reasoning as every other primitive-only field here).
  /// Global, same as every character's own SHOP menu (DECISIONS D-003).
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

  /// [characterId]'s own Character Upgrades levels (DECISIONS D-003) —
  /// never null, a character with no purchases yet reads as a fresh
  /// `CharacterUpgradeLevels()` (every field 0). Read-only: unlike
  /// [characterUpgradeLevels] itself, callers shouldn't mutate the object
  /// this returns for a character with no map entry — it isn't stored
  /// anywhere, so a mutation would silently vanish. [buyFor] is the only
  /// way to actually raise a level (it creates the real stored entry first).
  CharacterUpgradeLevels levelsFor(String characterId) =>
      characterUpgradeLevels[characterId] ?? CharacterUpgradeLevels();

  int levelOfFor(String characterId, MetaStat stat) =>
      levelsFor(characterId).levelOf(stat);

  /// Buys the next level of [stat] for [characterId] if there's a level
  /// left and enough coins on hand. Returns whether the purchase went
  /// through — callers use this to decide whether to bother persisting/
  /// re-rendering. Creates [characterId]'s `CharacterUpgradeLevels` entry on
  /// first purchase (`putIfAbsent`) — an entry only exists in
  /// [characterUpgradeLevels] once something has actually been bought for
  /// that character.
  bool buyFor(String characterId, MetaStat stat) {
    final levels = characterUpgradeLevels.putIfAbsent(
      characterId,
      CharacterUpgradeLevels.new,
    );
    final current = levels.levelOf(stat);
    if (current >= kMetaMaxLevel) return false;
    final cost = metaUpgradeCost(current);
    if (coins < cost) return false;
    coins -= cost;
    levels.setLevel(stat, current + 1);
    return true;
  }

  // SHOP (DECISIONS D-069) -- permanent one-time purchases, priced in gems,
  // distinct from the leveled coin dials above. Global (DECISIONS D-003) --
  // unlike Character Upgrades, SHOP ownership isn't keyed by character.
  bool ownsItem(ShopItemId id) => ownedItemIds.contains(id.name);

  /// Buys [item] if not already owned and enough gems are on hand. Same
  /// afford/cap-check-then-deduct shape as [buyFor] above.
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
  // DECISIONS D-003: superseded by _kCharacterUpgradeLevels below -- kept as
  // a comment, not dangling unused consts, so a future reader doesn't
  // wonder whether any of these is still written somewhere.
  // (old keys: 'meta.str' / 'meta.vit' / 'meta.dex' / 'meta.int' /
  // 'meta.corruption' / 'meta.haste' / 'meta.fortune' / 'meta.resolve' /
  // 'meta.magnet' / 'meta.luck' / 'meta.regen' / 'meta.crit')
  static const _kCharacterUpgradeLevels = 'meta.characterUpgradeLevels';
  static const _kOwnedItems = 'meta.ownedItems';
  static const _kLifetimeBossKills = 'meta.lifetimeBossKills';
  static const _kLifetimeGemsCollected = 'meta.lifetimeGemsCollected';
  static const _kLifetimeCoinsEarned = 'meta.lifetimeCoinsEarned';
  static const _kLifetimeChestsOpened = 'meta.lifetimeChestsOpened';
  static const _kLifetimePotionsCollected = 'meta.lifetimePotionsCollected';
  static const _kHighestLevelReached = 'meta.highestLevelReached';
  static const _kLongestSurvivalTimeSec = 'meta.longestSurvivalTimeSec';
  static const _kClaimedAchievements = 'meta.claimedAchievements';

  /// Field name each [MetaStat] encodes/decodes as inside the per-character
  /// JSON object below — kept as one table both directions read, so adding a
  /// 13th dial later can't have its encode/decode keys silently drift apart.
  static const _statJsonKeys = {
    MetaStat.str: 'str',
    MetaStat.vit: 'vit',
    MetaStat.dex: 'dex',
    MetaStat.intellect: 'int',
    MetaStat.corruption: 'corruption',
    MetaStat.haste: 'haste',
    MetaStat.fortune: 'fortune',
    MetaStat.resolve: 'resolve',
    MetaStat.magnet: 'magnet',
    MetaStat.luck: 'luck',
    MetaStat.regen: 'regen',
    MetaStat.crit: 'crit',
  };

  /// Decodes [_kCharacterUpgradeLevels]'s JSON blob (DECISIONS D-003) into
  /// the real map — a per-character stat map doesn't fit
  /// `SharedPreferences`' flat primitive-only shape the rest of this class
  /// uses, so this is the one field here that's JSON rather than a bare
  /// `getInt`/`getStringList`, same "small, contained JSON blob" precedent
  /// `GameConfig` already set for a different reason. Never throws past its
  /// own `try`/`catch` -- missing/malformed data degrades to "nobody's
  /// bought anything for any character yet," same as every other field's
  /// `?? 0`-style fallback.
  Map<String, CharacterUpgradeLevels> _decodeCharacterUpgradeLevels(
    String? raw,
  ) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, CharacterUpgradeLevels>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final levels = CharacterUpgradeLevels();
        for (final stat in MetaStat.values) {
          final raw = value[_statJsonKeys[stat]];
          if (raw is num) levels.setLevel(stat, raw.toInt());
        }
        result[entry.key as String] = levels;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  String _encodeCharacterUpgradeLevels(
    Map<String, CharacterUpgradeLevels> levels,
  ) {
    return jsonEncode({
      for (final entry in levels.entries)
        entry.key: {
          for (final stat in MetaStat.values)
            _statJsonKeys[stat]!: entry.value.levelOf(stat),
        },
    });
  }

  Future<MetaProgression> load() async {
    final prefs = await SharedPreferences.getInstance();
    return MetaProgression(
      coins: prefs.getInt(_kCoins) ?? 0,
      gems: prefs.getInt(_kGems) ?? 0,
      lifetimeKills: prefs.getInt(_kLifetimeKills) ?? 0,
      characterUpgradeLevels: _decodeCharacterUpgradeLevels(
        prefs.getString(_kCharacterUpgradeLevels),
      ),
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
    await prefs.setString(
      _kCharacterUpgradeLevels,
      _encodeCharacterUpgradeLevels(meta.characterUpgradeLevels),
    );
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
  /// load, every lifetime counter updated in memory, one save. Sequential
  /// in-memory updates, not concurrent separate load-modify-saves —
  /// DECISIONS D-089 found that shape racing itself and silently dropping
  /// updates; this method's whole point is to not repeat that mistake for
  /// the new counters.
  ///
  /// DECISIONS D-008: no longer auto-claims/auto-grants anything —
  /// achievements are claimed by hand from the ACHIEVEMENTS screen
  /// ([claimAchievement]) now, not the instant a threshold is crossed.
  /// Still returns the achievements that just became eligible *this call*
  /// (met before the round, unmet the round before it, still unclaimed) —
  /// compares stat values from before this round's counters were applied
  /// against after, not just "currently met," so calling this again next
  /// round doesn't keep re-reporting the same still-unclaimed achievement
  /// as "newly" anything. A future UI (a toast, the main menu's pip badge)
  /// can use this to know something just became claimable.
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
    final beforeValues = buildStatValues(
      lifetimeKills: current.lifetimeKills,
      lifetimeBossKills: current.lifetimeBossKills,
      lifetimeGemsCollected: current.lifetimeGemsCollected,
      lifetimeCoinsEarned: current.lifetimeCoinsEarned,
      lifetimeChestsOpened: current.lifetimeChestsOpened,
      lifetimePotionsCollected: current.lifetimePotionsCollected,
      highestLevelReached: current.highestLevelReached,
      longestSurvivalTimeSec: current.longestSurvivalTimeSec,
    );

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

    final afterValues = buildStatValues(
      lifetimeKills: current.lifetimeKills,
      lifetimeBossKills: current.lifetimeBossKills,
      lifetimeGemsCollected: current.lifetimeGemsCollected,
      lifetimeCoinsEarned: current.lifetimeCoinsEarned,
      lifetimeChestsOpened: current.lifetimeChestsOpened,
      lifetimePotionsCollected: current.lifetimePotionsCollected,
      highestLevelReached: current.highestLevelReached,
      longestSurvivalTimeSec: current.longestSurvivalTimeSec,
    );

    final newlyEligible = <Achievement>[
      for (final achievement in kAchievements)
        if (!current.claimedAchievementIds.contains(achievement.id) &&
            !isAchievementMet(achievement, beforeValues) &&
            isAchievementMet(achievement, afterValues))
          achievement,
    ];

    await save(current);
    return newlyEligible;
  }

  /// Claims [achievementId]'s reward if it's currently eligible (its stat
  /// threshold met) and not already claimed (DECISIONS D-008 — the player
  /// claims each achievement by hand from the ACHIEVEMENTS screen now, this
  /// is its only entry point). Returns whether the claim actually went
  /// through, same "caller decides whether to bother re-rendering/reloading"
  /// shape [buy]/[buyFor]/[buyItem] already use. Re-checks eligibility
  /// itself against a fresh `load()` rather than trusting the caller's own
  /// copy — same "read-modify-write against whatever's currently saved"
  /// reasoning [addCoins] already documents.
  Future<bool> claimAchievement(String achievementId) async {
    final current = await load();
    if (current.claimedAchievementIds.contains(achievementId)) return false;

    Achievement? achievement;
    for (final candidate in kAchievements) {
      if (candidate.id == achievementId) {
        achievement = candidate;
        break;
      }
    }
    if (achievement == null) return false;

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
    if (!isAchievementMet(achievement, statValues)) return false;

    current.claimedAchievementIds.add(achievementId);
    switch (achievement.reward) {
      case AchievementReward.coins:
        current.coins += achievement.rewardAmount;
      case AchievementReward.gems:
        current.gems += achievement.rewardAmount;
    }
    await save(current);
    return true;
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
  /// character-unlock metric) and every Character Upgrades level already
  /// bought are progress, not spendable currency, so a "reset wallet" debug
  /// tool leaves both alone.
  Future<void> debugResetWallet() async {
    final current = await load();
    current.coins = 0;
    current.gems = 0;
    await save(current);
  }
}
