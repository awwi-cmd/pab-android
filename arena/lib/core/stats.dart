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

/// The "grunt" — the one enemy type in the demo (PRD §6.4). Flat constants,
/// not derived from a `StatBlock` (that's for playable characters only),
/// but still the single place these numbers live (CLAUDE.md §4.3).
class EnemyStats {
  EnemyStats._();

  static const double maxHp = 20;
  static const double moveSpeedPxPerS = 70;
  static const double contactDamage = 8;
  static const double contactCooldownSec = 1.0;
  static const double radiusPx = 12;
}

/// The boss (`boss_map1.png`, DECISIONS D-042) — spawns at levels 3/6/9,
/// scaled per spawn by `bossStatMultiplier` (`core/game_rules.dart`), not
/// by player level directly like grunts (`enemyStatMultiplier`). Flat
/// constants, same reasoning as [EnemyStats]. First-guess placeholder
/// numbers, not tuned on-device yet.
class BossStats {
  BossStats._();

  static const double maxHp = 400;
  static const double moveSpeedPxPerS = 55; // slower than a grunt -- lumbering, not a threat to outrun
  static const double contactDamage = 15;
  static const double contactCooldownSec = 1.0;

  static const double fireRangePx = 260;
  static const double fireCooldownSec = 2.2;
  static const double boltDamage = 12;
  static const double boltSpeedPxPerS = 220;
  static const double boltKnockback = 40;

  /// How close the player has to get before the boss teleports away
  /// (DECISIONS D-042).
  static const double teleportTriggerDistancePx = 90;
}
