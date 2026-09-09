import 'dart:math';

import 'package:flame/components.dart';

import '../arena_game.dart';

/// Periodically drops a chest at a random point around the player
/// (DECISIONS D-055 — "spawn randomly on the map," same brief as potions,
/// D-043) — rarer and capped lower than potions, since a chest is a bigger
/// payout. Same random-point-in-a-rect-around-the-view shape as
/// `PotionSpawner` (chests are meant to be seen and walked toward, not to
/// appear off-screen like a threat).
class ChestSpawner extends Component with HasGameReference<ArenaGame> {
  static const _intervalSec = 40.0;
  static const _spawnAreaFactor = 1.5; // x the visible view's width/height
  static const _maxLiveChests = 2;

  double _timeUntilNextSpawn = _intervalSec;
  final Random _random = Random();

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.player.isAlive) return;

    _timeUntilNextSpawn -= dt;
    if (_timeUntilNextSpawn <= 0) {
      _timeUntilNextSpawn = _intervalSec;
      if (game.chestCount < _maxLiveChests) {
        game.spawnChest(_randomPointNearby());
      }
    }
  }

  Vector2 _randomPointNearby() {
    final visible = game.camera.visibleWorldRect;
    final halfW = visible.width * _spawnAreaFactor / 2;
    final halfH = visible.height * _spawnAreaFactor / 2;
    return Vector2(
      visible.center.dx + (_random.nextDouble() * 2 - 1) * halfW,
      visible.center.dy + (_random.nextDouble() * 2 - 1) * halfH,
    );
  }
}
