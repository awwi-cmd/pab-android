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
  // 2026-09-09 tune (DECISIONS D-052, developer's call): +30% (was 220).
  static const double boltSpeedPxPerS = 220 * 1.3;
  static const double boltKnockback = 40;

  /// 3-shot burst per fire cycle, each re-aimed at the player's position at
  /// the instant it actually fires — not the direction computed once when
  /// the burst started — spaced by [boltBurstIntervalSec] (DECISIONS
  /// D-052, developer's call: "shoot 3 in quick succession at player
  /// current location"). [fireCooldownSec] above is the gap between one
  /// whole burst ending and the next one starting, not between individual
  /// shots.
  static const int boltBurstCount = 3;
  static const double boltBurstIntervalSec = 0.12;

  /// How many times the bolt bounces off the edge of what's currently
  /// visible before it actually despawns (DECISIONS D-052) — see
  /// `ProjectileComponent.maxBounces`'s doc comment for why "the edge of
  /// the visible view" is what "the wall" means in a world with no fixed
  /// bounds (D-040).
  static const int boltBounceCount = 3;

  /// How many extra seconds of travel (DECISIONS D-053, developer's call:
  /// "last 5 seconds longer") get folded into [boltMaxRangePx] below — this
  /// project has no separate time-based projectile lifespan anywhere
  /// (every projectile despawns on distance travelled, not a clock), so
  /// "5 seconds longer" is converted to the equivalent extra distance at
  /// the bolt's own (post-D-052, +30%) speed rather than adding a second,
  /// parallel despawn mechanism just for this one bolt.
  static const double boltExtraLifetimeSec = 5.0;

  /// The bolt's actual despawn distance (`ProjectileComponent.maxRangePx`)
  /// — the original `fireRangePx * 2` budget plus [boltExtraLifetimeSec]
  /// converted to px via [boltSpeedPxPerS]. A getter, not a plain `const`,
  /// since it's derived from two other constants above rather than an
  /// independent number (CLAUDE.md §4.3 — no formula duplicated at the
  /// call site).
  static double get boltMaxRangePx =>
      fireRangePx * 2 + boltSpeedPxPerS * boltExtraLifetimeSec;

  /// How many of the boss's own bolts can be alive at once (DECISIONS
  /// D-053, developer's call: "maximum of 9 projectiles at once") —
  /// `BossComponent` tracks its own live bolts and skips a burst shot
  /// rather than firing over the cap.
  static const int boltMaxLiveCount = 9;

  /// How close the player has to get before the boss teleports away
  /// (DECISIONS D-042).
  static const double teleportTriggerDistancePx = 90;

  /// Multiplies the mirror-point offset the destination is computed from
  /// (DECISIONS D-060, developer's call: "make boss teleport a longer
  /// distance") — `1.0` would land exactly on the opposite-of-player mirror
  /// point (the original D-042 behavior); this lands further past it, in
  /// the same direction. First-guess placeholder like every other tuning
  /// number here.
  static const double teleportDistanceMultiplier = 1.6;

  /// Time between the destination telegraph (`effect_anima`) appearing and
  /// the boss actually arriving there (DECISIONS D-060, developer's call:
  /// "appear only where he will teleport 0.5 seconds before... teleport
  /// with a delay"). The boss is frozen — no walk/fire/contact damage —
  /// for the whole window, a committed wind-up rather than something the
  /// player can bait and dodge out of.
  static const double teleportDelaySec = 0.5;

  /// Minimum time between the *start* of one teleport wind-up and the next
  /// (DECISIONS D-074, developer's call: "add a cooldown for the boss
  /// teleportation, 3 seconds") — without it, a player camped right at
  /// [teleportTriggerDistancePx] could retrigger the wind-up the instant a
  /// prior one finished, reading as a boss that never actually holds still.
  static const double teleportCooldownSec = 3.0;
}
