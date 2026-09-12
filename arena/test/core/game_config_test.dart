import 'package:flutter_test/flutter_test.dart';

import 'package:arena/core/game_config.dart';

// DECISIONS D-090: real regression coverage for the actual shipped
// `assets/config/game_config.json`, not just the fallback defaults baked
// into `GameConfig` itself -- `TestWidgetsFlutterBinding` gives `flutter
// test` a real asset bundle, so `GameConfig.instance.load()` here reads the
// genuine file exactly like the app does at boot, catching a typo'd key
// name or a malformed edit that would otherwise silently fall back to
// defaults and go unnoticed until someone wonders why their edit did
// nothing on-device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameConfig', () {
    test('loads the real asset and every getter matches its shipped value', () async {
      await GameConfig.instance.load();
      final config = GameConfig.instance;

      expect(config.coinValueMultiplier, 1.0);
      expect(config.gemDropChanceBonus, 0.0);
      expect(config.bossCoinMultiplier, 10);

      expect(config.spawnStartingIntervalSec, 1.5);
      expect(config.spawnMinIntervalSec, 0.25);
      expect(config.spawnDecayFactor, 0.96);
      expect(config.maxLiveEnemies, 60);
      expect(config.enemyMaxHp, 20);
      expect(config.enemyMoveSpeedPxPerS, 70);
      expect(config.enemyContactDamage, 8);
      expect(config.enemyStatScalePerLevel, 0.12);
      expect(config.eliteChance, 0.15);
      expect(config.bossMaxHp, 400);
      expect(config.bossContactDamage, 15);
      expect(config.bossBoltDamage, 12);

      expect(config.characterStat('apprentice', 'str', -1), 4);
      expect(config.characterStat('apprentice', 'intellect', -1), 7);
      expect(config.characterStat('bruiser', 'str', -1), 8);
      expect(config.characterStat('skirmisher', 'dex', -1), 9);
      expect(config.characterStat('warden', 'vit', -1), 9);

      expect(config.xpPerKill, 10);
      expect(config.baseXpToNextLevel, 150);
      expect(config.xpGrowthFactor, 1.3);

      expect(config.startingSfxVolume, 70);
      expect(config.startingMusicVolume, 50);
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
