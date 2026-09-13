import 'dart:math';

import 'package:flame/components.dart';

import '../../core/game_config.dart';
import '../../core/game_rules.dart';
import '../arena_game.dart';

/// Scatters gem vases around the roaming world (DECISIONS D-002), same
/// camera-relative-rect placement `PotionSpawner`/`ChestSpawner`/
/// `TorchSpawner` all share, plus `TorchSpawner`'s own minimum-spacing
/// rejection against every other already-live vase ("how many vases we
/// spawn and how divided they are," the developer's literal spec). Unlike
/// `TorchSpawner` there's no straggler cull here — a vase already removes
/// itself the instant the player reaches it (`VaseComponent`), so one that
/// falls behind just sits there as ordinary unclaimed loot rather than
/// permanently eating into the live cap the way an uncullable enemy would.
class VaseSpawner extends Component with HasGameReference<ArenaGame> {
  static int get _maxLiveVases => GameConfig.instance.vaseCount;
  static double get _minSpacingPx => GameConfig.instance.vaseMinSpacingPx;

  static const _intervalSec = 20.0;
  static const _spawnAreaFactor = 1.5; // x the visible view's width/height
  static const _maxPlacementAttempts = 10;

  // Same "already populated at round start" reasoning as TorchSpawner.
  double _timeUntilNextSpawn = 0;
  final Random _random = Random();

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.player.isAlive) return;

    _timeUntilNextSpawn -= dt;
    if (_timeUntilNextSpawn <= 0) {
      _timeUntilNextSpawn = _intervalSec;
      if (game.vases.length < _maxLiveVases) {
        _trySpawn();
      }
    }
  }

  void _trySpawn() {
    final existing = [for (final vase in game.vases) vase.position];
    for (var attempt = 0; attempt < _maxPlacementAttempts; attempt++) {
      final candidate = _randomPointNearby();
      if (farEnoughFrom(candidate, existing, _minSpacingPx)) {
        game.spawnVase(candidate);
        return;
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
