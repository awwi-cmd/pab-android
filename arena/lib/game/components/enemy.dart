import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/stats.dart';
import '../arena_game.dart';

/// The "grunt" (PRD §6.4) — placeholder square, walks straight at the
/// player, no pathfinding or separation (enemies will stack; accepted for
/// the demo). Stats come from [EnemyStats], never typed inline here
/// (CLAUDE.md §4.3).
class EnemyComponent extends RectangleComponent
    with HasGameReference<ArenaGame> {
  EnemyComponent({required Vector2 startPosition})
    : hp = EnemyStats.maxHp,
      super(
        position: startPosition,
        size: Vector2.all(EnemyStats.radiusPx * 2),
        anchor: Anchor.center,
        paint: Paint()..color = ArenaColors.danger,
        priority: ArenaPriority.enemy,
      );

  double hp;

  /// This enemy's own cooldown before it can deal contact damage again
  /// (PRD §6.4/§4.8) — independent of the player's separate 0.6s i-frames.
  double _contactCooldown = 0;

  static const _knockbackDurationSec = 0.15;

  final Vector2 _scratch = Vector2.zero(); // reused every frame, no allocation

  @override
  void update(double dt) {
    super.update(dt);

    if (_contactCooldown > 0) {
      _contactCooldown -= dt;
    }

    final player = game.player;
    if (!player.isAlive) return;

    _scratch
      ..setFrom(player.position)
      ..sub(position);
    if (!_scratch.isZero()) {
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
    _scratch.setFrom(direction);
    if (!_scratch.isZero()) {
      _scratch.normalize();
    }
    _scratch.scale(impulsePxPerS * _knockbackDurationSec);
    position.add(_scratch);
  }

  void takeDamage(double amount) {
    hp -= amount;
    if (hp <= 0) {
      game.onEnemyKilled(this);
    }
  }
}
