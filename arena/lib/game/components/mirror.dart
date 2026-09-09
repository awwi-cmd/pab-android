import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/game_rules.dart';
import '../../core/progression.dart';
import '../arena_game.dart';
import 'projectile.dart';

/// The Ultimate Mirror skill (DECISIONS D-049/D-050) — a turret that cycles
/// between two phases for as long as the round runs: **active** (visible,
/// on screen, firing a bolt out each side on a fast, fixed timer) for
/// `UpgradeAmounts.mirrorActiveDurationSec`, then **hidden** (invisible,
/// idle) for `UpgradeAmounts.mirrorCooldownDurationSec` — "that's the
/// cooldown," the developer's exact spec, replacing the original permanent
/// turret which never went away. Each time it goes active again it
/// reappears at a fresh spot somewhere the player can currently see
/// (`randomVisiblePoint`, `core/game_rules.dart`), not the same one —
/// "make it come," not just fade back in in place. Levels add more of
/// these (`ArenaGame._syncMirrors` spawns the difference on each new pick);
/// a single mirror's own damage/pace never changes.
class MirrorComponent extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  MirrorComponent({required Vector2 startPosition, required SpriteAnimation animation})
    : super(
        animation: animation,
        position: startPosition,
        size: Vector2(kMirrorWidthPx, kMirrorWidthPx * kMirrorAspect),
        anchor: Anchor.center,
        paint: Paint()..filterQuality = FilterQuality.none, // D-011
        priority: ArenaPriority.enemy, // reads as a world object, not a HUD/VFX layer
      );

  double _fireTimer = UpgradeAmounts.mirrorFireIntervalSec;

  /// Starts active (matches the old always-on turret's opening beat) —
  /// [startPosition] above is already a fresh on-screen spot picked by
  /// `ArenaGame._syncMirrors` at spawn time.
  bool _active = true;
  double _phaseTimer = UpgradeAmounts.mirrorActiveDurationSec;
  final Random _random = Random();

  @override
  void update(double dt) {
    super.update(dt);

    _phaseTimer -= dt;
    if (_phaseTimer <= 0) {
      _active = !_active;
      if (_active) {
        _phaseTimer = UpgradeAmounts.mirrorActiveDurationSec;
        // "Make it come" -- reappears somewhere new, not just back in the
        // same spot it vanished from.
        position.setFrom(randomVisiblePoint(_random, game.camera.visibleWorldRect));
        _fireTimer = UpgradeAmounts.mirrorFireIntervalSec;
      } else {
        _phaseTimer = UpgradeAmounts.mirrorCooldownDurationSec;
      }
      // Opacity, not removeFromParent/add -- this component lives for the
      // whole round either way, only its visibility/firing toggles.
      opacity = _active ? 1 : 0;
    }

    if (!_active) return; // hidden during its cooldown, doesn't fire

    _fireTimer -= dt;
    if (_fireTimer <= 0) {
      _fireTimer = UpgradeAmounts.mirrorFireIntervalSec;
      _fire();
    }
  }

  /// "Shoots bolts from both sides" — fixed left/right, not aimed at a
  /// target (unlike every other attack in this project, DECISIONS D-005);
  /// the mirror's whole identity is firing both ways at once.
  void _fire() {
    for (final direction in [Vector2(1, 0), Vector2(-1, 0)]) {
      game.addToWorld(
        ProjectileComponent(
          startPosition: position.clone(),
          direction: direction,
          damage: UpgradeAmounts.mirrorBoltDamage,
          knockback: UpgradeAmounts.mirrorBoltKnockback,
          speedPxPerS: UpgradeAmounts.mirrorBoltSpeedPxPerS,
          maxRangePx: UpgradeAmounts.mirrorBoltRangePx,
          animation: game.boltAnimation,
        ),
      );
    }
  }
}
