/// The four playable stats and every derived-combat formula (PRD §5.1).
///
/// This is the ONLY place a damage value, speed, HP number or fire rate may
/// be computed (CLAUDE.md §4.3 / DECISIONS D-008). Nothing else in the
/// codebase may hardcode a combat number — read it off a [StatBlock].
class StatBlock {
  const StatBlock({
    required this.str,
    required this.vit,
    required this.dex,
    required this.intellect,
  });

  /// Strength — projectile damage, knockback.
  final int str;

  /// Vitality — max HP, passive regen.
  final int vit;

  /// Dexterity — move speed, fire rate.
  final int dex;

  /// Intellect — projectile speed, attack range.
  final int intellect;

  double get maxHp => 50 + vit * 10;
  double get hpRegenPerSec => 0.0 + vit * 0.05;
  double get damagePerHit => 5 + str * 2;
  double get knockbackImpulse => 40 + str * 6; // px/s applied to the enemy
  double get attacksPerSec => 1.0 + dex * 0.08;
  double get moveSpeedPxPerS => 120 + dex * 4;
  double get projSpeedPxPerS => 260 + intellect * 8;
  double get attackRangePx => 180 + intellect * 6;
}
