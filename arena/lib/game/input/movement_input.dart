import 'package:flame/game.dart' show Vector2;

/// Normalised movement vector shared between whichever control-scheme
/// widget is active and the game (CLAUDE.md §4.6). `PlayerComponent` reads
/// [direction] every frame and never knows which scheme produced it.
class MovementInput {
  /// Mutated in place every frame — never reallocate this field
  /// (CLAUDE.md §4.4: no `Vector2` construction in hot loops).
  final Vector2 direction = Vector2.zero();

  /// Sets [direction] from a raw (possibly non-unit) vector, clamping its
  /// magnitude to 1 — a half-pushed stick gives half speed, a full push (or
  /// a drag past the stick radius) gives full speed (PRD §6.2).
  void set(double x, double y) {
    direction.setValues(x, y);
    final length = direction.length;
    if (length > 1) {
      direction.scale(1 / length);
    }
  }

  void clear() => direction.setZero();
}
