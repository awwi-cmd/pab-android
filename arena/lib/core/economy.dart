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

/// Chests (DECISIONS D-057, superseding D-055's flat gem-group reward) — a
/// single draw from a real 52-card deck (`assets/images/cards`, 4 suits x 13
/// ranks) plus 2 Jokers, 54 cards total. The reveal (`ChestReveal` overlay)
/// spins through faces rapidly before landing on this one, so the roll
/// itself has to be decided up front, not mid-animation — [rollChestCard]
/// is the single source of truth both for what the spin lands on and what
/// it pays out. Suit is cosmetic; [ChestCard.gemReward] is keyed on rank
/// alone via [kCardRankGemValue] (or [kJokerGemValue] for the 2 Jokers).
/// Drawing uniformly across the full deck gives the reward table its own
/// natural odds for free — a Joker is 2/54, an Ace 4/54, a "2" 4/54 — no
/// separate weight table needed the way [kRarityWeights] has one.
enum CardSuit { clubs, diamonds, hearts, spades }

const Map<CardSuit, String> kCardSuitFolder = {
  CardSuit.clubs: 'Clubs',
  CardSuit.diamonds: 'Diamonds',
  CardSuit.hearts: 'Hearts',
  CardSuit.spades: 'Spades',
};

/// Rank order matches each suit folder's actual filenames.
const List<String> kCardRanks = [
  '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King', 'Ace',
];

/// Placeholder like every other tuning value in this project — number cards
/// pay their face value, face cards step up, Ace is the best non-Joker card.
const Map<String, int> kCardRankGemValue = {
  '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9, '10': 10,
  'Jack': 15, 'Queen': 20, 'King': 25, 'Ace': 35,
};

/// The jackpot card -- rarest draw in the deck (2/54), biggest payout.
const int kJokerGemValue = 75;

class ChestCard {
  const ChestCard({
    required this.assetPath,
    required this.label,
    required this.gemReward,
  });

  /// Full `Image.asset` path (DECISIONS D-057) -- the chest reveal is a
  /// plain Flutter overlay (CLAUDE.md §4.2), not a Flame component, so this
  /// is the `assets/images/...`-rooted path `Image.asset` expects directly,
  /// not the shorter Flame-relative path `sheet_loader.dart` uses.
  final String assetPath;

  /// e.g. "Ace of Spades", "Joker" -- display only.
  final String label;
  final int gemReward;
}

/// Built once (54 entries, same every time), not reconstructed per roll.
final List<ChestCard> kChestDeck = [
  for (final suit in CardSuit.values)
    for (final rank in kCardRanks)
      ChestCard(
        assetPath: 'assets/images/cards/${kCardSuitFolder[suit]}/$rank.png',
        label: '$rank of ${kCardSuitFolder[suit]}',
        gemReward: kCardRankGemValue[rank]!,
      ),
  const ChestCard(
    assetPath: 'assets/images/cards/Joker/Joker Card Black.png',
    label: 'Joker',
    gemReward: kJokerGemValue,
  ),
  const ChestCard(
    assetPath: 'assets/images/cards/Joker/Joker Card Red.png',
    label: 'Joker',
    gemReward: kJokerGemValue,
  ),
];

ChestCard rollChestCard(Random random) => kChestDeck[random.nextInt(kChestDeck.length)];
