import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Developer-editable tuning knobs, external to the Dart source (DECISIONS
/// D-090) — edit `assets/config/game_config.json` *before* building the APK
/// to influence economy/AI-spawn/AI-damage/character/progression/starting-
/// audio numbers without touching code. `main()` awaits [load] before
/// `runApp`, so every getter below is already backed by the file's values
/// from the very first frame — nothing that reads this needs to handle an
/// async gap or a "config not loaded yet" state.
///
/// Every getter has a hardcoded fallback that matches the shipped JSON's own
/// defaults exactly, so a missing file, a missing section/key (a partial
/// edit), or a malformed file degrades to "identical to the numbers this
/// project already shipped with" rather than crashing at boot — [load]
/// itself never throws past its own `try`/`catch`.
///
/// This is a process-wide singleton, same "outlives any one screen" shape
/// `BgmController`/`SfxPlayer` already use (`core/bgm_controller.dart`,
/// `core/sfx_player.dart`) — loaded once, read everywhere, never rewritten
/// at runtime (this is a *build-time* tuning file, not a live settings
/// screen).
class GameConfig {
  GameConfig._();
  static final GameConfig instance = GameConfig._();

  static const _assetPath = 'assets/config/game_config.json';

  Map<String, dynamic> _json = const {};

  /// Reads and parses [_assetPath]. Safe to call more than once (a hot
  /// restart in dev, say) — always re-reads, never throws.
  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw);
      _json = decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      // Missing/malformed file -- every getter below has its own hardcoded
      // fallback, so this is silently safe, not a crash.
      _json = const {};
    }
  }

  Map<String, dynamic> _section(String name) =>
      (_json[name] as Map<String, dynamic>?) ?? const {};

  double _d(String section, String key, double fallback) {
    final value = _section(section)[key];
    return value is num ? value.toDouble() : fallback;
  }

  int _i(String section, String key, int fallback) {
    final value = _section(section)[key];
    return value is num ? value.toInt() : fallback;
  }

  // ---- economy (core/economy.dart, ArenaGame._rollCoins/onEnemyKilled) ----

  /// Multiplies every coin roll (`rollCoinValue`'s own rarity table is left
  /// untouched — this scales the *result*, same shape Corruption/Fortune/
  /// SHOP's own reward multipliers already use in `ArenaGame._rollCoins`).
  double get coinValueMultiplier => _d('economy', 'coinValueMultiplier', 1.0);

  /// Added straight onto the gem-drop-chance roll, same `bonusChance`
  /// parameter LUCK's dial and SHOP's Gem Hoarder already feed
  /// (`ArenaGame.onEnemyKilled`) — a flat probability bump, not a
  /// multiplier, matching how those two already work.
  double get gemDropChanceBonus => _d('economy', 'gemDropChanceBonus', 0.0);

  /// Flat multiplier applied to a boss kill's coin haul on top of the
  /// normal per-kill roll (`core/economy.dart`'s old `kBossCoinMultiplier`).
  int get bossCoinMultiplier => _i('economy', 'bossCoinMultiplier', 10);

  // ---- enemyAI (game/components/spawner.dart, core/stats.dart, core/game_rules.dart) ----

  /// Seconds between spawns at round start (`Spawner`).
  double get spawnStartingIntervalSec =>
      _d('enemyAI', 'spawnStartingIntervalSec', 1.5);

  /// The spawn interval never decays below this (`Spawner`).
  double get spawnMinIntervalSec => _d('enemyAI', 'spawnMinIntervalSec', 0.25);

  /// Multiplies the spawn interval every decay tick (`Spawner`, every 10s).
  double get spawnDecayFactor => _d('enemyAI', 'spawnDecayFactor', 0.96);

  /// Hard cap on live enemies at once (`Spawner`).
  int get maxLiveEnemies => _i('enemyAI', 'maxLiveEnemies', 60);

  /// A grunt's base HP at player level 1 (`EnemyStats.maxHp`).
  double get enemyMaxHp => _d('enemyAI', 'enemyMaxHp', 20);

  /// A grunt's move speed (`EnemyStats.moveSpeedPxPerS`).
  double get enemyMoveSpeedPxPerS =>
      _d('enemyAI', 'enemyMoveSpeedPxPerS', 70);

  /// A grunt's base contact damage at player level 1
  /// (`EnemyStats.contactDamage`).
  double get enemyContactDamage => _d('enemyAI', 'enemyContactDamage', 8);

  /// How much tougher/harder-hitting enemies get per player level
  /// (`core/game_rules.dart`'s old `kEnemyScalePerLevel`, DECISIONS D-026).
  double get enemyStatScalePerLevel =>
      _d('enemyAI', 'enemyStatScalePerLevel', 0.12);

  /// Chance a spawned grunt rolls "elite" (`core/game_rules.dart`'s old
  /// `kEliteChance`, DECISIONS D-035).
  double get eliteChance => _d('enemyAI', 'eliteChance', 0.15);

  /// The boss's HP (`BossStats.maxHp`).
  double get bossMaxHp => _d('enemyAI', 'bossMaxHp', 400);

  /// The boss's contact damage (`BossStats.contactDamage`).
  double get bossContactDamage => _d('enemyAI', 'bossContactDamage', 15);

  /// Damage per bolt from the boss's ranged attack (`BossStats.boltDamage`).
  double get bossBoltDamage => _d('enemyAI', 'bossBoltDamage', 12);

  // ---- characters (data/characters.dart) ----

  /// One base stat (`'str'`/`'vit'`/`'dex'`/`'intellect'`) for a
  /// `CharacterDef.id`, e.g. `characterStat('apprentice', 'intellect', 7)`.
  /// [fallback] is the character's shipped baseline, passed in by
  /// `kCharacters` itself rather than duplicated here — there are 4
  /// characters x 4 stats, not worth 16 more named getters.
  double characterStat(String characterId, String statKey, double fallback) {
    final character = _section('characters')[characterId];
    if (character is Map<String, dynamic>) {
      final value = character[statKey];
      if (value is num) return value.toDouble();
    }
    return fallback;
  }

  // ---- progression (core/progression.dart) ----

  /// XP granted per regular kill (`core/progression.dart`'s old
  /// `kXpPerKill`).
  double get xpPerKill => _d('progression', 'xpPerKill', 10);

  /// XP needed to clear level 1→2; every level after multiplies by
  /// [xpGrowthFactor] (`core/progression.dart`'s old `kBaseXpToNextLevel`).
  double get baseXpToNextLevel => _d('progression', 'baseXpToNextLevel', 150);

  /// Per-level XP curve growth (`core/progression.dart`'s old
  /// `kXpGrowthFactor`).
  double get xpGrowthFactor => _d('progression', 'xpGrowthFactor', 1.3);

  // ---- audio (core/settings.dart's Settings.defaults) ----

  /// SFX Volume (0-100) a fresh install starts at — only matters until the
  /// player ever touches the slider themselves (`SettingsRepository` only
  /// falls back to `Settings.defaults` when nothing's been saved yet).
  int get startingSfxVolume => _i('audio', 'startingSfxVolume', 70);

  /// Music Volume (0-100) a fresh install starts at — same caveat as
  /// [startingSfxVolume].
  int get startingMusicVolume => _i('audio', 'startingMusicVolume', 50);

  // ---- worldObjects (game/components/torch_spawner.dart, vase_spawner.dart) ----

  /// Max standing torches live at once (`TorchSpawner`). Lowered from 6 to
  /// 4 (DECISIONS D-009, "spawn less torches") now that a torch is a real
  /// limited-use heal, not just scenery — fewer make each one feel like a
  /// find, not clutter.
  int get torchCount => _i('worldObjects', 'torchCount', 4);

  /// Minimum distance between two torches — a candidate spawn point closer
  /// than this to an already-live torch is rejected and retried
  /// (`TorchSpawner`).
  double get torchMinSpacingPx => _d('worldObjects', 'torchMinSpacingPx', 220);

  /// A torch heals the player (only the player — DECISIONS D-009, "give
  /// them functionality so that standing in an area near them gives ONLY
  /// the player... hp regen") while they're within this radius of it —
  /// deliberately wider than `kTorchCollisionRadiusPx` (the solid-obstacle
  /// push-out radius), so it's already in range the instant the player
  /// walks up and rests against it, not a separate closer approach
  /// (`TorchComponent`).
  double get torchHealRadiusPx => _d('worldObjects', 'torchHealRadiusPx', 50);

  /// Flat HP/sec while the player is in range — same additive-heal shape
  /// `PlayerComponent.heal` already uses for potions, just continuous
  /// instead of a one-shot.
  double get torchHealPerSec => _d('worldObjects', 'torchHealPerSec', 8);

  /// Total cumulative seconds the player can spend in range before the
  /// torch is used up (`TorchComponent`, "player stays near, consumes and
  /// then torch disappears") — counts time in range, not HP actually
  /// healed, so it still runs out even if the player's already at full HP
  /// and camps next to it.
  double get torchConsumeDurationSec =>
      _d('worldObjects', 'torchConsumeDurationSec', 5);

  /// Max gem vases live at once (`VaseSpawner`).
  int get vaseCount => _i('worldObjects', 'vaseCount', 4);

  /// Minimum distance between two vases, same rejection shape as
  /// [torchMinSpacingPx] (`VaseSpawner`).
  double get vaseMinSpacingPx => _d('worldObjects', 'vaseMinSpacingPx', 260);

  /// A broken vase drops a random gem count in `[vaseGemsMin, vaseGemsMax]`
  /// (`ArenaGame.breakVase`).
  int get vaseGemsMin => _i('worldObjects', 'vaseGemsMin', 3);
  int get vaseGemsMax => _i('worldObjects', 'vaseGemsMax', 6);
}
