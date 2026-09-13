import 'dart:math';

import 'package:flame/components.dart';

import '../../core/game_config.dart';
import '../../core/game_rules.dart';
import '../arena_game.dart';

/// Scatters standing torches around the roaming world (DECISIONS D-002 —
/// "add it randomly through the map, not too close to each other, have
/// player & enemy collision"). Same camera-relative "random point in a rect
/// around the visible view" shape `PotionSpawner`/`ChestSpawner` already
/// use, plus a minimum-spacing rejection against every already-live torch
/// (`farEnoughFrom`, a few retries, no costlier than one extra distance
/// check per attempt) and the same straggler cull `Spawner` uses for
/// enemies — torches never move, so nothing here "falls behind" on its own,
/// but the roaming camera can still leave one arbitrarily far off in an
/// unbounded world, and this project has no bounded rect to just stop
/// spawning past, so distance-culling is the only way the live count ever
/// comes back down again.
class TorchSpawner extends Component with HasGameReference<ArenaGame> {
  static int get _maxLiveTorches => GameConfig.instance.torchCount;
  static double get _minSpacingPx => GameConfig.instance.torchMinSpacingPx;

  static const _intervalSec = 8.0;
  static const _spawnAreaFactor = 1.5; // x the visible view's width/height
  static const _maxPlacementAttempts = 10;
  static const _cullCheckIntervalSec = 2.0;
  static const _cullDistanceFactor = 3.0; // same as Spawner's enemy cull

  // Starts at 0, not `_intervalSec` (unlike PotionSpawner/ChestSpawner) --
  // torches are ambient scenery, not a drip-fed reward, so the map should
  // already look populated the instant a round starts rather than opening
  // empty for the first several seconds.
  double _timeUntilNextSpawn = 0;
  double _timeUntilNextCullCheck = _cullCheckIntervalSec;
  final Random _random = Random();

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.player.isAlive) return;

    _timeUntilNextSpawn -= dt;
    if (_timeUntilNextSpawn <= 0) {
      _timeUntilNextSpawn = _intervalSec;
      if (game.torches.length < _maxLiveTorches) {
        _trySpawn();
      }
    }

    _timeUntilNextCullCheck -= dt;
    if (_timeUntilNextCullCheck <= 0) {
      _timeUntilNextCullCheck = _cullCheckIntervalSec;
      _cullStragglers();
    }
  }

  void _trySpawn() {
    final existing = [for (final torch in game.torches) torch.position];
    for (var attempt = 0; attempt < _maxPlacementAttempts; attempt++) {
      final candidate = _randomPointNearby();
      if (farEnoughFrom(candidate, existing, _minSpacingPx)) {
        game.spawnTorch(candidate);
        return;
      }
    }
    // Every attempt landed too close to an existing torch -- skip this
    // tick rather than force an overlapping placement; the next tick tries
    // again with a fresh set of random candidates.
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

  void _cullStragglers() {
    final visible = game.camera.visibleWorldRect;
    final cullDistance =
        max(visible.width, visible.height) * _cullDistanceFactor;
    final playerPosition = game.player.position;
    for (final torch in List.of(game.torches)) {
      if (torch.position.distanceTo(playerPosition) > cullDistance) {
        game.cullTorch(torch);
      }
    }
  }
}
