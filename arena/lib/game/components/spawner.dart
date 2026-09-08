import 'dart:math';

import 'package:flame/components.dart';

import '../../core/game_rules.dart';
import '../arena_game.dart';

/// Off-screen perimeter spawning (PRD §6.4): starts at 1.5s/enemy, interval
/// shrinks 4% every 10s, floored at 0.25s, hard cap of 60 live enemies.
/// These are spawn-cadence numbers, not combat numbers — kept here rather
/// than `core/stats.dart` (CLAUDE.md §4.3 is about damage/speed/HP values).
///
/// [_randomPerimeterPoint] still spawns around the world-origin rect
/// (`0..game.size`), a leftover of D-007's fixed camera — same known,
/// not-yet-built follow-up as `ArenaFloor`'s tiling (DECISIONS D-040):
/// once the player wanders away from the start, enemies keep spawning back
/// at the original spot instead of around the player. Re-centering this on
/// the player's current position is the next piece of the camera work, not
/// done here.
class Spawner extends Component with HasGameReference<ArenaGame> {
  static const _startingIntervalSec = 1.5;
  static const _minIntervalSec = 0.25;
  static const _decayEvery = 10.0;
  static const _decayFactor = 0.96;
  static const _maxLiveEnemies = 60;
  static const _spawnMarginPx = 64.0;

  double _interval = _startingIntervalSec;
  double _timeUntilNextSpawn = _startingIntervalSec;
  double _timeUntilNextDecay = _decayEvery;

  final Random _random = Random();

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.player.isAlive) return;

    _timeUntilNextDecay -= dt;
    if (_timeUntilNextDecay <= 0) {
      _timeUntilNextDecay += _decayEvery;
      _interval = nextSpawnInterval(
        _interval,
        factor: _decayFactor,
        floor: _minIntervalSec,
      );
    }

    _timeUntilNextSpawn -= dt;
    if (_timeUntilNextSpawn <= 0) {
      _timeUntilNextSpawn = _interval;
      if (game.enemies.length < _maxLiveEnemies) {
        game.spawnEnemy(_randomPerimeterPoint());
      }
    }
  }

  Vector2 _randomPerimeterPoint() {
    final size = game.size;
    final side = _random.nextInt(4);
    switch (side) {
      case 0: // top
        return Vector2(_random.nextDouble() * size.x, -_spawnMarginPx);
      case 1: // bottom
        return Vector2(
          _random.nextDouble() * size.x,
          size.y + _spawnMarginPx,
        );
      case 2: // left
        return Vector2(-_spawnMarginPx, _random.nextDouble() * size.y);
      default: // right
        return Vector2(
          size.x + _spawnMarginPx,
          _random.nextDouble() * size.y,
        );
    }
  }
}
