import 'dart:async' show unawaited;
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/widgets.dart' show EdgeInsets;

import '../core/constants.dart';
import '../core/economy.dart';
import '../core/game_config.dart';
import '../core/game_rules.dart';
import '../core/meta_progression.dart';
import '../core/progression.dart';
import '../core/settings.dart';
import '../core/sfx_player.dart';
import '../core/shop.dart';
import '../core/stats.dart';
import '../data/characters.dart';
import 'anim/enemy_animations.dart' show EnemySkin;
import 'components/arena_floor.dart';
import 'components/aura.dart';
import 'components/boss.dart';
import 'components/chest.dart';
import 'components/chest_spawner.dart';
import 'components/damageable.dart';
import 'components/damage_text.dart';
import 'components/defence_crystal.dart';
import 'components/enemy.dart';
import 'components/gem.dart';
import 'components/hp_bar.dart';
import 'components/mirror.dart';
import 'components/player.dart';
import 'components/potion.dart';
import 'components/potion_spawner.dart';
import 'components/ray_beam.dart';
import 'components/spawner.dart';
import 'components/torch.dart';
import 'components/torch_spawner.dart';
import 'components/tracking_effect.dart';
import 'components/vase.dart';
import 'components/vase_spawner.dart';
import 'components/xp_bar.dart';
import 'game_assets.dart';
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

  /// This round's own character's Character Upgrades level for [stat]
  /// (DECISIONS D-003: every dial is per-character now, not just
  /// STR/VIT/DEX/INT) — a thin `meta.levelOfFor(character.id, stat)`
  /// shortcut so every call site (here and every component with a `game`
  /// reference) doesn't repeat `character.id` itself.
  int metaLevel(MetaStat stat) => meta.levelOfFor(character.id, stat);

  /// [character]'s base `StatBlock` plus whatever's been bought for *this*
  /// character in Character Upgrades — STR/VIT/DEX/INT purchases there are
  /// +1 attribute point per level on `StatBlock`'s own integer scale
  /// (DECISIONS D-047), so they flow through every derived-stat formula in
  /// `core/stats.dart` for free. Per-character, not global (DECISIONS
  /// D-003) — `meta.levelsFor(character.id)` is a different character's own
  /// bonus for a different `character.id`. Read this everywhere combat code
  /// used to read `character.stats` directly (CLAUDE.md §4.3 — still the
  /// one place these get combined).
  StatBlock get effectiveStats {
    final levels = meta.levelsFor(character.id);
    return StatBlock(
      str: character.stats.str + levels.str,
      vit: character.stats.vit + levels.vit,
      dex: character.stats.dex + levels.dex,
      intellect: character.stats.intellect + levels.intellect,
    );
  }

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

  /// World objects (DECISIONS D-002) — populated/culled by
  /// [TorchSpawner]/[VaseSpawner], read every frame by `PlayerComponent`/
  /// `EnemyComponent`'s own collision resolution ([torches] only; vases
  /// aren't solid) and by both spawners' own minimum-spacing checks.
  final List<TorchComponent> torches = [];
  final List<VaseComponent> vases = [];

  /// Every loaded `SpriteAnimation`/`Sprite` (DECISIONS D-045/D-048) — was
  /// ~20 separate fields plus the whole loading block inline in `onLoad()`
  /// before the split into `game_assets.dart`. The getters below (
  /// [boltAnimation] etc.) delegate here so no other file had to change.
  late GameAssets gameAssets;
  final Random _random = Random();

  /// The Aura skill's orbiting-ring component (DECISIONS D-027) — null
  /// until the first Aura pick, created once and left in place afterwards;
  /// later picks just raise the stack count it reads each tick.
  AuraComponent? _aura;

  /// The Ultimate Mirror skill (DECISIONS D-049) — one turret per stack,
  /// spawned as picks come in (`_syncMirrors`), never removed/rebuilt.
  final List<MirrorComponent> _mirrors = [];

  /// Projectile Ray / Projectile Thunder (DECISIONS D-049) — second and
  /// third independently-cooling attacks, same "sync once on first pick,
  /// read the current stack count live every trigger" pattern as Aura
  /// above, just with a bare timer instead of a live Flame component (there
  /// being nothing to render between triggers).
  bool _rayActive = false;
  double _rayCooldownTimer = 0;
  bool _thunderActive = false;
  double _thunderCooldownTimer = 0;

  /// Defence Crystal (DECISIONS D-049) — single-pick, so unlike [_mirrors]
  /// this is just one nullable component, same shape as [_aura].
  DefenceCrystalComponent? _defenceCrystal;

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
  List<Damageable> get damageableTargets => [...enemies, ?_boss];

  // Economy (DECISIONS D-043) -- resets every round like everything else.
  int gemsCollected = 0;
  int coinsEarned = 0;
  int potionCount = 0;

  /// Chests (DECISIONS D-055) -- same "how many currently live" cap pattern
  /// as [potionCount].
  int chestCount = 0;

  // Achievements (DECISIONS D-091) -- round-scoped counts distinct from
  // [potionCount]/[chestCount] above (those track "how many are live in the
  // world right now," net of spawns *and* collects/opens, not a cumulative
  // "how many did the player actually get this round"). Credited into
  // `MetaProgression`'s matching lifetime totals at round-over
  // (`_persistRoundRewards`), same as `kills`/[coinsEarned]/[gemsCollected].
  int bossesKilledThisRound = 0;
  int chestsOpenedThisRound = 0;
  int potionsCollectedThisRound = 0;

  /// The most recently opened chest's reward card, shown by the ChestReveal
  /// overlay (`ArenaScreen`) until [closeChestReveal] is called — `null`
  /// when nothing is pending. Deferred behind [_maybeShowChestReveal]'s
  /// gate the same way a level-up is (DECISIONS D-025's `_pendingLevelUps`
  /// pattern), so a chest that finishes opening while the Pause Menu or a
  /// level-up popup is already showing doesn't fight it for the screen.
  /// Holds the already-rolled [ChestCard] (DECISIONS D-057) — the overlay's
  /// spin animation is cosmetic flicker leading up to this, not a live roll,
  /// so the result has to exist before the spin ever starts.
  ChestCard? _pendingChestCard;
  ChestCard? get pendingChestCard => _pendingChestCard;

  /// Exposed for [AttackBehavior]s (`attack_behavior.dart`) to build
  /// projectiles from — the animation itself isn't per-character yet, but
  /// the behavior that fires it is (DECISIONS D-024).
  SpriteAnimation get boltAnimation => gameAssets.boltAnimation;

  /// Exposed for [KnifeAttack] (DECISIONS D-029) the same way [boltAnimation]
  /// is for [ProjectileAttack] — the Bruiser's knife swaps between these two
  /// static sprites itself once it draws blood.
  Sprite get knifeCleanSprite => gameAssets.knifeCleanSprite;
  Sprite get knifeBloodySprite => gameAssets.knifeBloodySprite;

  /// Exposed for [SpiralFireAttack] (DECISIONS D-034) the same way
  /// [boltAnimation]/[knifeCleanSprite] are for the other kits.
  SpriteAnimation get pixelFireAnimation => gameAssets.pixelFireAnimation;
  SpriteAnimation get sparkleAnimation => gameAssets.sparkleAnimation;

  /// Exposed for [BossComponent] (DECISIONS D-042) the same way the above
  /// are for the playable kits.
  SpriteAnimation get animaAnimation => gameAssets.animaAnimation;

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

  /// Exposed for `XpBarComponent` (DECISIONS D-076) — `_xpToNextLevel`
  /// itself stays private (round state `ArenaGame` owns, CLAUDE.md §4.5);
  /// this is just the ratio the HUD actually needs to draw the fill.
  double get xpFraction =>
      _xpToNextLevel <= 0 ? 0 : (xp / _xpToNextLevel).clamp(0.0, 1.0);

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

  /// True only via a real death (`onPlayerDied`), never `debugDie()` —
  /// gates the death SFX in `_endRound` (DECISIONS D-054).
  bool _realDeath = false;

  /// SHOP's Second Wind item (DECISIONS D-069) — "survive one lethal hit
  /// *per round*," so unlike [MetaProgression.ownsSecondWind] (a permanent,
  /// forever-owned flag) this is round state, reset every `resetRound` like
  /// everything else (CLAUDE.md §4.5).
  bool _reviveUsedThisRound = false;

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
    gameAssets = await GameAssets.load(character);
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
    torches.clear(); // the components themselves went with removeAll above
    vases.clear();
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
    _realDeath = false;
    _reviveUsedThisRound = false;

    level = 1;
    xp = 0;
    _xpToNextLevel = xpThresholdForLevel(1);
    upgrades.reset();
    currentLevelUpChoices = const [];
    _pendingLevelUps = 0;
    debugGodMode = false;
    menuOpen.value = false;
    _aura = null; // the old instance was already removed via removeAll above
    _mirrors.clear(); // ditto -- the components themselves went with removeAll
    _rayActive = false;
    _rayCooldownTimer = 0;
    _thunderActive = false;
    _thunderCooldownTimer = 0;
    _defenceCrystal = null;
    _boss = null;
    _nextBossSpawnIndex = 0;
    _pendingBossSpawns = 0;
    _bossSpawnsCreated = 0;
    gemsCollected = 0;
    coinsEarned = 0;
    potionCount = 0;
    chestCount = 0;
    bossesKilledThisRound = 0; // DECISIONS D-091
    chestsOpenedThisRound = 0;
    potionsCollectedThisRound = 0;
    _pendingChestCard = null;

    addToWorld(ArenaFloor());
    player = PlayerComponent(
      character: character,
      stats: effectiveStats,
      input: input,
      animations: gameAssets.characterAnimations,
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
    // DECISIONS D-091: stacked directly under the HP bar now, both full
    // width at the top -- was its own bottom-of-screen box (D-076).
    addToHud(XpBarComponent());
    addToWorld(Spawner());
    addToWorld(PotionSpawner());
    addToWorld(ChestSpawner());
    addToWorld(TorchSpawner());
    addToWorld(VaseSpawner());

    if (settings.showFps) {
      // Below both top bars (DECISIONS D-091 stacked them: top margin +
      // 2 bars + the gap between them) so they don't overlap either one.
      addToHud(
        FpsTextComponent(
          position: Vector2(
            kHudBarSideMarginPx,
            kHudBarTopMarginPx + kHudBarHeightPx * 2 + kHudBarGapPx * 2,
          ),
        ),
      );
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
      // Haste (DECISIONS D-067) shrinks the base attack's own cooldown only
      // -- it doesn't reach into every skill's independent timer (aura
      // ticks, ray/thunder cooldowns), same deliberately narrow scope as
      // Corruption only ever touching spawn/enemy-stat/reward, not
      // everything in the round.
      _fireCooldown =
          character.attackBehavior.cooldownSeconds(effectiveStats) /
          hasteAttackSpeedMultiplier(metaLevel(MetaStat.haste)) /
          meta.attackSpeedMultiplierFromShop;
      character.attackBehavior.perform(this);
    }

    // Projectile Ray / Projectile Thunder (DECISIONS D-049) -- second and
    // third independently-cooling attacks, ticked here the same way
    // character.attackBehavior's cooldown is above, gated on _rayActive/
    // _thunderActive so an un-picked skill costs nothing but two bool checks.
    if (_rayActive) {
      _rayCooldownTimer -= dt;
      if (_rayCooldownTimer <= 0) {
        final stacks = upgrades.pickCounts[UpgradeKind.projectileRay] ?? 1;
        _rayCooldownTimer = UpgradeAmounts.rayCooldownSec(stacks);
        _fireRayBeam(stacks);
      }
    }
    if (_thunderActive) {
      _thunderCooldownTimer -= dt;
      if (_thunderCooldownTimer <= 0) {
        final stacks = upgrades.pickCounts[UpgradeKind.projectileThunder] ?? 1;
        _thunderCooldownTimer = UpgradeAmounts.thunderCooldownSec(stacks);
        _strikeThunder(stacks);
      }
    }
  }

  void spawnEnemy(Vector2 at) {
    final skin = EnemySkin.values[_random.nextInt(EnemySkin.values.length)];
    final enemy = EnemyComponent(
      startPosition: at,
      runAnimation: gameAssets.enemyAnimations.runFor(skin),
      deathAnimation: gameAssets.enemyAnimations.deathFor(skin),
      // DECISIONS D-026: baked in at spawn, not re-applied later — an
      // enemy that spawned at level 3 keeps level-3 stats even if the
      // player is level 5 by the time it dies. Corruption (D-047) layers on
      // top of the level scaling, not instead of it.
      statMultiplier:
          enemyStatMultiplier(level) *
          corruptionEnemyStatMultiplier(metaLevel(MetaStat.corruption)),
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
    if (rollIsElite(
      _random,
      chanceMultiplier: meta.eliteChanceMultiplierFromShop,
    )) {
      final width = enemy.size.x; // never wider than the enemy, per the ask
      addToWorld(
        TrackingSpriteEffect(
          target: enemy,
          offset: Vector2(0, enemy.size.y * 0.3), // toward the feet, not center
          animation: gameAssets.eliteFireAnimation,
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
    // silent running total shown only at round-over. LUCK's dial and SHOP's
    // Gem Hoarder (DECISIONS D-069/D-070) both layer an extra flat bonus
    // onto the same drop-chance curve.
    if (rollGemDrop(
      _random,
      level,
      // DECISIONS D-090: GameConfig.gemDropChanceBonus layers on the same
      // additive axis LUCK/SHOP already use, not a separate multiplier.
      bonusChance: luckGemDropBonus(metaLevel(MetaStat.luck)) +
          meta.gemDropBonusFromShop +
          GameConfig.instance.gemDropChanceBonus,
    )) {
      final rarity = rollRarity(_random);
      addToWorld(
        GemComponent(
          startPosition: deathPosition,
          rarity: rarity,
          animation: gameAssets.gemAnimations[rarity.index],
        ),
      );
    }
    coinsEarned += _rollCoins();
    // Vampiric Touch (DECISIONS D-070) -- a no-op `heal(0)` when unowned,
    // same "bonus getter reads 0/neutral when not bought" shape every other
    // SHOP hook uses.
    player.heal(meta.vampiricHealPerKillFromShop);
  }

  /// A single coin roll, scaled by Corruption's, Fortune's, and SHOP's
  /// Golden Touch reward bonuses (DECISIONS D-047/D-067/D-070) — shared by
  /// grunt and boss kills so the multipliers can't drift between the two
  /// call sites.
  int _rollCoins() {
    return (rollCoinValue(_random) *
            corruptionRewardMultiplier(metaLevel(MetaStat.corruption)) *
            fortuneRewardMultiplier(metaLevel(MetaStat.fortune)) *
            meta.coinMultiplierFromShop *
            // DECISIONS D-090: developer-editable tuning knob, same axis as
            // the multipliers above.
            GameConfig.instance.coinValueMultiplier)
        .round();
  }

  /// The boss (DECISIONS D-042) — same shape as [onEnemyKilled] plus a flat
  /// bonus on both the coins and XP it grants, since it's meant to feel
  /// like a real milestone. No regular gem drop of its own (Boss Hunter's
  /// flat exception below aside) — DECISIONS D-079 gives it a real-world
  /// milestone reward instead: a chest, always, right where it died.
  void onBossKilled(BossComponent boss) {
    final deathPosition = boss.position.clone();
    boss.removeFromParent();
    _boss = null;
    kills++;
    bossesKilledThisRound++; // DECISIONS D-091
    grantXp(kBossXpReward);
    coinsEarned += _rollCoins() * kBossCoinMultiplier;
    spawnChest(deathPosition); // DECISIONS D-079: "make boss drop a chest"
    // Boss Hunter (DECISIONS D-070) -- bosses otherwise drop no gems at all
    // (see the class doc's own note on that gap); this is the one flat
    // exception, gated on owning the item rather than a rarity roll.
    if (meta.ownsBossHunter) {
      gemsCollected += kBossHunterGemReward;
    }
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
    // Scholar's Insight (DECISIONS D-070) -- a flat multiplier on top,
    // neutral (1.0) until bought.
    xp += amount * meta.xpMultiplierFromShop;
    while (xp >= _xpToNextLevel) {
      xp -= _xpToNextLevel;
      level++;
      _xpToNextLevel = xpThresholdForLevel(level);
      _pendingLevelUps++;
      SfxPlayer.instance.playLevelUp(); // DECISIONS D-076
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
    SfxPlayer.instance.playLevelUp(); // DECISIONS D-076
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
      animations: gameAssets.bossAnimations,
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
    _syncMirrors();
    _syncRay();
    _syncThunder();
    _syncDefenceCrystal();
    _pendingLevelUps--;
    overlays.remove('LevelUp');
    _afterMenuClosed();
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
    _afterMenuClosed();
  }

  /// Shared by every overlay-close path above (DECISIONS D-055 generalized
  /// this from level-up-only to also cover the ChestReveal popup): pending
  /// level-ups take priority, then a pending chest reveal, and only once
  /// neither has anything queued does the round actually resume. Each of
  /// [_maybeShowNextLevelUp]/[_maybeShowChestReveal] is a no-op if it has
  /// nothing pending, so falling through all three checks here is exactly
  /// "nothing left to show."
  void _afterMenuClosed() {
    if (_pendingLevelUps > 0) {
      _maybeShowNextLevelUp();
      return;
    }
    if (_pendingChestCard != null) {
      _maybeShowChestReveal();
      return;
    }
    menuOpen.value = false;
    resumeEngine();
  }

  /// Spawns the Aura's ring component on the first pick (DECISIONS D-027).
  /// Later picks don't rebuild it -- `AuraComponent` reads the current
  /// stack count off `upgrades.pickCounts` itself every tick, so bumping
  /// the count is all a second/third pick needs to do.
  void _syncAura() {
    if (_aura != null) return;
    if ((upgrades.pickCounts[UpgradeKind.aura] ?? 0) <= 0) return;
    _aura = AuraComponent(shieldAnimation: gameAssets.auraShieldAnimation);
    addToWorld(_aura!);
  }

  /// Ultimate Mirror (DECISIONS D-049) — adds mirrors up to the current
  /// stack count, never removes any (a stack count can't go down mid-round).
  /// Each new mirror spawns somewhere the player can currently see
  /// (`randomVisiblePoint`, `core/game_rules.dart`) rather than off-screen
  /// like an enemy — the developer's literal "mirrors spawn only on screen
  /// where player can see."
  void _syncMirrors() {
    final stacks = (upgrades.pickCounts[UpgradeKind.ultimateMirror] ?? 0).clamp(
      0,
      UpgradeAmounts.mirrorMaxStacks,
    );
    while (_mirrors.length < stacks) {
      final mirror = MirrorComponent(
        startPosition: randomVisiblePoint(_random, camera.visibleWorldRect),
        animation: gameAssets.mirrorAnimation,
        // DECISIONS D-059 ("spawn not in sync, by 0.5 seconds delay"): each
        // new mirror's cycle starts half a second further behind the
        // previous one, by spawn order.
        staggerDelaySec: _mirrors.length * UpgradeAmounts.mirrorStaggerDelaySec,
      );
      _mirrors.add(mirror);
      addToWorld(mirror);
    }
  }

  /// Projectile Ray (DECISIONS D-049) — starts the timer on the first pick
  /// only; later picks just raise the stack count [update] reads on the
  /// next trigger, same "sync once, read live" shape as [_syncAura].
  void _syncRay() {
    if (_rayActive) return;
    if ((upgrades.pickCounts[UpgradeKind.projectileRay] ?? 0) <= 0) return;
    _rayActive = true;
    _rayCooldownTimer = UpgradeAmounts.rayCooldownSec(1);
  }

  /// A piercing beam along the line to the nearest target in range — every
  /// target [alongLineWithinRange] finds gets hit, not just the nearest one
  /// (DECISIONS D-049 — "pierces"). No-ops if nothing is in range, same as
  /// every other attack's targeting no-op.
  void _fireRayBeam(int stacks) {
    final stats = effectiveStats;
    final maxRange = stats.attackRangePx * UpgradeAmounts.rayRangeMultiplier;

    final targets = damageableTargets;
    final positions = [for (final t in targets) t.position];
    final index = nearestWithinRange(player.position, positions, maxRange);
    if (index == -1) return;
    final direction = targets[index].position - player.position;
    if (direction.length2 == 0) return; // exactly on top of the target
    direction.normalize();

    final damage = UpgradeAmounts.rayDamage(stacks);
    for (final i in alongLineWithinRange(
      player.position,
      direction,
      positions,
      maxRange,
      UpgradeAmounts.rayHalfWidthPx,
    )) {
      final target = targets[i];
      if (target.isDying) continue;
      target.takeDamage(damage);
      onProjectileHit(target.position.clone(), damage);
    }
    addToWorld(
      RayBeamEffectComponent(
        origin: player.position.clone(),
        direction: direction,
        lengthPx: maxRange,
        animation: gameAssets.rayBeamAnimation,
      ),
    );
  }

  /// Projectile Thunder (DECISIONS D-049) — same sync-once shape as
  /// [_syncRay].
  void _syncThunder() {
    if (_thunderActive) return;
    if ((upgrades.pickCounts[UpgradeKind.projectileThunder] ?? 0) <= 0) return;
    _thunderActive = true;
    _thunderCooldownTimer = UpgradeAmounts.thunderCooldownSec(1);
  }

  /// Strikes [UpgradeAmounts.thunderTargetCount] random living targets
  /// (grunts or the boss) with a lightning-bolt VFX and damage. The VFX
  /// uses [spawnEffect]'s default `ArenaPriority.hitEffects` — above
  /// `ArenaPriority.enemy` — so it always reads on top of the enemy sprite,
  /// never behind it (the developer's explicit ask). `brightness: 1.2` is a
  /// 2026-09-09 tune (D-050, developer's call: "increase brightness by
  /// 20%") — size is `kThunderWidthPx` itself (D-050, also +40%).
  void _strikeThunder(int stacks) {
    final living = damageableTargets.where((t) => !t.isDying).toList()
      ..shuffle(_random);
    final count = UpgradeAmounts.thunderTargetCount(stacks)
        .clamp(0, living.length);
    if (count <= 0) return;
    final damage = UpgradeAmounts.thunderDamage(stacks);
    for (var i = 0; i < count; i++) {
      final target = living[i];
      target.takeDamage(damage);
      onProjectileHit(target.position.clone(), damage);
      spawnEffect(
        gameAssets.thunderAnimation,
        // Strikes down onto the target from just above it, rather than
        // dead-center through the body.
        target.position - Vector2(0, target.size.y * 0.4),
        size: Vector2(kThunderWidthPx, kThunderWidthPx * kThunderAspect),
        brightness: 1.2,
      );
    }
  }

  /// Defence Crystal (DECISIONS D-049) — single-pick, so this only ever
  /// spawns the one component; the actual resistance/regen bonus is applied
  /// directly to `upgrades` by `PlayerUpgrades.apply` (called from
  /// `player.grantUpgrade` just before this runs), not read live off a
  /// component the way the skills above are.
  void _syncDefenceCrystal() {
    if (_defenceCrystal != null) return;
    if ((upgrades.pickCounts[UpgradeKind.defenceCrystal] ?? 0) <= 0) return;
    _defenceCrystal = DefenceCrystalComponent(
      animation: gameAssets.defenceCrystalAnimation,
    );
    addToWorld(_defenceCrystal!);
  }

  void onEnemyContact(EnemyComponent enemy) {
    player.takeDamage(enemy.contactDamage);
  }

  /// Folds in every persistent per-hit damage modifier scoped to just the
  /// base auto-attack (DECISIONS D-069): SHOP's Sharp Edge multiplier, then
  /// a CRIT roll off the CRIT dial — same deliberately narrow "base attack
  /// only, not every skill" precedent Haste already set for attack speed
  /// (`hasteAttackSpeedMultiplier`'s own doc comment). Called by every
  /// `AttackBehavior` (`attack_behavior.dart`) right where it used to read
  /// `stats.damagePerHit + game.upgrades.bonusDamage` bare — Ray/Thunder/
  /// Aura/Mirror stay unaffected, same scope Haste already drew.
  double resolveAttackDamage(double baseDamage) {
    var damage = baseDamage * meta.damageMultiplierFromShop;
    // Battle Fury (DECISIONS D-070) -- conditional on the player's *current*
    // HP, so unlike every other shop bonus this can't be a bare getter on
    // `MetaProgression` (it has no access to a live player); checked here,
    // the one place `resolveAttackDamage` already has both `meta` and
    // `player`.
    if (meta.ownsItem(ShopItemId.battleFury) &&
        player.hp <= player.effectiveMaxHp * kBattleFuryHpThreshold) {
      damage *= kBattleFuryDamageMultiplier;
    }
    return rollCrit(damage);
  }

  double rollCrit(double damage) {
    return _random.nextDouble() < critChance(metaLevel(MetaStat.crit))
        ? damage * kCritDamageMultiplier
        : damage;
  }

  /// SHOP's Second Wind (DECISIONS D-069) — true only if the item is owned
  /// AND it hasn't already saved the player this round. Consuming it
  /// (`tryConsumeRevive`) is a separate step so `PlayerComponent.takeDamage`
  /// can check availability and act on the *same* answer atomically, rather
  /// than a check-then-act race against itself.
  bool get reviveAvailable =>
      meta.ownsSecondWind && !_reviveUsedThisRound;

  /// Called by `PlayerComponent.takeDamage` the instant a hit would
  /// otherwise be lethal. Returns whether the revive actually fired —
  /// `false` means take the death path as normal.
  bool tryConsumeRevive() {
    if (!reviveAvailable) return false;
    _reviveUsedThisRound = true;
    return true;
  }

  void onProjectileHit(Vector2 at, double damage) {
    damageDealt += damage;
    addToWorld(
      SpriteAnimationComponent(
        animation: gameAssets.sparkAnimation,
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
  /// D-033/D-034/D-035). [opacity] defaults to fully opaque. [brightness] is
  /// a multiply-up on every channel (1 = untouched, >1 brighter), added here
  /// for Projectile Thunder's own brightness tune (D-050). [contrast]
  /// (DECISIONS D-071) is the other half of `AuraComponent`'s own tuning
  /// knob (D-032) — a pull-toward-mid-grey (1 = untouched, <1 flatter) — now
  /// available to any one-shot VFX, the chest anima's own tune (D-071)
  /// being the first user beyond Aura's ring.
  void spawnEffect(
    SpriteAnimation animation,
    Vector2 at, {
    required Vector2 size,
    double opacity = 1,
    double brightness = 1,
    double contrast = 1,
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
          ..filterQuality = FilterQuality
              .none // D-011
          ..color = Color.fromRGBO(255, 255, 255, opacity)
          ..colorFilter = (brightness == 1 && contrast == 1)
              ? null
              : ColorFilter.matrix(_colorMatrix(contrast, brightness)),
      ),
    );
  }

  /// Combines a contrast pull-toward-grey and a flat brightness multiply
  /// into one matrix (alpha untouched, last row `0 0 0 1 0`) rather than
  /// chaining two `ColorFilter`s, which `Paint.colorFilter` can only hold
  /// one of at a time — the exact same formula `AuraComponent._colorMatrix`
  /// uses (DECISIONS D-032), generalized here so any [spawnEffect] caller
  /// can reach for either knob. `contrast == 1` collapses the translate term
  /// to 0, leaving a pure multiply — the old `_brightnessMatrix` this
  /// replaced was exactly this special case.
  static List<double> _colorMatrix(double contrast, double brightness) {
    final scale = contrast * brightness;
    final translate = (1 - contrast) * 255 / 2 * brightness;
    return [
      scale, 0, 0, 0, translate,
      0, scale, 0, 0, translate,
      0, 0, scale, 0, translate,
      0, 0, 0, 1, 0,
    ];
  }

  /// Player hit feedback (DECISIONS D-033) — a blood splat somewhere on the
  /// player's own body, a different spot each time so it doesn't read as a
  /// static decal. Called from `PlayerComponent.takeDamage` only when
  /// damage actually lands (not during i-frames/god mode).
  void spawnBloodImpact() {
    final width = player.size.x * kBloodImpactWidthFactor;
    final maxOffsetX = player.size.x * 0.3;
    final maxOffsetY = player.size.y * 0.3;
    final at =
        player.position +
        Vector2(
          (_random.nextDouble() * 2 - 1) * maxOffsetX,
          (_random.nextDouble() * 2 - 1) * maxOffsetY,
        );
    spawnEffect(
      gameAssets.bloodImpactAnimation,
      at,
      size: Vector2(width, width * kBloodImpactAspect),
    );
  }

  /// Non-lethal hit from the Skirmisher's Spiral Fire (DECISIONS D-034) —
  /// [spawnExplosionEffect] plays instead when that hit was the kill.
  void spawnImpactEffect(Vector2 at) {
    spawnEffect(
      gameAssets.impactAnimation,
      at,
      size: Vector2(
        kSpiralImpactWidthPx,
        kSpiralImpactWidthPx * kSpiralImpactAspect,
      ),
    );
  }

  void spawnExplosionEffect(Vector2 at) {
    spawnEffect(
      gameAssets.explosionAnimation,
      at,
      size: Vector2(
        kSpiralExplosionWidthPx,
        kSpiralExplosionWidthPx * kSpiralExplosionAspect,
      ),
    );
    // DECISIONS D-044: "when we kill boss, when any explosion effect is
    // played" -- one hook covers both, since a boss kill also calls this.
    // D-081-style pooled playback (SfxPlayer), not a raw FlameAudio.play --
    // this fires often enough (every spiral-fire kill, every chest, every
    // boss death) that the old unpooled path leaked exactly like the other
    // one-shots D-079/D-081 fixed.
    SfxPlayer.instance.playExplosion();
  }

  /// DECISIONS D-043 — called by [GemComponent] when the player walks close
  /// enough to one.
  void collectGem(ItemRarity rarity) {
    gemsCollected++;
    SfxPlayer.instance.playPickup(); // DECISIONS D-091
  }

  /// DECISIONS D-043 — called by [PotionComponent] when the player walks
  /// close enough to one. "We will add more logic later" per the developer
  /// — a flat heal by tier is the whole mechanic for now.
  void collectPotion(ItemRarity rarity) {
    potionCount--;
    potionsCollectedThisRound++; // DECISIONS D-091
    // Potion Master (DECISIONS D-070) -- neutral (1.0) until bought.
    player.heal(potionHealAmount(rarity) * meta.potionHealMultiplierFromShop);
    SfxPlayer.instance.playPickup(); // DECISIONS D-091
  }

  /// Called by [PotionSpawner] on its own timer.
  void spawnPotion(Vector2 at) {
    final rarity = rollRarity(_random);
    potionCount++;
    addToWorld(
      PotionComponent(
        startPosition: at,
        rarity: rarity,
        animation: gameAssets.potionAnimations[rarity.index],
      ),
    );
  }

  /// Called by [ChestSpawner] on its own timer.
  void spawnChest(Vector2 at) {
    chestCount++;
    addToWorld(
      ChestComponent(
        startPosition: at,
        idleAnimation: gameAssets.chestIdleAnimation,
      ),
    );
  }

  /// Called by [TorchSpawner] on its own timer.
  void spawnTorch(Vector2 at) {
    final torch = TorchComponent(
      startPosition: at,
      animation: gameAssets.torchAnimation,
    );
    torches.add(torch);
    addToWorld(torch);
  }

  /// Called by [TorchSpawner]'s own straggler cull, same "fallen too far
  /// behind the roaming camera to ever matter again" reasoning as
  /// [cullEnemy] (torches don't chase, but the world is unbounded, so one
  /// left behind is otherwise never removed).
  void cullTorch(TorchComponent torch) {
    torches.remove(torch);
    torch.removeFromParent();
  }

  /// Called by [VaseSpawner] on its own timer.
  void spawnVase(Vector2 at) {
    final vase = VaseComponent(
      startPosition: at,
      animation: gameAssets.vaseAnimation,
    );
    vases.add(vase);
    addToWorld(vase);
  }

  /// Called by [VaseComponent] the instant the player walks into it
  /// (DECISIONS D-002). Removes the vase and scatters a random
  /// [GameConfig.vaseGemsMin]-[GameConfig.vaseGemsMax] burst of gems
  /// alternating left/right of where it stood — "gems fly out of the vase
  /// left and right," the developer's literal spec — rather than a fully
  /// random scatter that could occasionally land every gem on one side.
  void breakVase(VaseComponent vase) {
    vases.remove(vase);
    vase.removeFromParent();

    final minGems = GameConfig.instance.vaseGemsMin;
    final maxGems = GameConfig.instance.vaseGemsMax;
    final gemCount = minGems + _random.nextInt(max(1, maxGems - minGems + 1));
    for (var i = 0; i < gemCount; i++) {
      final rarity = rollRarity(_random);
      final side = i.isEven ? -1.0 : 1.0;
      final offsetX = side *
          (kVaseGemScatterMinPx +
              _random.nextDouble() *
                  (kVaseGemScatterMaxPx - kVaseGemScatterMinPx));
      final offsetY = (_random.nextDouble() * 2 - 1) * kVaseGemScatterVerticalPx;
      addToWorld(
        GemComponent(
          startPosition: vase.position + Vector2(offsetX, offsetY),
          rarity: rarity,
          animation: gameAssets.gemAnimations[rarity.index],
        ),
      );
    }
  }

  /// The vase's "card chosen" burst (DECISIONS D-002) — see
  /// `kCardChosenBurstCount`'s own doc comment (constants.dart) for why
  /// this reuses [GameAssets.cardChosenBurstAnimation] rather than the
  /// chest-reveal overlay's own Flutter-widget sparkle burst.
  void spawnCardChosenBurst(Vector2 at) {
    for (var i = 0; i < kCardChosenBurstCount; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final distance = kCardChosenBurstMinDistancePx +
          _random.nextDouble() *
              (kCardChosenBurstMaxDistancePx - kCardChosenBurstMinDistancePx);
      spawnEffect(
        gameAssets.cardChosenBurstAnimation,
        at + Vector2(cos(angle), sin(angle)) * distance,
        size: Vector2.all(kCardChosenBurstSparkleSizePx),
      );
    }
  }

  /// Called by [ChestComponent] once its opening sequence finishes
  /// (DECISIONS D-057, superseding D-055's flat gem-group reward). The
  /// card's `gemReward` folds into the same round-scoped [gemsCollected]
  /// Round Over already shows (chests and enemy drops aren't tracked
  /// separately); the reveal popup itself is deferred behind
  /// [_maybeShowChestReveal]'s gate, same as a level-up's, so it can't pop
  /// up on top of the Pause Menu or Level Up.
  void onChestOpened(ChestCard card) {
    // Treasure Hunter (DECISIONS D-070) -- neutral (1.0) until bought.
    gemsCollected += (card.gemReward * meta.chestGemMultiplierFromShop).round();
    chestCount--;
    chestsOpenedThisRound++; // DECISIONS D-091
    _pendingChestCard = card;
    _maybeShowChestReveal();
  }

  void _maybeShowChestReveal() {
    if (roundOver.value || _pendingChestCard == null) return;
    if (overlays.isActive('PauseMenu') ||
        overlays.isActive('LevelUp') ||
        overlays.isActive('ChestReveal')) {
      return;
    }
    overlays.add('ChestReveal');
    menuOpen.value = true;
    pauseEngine();
  }

  /// Called by the ChestReveal overlay's own dismiss button.
  void closeChestReveal() {
    overlays.remove('ChestReveal');
    _pendingChestCard = null;
    _afterMenuClosed();
  }

  /// PRD §6.5: freeze after the death frame, then show Round Over. Debug
  /// stand-in `debugDie()` shares this same path -- but never sets
  /// [_realDeath], since a debug kill isn't a real death and shouldn't play
  /// the death SFX.
  void onPlayerDied() {
    _realDeath = true;
    _roundEndDelay ??= _roundEndDelaySec;
  }

  /// Debug-only stand-in for HP <= 0 (PRD §3: the arena's only real exit is
  /// death) — jumps straight to round end without waiting on a death anim,
  /// since the player box hasn't necessarily taken lethal damage. Also the
  /// implementation behind [debugEndRound] below — both are "skip straight
  /// to Round Over," just reachable from two different debug surfaces.
  void debugDie() {
    if (roundOver.value || _roundEndDelay != null) return;
    _roundEndDelay = 0;
  }

  /// Debug-only "end round now" button (Settings' debug section, reachable
  /// from the Pause Menu — developer's ask: a dedicated end-round control,
  /// separate from the always-on-screen DIE button, that's easy to verify
  /// carries the round's actual kills/score/coins/gems through). Same exact
  /// path as [debugDie] — `_roundEndDelay = 0` is read by [update] the next
  /// tick and calls [_endRound], which unconditionally banks
  /// `coinsEarned`/`gemsCollected`/`kills` into the persistent wallet
  /// (DECISIONS D-047/D-055) regardless of how the round ended — so nothing
  /// extra is needed here to make those numbers carry over correctly.
  /// Called while the engine is still paused (Settings is reached from the
  /// Pause Menu without resuming first) — that's fine, [update] just won't
  /// run (and so [_endRound] won't fire) until the player backs out to
  /// Resume/closes the pause menu, same "queued, plays out once the menu
  /// closes" shape [debugGrantLevelUp] already uses for its own popup.
  void debugEndRound() => debugDie();

  void _endRound() {
    roundOver.value = true;
    overlays.add('RoundOver');
    pauseEngine();
    // DECISIONS D-054: fires here, once the dark Round Over overlay is
    // actually up -- was firing the instant HP hit 0 (`onPlayerDied`,
    // still under the death animation, well before the overlay appears).
    // `debugDie()` never sets `_realDeath`, so a debug kill still stays
    // silent.
    if (_realDeath) {
      SfxPlayer.instance.playPlayerDeath();
    }
    // The round's coin/gem haul, kill count, and every other lifetime
    // achievement stat cross over into the persistent wallet exactly once,
    // here (DECISIONS D-047/D-055/D-091) — `coinsEarned`/`gemsCollected`/
    // `kills` themselves stay the round-scoped display values Round Over
    // reads, untouched by this. Fire-and-forget from the caller's side:
    // nothing on screen is waiting on this write landing. DECISIONS D-089:
    // this used to be 3 separate concurrent `addX` calls, each its own
    // load-modify-save cycle against `SharedPreferences` — racing meant
    // whichever `save()` landed last clobbered the other two fields back to
    // their pre-round values (reported: "coins and gems not saved... only
    // kills"). `recordRoundEnd` (DECISIONS D-091) replaced that with one
    // load, every field updated in memory, one save — not just sequential
    // awaits anymore, genuinely atomic.
    unawaited(_persistRoundRewards());
  }

  Future<void> _persistRoundRewards() async {
    await MetaProgressionRepository().recordRoundEnd(
      coins: coinsEarned,
      gems: gemsCollected,
      kills: kills,
      bossKills: bossesKilledThisRound,
      chestsOpened: chestsOpenedThisRound,
      potionsCollected: potionsCollectedThisRound,
      levelReached: level,
      survivalTimeSec: elapsed,
    );
  }
}
