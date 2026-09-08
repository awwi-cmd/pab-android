import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/progression.dart';
import '../../data/characters.dart';
import '../anim/anim_state.dart';
import '../anim/character_animations.dart';
import '../arena_game.dart';
import '../input/movement_input.dart';

/// The real animated sprite (Phase 5.4-5.9, pulled forward): idle, run,
/// fire, spawn, hurt and death all wired from the `main-*.png` sheets
/// (DECISIONS D-015). Stats come from the selected [CharacterDef]
/// (CLAUDE.md §3.3) — no combat number is computed here, everything reads
/// off `StatBlock` (DECISIONS D-008).
class PlayerComponent extends SpriteAnimationGroupComponent<AnimState>
    with HasGameReference<ArenaGame> {
  PlayerComponent({
    required this.character,
    required this.input,
    required CharacterAnimations animations,
  }) : hp = character.stats.maxHp,
       super(
         animations: animations.all,
         current: AnimState.spawn,
         size: Vector2(
           CharacterAnimations.cellWidth * kCharacterRenderScale,
           CharacterAnimations.cellHeight * kCharacterRenderScale,
         ),
         anchor: Anchor.center,
         paint: Paint()..filterQuality = FilterQuality.none, // D-011: never smoothed
         priority: ArenaPriority.player,
       );

  final CharacterDef character;
  final MovementInput input;

  double hp;

  /// Remaining invulnerability after taking damage (PRD §6.2: 0.6s i-frames,
  /// sprite flashes). The flash here is an opacity flicker, not the `hurt`
  /// AnimState — that's the recoil pose (main-hurt.png), a separate thing.
  double _invulnTimer = 0;
  static const _invulnDurationSec = 0.6;

  final Vector2 _velocity = Vector2.zero(); // scratch, reused every frame

  bool get isAlive => current != AnimState.death;

  /// Base stat plus whatever level-up picks have added this round
  /// (`ArenaGame.upgrades`, DECISIONS D-025) — a flat additive layer on
  /// top of `StatBlock`, not a re-derivation of it.
  double get effectiveMaxHp => character.stats.maxHp + game.upgrades.bonusMaxHp;
  double get effectiveMoveSpeed =>
      character.stats.moveSpeedPxPerS + game.upgrades.bonusMoveSpeed;

  @override
  void update(double dt) {
    super.update(dt);

    if (current == AnimState.death) return; // frozen on the death frame

    if (current == AnimState.spawn) {
      if (animationTicker?.done() ?? true) {
        current = AnimState.idle;
      } else {
        return; // controls locked during the spawn sequence (PRD §6.5)
      }
    }

    hp = min(effectiveMaxHp, hp + character.stats.hpRegenPerSec * dt);

    if (_invulnTimer > 0) {
      _invulnTimer -= dt;
      opacity = sin(_invulnTimer * 40) > 0 ? 1.0 : 0.35;
    } else {
      opacity = 1.0;
    }

    final moving = !input.direction.isZero();
    if (moving && current != AnimState.hurt) {
      _velocity
        ..setFrom(input.direction)
        ..scale(effectiveMoveSpeed * dt);
      position.add(_velocity);

      // Horizontal-flip-only facing (PRD §6.2) — no 8-way sprite set.
      if (input.direction.x != 0) {
        scale.x = input.direction.x < 0 ? -1 : 1;
      }
    }
    _clampToSafeArea();

    if (current == AnimState.hurt || current == AnimState.fire) {
      if (animationTicker?.done() ?? true) {
        current = moving ? AnimState.run : AnimState.idle;
      }
      return;
    }

    current = moving ? AnimState.run : AnimState.idle;
  }

  /// Screen inset by 24px + system safe-area insets (PRD §6.1). Clamping
  /// each axis independently — rather than the whole vector — is what
  /// makes the player slide along the boundary instead of sticking when
  /// moving diagonally into it.
  void _clampToSafeArea() {
    final bounds = game.safeAreaBounds;
    final halfW = size.x / 2;
    final halfH = size.y / 2;
    position.x = position.x.clamp(bounds.left + halfW, bounds.right - halfW);
    position.y = position.y.clamp(bounds.top + halfH, bounds.bottom - halfH);
  }

  void playFire() {
    if (current == AnimState.hurt || current == AnimState.death) return;
    current = AnimState.fire;
  }

  /// Contact damage from an enemy (PRD §6.2). No-ops during i-frames or
  /// after death — the 1.0s per-enemy cooldown lives on `EnemyComponent`
  /// instead, so this only guards the player's own invulnerability window.
  void takeDamage(double amount) {
    if (game.debugGodMode) return;
    if (_invulnTimer > 0 || current == AnimState.death) return;
    hp = (hp - amount).clamp(0, effectiveMaxHp);
    _invulnTimer = _invulnDurationSec;
    game.spawnBloodImpact(); // DECISIONS D-033: only on damage that lands

    if (hp <= 0) {
      current = AnimState.death;
      game.onPlayerDied();
    } else {
      current = AnimState.hurt;
    }
  }

  /// Applies a chosen level-up upgrade (DECISIONS D-025). Heals by however
  /// much max HP the pick just added, so a level-up doesn't leave the
  /// player relatively worse off by only raising the ceiling.
  void grantUpgrade(UpgradeKind kind) {
    final healed = game.upgrades.apply(kind);
    hp = min(effectiveMaxHp, hp + healed);
  }
}
