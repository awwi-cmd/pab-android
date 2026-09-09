import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/game_rules.dart';
import '../../core/stats.dart';
import '../arena_game.dart';
import 'damageable.dart';
import 'projectile.dart';

enum BossAnim { idle, walk, fire, death }

/// The boss (`boss_map1.png`, DECISIONS D-042) — spawns at player levels
/// 3/6/9, ~20% stronger each time (`bossStatMultiplier`,
/// `core/game_rules.dart`). Ranged only: walks toward the player until in
/// firing range, fires a green-tinted bolt (`ProjectileComponent`'s [tint]
/// param — the same sprite/animation the Apprentice's bolt uses, just
/// recoloured) on a cooldown, and teleports to the opposite side of the
/// player — playing `effect_anima` at both the departure and arrival
/// points — the instant the player gets close enough to threaten melee.
///
/// `implements Damageable` (not `extends EnemyComponent`): the two share
/// no behavior worth inheriting — different animation states, different
/// movement rule (approach-then-hold-range instead of always-chase),
/// firing and teleporting that `EnemyComponent` has no hook for — but both
/// need to be hittable by the exact same attack code, which `Damageable`
/// (`damageable.dart`) gives them without either knowing the other exists.
class BossComponent extends SpriteAnimationGroupComponent<BossAnim>
    with HasGameReference<ArenaGame>
    implements Damageable {
  BossComponent({
    required Vector2 startPosition,
    required Map<BossAnim, SpriteAnimation> animations,
    required double statMultiplier,
  }) : hp = BossStats.maxHp * statMultiplier,
       _statMultiplier = statMultiplier,
       super(
         animations: animations,
         current: BossAnim.idle,
         position: startPosition,
         size: Vector2(kBossWidthPx, kBossWidthPx * kBossAspect),
         anchor: Anchor.center,
         paint: Paint()..filterQuality = FilterQuality.none, // D-011
         priority: ArenaPriority.enemy,
       );

  double hp;

  final double _statMultiplier;

  double _fireCooldownTimer = 0;
  double _contactCooldownTimer = 0;

  final Vector2 _scratch = Vector2.zero(); // reused every frame

  @override
  bool get isDying => current == BossAnim.death;

  @override
  void update(double dt) {
    super.update(dt);

    if (isDying) {
      if (animationTicker?.done() ?? true) {
        game.onBossKilled(this);
      }
      return;
    }

    final player = game.player;
    if (!player.isAlive) return;

    final toPlayer = player.position - position;
    final distance = toPlayer.length;

    // Teleport away the instant the player threatens melee (DECISIONS
    // D-042) -- checked before anything else this frame, so it pre-empts
    // both contact damage and the walk/fire state below.
    if (distance <= BossStats.teleportTriggerDistancePx) {
      _teleportAwayFrom(player.position);
      return;
    }

    if (_contactCooldownTimer > 0) _contactCooldownTimer -= dt;
    final touching = distance < (size.x / 2 + player.size.x / 2);
    if (touching && _contactCooldownTimer <= 0) {
      _contactCooldownTimer = BossStats.contactCooldownSec;
      player.takeDamage(BossStats.contactDamage * _statMultiplier);
    }

    if (distance > BossStats.fireRangePx) {
      // Too far to fire -- close the distance.
      current = BossAnim.walk;
      _scratch
        ..setFrom(toPlayer)
        ..normalize()
        ..scale(BossStats.moveSpeedPxPerS * dt);
      if (_scratch.x != 0) scale.x = _scratch.x < 0 ? -1 : 1;
      position.add(_scratch);
    } else {
      // In range -- hold position and shoot instead of closing all the way
      // in (a caster boss, not a brawler).
      if (toPlayer.x != 0) scale.x = toPlayer.x < 0 ? -1 : 1;
      _fireCooldownTimer -= dt;
      if (_fireCooldownTimer <= 0) {
        _fireCooldownTimer = BossStats.fireCooldownSec;
        _fire(toPlayer);
      } else {
        current = BossAnim.idle;
      }
    }
  }

  void _fire(Vector2 towardPlayer) {
    if (towardPlayer.length2 == 0) return; // exactly on top of the player
    current = BossAnim.fire;
    game.addToWorld(
      ProjectileComponent(
        startPosition: position.clone(),
        direction: towardPlayer.normalized(),
        damage: BossStats.boltDamage * _statMultiplier,
        knockback: BossStats.boltKnockback,
        speedPxPerS: BossStats.boltSpeedPxPerS,
        maxRangePx: BossStats.fireRangePx * 2,
        animation: game.boltAnimation,
        tint: kBossBoltTint,
        // DECISIONS D-051: checks the player, not game.damageableTargets --
        // the bug this fixes. excludeSelf (the D-046 self-hit guard) is
        // gone with it: it only ever mattered for the damageableTargets
        // loop this bolt no longer runs, so self-collision is impossible
        // by construction now, not guarded against.
        targetsPlayer: true,
      ),
    );
  }

  /// Teleports to the mirror image of the boss's current position across
  /// the player -- literally "the other side" of wherever the player is,
  /// not a random point (DECISIONS D-042). Plays `effect_anima` at both
  /// ends; both are one-shot (`ArenaGame.spawnEffect`'s `removeOnFinish`)
  /// so neither needs manual cleanup.
  void _teleportAwayFrom(Vector2 playerPosition) {
    game.spawnEffect(
      game.animaAnimation,
      position.clone(),
      size: Vector2(kAnimaWidthPx, kAnimaWidthPx * kAnimaAspect),
    );
    _scratch
      ..setFrom(playerPosition)
      ..sub(position); // vector from boss to player
    position
      ..setFrom(playerPosition)
      ..add(_scratch); // player position + (player - boss) = mirrored point
    game.spawnEffect(
      game.animaAnimation,
      position.clone(),
      size: Vector2(kAnimaWidthPx, kAnimaWidthPx * kAnimaAspect),
    );
    current = BossAnim.idle;
  }

  @override
  void applyKnockback(Vector2 direction, double impulsePxPerS) {
    if (isDying) return;
    _scratch.setFrom(direction);
    if (!_scratch.isZero()) _scratch.normalize();
    _scratch.scale(knockbackDistance(impulsePxPerS, 0.15));
    position.add(_scratch);
  }

  @override
  void takeDamage(double amount) {
    if (isDying) return;
    hp -= amount;
    // "Hits on this boss will play effect_impact" (DECISIONS D-042) --
    // every hit, any attack kit, not just the ones (Spiral Fire) that
    // already spawn their own hit flourish.
    if (hp <= 0) {
      current = BossAnim.death; // removed once this finishes, see update()
      game.spawnExplosionEffect(position.clone()); // also the kill SFX, D-044
    } else {
      game.spawnImpactEffect(position.clone());
    }
  }
}
