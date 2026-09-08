import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/widgets.dart' show EdgeInsets;

import '../core/constants.dart';
import '../core/game_rules.dart';
import '../core/progression.dart';
import '../core/settings.dart';
import '../data/characters.dart';
import 'anim/character_animations.dart';
import 'anim/enemy_animations.dart';
import 'anim/sheet_loader.dart';
import 'components/arena_floor.dart';
import 'components/aura.dart';
import 'components/damage_text.dart';
import 'components/enemy.dart';
import 'components/hp_bar.dart';
import 'components/player.dart';
import 'components/spawner.dart';
import 'components/tracking_effect.dart';
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
  late SpriteAnimation _auraShieldAnimation;
  late Sprite _knifeCleanSprite;
  late Sprite _knifeBloodySprite;
  late SpriteAnimation _bloodImpactAnimation;
  late SpriteAnimation _eliteFireAnimation;
  late SpriteAnimation _pixelFireAnimation;
  late SpriteAnimation _sparkleAnimation;
  late SpriteAnimation _impactAnimation;
  late SpriteAnimation _explosionAnimation;
  final Random _random = Random();

  /// The Aura skill's orbiting-ring component (DECISIONS D-027) — null
  /// until the first Aura pick, created once and left in place afterwards;
  /// later picks just raise the stack count it reads each tick.
  AuraComponent? _aura;

  /// Exposed for [AttackBehavior]s (`attack_behavior.dart`) to build
  /// projectiles from — the animation itself isn't per-character yet, but
  /// the behavior that fires it is (DECISIONS D-024).
  SpriteAnimation get boltAnimation => _boltAnimation;

  /// Exposed for [KnifeAttack] (DECISIONS D-029) the same way [boltAnimation]
  /// is for [ProjectileAttack] — the Bruiser's knife swaps between these two
  /// static sprites itself once it draws blood.
  Sprite get knifeCleanSprite => _knifeCleanSprite;
  Sprite get knifeBloodySprite => _knifeBloodySprite;

  /// Exposed for [SpiralFireAttack] (DECISIONS D-034) the same way
  /// [boltAnimation]/[knifeCleanSprite] are for the other kits.
  SpriteAnimation get pixelFireAnimation => _pixelFireAnimation;

  /// Flutter-observable mirror of round-over state, so the movement-input
  /// overlay (a Flutter widget, not a Flame overlay) knows to stop
  /// capturing touches once the round has ended.
  final ValueNotifier<bool> roundOver = ValueNotifier(false);

  /// True whenever the Level Up or Pause Menu overlay is showing — mirrors
  /// `roundOver` for the same reason (DECISIONS D-025): hides the
  /// movement-input overlay and the top HUD buttons while a menu owns the
  /// screen, without those Flutter widgets needing to know why.
  final ValueNotifier<bool> menuOpen = ValueNotifier(false);

  // Round state (TASKS 4.12).
  double elapsed = 0;
  int kills = 0;
  double damageDealt = 0;

  // In-round leveling (DECISIONS D-025) -- resets every round, same as
  // everything else here (CLAUDE.md §4.5). core/progression.dart owns the
  // actual formulas/bonus math; this is just the round-scoped state.
  int level = 1;
  double xp = 0;
  double _xpToNextLevel = xpThresholdForLevel(1);
  final PlayerUpgrades upgrades = PlayerUpgrades();
  List<UpgradeKind> currentLevelUpChoices = const [];
  int _pendingLevelUps = 0;
  int get pendingLevelUps => _pendingLevelUps;
  bool debugGodMode = false;

  double _fireCooldown = 0;

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
    _animations = await CharacterAnimations.load(
      character.spriteFolder,
      character.spritePrefix,
    );
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
    // Aura's shield ring (DECISIONS D-032) -- a 9x7 grid sheet, 60 real
    // frames padded out to a 63-cell rectangle (the last 3 cells of the
    // last row are blank), not a single-row strip like every other sheet
    // in this project.
    _auraShieldAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_electric-shield.png',
      cellWidth: 265,
      cellHeight: 265,
      stepTime: 0.03,
      frameCount: 60,
      amountPerRow: 9,
    );
    // Single static images, not sheets (DECISIONS D-029) -- Sprite.load, not
    // loadSheetAnimation.
    _knifeCleanSprite = await Sprite.load('vfx/projectiles/knife_clean.png');
    _knifeBloodySprite = await Sprite.load('vfx/projectiles/knife_bloody.png');
    // Player hit-splat (DECISIONS D-033) -- one-shot, doesn't loop.
    _bloodImpactAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_blood-impact.png',
      cellWidth: 60,
      cellHeight: 63,
      stepTime: 0.012,
      frameCount: 48,
      amountPerRow: 9,
      loop: false,
    );
    // Elite enemy marker (DECISIONS D-035) -- persistent looping glow, lives
    // as long as the enemy it's tracking does.
    _eliteFireAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_dithered-fire.png',
      cellWidth: 517,
      cellHeight: 246,
      stepTime: 0.05,
      frameCount: 60,
      amountPerRow: 9,
    );
    // Skirmisher's Spiral Fire skill (DECISIONS D-034) -- three sheets:
    // the projectile itself (loops for however long it's in flight), the
    // cast sparkle on the caster's body (one-shot), the hit/kill flourishes
    // (one-shot each, picked by whether that hit was lethal).
    _pixelFireAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_pixel-fire.png',
      cellWidth: 173,
      cellHeight: 197,
      stepTime: 0.03,
      frameCount: 60,
      amountPerRow: 9,
    );
    _sparkleAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_sparkles-constelation.png',
      cellWidth: 309,
      cellHeight: 313,
      stepTime: 0.008,
      frameCount: 60,
      amountPerRow: 9,
      loop: false,
    );
    // First real cell is index 1, not 0 -- effect_impact.png's (0,0) cell is
    // blank on this sheet. Included as frame 0 anyway (one invisible ~12ms
    // frame at the very start of a one-shot flash is imperceptible) rather
    // than adding texturePosition-offset support to the loader for it.
    _impactAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_impact.png',
      cellWidth: 305,
      cellHeight: 383,
      stepTime: 0.012,
      frameCount: 29,
      amountPerRow: 9,
      loop: false,
    );
    // Same leading-blank-cell situation as effect_impact.png above.
    _explosionAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_explosion2.png',
      cellWidth: 355,
      cellHeight: 365,
      stepTime: 0.011,
      frameCount: 53,
      amountPerRow: 9,
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

    level = 1;
    xp = 0;
    _xpToNextLevel = xpThresholdForLevel(1);
    upgrades.reset();
    currentLevelUpChoices = const [];
    _pendingLevelUps = 0;
    debugGodMode = false;
    menuOpen.value = false;
    _aura = null; // the old instance was already removed via removeAll above

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
      // Cooldown always resets on schedule, whether or not perform()
      // actually found a target -- matches the pre-D-024 behavior exactly.
      _fireCooldown = character.attackBehavior.cooldownSeconds(character.stats);
      character.attackBehavior.perform(this);
    }
  }

  void spawnEnemy(Vector2 at) {
    final skin = EnemySkin.values[_random.nextInt(EnemySkin.values.length)];
    final enemy = EnemyComponent(
      startPosition: at,
      runAnimation: _enemyAnimations.runFor(skin),
      deathAnimation: _enemyAnimations.deathFor(skin),
      // DECISIONS D-026: baked in at spawn, not re-applied later — an
      // enemy that spawned at level 3 keeps level-3 stats even if the
      // player is level 5 by the time it dies.
      statMultiplier: enemyStatMultiplier(level),
    );
    enemies.add(enemy);
    add(enemy);

    // Elite marker (DECISIONS D-035) -- visual only, no stat change. A
    // separate top-level sibling rather than a child of `enemy`: a
    // component's own children render on top of it (Flame renders self then
    // children), which would put the glow in front of the enemy instead of
    // under it. `groundEffects` priority (< `enemy`) plus tracking the
    // enemy's position every frame gets the same "glued to it" effect with
    // the right z-order instead.
    if (rollIsElite(_random)) {
      final width = enemy.size.x; // never wider than the enemy, per the ask
      add(
        TrackingSpriteEffect(
          target: enemy,
          offset: Vector2(0, enemy.size.y * 0.3), // toward the feet, not center
          animation: _eliteFireAnimation,
          size: Vector2(width, width * kEliteFireAspect),
          priority: ArenaPriority.groundEffects,
          removeOnFinish: false, // persists for the enemy's whole lifetime
        ),
      );
    }
  }

  void onEnemyKilled(EnemyComponent enemy) {
    enemies.remove(enemy);
    enemy.removeFromParent();
    kills++;
    grantXp(kXpPerKill);
  }

  /// Kills grant XP directly — no drops (developer's spec). Loops in case
  /// one grant crosses more than one threshold at once.
  void grantXp(double amount) {
    if (roundOver.value) return;
    xp += amount;
    while (xp >= _xpToNextLevel) {
      xp -= _xpToNextLevel;
      level++;
      _xpToNextLevel = xpThresholdForLevel(level);
      _pendingLevelUps++;
    }
    _maybeShowNextLevelUp();
  }

  /// Debug-only: grants a level (and its popup) for free, no XP required.
  /// The popup itself is deferred by `_maybeShowNextLevelUp`'s Pause Menu
  /// guard below until the menu actually closes (developer's spec).
  void debugGrantLevelUp() {
    level++;
    _pendingLevelUps++;
    _maybeShowNextLevelUp();
  }

  void _maybeShowNextLevelUp() {
    if (roundOver.value || _pendingLevelUps <= 0) return;
    if (overlays.isActive('PauseMenu') || overlays.isActive('LevelUp')) return;
    currentLevelUpChoices = rollUpgradeChoices(
      _random,
      pickCounts: upgrades.pickCounts,
      candidates: upgradeKindsFor(character.id),
    );
    overlays.add('LevelUp');
    menuOpen.value = true;
    pauseEngine();
  }

  /// Called by the Level Up overlay once the player taps one of the 3
  /// choices. Chains straight into the next pending level-up (still
  /// paused) if more than one queued up, rather than resuming in between.
  void resolveLevelUpChoice(UpgradeKind kind) {
    player.grantUpgrade(kind);
    _syncAura();
    _pendingLevelUps--;
    overlays.remove('LevelUp');
    if (_pendingLevelUps > 0) {
      _maybeShowNextLevelUp();
    } else {
      menuOpen.value = false;
      resumeEngine();
    }
  }

  void openPauseMenu() {
    if (roundOver.value) return;
    if (overlays.isActive('LevelUp') || overlays.isActive('PauseMenu')) return;
    overlays.add('PauseMenu');
    menuOpen.value = true;
    pauseEngine();
  }

  /// Any level-ups granted (debug or otherwise) while the menu was open
  /// play out immediately after it closes, still paused, rather than
  /// resuming gameplay first (developer's spec).
  void closePauseMenu() {
    overlays.remove('PauseMenu');
    if (_pendingLevelUps > 0) {
      _maybeShowNextLevelUp();
    } else {
      menuOpen.value = false;
      resumeEngine();
    }
  }

  /// Spawns the Aura's ring component on the first pick (DECISIONS D-027).
  /// Later picks don't rebuild it -- `AuraComponent` reads the current
  /// stack count off `upgrades.pickCounts` itself every tick, so bumping
  /// the count is all a second/third pick needs to do.
  void _syncAura() {
    if (_aura != null) return;
    if ((upgrades.pickCounts[UpgradeKind.aura] ?? 0) <= 0) return;
    _aura = AuraComponent(shieldAnimation: _auraShieldAnimation);
    add(_aura!);
  }

  void onEnemyContact(EnemyComponent enemy) {
    player.takeDamage(enemy.contactDamage);
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

  /// A one-shot VFX at a fixed point that removes itself once its animation
  /// finishes — for effects tied to a moment (a hit, a kill), not to a
  /// still-living target's body (that's `TrackingSpriteEffect`, DECISIONS
  /// D-033/D-034/D-035). [opacity] defaults to fully opaque.
  void spawnEffect(
    SpriteAnimation animation,
    Vector2 at, {
    required Vector2 size,
    double opacity = 1,
    int priority = ArenaPriority.hitEffects,
  }) {
    add(
      SpriteAnimationComponent(
        animation: animation,
        position: at,
        size: size,
        anchor: Anchor.center,
        removeOnFinish: true,
        priority: priority,
        paint: Paint()
          ..filterQuality = FilterQuality.none // D-011
          ..color = Color.fromRGBO(255, 255, 255, opacity),
      ),
    );
  }

  /// Player hit feedback (DECISIONS D-033) — a blood splat somewhere on the
  /// player's own body, a different spot each time so it doesn't read as a
  /// static decal. Called from `PlayerComponent.takeDamage` only when
  /// damage actually lands (not during i-frames/god mode).
  void spawnBloodImpact() {
    final width = player.size.x * kBloodImpactWidthFactor;
    final maxOffsetX = player.size.x * 0.3;
    final maxOffsetY = player.size.y * 0.3;
    final at = player.position +
        Vector2(
          (_random.nextDouble() * 2 - 1) * maxOffsetX,
          (_random.nextDouble() * 2 - 1) * maxOffsetY,
        );
    spawnEffect(
      _bloodImpactAnimation,
      at,
      size: Vector2(width, width * kBloodImpactAspect),
    );
  }

  /// The Skirmisher's Spiral Fire cast flourish (DECISIONS D-034) — glued to
  /// [caster] for its short duration (`TrackingSpriteEffect`) rather than a
  /// fixed point, since the player can keep moving mid-cast. Rendered behind
  /// the caster (`groundEffects` priority < `player`) and dimmed to 35%
  /// opacity per spec.
  void spawnCastSparkle(PositionComponent caster) {
    final width = caster.size.x * kSparkleWidthFactor;
    add(
      TrackingSpriteEffect(
        target: caster,
        animation: _sparkleAnimation,
        size: Vector2(width, width * kSparkleAspect),
        priority: ArenaPriority.groundEffects,
        paint: Paint()
          ..filterQuality = FilterQuality.none // D-011
          ..color = const Color.fromRGBO(255, 255, 255, 0.35),
      ),
    );
  }

  /// Non-lethal hit from the Skirmisher's Spiral Fire (DECISIONS D-034) —
  /// [spawnExplosionEffect] plays instead when that hit was the kill.
  void spawnImpactEffect(Vector2 at) {
    spawnEffect(
      _impactAnimation,
      at,
      size: Vector2(kSpiralImpactWidthPx, kSpiralImpactWidthPx * kSpiralImpactAspect),
    );
  }

  void spawnExplosionEffect(Vector2 at) {
    spawnEffect(
      _explosionAnimation,
      at,
      size: Vector2(
        kSpiralExplosionWidthPx,
        kSpiralExplosionWidthPx * kSpiralExplosionAspect,
      ),
    );
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
    overlays.add('RoundOver');
    pauseEngine();
  }
}
