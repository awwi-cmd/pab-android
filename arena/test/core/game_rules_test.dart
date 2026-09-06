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
}
