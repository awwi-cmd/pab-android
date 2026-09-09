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

  /// The current 3-shot burst (DECISIONS D-052) — `_burstShotsRemaining >
  /// 0` while one is in progress; `_fireCooldownTimer` above only starts
  /// counting down again once the whole burst is spent, not between
  /// individual shots inside it.
  int _burstShotsRemaining = 0;
  double _burstTimer = 0;

  /// The boss's own live bolts (DECISIONS D-053, "maximum of 9 projectiles
  /// at once") — pruned of anything no longer mounted (hit something,
  /// expired, poofed away) each time it's checked, rather than needing
  /// `ProjectileComponent` to call back out when it's removed.
  final List<ProjectileComponent> _liveBolts = [];

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

    if (_burstShotsRemaining > 0) {
      // Mid-burst (DECISIONS D-052) -- pre-empts the walk/hold decision
      // below entirely, same as the teleport check above pre-empts
      // everything. Each shot re-aims fresh at wherever the player
      // currently is, not the `toPlayer` snapshot from the top of this
      // frame -- the player may have moved since the burst started.
      current = BossAnim.fire;
      _burstTimer -= dt;
      if (_burstTimer <= 0) {
        _burstTimer = BossStats.boltBurstIntervalSec;
        _burstShotsRemaining--;
        // Skip this shot outright if already at the live-bolt cap, rather
        // than queuing/delaying it -- the burst still finishes on schedule
        // either way, it just may fire fewer than 3 bolts on a screen
        // that's already crowded with this boss's own shots.
        if (_liveBoltCountBelowCap()) {
          _fire(player.position - position);
        }
      }
    } else if (distance > BossStats.fireRangePx) {
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
        // Starts the burst -- the first shot goes out next frame (burst
        // timer starts at 0), not this one, keeping this branch itself
        // simple (just "should a burst start").
        _burstShotsRemaining = BossStats.boltBurstCount;
        _burstTimer = 0;
      } else {
        current = BossAnim.idle;
      }
    }
  }

  /// `true` if the boss can fire another bolt without going over
  /// [BossStats.boltMaxLiveCount] (DECISIONS D-053) — prunes [_liveBolts]
  /// of anything no longer mounted first, since that's the only signal
  /// available that an earlier bolt is gone (hit something, ran out of
  /// range/bounces, poofed away).
  bool _liveBoltCountBelowCap() {
    _liveBolts.removeWhere((bolt) => !bolt.isMounted);
    return _liveBolts.length < BossStats.boltMaxLiveCount;
  }

  void _fire(Vector2 towardPlayer) {
    if (towardPlayer.length2 == 0) return; // exactly on top of the player
    current = BossAnim.fire;
    final bolt = ProjectileComponent(
      startPosition: position.clone(),
      direction: towardPlayer.normalized(),
      damage: BossStats.boltDamage * _statMultiplier,
      knockback: BossStats.boltKnockback,
      speedPxPerS: BossStats.boltSpeedPxPerS,
      // DECISIONS D-053: the original fireRangePx*2 budget plus "5 seconds
      // longer" worth of extra travel at the bolt's own speed.
      maxRangePx: BossStats.boltMaxRangePx,
      animation: game.boltAnimation,
      tint: kBossBoltTint,
      // DECISIONS D-051: checks the player, not game.damageableTargets --
      // the bug this fixes. excludeSelf (the D-046 self-hit guard) is
      // gone with it: it only ever mattered for the damageableTargets
      // loop this bolt no longer runs, so self-collision is impossible
      // by construction now, not guarded against.
      targetsPlayer: true,
      // DECISIONS D-052: bounces off the edge of the visible view instead
      // of despawning immediately, up to boltBounceCount times.
      maxBounces: BossStats.boltBounceCount,
    );
    game.addToWorld(bolt);
    _liveBolts.add(bolt);
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
      size: Vector2(kBossAnimaWidthPx, kBossAnimaWidthPx * kAnimaAspect),
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
      size: Vector2(kBossAnimaWidthPx, kBossAnimaWidthPx * kAnimaAspect),
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
