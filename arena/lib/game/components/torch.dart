import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/game_config.dart';
import '../arena_game.dart';

/// A standing torch (DECISIONS D-002, real heal functionality added by
/// D-009) — a solid world obstacle scattered randomly by [TorchSpawner],
/// and a limited-use heal *only* for the player ("give them functionality
/// so that standing in an area near them gives ONLY the player (not
/// enemies) hp regen"): standing within [GameConfig.torchHealRadiusPx]
/// heals the player [GameConfig.torchHealPerSec] every second, and once
/// [_healElapsedSec] (cumulative time in range, not HP actually healed —
/// it still runs out even at full HP) reaches
/// [GameConfig.torchConsumeDurationSec], the torch is consumed: it
/// disappears with an explosion VFX + the explosion SFX ("player stays
/// near, consumes and then torch disappears with an explosion vfx &
/// sounds"). The solid-obstacle collision against the player/enemies is
/// still resolved every frame in their own `update()` via
/// `core/game_rules.dart`'s `resolveCircleObstacle`, reading
/// [collisionRadius]/[position] off this component — unrelated to (and
/// unaffected by) the heal radius, which is wider on purpose so healing is
/// already active the instant the player rests against the torch's own
/// collision boundary, not a separate closer approach.
class TorchComponent extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  TorchComponent({required Vector2 startPosition, required SpriteAnimation animation})
    : super(
        animation: animation,
        position: startPosition,
        size: Vector2.all(16 * kTorchRenderScale),
        anchor: Anchor.center,
        paint: Paint()..filterQuality = FilterQuality.none, // D-011
        priority: ArenaPriority.obstacle,
      );

  double get collisionRadius => kTorchCollisionRadiusPx;

  /// Cumulative seconds the player has spent within heal range — once this
  /// reaches `GameConfig.torchConsumeDurationSec` the torch consumes
  /// itself. Never decreases (walking away and back just resumes the same
  /// countdown, doesn't reset it) — a torch is a limited total use, not a
  /// once-per-visit reward.
  double _healElapsedSec = 0;
  bool _consumed = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_consumed) return; // already mid-removal this frame, do nothing more

    final player = game.player;
    if (!player.isAlive) return;
    if (position.distanceTo(player.position) > GameConfig.instance.torchHealRadiusPx) {
      return;
    }

    player.heal(GameConfig.instance.torchHealPerSec * dt);
    _healElapsedSec += dt;
    if (_healElapsedSec >= GameConfig.instance.torchConsumeDurationSec) {
      _consumed = true;
      game.consumeTorch(this);
    }
  }
}
