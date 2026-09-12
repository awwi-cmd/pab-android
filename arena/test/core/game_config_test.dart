import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:arena/core/game_config.dart';

// DECISIONS D-090/D-091: real regression coverage for the actual shipped
// `assets/config/game_config.json`, not just the fallback defaults baked
// into `GameConfig` itself -- `TestWidgetsFlutterBinding` gives `flutter
// test` a real asset bundle, so `GameConfig.instance.load()` here reads the
// genuine file exactly like the app does at boot.
//
// D-091: this used to assert hardcoded literal values ("the shipped
// defaults") -- the whole point of this file is that the developer edits
// it freely to tune the game, so pinning specific numbers here broke the
// very first time it actually got tuned (xpPerKill/startingSfxVolume/
// startingMusicVolume all changed on-device, and this test failed on a
// change that was working exactly as designed). Rewritten to compare each
// `GameConfig` getter against the *same file*, parsed independently right
// here -- this only fails if `GameConfig`'s own parsing/wiring breaks, not
// every time someone tunes a number, which is what "config the developer
// edits before every build" actually needs from its test coverage.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameConfig', () {
    late Map<String, dynamic> raw;

    setUpAll(() async {
      final text = await rootBundle.loadString(
        'assets/config/game_config.json',
      );
      raw = jsonDecode(text) as Map<String, dynamic>;
    });

    num economy(String key) => (raw['economy'] as Map<String, dynamic>)[key] as num;
    num enemyAI(String key) => (raw['enemyAI'] as Map<String, dynamic>)[key] as num;
    num character(String id, String key) =>
        ((raw['characters'] as Map<String, dynamic>)[id]
            as Map<String, dynamic>)[key] as num;
    num progression(String key) =>
        (raw['progression'] as Map<String, dynamic>)[key] as num;
    num audio(String key) => (raw['audio'] as Map<String, dynamic>)[key] as num;

    test('every getter matches the real file it just parsed', () async {
      await GameConfig.instance.load();
      final config = GameConfig.instance;

      expect(config.coinValueMultiplier, economy('coinValueMultiplier'));
      expect(config.gemDropChanceBonus, economy('gemDropChanceBonus'));
      expect(config.bossCoinMultiplier, economy('bossCoinMultiplier').toInt());

      expect(
        config.spawnStartingIntervalSec,
        enemyAI('spawnStartingIntervalSec'),
      );
      expect(config.spawnMinIntervalSec, enemyAI('spawnMinIntervalSec'));
      expect(config.spawnDecayFactor, enemyAI('spawnDecayFactor'));
      expect(config.maxLiveEnemies, enemyAI('maxLiveEnemies').toInt());
      expect(config.enemyMaxHp, enemyAI('enemyMaxHp'));
      expect(config.enemyMoveSpeedPxPerS, enemyAI('enemyMoveSpeedPxPerS'));
      expect(config.enemyContactDamage, enemyAI('enemyContactDamage'));
      expect(
        config.enemyStatScalePerLevel,
        enemyAI('enemyStatScalePerLevel'),
      );
      expect(config.eliteChance, enemyAI('eliteChance'));
      expect(config.bossMaxHp, enemyAI('bossMaxHp'));
      expect(config.bossContactDamage, enemyAI('bossContactDamage'));
      expect(config.bossBoltDamage, enemyAI('bossBoltDamage'));

      for (final id in ['apprentice', 'bruiser', 'skirmisher', 'warden']) {
        for (final stat in ['str', 'vit', 'dex', 'intellect']) {
          expect(
            config.characterStat(id, stat, -1),
            character(id, stat),
            reason: '$id.$stat',
          );
        }
      }

      expect(config.xpPerKill, progression('xpPerKill'));
      expect(config.baseXpToNextLevel, progression('baseXpToNextLevel'));
      expect(config.xpGrowthFactor, progression('xpGrowthFactor'));

      expect(config.startingSfxVolume, audio('startingSfxVolume').toInt());
      expect(
        config.startingMusicVolume,
        audio('startingMusicVolume').toInt(),
      );
    });

    test('an unknown character/stat falls back to the given default', () async {
      await GameConfig.instance.load();
      expect(
        GameConfig.instance.characterStat('nobody', 'str', 99),
        99,
      );
      expect(
        GameConfig.instance.characterStat('apprentice', 'nonsense', 42),
        42,
      );
    });

    // "Falls back safely when never loaded" isn't re-tested here on its own
    // -- `GameConfig.instance` is a true process-wide singleton, so by this
    // point in the file it's already loaded from the tests above and there's
    // no reset hook to undo that. That property is already covered for real
    // by every *other* test file in this suite (progression_test.dart,
    // stats_test.dart, economy_test.dart, characters_test.dart) — none of
    // them ever call `GameConfig.instance.load()`, and all of them pass,
    // which is exactly "unloaded config still returns sane defaults" in
    // practice, not just in theory.
  });
}
