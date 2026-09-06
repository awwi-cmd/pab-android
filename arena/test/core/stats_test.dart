import 'package:arena/core/stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StatBlock derived formulas', () {
    // The Apprentice, PRD §5.2: STR 4, VIT 4, DEX 5, INT 7 ->
    // 90 HP, 0.20 hp/s regen, 13 dmg, 1.40 shots/s, 140 px/s move,
    // 316 px/s projectile, 222 px range.
    const apprentice = StatBlock(str: 4, vit: 4, dex: 5, intellect: 7);

    test('maxHp = 50 + VIT*10', () {
      expect(apprentice.maxHp, 90);
    });

    test('hpRegenPerSec = VIT*0.05', () {
      expect(apprentice.hpRegenPerSec, closeTo(0.20, 1e-9));
    });

    test('damagePerHit = 5 + STR*2', () {
      expect(apprentice.damagePerHit, 13);
    });

    test('knockbackImpulse = 40 + STR*6', () {
      expect(apprentice.knockbackImpulse, 64);
    });

    test('attacksPerSec = 1.0 + DEX*0.08', () {
      expect(apprentice.attacksPerSec, closeTo(1.40, 1e-9));
    });

    test('moveSpeedPxPerS = 120 + DEX*4', () {
      expect(apprentice.moveSpeedPxPerS, 140);
    });

    test('projSpeedPxPerS = 260 + INT*8', () {
      expect(apprentice.projSpeedPxPerS, 316);
    });

    test('attackRangePx = 180 + INT*6', () {
      expect(apprentice.attackRangePx, 222);
    });

    test('formulas scale independently per stat', () {
      const base = StatBlock(str: 1, vit: 1, dex: 1, intellect: 1);
      const doubled = StatBlock(str: 2, vit: 1, dex: 1, intellect: 1);
      // Only STR-derived stats should move when only STR changes.
      expect(doubled.damagePerHit - base.damagePerHit, 2);
      expect(doubled.knockbackImpulse - base.knockbackImpulse, 6);
      expect(doubled.maxHp, base.maxHp);
      expect(doubled.moveSpeedPxPerS, base.moveSpeedPxPerS);
      expect(doubled.projSpeedPxPerS, base.projSpeedPxPerS);
    });
  });
}
