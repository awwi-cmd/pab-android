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
  MirrorComponent({
    required Vector2 startPosition,
    required SpriteAnimation animation,
    double staggerDelaySec = 0,
  }) : super(
        animation: animation,
        position: startPosition,
        size: Vector2(kMirrorWidthPx, kMirrorWidthPx * kMirrorAspect),
        anchor: Anchor.center,
        paint: Paint()..filterQuality = FilterQuality.none, // D-011
        priority: ArenaPriority.enemy, // reads as a world object, not a HUD/VFX layer
      ) {
    // DECISIONS D-059 ("spawn not in sync, by 0.5 seconds delay"): only the
    // very first active->hidden flip is pushed back -- since every mirror
    // runs the same active/cooldown durations, one initial offset keeps
    // them permanently out of phase with each other, not just at the start.
    _phaseTimer += staggerDelaySec;
    _horizontalAxis = _random.nextBool();
  }

  double _fireTimer = UpgradeAmounts.mirrorFireIntervalSec;

  /// Starts active (matches the old always-on turret's opening beat) —
  /// [startPosition] above is already a fresh on-screen spot picked by
  /// `ArenaGame._syncMirrors` at spawn time.
  bool _active = true;
  double _phaseTimer = UpgradeAmounts.mirrorActiveDurationSec;
  final Random _random = Random();

  /// Which axis this mirror fires along (DECISIONS D-059: "can also spawn
  /// shooting from up to down") — re-rolled every time it reactivates
  /// (below), so a mirror doesn't stay locked to left/right for the whole
  /// round.
  bool _horizontalAxis = true;

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
        // DECISIONS D-059: re-rolled on every reactivation, not just once at
        // spawn -- across a long round the same mirror can come back
        // firing horizontally one time, vertically the next.
        _horizontalAxis = _random.nextBool();
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

  /// "Shoots bolts from both sides" — fixed along [_horizontalAxis]'s
  /// current axis (left/right or up/down, DECISIONS D-059), not aimed at a
  /// target (unlike every other attack in this project, DECISIONS D-005);
  /// the mirror's whole identity is firing both ways along one line at
  /// once. Bolts never expire/despawn (DECISIONS D-059,
  /// `ProjectileComponent.neverExpire`) — `maxRangePx` is still passed
  /// since the parameter's required, but it's never actually read while
  /// that flag is set.
  void _fire() {
    final directions = _horizontalAxis
        ? [Vector2(1, 0), Vector2(-1, 0)]
        : [Vector2(0, 1), Vector2(0, -1)];
    for (final direction in directions) {
      game.addToWorld(
        ProjectileComponent(
          startPosition: position.clone(),
          direction: direction,
          damage: UpgradeAmounts.mirrorBoltDamage,
          knockback: UpgradeAmounts.mirrorBoltKnockback,
          speedPxPerS: UpgradeAmounts.mirrorBoltSpeedPxPerS,
          maxRangePx: UpgradeAmounts.mirrorBoltRangePx,
          animation: game.boltAnimation,
          neverExpire: true,
        ),
      );
    }
  }
}
