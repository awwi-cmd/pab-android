import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/widgets.dart' show EdgeInsets;

import '../core/constants.dart';
import '../core/settings.dart';
import '../core/stats.dart';
import '../data/characters.dart';
import 'anim/character_animations.dart';
import 'anim/enemy_animations.dart';
import 'anim/sheet_loader.dart';
import 'components/arena_floor.dart';
import 'components/damage_text.dart';
import 'components/enemy.dart';
import 'components/hp_bar.dart';
import 'components/player.dart';
import 'components/projectile.dart';
import 'components/spawner.dart';
import 'input/movement_input.dart';

/// Owns round state end to end (CLAUDE.md §4.5): elapsed time, kills,
/// damage dealt, spawn interval. Resets it in `onLoad`/`resetRound` — a
/// fresh arena entry must look exactly like the first one.
class ArenaGame extends FlameGame {
  ArenaGame({
    required this.character,
    required this.settings,
    this.systemInsets = EdgeInsets.zero,
  });

  final CharacterDef character;
  final Settings settings;

  /// Captured once at arena entry (device notch / gesture-bar insets).
  /// The app is portrait-locked, so this doesn't need to track rotation.
  final EdgeInsets systemInsets;

  static const double kSafeAreaInset = 24;

  /// Read at arena entry, never live-switched mid-round (DECISIONS D-006).
  final MovementInput input = MovementInput();

  late PlayerComponent player;
  final List<EnemyComponent> enemies = [];

  late CharacterAnimations _animations;
  late EnemyAnimations _enemyAnimations;
  late SpriteAnimation _boltAnimation;
  late SpriteAnimation _sparkAnimation;
  final Random _random = Random();

  /// Flutter-observable mirror of round-over state, so the movement-input
  /// overlay (a Flutter widget, not a Flame overlay) knows to stop
  /// capturing touches once the round has ended.
  final ValueNotifier<bool> roundOver = ValueNotifier(false);

  // Round state (TASKS 4.12).
  double elapsed = 0;
  int kills = 0;
  double damageDealt = 0;

  double _fireCooldown = 0;
  final Vector2 _fireDirection = Vector2.zero();

  /// Set on player death, ticks down to let the death animation play before
  /// the round actually ends (PRD §6.5).
  double? _roundEndDelay;
  static const _roundEndDelaySec = 0.6;

  @override
  Color backgroundColor() => ArenaColors.background;

  /// Screen inset by 24px on all sides plus system safe-area insets
  /// (PRD §6.1). Enemies are not clamped to this — only the player.
  Rect get safeAreaBounds => Rect.fromLTRB(
        kSafeAreaInset + systemInsets.left,
        kSafeAreaInset + systemInsets.top,
        size.x - kSafeAreaInset - systemInsets.right,
        size.y - kSafeAreaInset - systemInsets.bottom,
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _animations = await CharacterAnimations.load(character.spriteFolder);
    _enemyAnimations = await EnemyAnimations.load();
    _boltAnimation = await loadSheetAnimation(
      'vfx/projectiles/projectile-bolt.png',
      cellWidth: 16,
      cellHeight: 16,
      stepTime: 0.08,
    );
    _sparkAnimation = await loadSheetAnimation(
      'vfx/projectiles/projectile-spark.png',
      cellWidth: 16,
      cellHeight: 16,
      stepTime: 0.05,
      loop: false,
    );
    resetRound();
  }

  /// Never carry state across rounds via globals/singletons (CLAUDE.md
  /// §4.5) — this rebuilds the round from a clean slate every time.
  void resetRound() {
    roundOver.value = false;
    input.clear();
    removeAll(children.toList());
    enemies.clear();
    // Not touching `overlays` here: this only ever runs from onLoad(),
    // before GameWidget has finished mounting and registered its overlay
    // builders -- calling overlays.add/remove this early throws (asserts
    // the overlay name is known). The initial "DebugDie" overlay comes from
    // GameWidget's `initialActiveOverlays` instead; debugDie()/_endRound()
    // are the only other places that touch overlays, and those only ever
    // run once the game is already interactive.

    elapsed = 0;
    kills = 0;
    damageDealt = 0;
    _fireCooldown = 0;
    _roundEndDelay = null;

    add(ArenaFloor());
    player = PlayerComponent(
      character: character,
      input: input,
      animations: _animations,
    )..position = size / 2;
    add(player);
    add(HpBarComponent());
    add(Spawner());

    if (settings.showFps) {
      // Below the HP bar (top-left, 24,24 + 14 tall) so they don't overlap.
      add(FpsTextComponent(position: Vector2(24, 46)));
    }

    resumeEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (roundOver.value) return;

    if (_roundEndDelay != null) {
      _roundEndDelay = _roundEndDelay! - dt;
      if (_roundEndDelay! <= 0) {
        _roundEndDelay = null;
        _endRound();
      }
      return;
    }

    elapsed += dt;

    _fireCooldown -= dt;
    if (_fireCooldown <= 0) {
      _tryFire();
    }
  }

  void _tryFire() {
    _fireCooldown = 1 / character.stats.attacksPerSec;

    EnemyComponent? nearest;
    var nearestDist = character.stats.attackRangePx;
    for (var i = 0; i < enemies.length; i++) {
      final enemy = enemies[i];
      final dist = enemy.position.distanceTo(player.position);
      if (dist <= nearestDist) {
        nearest = enemy;
        nearestDist = dist;
      }
    }
    if (nearest == null) return;

    _fireDirection
      ..setFrom(nearest.position)
      ..sub(player.position);
    if (_fireDirection.isZero()) return;
    _fireDirection.normalize();

    add(
      ProjectileComponent(
        startPosition: player.position.clone(),
        direction: _fireDirection.clone(),
        damage: character.stats.damagePerHit,
        knockback: character.stats.knockbackImpulse,
        speedPxPerS: character.stats.projSpeedPxPerS,
        maxRangePx: character.stats.attackRangePx * 1.5,
        animation: _boltAnimation,
      ),
    );
    player.playFire();
  }

  void spawnEnemy(Vector2 at) {
    final skin = EnemySkin.values[_random.nextInt(EnemySkin.values.length)];
    final enemy = EnemyComponent(
      startPosition: at,
      runAnimation: _enemyAnimations.runFor(skin),
      deathAnimation: _enemyAnimations.deathFor(skin),
    );
    enemies.add(enemy);
    add(enemy);
  }

  void onEnemyKilled(EnemyComponent enemy) {
    enemies.remove(enemy);
    enemy.removeFromParent();
    kills++;
  }

  void onEnemyContact() {
    player.takeDamage(EnemyStats.contactDamage);
  }

  void onProjectileHit(Vector2 at, double damage) {
    damageDealt += damage;
    add(
      SpriteAnimationComponent(
        animation: _sparkAnimation,
        position: at,
        size: Vector2.all(16 * kProjectileRenderScale),
        anchor: Anchor.center,
        removeOnFinish: true,
        priority: ArenaPriority.hitEffects,
      ),
    );
    add(DamageTextComponent(position: at.clone(), amount: damage));
  }

  /// PRD §6.5: freeze after the death frame, then show Round Over. Debug
  /// stand-in `debugDie()` shares this same path.
  void onPlayerDied() {
    _roundEndDelay ??= _roundEndDelaySec;
  }

  /// Debug-only stand-in for HP <= 0 (PRD §3: the arena's only real exit is
  /// death) — jumps straight to round end without waiting on a death anim,
  /// since the player box hasn't necessarily taken lethal damage.
  void debugDie() {
    if (roundOver.value || _roundEndDelay != null) return;
    _roundEndDelay = 0;
  }

  void _endRound() {
    roundOver.value = true;
    overlays.remove('DebugDie');
    overlays.add('RoundOver');
    pauseEngine();
  }
}
