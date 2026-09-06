import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/widgets.dart' show TextStyle, FontWeight;

import '../../core/constants.dart';

/// Floating damage number on a projectile hit (PRD §6.3, §10.5). Rises and
/// disappears after a short lifespan — no art needed, just a text render.
class DamageTextComponent extends TextComponent {
  DamageTextComponent({required super.position, required double amount})
    : super(
        text: amount.round().toString(),
        anchor: Anchor.center,
        priority: ArenaPriority.damageText,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: ArenaColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );

  double _age = 0;
  static const _lifespanSec = 0.6;
  static const _riseSpeedPxPerS = 30.0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position.y -= _riseSpeedPxPerS * dt;
    if (_age >= _lifespanSec) {
      removeFromParent();
    }
  }
}
