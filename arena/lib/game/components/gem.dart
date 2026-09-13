import 'dart:math';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/economy.dart';
import '../../core/game_rules.dart';
import '../../core/meta_progression.dart';
import '../arena_game.dart';

/// A dropped gem (DECISIONS D-043) — spawned at an enemy's death position
/// when `rollGemDrop` hits, auto-collected when the player walks close
/// enough (no manual pickup input, matching how nothing else in this
/// project asks for a button press). [rarity] only picks which of the 5
/// `gems.png` columns this looks like (`ArenaGame.gemAnimationFor`) — no
/// gameplay difference between tiers yet. Floats up and down in place same
/// as `PotionComponent` (DECISIONS D-059, developer's literal ask: "make it
/// like the potion one") — same shared `kItemFloatAmplitudePx`/
/// `kItemFloatPeriodSec` constants, not a second set of numbers.
class GemComponent extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  GemComponent({
    required Vector2 startPosition,
    required this.rarity,
    required SpriteAnimation animation,
    // DECISIONS D-006 — `VaseGemBurstComponent`'s own "fly out" moment:
    // when set, this gem visibly travels from [launchFrom] to
    // [startPosition] (its landing/float-bob point) over
    // `kVaseGemLaunchDurationSec` instead of just appearing there already
    // scattered. Every other spawn site (enemy drops, chests) leaves this
    // null and gets the exact same instant-appear behavior as before.
    Vector2? launchFrom,
  }) : _basePosition = startPosition.clone(),
       _launchFrom = launchFrom?.clone(),
       _launchElapsed = launchFrom != null ? 0 : null,
       super(
         animation: animation,
         position: launchFrom ?? startPosition,
         size: Vector2.all(16 * kItemRenderScale),
         anchor: Anchor.center,
         priority: ArenaPriority.pickup,
       );

  final ItemRarity rarity;
  final Vector2 _basePosition;
  double _floatTime = 0;

  /// Null for a normal (non-launched) gem. While non-null, [update] is
  /// animating [position] from here to [_basePosition] instead of running
  /// the usual float-bob/pickup check.
  final Vector2? _launchFrom;

  /// Seconds into the launch flight; becomes null the instant it lands
  /// (`>= kVaseGemLaunchDurationSec`), permanently switching this gem over
  /// to the normal float-bob/pickup behavior for the rest of its life.
  double? _launchElapsed;

  @override
  void update(double dt) {
    super.update(dt);

    if (_launchElapsed != null) {
      _launchElapsed = _launchElapsed! + dt;
      final t = (_launchElapsed! / kVaseGemLaunchDurationSec).clamp(0.0, 1.0);
      final eased = 1 - (1 - t) * (1 - t); // ease-out -- fast start, soft landing
      final from = _launchFrom!;
      position.setValues(
        from.x + (_basePosition.x - from.x) * eased,
        from.y + (_basePosition.y - from.y) * eased,
      );
      if (t >= 1) _launchElapsed = null; // landed -- float-bob takes over next frame
      return;
    }

    _floatTime += dt;
    position.x = _basePosition.x;
    position.y = _basePosition.y +
        sin(_floatTime * 2 * pi / kItemFloatPeriodSec) *
            kItemFloatAmplitudePx;

    final player = game.player;
    // MAGNET (DECISIONS D-069) widens every pickup's own collect radius.
    final radius = kItemPickupRadiusPx *
        magnetPickupRadiusMultiplier(game.metaLevel(MetaStat.magnet));
    if (player.isAlive && position.distanceTo(player.position) < radius) {
      game.collectGem(rarity);
      removeFromParent();
    }
  }
}
