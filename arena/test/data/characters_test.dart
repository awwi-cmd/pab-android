import 'package:arena/core/stats.dart';
import 'package:arena/data/characters.dart';
import 'package:arena/game/attack_behavior.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const stats = StatBlock(str: 0, vit: 0, dex: 0, intellect: 0);
  const attackBehavior = ProjectileAttack();

  group('CharacterDef.isUnlockedFor (DECISIONS D-055)', () {
    test('null threshold is always unlocked, at any kill count', () {
      const character = CharacterDef(
        id: 'x',
        name: 'x',
        descriptor: 'x',
        stats: stats,
        spriteFolder: 'x',
        spritePrefix: 'x',
        attackBehavior: attackBehavior,
      );
      expect(character.isUnlockedFor(0), isTrue);
      expect(character.isUnlockedFor(1000000), isTrue);
    });

    test('locked below the threshold, unlocked at and above it', () {
      const character = CharacterDef(
        id: 'x',
        name: 'x',
        descriptor: 'x',
        stats: stats,
        spriteFolder: 'x',
        spritePrefix: 'x',
        attackBehavior: attackBehavior,
        unlockKillThreshold: 50,
      );
      expect(character.isUnlockedFor(49), isFalse);
      expect(character.isUnlockedFor(50), isTrue);
      expect(character.isUnlockedFor(51), isTrue);
    });
  });

  group('kCharacters (DECISIONS D-055)', () {
    test('the Apprentice has no unlock requirement', () {
      final apprentice = kCharacters.firstWhere((c) => c.id == 'apprentice');
      expect(apprentice.unlockKillThreshold, isNull);
      expect(apprentice.isUnlockedFor(0), isTrue);
    });

    test('every other slot has a threshold, strictly increasing by slot', () {
      final thresholds = [
        for (final c in kCharacters.skip(1)) c.unlockKillThreshold!,
      ];
      for (var i = 1; i < thresholds.length; i++) {
        expect(thresholds[i], greaterThan(thresholds[i - 1]));
      }
    });
  });
}
