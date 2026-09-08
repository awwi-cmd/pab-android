import 'dart:math';

import 'package:flame/components.dart';

import '../../core/game_rules.dart';
import '../arena_game.dart';
import 'enemy.dart';

/// Off-screen perimeter spawning (PRD §6.4): starts at 1.5s/enemy, interval
/// shrinks 4% every 10s, floored at 0.25s, hard cap of 60 live enemies.
/// These are spawn-cadence numbers, not combat numbers — kept here rather
/// than `core/stats.dart` (CLAUDE.md §4.3 is about damage/speed/HP values).
///
/// [_randomPerimeterPoint] is centered on the camera's current view
/// (DECISIONS D-041, Phase 9.4 — closes the D-040 gap), not a fixed rect at
/// the world origin: spawns land just outside whatever the player can
/// currently see, by [_visibleMarginFactor], so nothing pops in on-screen
/// but nothing spawns so far out it's irrelevant either. [_cullStragglers]
/// is the other half of the same fix — enemies move slower than every
/// playable character (`EnemyStats.moveSpeedPxPerS` 70 vs. 120+ for the
/// player), so in an unbounded world one that spawns behind a player who
/// then moves away in roughly one direction can fall behind forever; left
/// unculled, those never die and permanently eat into [_maxLiveEnemies],
/// which is exactly what caused spawning to visibly stop entirely far from
/// the start (developer-reported bug, not a hypothetical).
class Spawner extends Component with HasGameReference<ArenaGame> {
  static const _startingIntervalSec = 1.5;
  static const _minIntervalSec = 0.25;
  static const _decayEvery = 10.0;
  static const _decayFactor = 0.96;
  static const _maxLiveEnemies = 60;

  /// How far outside the visible view a spawn point sits, as a fraction of
  /// that view's own width/height — developer's ask: "outside the player's
  /// see area, maybe 15% further, just in case the player moves toward it."
  static const _visibleMarginFactor = 0.15;

  /// How often [_cullStragglers] scans the live enemy list — cheap (at
  /// most `_maxLiveEnemies` items) so this doesn't need to be every frame.
  static const _cullCheckIntervalSec = 1.0;

  /// An enemy further than this multiple of the visible view's larger
  /// dimension from the player is considered unreachable, not just
  /// "currently behind" — generous on purpose, well beyond the spawn
  /// margin above, so normal chasing is never mistaken for straggling.
  static const _cullDistanceFactor = 3.0;

  double _interval = _startingIntervalSec;
  double _timeUntilNextSpawn = _startingIntervalSec;
  double _timeUntilNextDecay = _decayEvery;
  double _timeUntilNextCullCheck = _cullCheckIntervalSec;

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

    _timeUntilNextCullCheck -= dt;
    if (_timeUntilNextCullCheck <= 0) {
      _timeUntilNextCullCheck = _cullCheckIntervalSec;
      _cullStragglers();
    }
  }

  Vector2 _randomPerimeterPoint() {
    final visible = game.camera.visibleWorldRect;
    final marginX = visible.width * _visibleMarginFactor;
    final marginY = visible.height * _visibleMarginFactor;
    final left = visible.left - marginX;
    final right = visible.right + marginX;
    final top = visible.top - marginY;
    final bottom = visible.bottom + marginY;

    final side = _random.nextInt(4);
    switch (side) {
      case 0: // top
        return Vector2(left + _random.nextDouble() * (right - left), top);
      case 1: // bottom
        return Vector2(left + _random.nextDouble() * (right - left), bottom);
      case 2: // left
        return Vector2(left, top + _random.nextDouble() * (bottom - top));
      default: // right
        return Vector2(right, top + _random.nextDouble() * (bottom - top));
    }
  }

  void _cullStragglers() {
    final visible = game.camera.visibleWorldRect;
    final cullDistance =
        max(visible.width, visible.height) * _cullDistanceFactor;
    final playerPosition = game.player.position;
    for (final enemy in List<EnemyComponent>.of(game.enemies)) {
      if (enemy.isDying) continue; // let a real death animation finish
      if (enemy.position.distanceTo(playerPosition) > cullDistance) {
        game.cullEnemy(enemy);
      }
    }
  }
}
