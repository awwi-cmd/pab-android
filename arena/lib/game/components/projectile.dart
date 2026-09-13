import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../arena_game.dart';
import 'damageable.dart';
import 'projectile_poof.dart';

/// Straight-line, constant speed, one enemy per projectile, no pierce, no
/// homing/leading (PRD §6.3 / DECISIONS D-005). Also the boss's bolt
/// (DECISIONS D-042) and Ultimate Mirror's (DECISIONS D-049) via [tint] —
/// same shape, sprite recoloured green for the boss, rather than a whole
/// second component class.
///
/// [targetsPlayer] (DECISIONS D-051) picks which side this bolt can hit:
/// `false` (default) is every player-owned shot — the Apprentice/Warden's
/// own attack, Ultimate Mirror's bolts — checked against
/// `game.damageableTargets` (enemies + the boss), same as always. `true` is
/// the boss's own bolt (`BossComponent._fire`) — it has to check the player
/// instead, since the player was never in `damageableTargets` (that list
/// only exists to answer "what can a player attack hit") and a bolt built
/// with the default would silently never find a target to damage at all.
///
/// [maxBounces] (DECISIONS D-052) — `0` (default, every existing use)
/// despawns on leaving `camera.visibleWorldRect` same as always. A positive
/// count reflects off that same edge instead, up to that many times, before
/// finally despawning on the next one — this project has no fixed arena
/// wall to bounce off since D-040 (roaming world, no bounds), so "the wall"
/// is read as the edge of what's currently visible, the existing stand-in
/// for "off-screen" everywhere else in this file.
class ProjectileComponent extends SpriteAnimationComponent
    with HasGameReference<ArenaGame> {
  ProjectileComponent({
    required Vector2 startPosition,
    required Vector2 direction,
    required this.damage,
    required this.knockback,
    required this.speedPxPerS,
    required this.maxRangePx,
    required SpriteAnimation animation,
    Color? tint,
    this.excludeSelf,
    this.targetsPlayer = false,
    this.neverExpire = false,
    int maxBounces = 0,
  }) : _direction = direction.normalized(),
       _bouncesLeft = maxBounces,
       super(
         animation: animation,
         position: startPosition,
         size: Vector2.all(16 * kProjectileRenderScale),
         anchor: Anchor.center,
         paint: Paint()
           ..filterQuality = FilterQuality.none // D-011
           ..colorFilter = tint == null
               ? null
               : ColorFilter.mode(tint, BlendMode.srcIn),
         priority: ArenaPriority.projectile,
       );

  final double damage;
  final double knockback;
  final double speedPxPerS;
  final double maxRangePx;
  final Vector2 _direction;
  // The boss fires this same component at itself, position-wise, at spawn
  // (`BossComponent._fire` starts the bolt at `position.clone()`, and the
  // boss is itself in `game.damageableTargets`) -- without this, the very
  // first update() call after spawn found the boss "touching" its own bolt
  // at distance 0 and destroyed it before it ever traveled anywhere,
  // reported on-device as "boss does the animation but I never see a
  // projectile" (2026-09-09).
  final Damageable? excludeSelf;
  final bool targetsPlayer;

  /// `true` skips both the [maxRangePx] and [_outOfBounds] despawn checks
  /// entirely (DECISIONS D-059, developer's call: Ultimate Mirror's bolts
  /// should "not expire and not despawn") — the projectile just keeps
  /// flying in a straight line forever, only ever removed by actually
  /// hitting something. `false` (default, every other existing use) is
  /// unchanged. Not combined with [maxBounces] anywhere yet — bouncing only
  /// triggers off the same out-of-bounds check this flag skips.
  final bool neverExpire;
  int _bouncesLeft;

  double _traveled = 0;
  final Vector2 _scratch = Vector2.zero(); // reused every frame

  @override
  void update(double dt) {
    super.update(dt);

    final step = speedPxPerS * dt;
    _scratch
      ..setFrom(_direction)
      ..scale(step);
    position.add(_scratch);
    _traveled += step;

    if (!neverExpire) {
      if (_traveled >= maxRangePx) {
        _expire();
        return;
      }
      if (_outOfBounds()) {
        if (_bouncesLeft > 0) {
          _bounce();
        } else if (_farOutOfBounds()) {
          _expire();
          return;
        }
        // Else: past the visible edge with nothing left to bounce off, but
        // not "way out" yet (DECISIONS D-061) -- keeps flying straight;
        // _farOutOfBounds() catches it a few frames later once it truly
        // clears the screen.
      }
    }

    if (targetsPlayer) {
      _checkPlayerHit();
    } else {
      _checkDamageableHit();
    }
  }

  /// The boss's bolt (DECISIONS D-051) — `PlayerComponent` isn't a
  /// `Damageable` (no `applyKnockback`; nothing in this project knocks the
  /// player back, only enemies get shoved by the player's own hits), so
  /// this is a separate, simpler check than [_checkDamageableHit] rather
  /// than trying to fit the player through the same interface.
  void _checkPlayerHit() {
    final player = game.player;
    if (!player.isAlive) return;
    final touching = position.distanceTo(player.position) <
        (size.x / 2 + player.size.x / 2);
    if (touching) {
      player.takeDamage(damage);
      // DECISIONS D-010: the hit spark at the *player's* own center, not
      // this bolt's current position (see `_checkDamageableHit`'s matching
      // fix and its own doc comment for why).
      game.onProjectileHit(player.position.clone(), damage);
      removeFromParent();
    }
  }

  void _checkDamageableHit() {
    final targets = game.damageableTargets;
    Damageable? hit;
    for (var i = 0; i < targets.length; i++) {
      final target = targets[i];
      if (identical(target, excludeSelf)) continue;
      if (target.isDying) continue; // already dead, let the shot pass through
      final touching = position.distanceTo(target.position) <
          (size.x / 2 + target.size.x / 2);
      if (touching) {
        hit = target;
        break;
      }
    }

    if (hit != null) {
      // Resolve the hit only after the search loop ends -- takeDamage() can
      // remove `hit` from game.enemies, which must not happen mid-iteration.
      hit.applyKnockback(_direction, knockback);
      hit.takeDamage(damage);
      // DECISIONS D-010 ("main projectiles disappears at bounding box...
      // make it read as a real hit"): the spark VFX used to spawn at this
      // bolt's own position -- the moment their bounding circles first
      // touch, which is the *edge* of the target's hitbox, well short of
      // its visible center, so the bolt looked like it vanished in open
      // air just before reaching the enemy. Every other attack in this
      // project (Knife, Spiral Fire, Aura, Warden Slam) already spawns
      // this same spark at `target.position` — this was the one straggler
      // still passing its own position. No collision/timing change, only
      // where the existing hit-feedback VFX renders.
      game.onProjectileHit(hit.position.clone(), damage);
      removeFromParent();
    }
  }

  /// Off the camera's current view (DECISIONS D-040) — not a fixed
  /// `0..game.size` rect, which only ever meant "off screen" back when the
  /// camera was pinned to the world origin (D-007). Since the camera now
  /// follows the player anywhere in the world, "on screen" has to be
  /// computed relative to wherever the camera actually is right now.
  bool _outOfBounds() {
    return !game.camera.visibleWorldRect.contains(position.toOffset());
  }

  /// DECISIONS D-061 — [_outOfBounds] alone marks the moment this
  /// projectile's *center* crosses the visible edge, which is exactly right
  /// as the bounce trigger (that edge IS "the wall" it bounces off, D-052)
  /// but too early to actually despawn at: half the sprite is still clearly
  /// on-screen. Once there are no bounces left, this more generous check
  /// (inflated by [kProjectileDespawnMarginFactor] times this bolt's own
  /// width) is what the zero-bounce despawn path waits for instead.
  bool _farOutOfBounds() {
    return !game.camera.visibleWorldRect
        .inflate(size.x * kProjectileDespawnMarginFactor)
        .contains(position.toOffset());
  }

  /// Ran out of range or bounces without ever hitting anything (DECISIONS
  /// D-053) — hands off to a shrink-and-drift "poof" instead of just
  /// vanishing. Not called from the hit paths above; those already have
  /// their own feedback ([ArenaGame.onProjectileHit]).
  void _expire() {
    game.addToWorld(
      ProjectilePoofComponent(
        startPosition: position.clone(),
        startSize: size.clone(),
        animation: animation,
        paint: paint,
      ),
    );
    removeFromParent();
  }

  /// Reflects off whichever edge(s) of [camera.visibleWorldRect] were
  /// crossed (DECISIONS D-052) — checks each axis independently so a
  /// corner-clip flips both x and y in the same call, same as a real
  /// bounce. Clamps back inside afterwards so a fast-moving bolt doesn't
  /// re-trigger a second bounce next frame while it's still technically
  /// outside.
  void _bounce() {
    _bouncesLeft--;
    final visible = game.camera.visibleWorldRect;
    if (position.x < visible.left || position.x > visible.right) {
      _direction.x = -_direction.x;
    }
    if (position.y < visible.top || position.y > visible.bottom) {
      _direction.y = -_direction.y;
    }
    position
      ..x = position.x.clamp(visible.left, visible.right)
      ..y = position.y.clamp(visible.top, visible.bottom);
  }
}
