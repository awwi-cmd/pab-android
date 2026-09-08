import 'package:flame/components.dart';

/// Anything a player attack can hit and damage (DECISIONS D-042) — lets
/// [BossComponent] (`game/components/boss.dart`) participate in exactly the
/// same hit-detection loops as [EnemyComponent] (`projectile.dart`,
/// `knife_projectile.dart`, `spiral_fire_projectile.dart`, `aura.dart`)
/// without either one knowing the other exists. Both already have every
/// member here with a matching signature (`position`/`size` come from
/// `PositionComponent`), so implementing it costs each class nothing beyond
/// the `implements` clause.
abstract class Damageable {
  bool get isDying;
  Vector2 get position;
  Vector2 get size;
  void applyKnockback(Vector2 direction, double impulsePxPerS);
  void takeDamage(double amount);
}
