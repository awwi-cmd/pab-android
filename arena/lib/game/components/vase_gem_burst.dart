import 'dart:math';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/economy.dart';
import '../arena_game.dart';
import 'gem.dart';

/// Spawns a broken vase's gems one at a time rather than all at once
/// (DECISIONS D-006 — "make the gems fly out of it more when we break it,
/// like 1 by 1, 0.5 sec delay, fly a generous amount of distance from the
/// vase, not too far"). A bare `Component`, not a visible one — it owns
/// nothing but the countdown between spawns; each actual gem is an ordinary
/// [GemComponent] with its own `launchFrom` set to [origin], so it's the
/// gem itself that visibly flies out, not this spawner. Removes itself once
/// every gem in [gemCount] has been spawned.
class VaseGemBurstComponent extends Component with HasGameReference<ArenaGame> {
  VaseGemBurstComponent({required Vector2 origin, required this.gemCount})
    : origin = origin.clone();

  final Vector2 origin;
  final int gemCount;

  final Random _random = Random();
  int _spawned = 0;
  double _timeUntilNext = 0; // the first gem flies immediately, no delay

  @override
  void update(double dt) {
    super.update(dt);

    if (_spawned >= gemCount) {
      removeFromParent();
      return;
    }

    _timeUntilNext -= dt;
    if (_timeUntilNext > 0) return;
    _timeUntilNext = kVaseGemBurstIntervalSec;

    // Alternating left/right (DECISIONS D-002's original spec, still true)
    // rather than fully random, so even a small gem count visibly reads as
    // "left AND right" instead of occasionally clustering on one side.
    final rarity = rollRarity(_random);
    final side = _spawned.isEven ? -1.0 : 1.0;
    final offsetX = side *
        (kVaseGemScatterMinPx +
            _random.nextDouble() * (kVaseGemScatterMaxPx - kVaseGemScatterMinPx));
    final offsetY = (_random.nextDouble() * 2 - 1) * kVaseGemScatterVerticalPx;
    game.addToWorld(
      GemComponent(
        startPosition: origin + Vector2(offsetX, offsetY),
        rarity: rarity,
        animation: game.gameAssets.gemAnimations[rarity.index],
        launchFrom: origin,
      ),
    );
    _spawned++;
  }
}
