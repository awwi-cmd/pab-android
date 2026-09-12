/// SHOP's real content (DECISIONS D-069/D-070) — supersedes D-047's
/// deliberate empty placeholder ("nothing yet, empty, just a back button").
/// Gem-priced, **permanent one-time** purchases: unlike the leveled
/// `MetaStat` dials (`core/meta_progression.dart`, bought with coins, 10
/// levels each), every `ShopItem` here is bought once and applies forever
/// after — there's nothing to level up, just owned or not.
/// `MetaProgression.ownedItemIds` is the flat set of which of these have
/// been bought; the bonus getters there (`bonusMaxHpFromShop` etc.) are
/// what combat code actually reads.
///
/// Kept as its own file rather than folded into `meta_progression.dart` for
/// the same reason `economy.dart` is separate from it — data/formulas here,
/// wallet/persistence there (CLAUDE.md §4.3).
///
/// `kShopPages` (DECISIONS D-070, "no scrolling, add 2 more pages") is the
/// SHOP screen's own row-order/page-grouping source of truth — same
/// "declaration order is display order" pattern `UpgradesScreen._statPages`
/// already uses. `kShopItems` is the flattened view every existing
/// buy-lookup/test already reads, so nothing downstream had to change shape.
enum ShopItemId {
  vitalityCharm,
  swiftBoots,
  sharpEdge,
  ironWill,
  secondWind,
  quickHands,
  battleFury,
  potionMaster,
  steelNerves,
  vampiricTouch,
  treasureHunter,
  scholarsInsight,
  goldenTouch,
  gemHoarder,
  bossHunter,
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.label,
    required this.description,
    required this.costGems,
  });

  final ShopItemId id;
  final String label;
  final String description;
  final int costGems;
}

// Bonus magnitudes -- first-guess placeholders, not tuned on-device, same
// disclaimer as every other number introduced in this project's economy
// (see `economy.dart`/`meta_progression.dart`). Every description string
// below is a literal, not interpolated from these -- a `const` list can't
// call `.toStringAsFixed()`/string formatting in a const-eval context, so
// keep the two in sync by hand if either is ever retuned.

// Page 1 -- flat permanent stat bonuses.
const double kVitalityCharmBonusMaxHp = 30;
const double kSwiftBootsBonusMoveSpeed = 20; // same unit as StatBlock.moveSpeedPxPerS
const double kSharpEdgeDamageMultiplier = 1.15;
const double kIronWillDamageResistance = 0.08;
const double kReviveHpFraction = 0.5; // fraction of max HP a Second Wind revive sets

// Page 2 -- combat & survival (DECISIONS D-070).
const double kQuickHandsAttackSpeedMultiplier = 1.10;
const double kBattleFuryDamageMultiplier = 1.2;
const double kBattleFuryHpThreshold = 0.5; // active below this fraction of max HP
const double kPotionMasterHealMultiplier = 1.5;
const double kSteelNervesEliteChanceMultiplier = 0.5; // halves the elite roll
const double kVampiricTouchHealPerKill = 2;

// Page 3 -- economy & utility (DECISIONS D-070).
const double kTreasureHunterGemRewardMultiplier = 1.3;
const double kScholarsInsightXpMultiplier = 1.2;
const double kGoldenTouchCoinMultiplier = 1.2;
const double kGemHoarderDropBonus = 0.05; // additive, same axis as LUCK's dial
const int kBossHunterGemReward = 50; // flat, on top of a boss's normal (zero) drop

/// Declaration order is display order within a page; the outer list's
/// order is page order. Kept as pages here rather than one flat list
/// (DECISIONS D-070, "no scrolling") — the SHOP screen pages through these
/// exactly like `UpgradesScreen._statPages`, so it never needs its own
/// scroll view regardless of screen height.
const List<List<ShopItem>> kShopPages = [
  [
    ShopItem(
      id: ShopItemId.vitalityCharm,
      label: 'Vitality Charm',
      description: '+30 max HP, every run.',
      costGems: 200,
    ),
    ShopItem(
      id: ShopItemId.swiftBoots,
      label: 'Swift Boots',
      description: '+20 move speed, every run.',
      costGems: 200,
    ),
    ShopItem(
      id: ShopItemId.sharpEdge,
      label: 'Sharp Edge',
      description: '+15% auto-attack damage, every run.',
      costGems: 250,
    ),
    ShopItem(
      id: ShopItemId.ironWill,
      label: 'Iron Will',
      description: '+8% damage resistance, every run.',
      costGems: 250,
    ),
    ShopItem(
      id: ShopItemId.secondWind,
      label: 'Second Wind',
      description: 'Survive one lethal hit per round, at 50% HP.',
      costGems: 500,
    ),
  ],
  [
    ShopItem(
      id: ShopItemId.quickHands,
      label: 'Quick Hands',
      description: '+10% attack speed, every run.',
      costGems: 220,
    ),
    ShopItem(
      id: ShopItemId.battleFury,
      label: 'Battle Fury',
      description: '+20% auto-attack damage while below 50% HP.',
      costGems: 280,
    ),
    ShopItem(
      id: ShopItemId.potionMaster,
      label: 'Potion Master',
      description: 'Potions heal 50% more.',
      costGems: 180,
    ),
    ShopItem(
      id: ShopItemId.steelNerves,
      label: 'Steel Nerves',
      description: 'Half as many Elite enemies spawn.',
      costGems: 200,
    ),
    ShopItem(
      id: ShopItemId.vampiricTouch,
      label: 'Vampiric Touch',
      description: 'Heal a little on every kill.',
      costGems: 260,
    ),
  ],
  [
    ShopItem(
      id: ShopItemId.treasureHunter,
      label: 'Treasure Hunter',
      description: '+30% gems from every chest.',
      costGems: 260,
    ),
    ShopItem(
      id: ShopItemId.scholarsInsight,
      label: "Scholar's Insight",
      description: '+20% XP from every kill.',
      costGems: 220,
    ),
    ShopItem(
      id: ShopItemId.goldenTouch,
      label: 'Golden Touch',
      description: '+20% coin value, every run.',
      costGems: 240,
    ),
    ShopItem(
      id: ShopItemId.gemHoarder,
      label: 'Gem Hoarder',
      description: '+5% flat gem drop chance, every run.',
      costGems: 220,
    ),
    ShopItem(
      id: ShopItemId.bossHunter,
      label: 'Boss Hunter',
      description: 'Bosses now drop a bonus gem haul.',
      costGems: 350,
    ),
  ],
];

/// The flattened view every buy-lookup/test reads — page grouping above is
/// purely a SHOP-screen display concern.
final List<ShopItem> kShopItems = [for (final page in kShopPages) ...page];
