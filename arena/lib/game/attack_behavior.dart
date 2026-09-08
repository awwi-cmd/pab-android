import '../core/game_rules.dart';
import '../core/stats.dart';
import 'arena_game.dart';
import 'components/knife_projectile.dart';
import 'components/projectile.dart';

/// How a `CharacterDef` attacks (DECISIONS D-024). `ArenaGame` owns the
/// cooldown timer (round state stays on `ArenaGame`, CLAUDE.md §4.5) and
/// calls [perform] once it elapses; behaviors are stateless so they can be
/// `const` and shared across `CharacterDef`s without leaking state between
/// rounds.
///
/// The demo only ships [ProjectileAttack]. This exists as an extension
/// point so a melee or otherwise different character (D-005 already flags
/// that the ranged stat formulas won't fit one) is a new class here, not a
/// rewrite of `ArenaGame`.
abstract class AttackBehavior {
  const AttackBehavior();

  /// Seconds between attacks, given this character's current stats.
  double cooldownSeconds(StatBlock stats);

  /// Called once the cooldown elapses. Whatever this does — spawn a
  /// projectile, start a melee swing — it's responsible for its own
  /// "nothing to attack" no-op case.
  void perform(ArenaGame game);
}

/// The only attack in the demo: fires one projectile at the nearest enemy
/// in range, straight line, no leading/homing, one target per shot
/// (PRD §6.2-§6.3, DECISIONS D-005).
class ProjectileAttack extends AttackBehavior {
  const ProjectileAttack();

  @override
  double cooldownSeconds(StatBlock stats) => 1 / stats.attacksPerSec;

  @override
  void perform(ArenaGame game) {
    final stats = game.character.stats;
    final player = game.player;

    final positions = [for (final enemy in game.enemies) enemy.position];
    final index = nearestWithinRange(
      player.position,
      positions,
      stats.attackRangePx,
    );
    if (index == -1) return;
    final target = game.enemies[index];

    final direction = target.position - player.position;
    if (direction.length2 == 0) return; // exactly on top of the target
    direction.normalize();

    game.add(
      ProjectileComponent(
        startPosition: player.position.clone(),
        direction: direction,
        damage: stats.damagePerHit + game.upgrades.bonusDamage,
        knockback: stats.knockbackImpulse,
        speedPxPerS: stats.projSpeedPxPerS,
        maxRangePx: stats.attackRangePx * 1.5,
        animation: game.boltAnimation,
      ),
    );
    player.playFire();
  }
}

/// The Bruiser's kit (DECISIONS D-029): a spinning knife thrown at the
/// nearest enemy in range, same targeting as [ProjectileAttack] but it
/// pierces through every enemy in its path instead of stopping at the
/// first one, and its sprite turns bloody the moment it draws blood. Reuses
/// [ProjectileAttack]'s exact cooldown/damage/range formulas for now —
/// pierce is the whole differentiator until a real balance pass retunes it.
class KnifeAttack extends AttackBehavior {
  const KnifeAttack();

  @override
  double cooldownSeconds(StatBlock stats) => 1 / stats.attacksPerSec;

  @override
  void perform(ArenaGame game) {
    final stats = game.character.stats;
    final player = game.player;

    final positions = [for (final enemy in game.enemies) enemy.position];
    final index = nearestWithinRange(
      player.position,
      positions,
      stats.attackRangePx,
    );
    if (index == -1) return;
    final target = game.enemies[index];

    final direction = target.position - player.position;
    if (direction.length2 == 0) return; // exactly on top of the target
    direction.normalize();

    game.add(
      KnifeProjectileComponent(
        startPosition: player.position.clone(),
        direction: direction,
        damage: stats.damagePerHit + game.upgrades.bonusDamage,
        knockback: stats.knockbackImpulse,
        speedPxPerS: stats.projSpeedPxPerS,
        maxRangePx: stats.attackRangePx * 1.5,
        cleanSprite: game.knifeCleanSprite,
        bloodySprite: game.knifeBloodySprite,
      ),
    );
    player.playFire();
  }
}
