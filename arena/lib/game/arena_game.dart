import 'dart:async' show unawaited;
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/widgets.dart' show EdgeInsets;

import '../core/constants.dart';
import '../core/economy.dart';
import '../core/game_rules.dart';
import '../core/meta_progression.dart';
import '../core/progression.dart';
import '../core/settings.dart';
import '../core/stats.dart';
import '../data/characters.dart';
import 'anim/character_animations.dart';
import 'anim/enemy_animations.dart';
import 'anim/sheet_loader.dart';
import 'components/arena_floor.dart';
import 'components/aura.dart';
import 'components/boss.dart';
import 'components/damageable.dart';
import 'components/damage_text.dart';
import 'components/enemy.dart';
import 'components/gem.dart';
import 'components/hp_bar.dart';
import 'components/player.dart';
import 'components/potion.dart';
import 'components/potion_spawner.dart';
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
    required this.meta,
    this.systemInsets = EdgeInsets.zero,
  });

  final CharacterDef character;
  final Settings settings;

  /// Loaded once at arena entry (`ArenaScreen._load`, same as [settings]) —
  /// the Upgrades shop's purchases as of right now (DECISIONS D-047). Not
  /// re-read mid-round: a purchase made from character-select before this
  /// round started is reflected; the shop itself is unreachable mid-round.
  final MetaProgression meta;

  /// [character]'s base `StatBlock` plus whatever's been bought in the
  /// Upgrades shop — STR/VIT/DEX/INT purchases there are +1 attribute point
  /// per level on `StatBlock`'s own integer scale (DECISIONS D-047), so
  /// they flow through every derived-stat formula in `core/stats.dart` for
  /// free. Read this everywhere combat code used to read `character.stats`
  /// directly (CLAUDE.md §4.3 — still the one place these get combined).
  StatBlock get effectiveStats => StatBlock(
        str: character.stats.str + meta.bonusStr,
        vit: character.stats.vit + meta.bonusVit,
        dex: character.stats.dex + meta.bonusDex,
        intellect: character.stats.intellect + meta.bonusIntellect,
      );

  /// Captured once at arena entry (device notch / gesture-bar insets).
  /// The app is portrait-locked, so this doesn't need to track rotation.
  /// Currently unused — was only ever consumed by the safe-area clamp D-040
  /// removed. Kept (not deleted) since HUD elements placed in `camera.
  /// viewport` may want it for real notch-avoidance later.
  final EdgeInsets systemInsets;

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
  late SpriteAnimation _animaAnimation;
  late Map<BossAnim, SpriteAnimation> _bossAnimations;
  late List<SpriteAnimation> _gemAnimations; // indexed by ItemRarity
  late List<SpriteAnimation> _potionAnimations; // indexed by ItemRarity
  final Random _random = Random();

  /// The Aura skill's orbiting-ring component (DECISIONS D-027) — null
  /// until the first Aura pick, created once and left in place afterwards;
  /// later picks just raise the stack count it reads each tick.
  AuraComponent? _aura;

  /// The boss (DECISIONS D-042) — null when not currently fought. At most
  /// one alive at a time; a spawn queued while one is already up
  /// (`_pendingBossSpawns`) waits for [onBossKilled] instead of stacking a
  /// second one.
  BossComponent? _boss;
  static const _bossSpawnLevels = [3, 6, 9];
  static const _bossSpawnMarginFactor = 0.15; // same as Spawner's enemy ring
  int _nextBossSpawnIndex = 0;
  int _pendingBossSpawns = 0;
  int _bossSpawnsCreated = 0;

  /// Everything a player attack can hit (DECISIONS D-042) — grunts plus the
  /// boss, if one is currently up. Every attack's hit-detection loop reads
  /// this instead of [enemies] directly.
  List<Damageable> get damageableTargets => [
        ...enemies,
        ?_boss,
      ];

  // Economy (DECISIONS D-043) -- resets every round like everything else.
  int gemsCollected = 0;
  int coinsEarned = 0;
  int potionCount = 0;

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
  SpriteAnimation get sparkleAnimation => _sparkleAnimation;

  /// Exposed for [BossComponent] (DECISIONS D-042) the same way the above
  /// are for the playable kits.
  SpriteAnimation get animaAnimation => _animaAnimation;

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

  /// All gameplay content (floor, player, enemies, projectiles, VFX) lives
  /// in `world`, never added directly to the game (DECISIONS D-040 —
  /// superseded D-007's fixed camera/world-equals-screen assumption).
  /// `camera` follows the player through it (`resetRound`) instead of the
  /// old safe-area clamp keeping the player inside a fixed rect.
  void addToWorld(Component c) => world.add(c);

  /// Screen-fixed HUD (HP bar, FPS counter) — added to the camera's
  /// viewport instead of `world`, so it never scrolls with the camera.
  void addToHud(Component c) => camera.viewport.add(c);

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
    // Looping (DECISIONS D-036): the Skirmisher's cast sparkle is now an
    // always-on visual for the whole round, not a one-shot per cast, so it
    // needs to keep animating indefinitely rather than freeze on its last
    // frame.
    _sparkleAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_sparkles-constelation.png',
      cellWidth: 309,
      cellHeight: 313,
      stepTime: 0.008,
      frameCount: 60,
      amountPerRow: 9,
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
    // The boss's teleport flourish (DECISIONS D-042) -- plays once at both
    // the departure and arrival points.
    _animaAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_anima.png',
      cellWidth: 429,
      cellHeight: 437,
      stepTime: 0.02,
      frameCount: 60,
      amountPerRow: 9,
      loop: false,
    );
    // The boss (DECISIONS D-042) -- one 4-cols x 8-rows sheet holding
    // idle/walk/fire/death back to back, in that reading order (not one
    // image per state like every character sheet before it). Frame ranges
    // found by inspecting the sheet's actual non-blank cells: idle is 6
    // frames (rows 0-1), walk 3 (row 2), fire 5 (rows 3-4), death 10
    // (rows 5-7).
    const bossCellWidth = 256.0;
    const bossCellHeight = 192.0;
    _bossAnimations = {
      BossAnim.idle: await loadSheetAnimation(
        'characters/enemies/boss_map1.png',
        cellWidth: bossCellWidth,
        cellHeight: bossCellHeight,
        stepTime: 0.15,
        frameCount: 6,
        amountPerRow: 4,
      ),
      BossAnim.walk: await loadSheetAnimation(
        'characters/enemies/boss_map1.png',
        cellWidth: bossCellWidth,
        cellHeight: bossCellHeight,
        stepTime: 0.12,
        frameCount: 3,
        // No amountPerRow here (unlike the other 3 slices) -- walk fits
        // entirely within row 2, so there's no next row to wrap onto, and
        // Flame's own SpriteAnimationData asserts amount >= amountPerRow
        // when it's given (3 frames can't satisfy amountPerRow: 4).
        // texturePosition alone is enough to select the row.
        texturePosition: Vector2(0, 2 * bossCellHeight),
      ),
      BossAnim.fire: await loadSheetAnimation(
        'characters/enemies/boss_map1.png',
        cellWidth: bossCellWidth,
        cellHeight: bossCellHeight,
        stepTime: 0.08,
        frameCount: 5,
        amountPerRow: 4,
        texturePosition: Vector2(0, 3 * bossCellHeight),
        loop: false,
      ),
      BossAnim.death: await loadSheetAnimation(
        'characters/enemies/boss_map1.png',
        cellWidth: bossCellWidth,
        cellHeight: bossCellHeight,
        stepTime: 0.15,
        frameCount: 10,
        amountPerRow: 4,
        texturePosition: Vector2(0, 5 * bossCellHeight),
        loop: false,
      ),
    };
    // Gems/potions (DECISIONS D-043) -- 5 rarity tiers, left to right, each
    // its own vertical animation strip (loadColumnAnimation, not the
    // row-major loadSheetAnimation every other sheet uses).
    _gemAnimations = [
      for (var tier = 0; tier < ItemRarity.values.length; tier++)
        await loadColumnAnimation(
          'consumables/gems.png',
          cellSize: 16,
          column: tier,
          rows: 9,
          stepTime: 0.1,
        ),
    ];
    _potionAnimations = [
      for (var tier = 0; tier < ItemRarity.values.length; tier++)
        await loadColumnAnimation(
          'consumables/potions.png',
          cellSize: 16,
          column: tier,
          rows: 8,
          stepTime: 0.12,
        ),
    ];
    resetRound();
  }

  /// Never carry state across rounds via globals/singletons (CLAUDE.md
  /// §4.5) — this rebuilds the round from a clean slate every time.
  void resetRound() {
    roundOver.value = false;
    input.clear();
    // `world`/`camera` themselves are permanent (FlameGame owns them for
    // its whole lifetime) -- only their *contents* reset every round.
    // Clearing `children` directly (the old D-007-era code) would also
    // try to remove `world`/`camera` themselves.
    world.removeAll(world.children.toList());
    camera.viewport.removeAll(camera.viewport.children.toList());
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
    _boss = null;
    _nextBossSpawnIndex = 0;
    _pendingBossSpawns = 0;
    _bossSpawnsCreated = 0;
    gemsCollected = 0;
    coinsEarned = 0;
    potionCount = 0;

    addToWorld(ArenaFloor());
    player = PlayerComponent(
      character: character,
      stats: effectiveStats,
      input: input,
      animations: _animations,
      // `ArenaFloor` still only tiles the original size.x/size.y patch
      // (endless floor tiling is a separate follow-up, DECISIONS D-040) --
      // spawning dead center of that patch, same as the old fixed-camera
      // layout, means the round doesn't open with the floor's edge already
      // visible.
    )..position = size / 2;
    addToWorld(player);
    // snap: true -- jump straight to the player, don't pan in from wherever
    // the (recycled) camera/viewfinder happened to be left after last round.
    camera.follow(player, snap: true);
    // Hook for any persistent per-kit visual/setup that isn't tied to a
    // single perform() call (DECISIONS D-036) -- SpiralFireAttack's
    // always-on cast sparkle is the only override so far. Default no-op,
    // called here rather than branched on `character.id` (CLAUDE.md §4.12:
    // character-specific behavior is a strategy object, not an `if` in
    // ArenaGame).
    character.attackBehavior.onEquipped(this);
    addToHud(HpBarComponent());
    addToWorld(Spawner());
    addToWorld(PotionSpawner());

    if (settings.showFps) {
      // Below the HP bar (top-left, 24,24 + 14 tall) so they don't overlap.
      addToHud(FpsTextComponent(position: Vector2(24, 46)));
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
      _fireCooldown = character.attackBehavior.cooldownSeconds(effectiveStats);
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
      // player is level 5 by the time it dies. Corruption (D-047) layers on
      // top of the level scaling, not instead of it.
      statMultiplier:
          enemyStatMultiplier(level) * corruptionEnemyStatMultiplier(meta.corruptionLevel),
    );
    enemies.add(enemy);
    addToWorld(enemy);

    // Elite marker (DECISIONS D-035/D-036) -- visual only, no stat change. A
    // separate top-level sibling rather than a child of `enemy`: a
    // component's own children render on top of it (Flame renders self then
    // children) regardless of the child's own priority, so a child could
    // never be tucked *behind* `enemy` -- irrelevant now since D-036 wants
    // it on top anyway, but it's still a sibling (not a child) so its
    // `enemyOverlay` priority is actually respected against other
    // top-level components. Fades out (not a hard cut) the instant the
    // enemy starts dying, rather than staying at full brightness through
    // the whole death animation and then vanishing on removal.
    if (rollIsElite(_random)) {
      final width = enemy.size.x; // never wider than the enemy, per the ask
      addToWorld(
        TrackingSpriteEffect(
          target: enemy,
          offset: Vector2(0, enemy.size.y * 0.3), // toward the feet, not center
          animation: _eliteFireAnimation,
          size: Vector2(width, width * kEliteFireAspect),
          priority: ArenaPriority.enemyOverlay,
          removeOnFinish: false, // persists for the enemy's whole lifetime
          fadeOutWhen: () => enemy.isDying,
          fadeOutDurationSec: kEliteFireFadeOutSec,
        ),
      );
    }
  }

  void onEnemyKilled(EnemyComponent enemy) {
    final deathPosition = enemy.position.clone();
    enemies.remove(enemy);
    enemy.removeFromParent();
    kills++;
    grantXp(kXpPerKill);

    // Economy (DECISIONS D-043) -- gems drop in the world, coins are a
    // silent running total shown only at round-over.
    if (rollGemDrop(_random, level)) {
      final rarity = rollRarity(_random);
      addToWorld(
        GemComponent(
          startPosition: deathPosition,
          rarity: rarity,
          animation: _gemAnimations[rarity.index],
        ),
      );
    }
    coinsEarned += _rollCoins();
  }

  /// A single coin roll, scaled by Corruption's reward bonus (DECISIONS
  /// D-047) — shared by grunt and boss kills so the multiplier can't drift
  /// between the two call sites.
  int _rollCoins() {
    return (rollCoinValue(_random) * corruptionRewardMultiplier(meta.corruptionLevel))
        .round();
  }

  /// The boss (DECISIONS D-042) — same shape as [onEnemyKilled] but no gem
  /// drop (not designed yet what a boss should drop beyond currency/XP) and
  /// a flat bonus on both the coins and XP it grants, since it's meant to
  /// feel like a real milestone.
  void onBossKilled(BossComponent boss) {
    boss.removeFromParent();
    _boss = null;
    kills++;
    grantXp(kBossXpReward);
    coinsEarned += _rollCoins() * kBossCoinMultiplier;
    _maybeSpawnBoss(); // in case another spawn was queued while this one was up
  }

  /// Silently removes an enemy that's fallen too far behind the player to
  /// ever catch up (DECISIONS D-041, `Spawner._cullStragglers`) — no kill
  /// count, no XP, unlike [onEnemyKilled]. Any of the enemy's own
  /// components that key off it leaving the tree (e.g. an elite's
  /// `TrackingSpriteEffect` fire glow) clean themselves up the same way
  /// they would on a normal death.
  void cullEnemy(EnemyComponent enemy) {
    enemies.remove(enemy);
    enemy.removeFromParent();
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
      _checkBossSpawnThreshold();
    }
    _maybeShowNextLevelUp();
  }

  /// Debug-only: grants a level (and its popup) for free, no XP required.
  /// The popup itself is deferred by `_maybeShowNextLevelUp`'s Pause Menu
  /// guard below until the menu actually closes (developer's spec).
  void debugGrantLevelUp() {
    level++;
    _pendingLevelUps++;
    _checkBossSpawnThreshold();
    _maybeShowNextLevelUp();
  }

  /// The boss spawns at levels 3/6/9 (DECISIONS D-042), "right when you
  /// level up" — checked every time [level] actually increases (both real
  /// XP and the debug grant), not just once, so a jump across more than one
  /// threshold in a single call (e.g. debug-granting several levels at
  /// once) queues all of them rather than only the first.
  void _checkBossSpawnThreshold() {
    while (_nextBossSpawnIndex < _bossSpawnLevels.length &&
        level >= _bossSpawnLevels[_nextBossSpawnIndex]) {
      _pendingBossSpawns++;
      _nextBossSpawnIndex++;
    }
    _maybeSpawnBoss();
  }

  /// Only one boss at a time — a spawn queued while one is already up waits
  /// here until [onBossKilled] calls this again, rather than stacking a
  /// second one.
  void _maybeSpawnBoss() {
    if (_boss != null || _pendingBossSpawns <= 0) return;
    _pendingBossSpawns--;
    final spawnPoint = randomPerimeterPoint(
      _random,
      camera.visibleWorldRect,
      marginFactor: _bossSpawnMarginFactor,
    );
    final boss = BossComponent(
      startPosition: spawnPoint,
      animations: _bossAnimations,
      statMultiplier: bossStatMultiplier(_bossSpawnsCreated),
    );
    _bossSpawnsCreated++;
    _boss = boss;
    addToWorld(boss);
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
    addToWorld(_aura!);
  }

  void onEnemyContact(EnemyComponent enemy) {
    player.takeDamage(enemy.contactDamage);
  }

  void onProjectileHit(Vector2 at, double damage) {
    damageDealt += damage;
    addToWorld(
      SpriteAnimationComponent(
        animation: _sparkAnimation,
        position: at,
        size: Vector2.all(16 * kProjectileRenderScale),
        anchor: Anchor.center,
        removeOnFinish: true,
        priority: ArenaPriority.hitEffects,
      ),
    );
    addToWorld(DamageTextComponent(position: at.clone(), amount: damage));
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
    addToWorld(
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
    // DECISIONS D-044: "when we kill boss, when any explosion effect is
    // played" -- one hook covers both, since a boss kill also calls this.
    _playSfx('core/sfx-explosion.wav');
  }

  /// DECISIONS D-043 — called by [GemComponent] when the player walks close
  /// enough to one.
  void collectGem(ItemRarity rarity) {
    gemsCollected++;
  }

  /// DECISIONS D-043 — called by [PotionComponent] when the player walks
  /// close enough to one. "We will add more logic later" per the developer
  /// — a flat heal by tier is the whole mechanic for now.
  void collectPotion(ItemRarity rarity) {
    potionCount--;
    player.heal(potionHealAmount(rarity));
  }

  /// Called by [PotionSpawner] on its own timer.
  void spawnPotion(Vector2 at) {
    final rarity = rollRarity(_random);
    potionCount++;
    addToWorld(
      PotionComponent(
        startPosition: at,
        rarity: rarity,
        animation: _potionAnimations[rarity.index],
      ),
    );
  }

  /// One-shot SFX at a volume derived from the player's own SFX slider
  /// (`Settings.sfxVolume`, 0-100), capped low regardless — "make sure they
  /// are not that loud" (DECISIONS D-044).
  void _playSfx(String file) {
    final volume = (settings.sfxVolume / 100) * kSfxVolumeCap;
    if (volume <= 0) return;
    FlameAudio.play(file, volume: volume);
  }

  /// PRD §6.5: freeze after the death frame, then show Round Over. Debug
  /// stand-in `debugDie()` shares this same path -- but skips the SFX
  /// (`_roundEndDelay == null` guards it to once), since a debug kill isn't
  /// a real death.
  void onPlayerDied() {
    if (_roundEndDelay == null) _playSfx('core/sfx-you-died.wav');
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
    // The round's coin haul crosses over into the persistent Upgrades-shop
    // wallet exactly once, here (DECISIONS D-047) — `coinsEarned` itself
    // stays the round-scoped display value the RoundOver overlay reads,
    // untouched by this. Fire-and-forget: nothing on screen is waiting on
    // this write landing.
    unawaited(MetaProgressionRepository().addCoins(coinsEarned));
  }
}
