import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/game_rules.dart';
import '../../core/progression.dart';
import '../../core/stats.dart';
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
    required this.stats,
    required this.input,
    required CharacterAnimations animations,
  }) : hp = stats.maxHp,
       super(
         animations: animations.all,
         current: AnimState.spawn,
         size: Vector2(
           CharacterAnimations.cellWidth * kCharacterRenderScale,
           CharacterAnimations.cellHeight * kCharacterRenderScale,
         ),
         anchor: Anchor.center,
         paint: Paint()
           ..filterQuality = FilterQuality.none, // D-011: never smoothed
         priority: ArenaPriority.player,
       );

  final CharacterDef character;

  /// The character's base stats plus whatever's been bought in the
  /// Upgrades shop (`ArenaGame.effectiveStats`, DECISIONS D-047) — resolved
  /// once at round start, not re-read from `character` directly, since the
  /// shop's purchases aren't reachable mid-round anyway.
  final StatBlock stats;
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
  double get effectiveMaxHp => stats.maxHp + game.upgrades.bonusMaxHp;
  double get effectiveMoveSpeed =>
      stats.moveSpeedPxPerS + game.upgrades.bonusMoveSpeed;

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

    // Defence Crystal (in-round, DECISIONS D-049) and Resolve (persistent,
    // DECISIONS D-067) both add a flat regen bonus, same additive-layer
    // pattern as effectiveMaxHp/effectiveMoveSpeed above.
    hp = min(
      effectiveMaxHp,
      hp +
          (stats.hpRegenPerSec +
                  game.upgrades.bonusHpRegenPerSec +
                  resolveHpRegenPerSec(game.meta.resolveLevel)) *
              dt,
    );

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
    // No bounds clamp (DECISIONS D-040 — the arena is no longer a fixed
    // rect; the camera follows the player anywhere in the world instead of
    // keeping the player inside a fixed viewport-sized area).

    if (current == AnimState.hurt || current == AnimState.fire) {
      if (animationTicker?.done() ?? true) {
        current = moving ? AnimState.run : AnimState.idle;
      }
      return;
    }

    current = moving ? AnimState.run : AnimState.idle;
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
    // Defence Crystal (in-round, DECISIONS D-049) and Resolve (persistent,
    // DECISIONS D-067) both add flat damage resistance, clamped together so
    // a future bug/overstack can't invert it into bonus damage.
    final resistanceMultiplier =
        (1 -
                game.upgrades.damageResistance -
                resolveDamageResistance(game.meta.resolveLevel))
            .clamp(0.0, 1.0);
    hp = (hp - amount * resistanceMultiplier).clamp(0, effectiveMaxHp);
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

  /// A potion pickup (DECISIONS D-043) — clamped the same way every other
  /// heal in this file is, never past [effectiveMaxHp].
  void heal(double amount) {
    hp = min(effectiveMaxHp, hp + amount);
  }
}
