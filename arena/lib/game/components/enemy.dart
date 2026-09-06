import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/stats.dart';
import '../arena_game.dart';

enum EnemyAnim { run, death }

/// The "grunt" (PRD §6.4) — three visual skins for variety, one stats
/// profile (developer's call: visual variety only, not new enemy types;
/// PRD §9 keeps "more than one enemy type" out of scope for the demo).
/// Stats come from [EnemyStats], never typed inline here (CLAUDE.md §4.3).
class EnemyComponent extends SpriteAnimationGroupComponent<EnemyAnim>
    with HasGameReference<ArenaGame> {
  EnemyComponent({
    required Vector2 startPosition,
    required SpriteAnimation runAnimation,
    required SpriteAnimation deathAnimation,
  }) : hp = EnemyStats.maxHp,
       super(
         animations: {
           EnemyAnim.run: runAnimation,
           EnemyAnim.death: deathAnimation,
         },
         current: EnemyAnim.run,
         position: startPosition,
         size: Vector2(16, 24) * kCharacterRenderScale,
         anchor: Anchor.center,
         paint: Paint()..filterQuality = FilterQuality.none, // D-011
         priority: ArenaPriority.enemy,
       );

  double hp;

  /// This enemy's own cooldown before it can deal contact damage again
  /// (PRD §6.4/§4.8) — independent of the player's separate 0.6s i-frames.
  double _contactCooldown = 0;

  static const _knockbackDurationSec = 0.15;

  final Vector2 _scratch = Vector2.zero(); // reused every frame, no allocation

  bool get isDying => current == EnemyAnim.death;

  @override
  void update(double dt) {
    super.update(dt);

    if (isDying) {
      if (animationTicker?.done() ?? true) {
        game.onEnemyKilled(this);
      }
      return;
    }

    if (_contactCooldown > 0) {
      _contactCooldown -= dt;
    }

    final player = game.player;
    if (!player.isAlive) return;

    _scratch
      ..setFrom(player.position)
      ..sub(position);
    if (!_scratch.isZero()) {
      if (_scratch.x != 0) {
        scale.x = _scratch.x < 0 ? -1 : 1;
      }
      _scratch.normalize();
    }
    _scratch.scale(EnemyStats.moveSpeedPxPerS * dt);
    position.add(_scratch);

    final touching =
        position.distanceTo(player.position) < (size.x / 2 + player.size.x / 2);
    if (touching && _contactCooldown <= 0) {
      _contactCooldown = EnemyStats.contactCooldownSec;
      game.onEnemyContact();
    }
  }

  /// Instant shove away from the hit, converting the PRD's px/s knockback
  /// formula into a one-off distance rather than a decaying velocity —
  /// simpler, and plenty for the demo's feel.
  void applyKnockback(Vector2 direction, double impulsePxPerS) {
    if (isDying) return;
    _scratch.setFrom(direction);
    if (!_scratch.isZero()) {
      _scratch.normalize();
    }
    _scratch.scale(impulsePxPerS * _knockbackDurationSec);
    position.add(_scratch);
  }

  void takeDamage(double amount) {
    if (isDying) return;
    hp -= amount;
    if (hp <= 0) {
      current = EnemyAnim.death; // removed from the game once this finishes
    }
  }
}
