import 'dart:math';

/// Loot/currency economy (DECISIONS D-043): gems, money, and potions all
/// share one 5-tier rarity scale — left-to-right in their sprite sheets,
/// least to most rare — one weight table, one roll function, reused by all
/// three per the developer's explicit "same value logic" ask. Pure, no
/// Flame dependency, unit-tested the same way `stats.dart`/`game_rules.dart`
/// are (CLAUDE.md §4.3/§4.11).
enum ItemRarity { common, uncommon, rare, epic, legendary }

/// Placeholder weights, heavily front-loaded so common drops feel common —
/// not tuned on-device yet, same as every other first-pass number in this
/// project.
const Map<ItemRarity, double> kRarityWeights = {
  ItemRarity.common: 50,
  ItemRarity.uncommon: 25,
  ItemRarity.rare: 15,
  ItemRarity.epic: 7,
  ItemRarity.legendary: 3,
};

/// Weighted single pick across [kRarityWeights].
ItemRarity rollRarity(Random random) {
  final total = kRarityWeights.values.reduce((a, b) => a + b);
  var roll = random.nextDouble() * total;
  for (final tier in ItemRarity.values) {
    roll -= kRarityWeights[tier]!;
    if (roll <= 0) return tier;
  }
  return ItemRarity.values.last; // float rounding backstop
}

/// Gems (DECISIONS D-043): "80% and growing depending on your level" at
/// first ship read as way too dense on-device ("spawn near one another") —
/// 2026-09-09 tune cut both numbers 80% (D-046).
const double kGemBaseDropChance = 0.16;
const double kGemDropChancePerLevel = 0.002;

double gemDropChance(int playerLevel) {
  return (kGemBaseDropChance + (playerLevel - 1) * kGemDropChancePerLevel)
      .clamp(0.0, 1.0);
}

bool rollGemDrop(Random random, int playerLevel) {
  return random.nextDouble() < gemDropChance(playerLevel);
}

/// Coin value granted per kill (DECISIONS D-043) — "coin gathering... based
/// on the kills you make": every kill rolls one rarity tier via
/// [rollRarity], each tier worth a flat number of coins.
const Map<ItemRarity, int> kCoinValueByRarity = {
  ItemRarity.common: 1,
  ItemRarity.uncommon: 3,
  ItemRarity.rare: 8,
  ItemRarity.epic: 20,
  ItemRarity.legendary: 50,
};

int rollCoinValue(Random random) => kCoinValueByRarity[rollRarity(random)]!;

/// The boss's kill is worth a flat multiple of a normal roll — same
/// "feels like a milestone" reasoning as `kBossXpReward`
/// (`core/progression.dart`).
const int kBossCoinMultiplier = 10;

/// Potion heal amount per tier (DECISIONS D-043) — flat HP, not a
/// percentage of max HP; "we will add more logic later" per the developer,
/// so this is deliberately the simplest version that works.
const Map<ItemRarity, double> kPotionHealByRarity = {
  ItemRarity.common: 15,
  ItemRarity.uncommon: 30,
  ItemRarity.rare: 50,
  ItemRarity.epic: 80,
  ItemRarity.legendary: 120,
};

double potionHealAmount(ItemRarity rarity) => kPotionHealByRarity[rarity]!;

/// Chests (DECISIONS D-055) — a bigger, rarer payout than a single dropped
/// gem: a handful of gems at once, each still rolled independently through
/// [rollRarity] (same weighted scale gems/coins/potions already share, per
/// the developer's original "same value logic" ask, D-043 — not a new
/// probability scheme just for chests).
const int kChestMinGems = 3;
const int kChestMaxGems = 6;

List<ItemRarity> rollChestGems(Random random) {
  final count = kChestMinGems + random.nextInt(kChestMaxGems - kChestMinGems + 1);
  return [for (var i = 0; i < count; i++) rollRarity(random)];
}
