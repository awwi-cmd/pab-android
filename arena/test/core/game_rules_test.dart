import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'package:arena/core/game_rules.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nearestWithinRange', () {
    test('returns -1 for an empty candidate list', () {
      expect(nearestWithinRange(Vector2.zero(), [], 100), -1);
    });

    test('returns -1 when nothing is within range', () {
      final candidates = [Vector2(200, 0), Vector2(0, 300)];
      expect(nearestWithinRange(Vector2.zero(), candidates, 100), -1);
    });

    test('picks the closest candidate, not the first in range', () {
      final candidates = [Vector2(90, 0), Vector2(10, 0), Vector2(50, 0)];
      expect(nearestWithinRange(Vector2.zero(), candidates, 100), 1);
    });

    test('a candidate exactly at maxRange still counts', () {
      final candidates = [Vector2(100, 0)];
      expect(nearestWithinRange(Vector2.zero(), candidates, 100), 0);
    });
  });

  group('nextSpawnInterval', () {
    test('shrinks by the given factor', () {
      expect(
        nextSpawnInterval(1.5, factor: 0.96, floor: 0.25),
        closeTo(1.44, 1e-9),
      );
    });

    test('floors instead of going below it', () {
      expect(nextSpawnInterval(0.26, factor: 0.5, floor: 0.25), 0.25);
    });

    test('never returns below the floor even after many decays', () {
      var interval = 1.5;
      for (var i = 0; i < 200; i++) {
        interval = nextSpawnInterval(interval, factor: 0.96, floor: 0.25);
      }
      expect(interval, 0.25);
    });
  });

  group('knockbackDistance', () {
    test('is impulse times duration', () {
      expect(knockbackDistance(64, 0.15), closeTo(9.6, 1e-9));
    });

    test('zero impulse gives zero distance', () {
      expect(knockbackDistance(0, 0.15), 0);
    });
  });

  group('allWithinRange', () {
    test('returns an empty list for an empty candidate list', () {
      expect(allWithinRange(Vector2.zero(), [], 100), isEmpty);
    });

    test('returns every candidate within range, order preserved', () {
      final candidates = [Vector2(10, 0), Vector2(200, 0), Vector2(0, 50)];
      expect(allWithinRange(Vector2.zero(), candidates, 60), [0, 2]);
    });

    test('a candidate exactly at maxRange still counts', () {
      final candidates = [Vector2(100, 0)];
      expect(allWithinRange(Vector2.zero(), candidates, 100), [0]);
    });
  });

  group('enemyStatMultiplier', () {
    test('is 1 at level 1 (no scaling for the starting level)', () {
      expect(enemyStatMultiplier(1), 1.0);
    });

    test('grows linearly with level', () {
      expect(enemyStatMultiplier(2), closeTo(1.12, 1e-9));
      expect(enemyStatMultiplier(6), closeTo(1.6, 1e-9));
    });
  });

  group('rollIsElite', () {
    test('is deterministic for a given seed', () {
      expect(rollIsElite(Random(7)), rollIsElite(Random(7)));
    });

    test('rolls true roughly kEliteChance of the time over many trials', () {
      const trials = 20000;
      var trueCount = 0;
      final random = Random(1);
      for (var i = 0; i < trials; i++) {
        if (rollIsElite(random)) trueCount++;
      }
      final rate = trueCount / trials;
      expect(rate, closeTo(kEliteChance, 0.02)); // generous tolerance
    });
  });

  group('bossStatMultiplier', () {
    test('is 1 for the first spawn (index 0)', () {
      expect(bossStatMultiplier(0), 1.0);
    });

    test('compounds ~20% per spawn, not flat', () {
      expect(bossStatMultiplier(1), closeTo(1.2, 1e-9));
      expect(bossStatMultiplier(2), closeTo(1.44, 1e-9)); // 1.2^2, not 1.4
    });
  });

  group('corruption multipliers', () {
    test('are neutral at level 0', () {
      expect(corruptionSpawnIntervalMultiplier(0), 1.0);
      expect(corruptionEnemyStatMultiplier(0), 1.0);
      expect(corruptionRewardMultiplier(0), 1.0);
    });

    test('scale linearly with level', () {
      expect(corruptionSpawnIntervalMultiplier(5), closeTo(0.6, 1e-9));
      expect(corruptionEnemyStatMultiplier(5), closeTo(1.4, 1e-9));
      expect(corruptionRewardMultiplier(5), closeTo(1.5, 1e-9));
    });

    test('spawn interval multiplier never drops below its floor', () {
      expect(corruptionSpawnIntervalMultiplier(10), greaterThanOrEqualTo(0.2));
      expect(corruptionSpawnIntervalMultiplier(100), 0.2);
    });
  });

  group('randomPerimeterPoint', () {
    test('always lands outside the visible rect, inflated by the margin', () {
      const visible = Rect.fromLTWH(0, 0, 360, 800);
      final random = Random(3);
      for (var i = 0; i < 200; i++) {
        final point = randomPerimeterPoint(random, visible, marginFactor: 0.15);
        final inflated = visible.inflate(0.01); // float-rounding slack
        expect(inflated.contains(Offset(point.x, point.y)), isFalse);
      }
    });

    test('is deterministic for a given seed', () {
      const visible = Rect.fromLTWH(0, 0, 360, 800);
      expect(
        randomPerimeterPoint(Random(9), visible, marginFactor: 0.15),
        randomPerimeterPoint(Random(9), visible, marginFactor: 0.15),
      );
    });
  });
}
