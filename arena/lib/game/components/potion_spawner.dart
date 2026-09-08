import 'dart:math';

import 'package:flame/components.dart';

import '../arena_game.dart';

/// Periodically drops a potion at a random point around the player
/// (DECISIONS D-043 — "spawn randomly on the map"), not tied to kills the
/// way gems/coins are. A random point within a rect around the camera's
/// current view, not just its perimeter (unlike `Spawner`'s enemy ring) —
/// potions are meant to be seen and walked toward, not to appear off-screen
/// like a threat.
class PotionSpawner extends Component with HasGameReference<ArenaGame> {
  static const _intervalSec = 15.0;
  static const _spawnAreaFactor = 1.5; // x the visible view's width/height
  static const _maxLivePotions = 5;

  double _timeUntilNextSpawn = _intervalSec;
  final Random _random = Random();

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.player.isAlive) return;

    _timeUntilNextSpawn -= dt;
    if (_timeUntilNextSpawn <= 0) {
      _timeUntilNextSpawn = _intervalSec;
      if (game.potionCount < _maxLivePotions) {
        game.spawnPotion(_randomPointNearby());
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
