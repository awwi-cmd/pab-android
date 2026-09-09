import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/constants.dart';
import '../../core/progression.dart';
import '../arena_game.dart';

/// The Defence Crystal skill's visual (DECISIONS D-049/D-050) — the actual
/// damage resistance / HP regen bonus is a flat `PlayerUpgrades` add-on
/// applied directly by `PlayerComponent` (same pattern as vit/dex/str/
/// intellect, D-025 #2); this component is purely decorative, orbiting the
/// player in a figure-8 (a lemniscate: `x = sin(t)`, `y = sin(2t)/2`,
/// DECISIONS D-049's literal "orbits ... in a kind of 8 shape" ask).
/// Single-pick skill — only ever one of these exists
/// (`ArenaGame._syncDefenceCrystal`), unlike the mirror squad which can have
/// several.
///
/// D-050: [priority] now toggles between just-behind-the-player and
/// just-in-front as the crystal crosses the figure-8's own center — the two
/// lobes of a lemniscate naturally read as "near side" / "far side" of the
/// player, so flipping depth exactly there gives the "flying behind and in
/// front of him" look the developer asked for, not a separate depth curve.
class DefenceCrystalComponent extends PositionComponent
    with HasGameReference<ArenaGame> {
  DefenceCrystalComponent({required SpriteAnimation animation})
    : super(anchor: Anchor.center, priority: _behindPriority) {
    add(
      SpriteAnimationComponent(
        animation: animation,
        size: Vector2(kDefenceCrystalWidthPx, kDefenceCrystalWidthPx * kDefenceCrystalAspect),
        anchor: Anchor.center,
        paint: Paint()..filterQuality = FilterQuality.none, // D-011
      ),
    );
  }

  // One below/above ArenaPriority.player (not a new named constant in
  // constants.dart -- this pairing only ever makes sense relative to the
  // player's own priority, so it's derived here instead of duplicated).
  static const _behindPriority = ArenaPriority.player - 1;
  static const _frontPriority = ArenaPriority.player + 1;

  double _t = 0;
  final Vector2 _scratch = Vector2.zero(); // reused every frame

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt * UpgradeAmounts.defenceCrystalOrbitSpeedRadPerSec;
    final x = sin(_t) * UpgradeAmounts.defenceCrystalOrbitRadiusXPx;
    _scratch.setValues(
      x,
      sin(2 * _t) * 0.5 * UpgradeAmounts.defenceCrystalOrbitRadiusYPx,
    );
    position
      ..setFrom(game.player.position)
      ..add(_scratch);

    // Which lobe of the 8 it's currently on -- the sign of x alone (not a
    // separate phase check) already tells the two lobes apart, since x
    // crosses zero exactly at the figure-8's own center crossing.
    priority = x >= 0 ? _frontPriority : _behindPriority;
  }
}
