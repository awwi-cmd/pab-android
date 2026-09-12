import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/progression.dart';

/// The skill's own real game art (or, for the 4 flat stat bumps — which
/// have no dedicated art — a plain `Icon` glyph), cropped to a small square
/// badge (DECISIONS D-078). A bordered box of its own, colored [accent], so
/// it reads as a slotted-in icon rather than a floating sprite. Shared by
/// the LevelUp screen's `_LevelUpCard` (`arena_screen.dart`) and
/// `TutorialScreen`'s powers slide (DECISIONS D-084) — promoted out of
/// `arena_screen.dart` into its own widget the moment a second screen
/// needed the exact same per-skill iconography.
class SkillIcon extends StatelessWidget {
  const SkillIcon({super.key, required this.kind, required this.accent});

  final UpgradeKind kind;
  final Color accent;

  static const _boxSize = 44.0;
  static const _spriteSize = 34.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _boxSize,
      height: _boxSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ArenaColors.background,
        border: Border.all(color: accent),
      ),
      child: _iconFor(kind),
    );
  }

  Widget _iconFor(UpgradeKind kind) {
    switch (kind) {
      case UpgradeKind.vit:
        return const Icon(Icons.favorite, color: ArenaColors.textPrimary, size: 22);
      case UpgradeKind.dex:
        return const Icon(Icons.directions_run, color: ArenaColors.textPrimary, size: 22);
      case UpgradeKind.str:
        return const Icon(Icons.fitness_center, color: ArenaColors.textPrimary, size: 22);
      case UpgradeKind.intellect:
        return const Icon(Icons.auto_fix_high, color: ArenaColors.textPrimary, size: 22);
      case UpgradeKind.aura:
        return const SpriteCellIcon(
          asset: 'assets/images/vfx/vfx/effect_electric-shield.png',
          sheetWidth: 2385,
          sheetHeight: 1855,
          cellWidth: 265,
          cellHeight: 265,
          boxSize: _spriteSize,
        );
      case UpgradeKind.knifeMastery:
        return const SpriteCellIcon(
          asset: 'assets/images/vfx/projectiles/knife_clean.png',
          sheetWidth: 32,
          sheetHeight: 32,
          cellWidth: 32,
          cellHeight: 32,
          boxSize: _spriteSize,
        );
      case UpgradeKind.ultimateMirror:
        return const SpriteCellIcon(
          asset: 'assets/images/vfx/projectiles/ultimate-mirror.png',
          sheetWidth: 128,
          sheetHeight: 640,
          cellWidth: 128,
          cellHeight: 128,
          boxSize: _spriteSize,
        );
      case UpgradeKind.projectileRay:
        return const SpriteCellIcon(
          asset: 'assets/images/vfx/projectiles/projectile-ray-beam.png',
          sheetWidth: 256,
          sheetHeight: 448,
          cellWidth: 256,
          cellHeight: 64,
          boxSize: _spriteSize,
        );
      case UpgradeKind.projectileThunder:
        return const SpriteCellIcon(
          asset: 'assets/images/vfx/projectiles/projectile-thunder.png',
          sheetWidth: 512,
          sheetHeight: 256,
          cellWidth: 128,
          cellHeight: 256,
          boxSize: _spriteSize,
        );
      case UpgradeKind.defenceCrystal:
        return const SpriteCellIcon(
          asset: 'assets/images/vfx/projectiles/defence-crystal.png',
          sheetWidth: 768,
          sheetHeight: 128,
          cellWidth: 128,
          cellHeight: 128,
          boxSize: _spriteSize,
        );
    }
  }
}

/// Crops frame 0 (top-left cell) out of a sprite sheet for a plain Flutter
/// `Image.asset` (DECISIONS D-078) — same `OverflowBox`/`ClipRect` crop
/// trick `_SpriteCell` (`arena_screen.dart`) uses, generalized for a
/// *non-square* cell (the ray beam/thunder sheets aren't): scales by the
/// cell's larger dimension and centers the result in a square [boxSize]
/// box, so a wide or tall frame letterboxes instead of stretching. Every
/// asset used here only ever needs its first frame (column 0, row 0), so
/// unlike `_SpriteCell` there's no column/row parameter to get wrong.
class SpriteCellIcon extends StatelessWidget {
  const SpriteCellIcon({
    super.key,
    required this.asset,
    required this.sheetWidth,
    required this.sheetHeight,
    required this.cellWidth,
    required this.cellHeight,
    required this.boxSize,
  });

  final String asset;
  final double sheetWidth;
  final double sheetHeight;
  final double cellWidth;
  final double cellHeight;
  final double boxSize;

  @override
  Widget build(BuildContext context) {
    final scale = boxSize / (cellWidth > cellHeight ? cellWidth : cellHeight);
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Center(
        child: SizedBox(
          width: cellWidth * scale,
          height: cellHeight * scale,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: sheetWidth * scale,
              maxHeight: sheetHeight * scale,
              // Always frame (0, 0) -- top-left cell -- see class doc.
              alignment: Alignment.topLeft,
              child: Image.asset(
                asset,
                width: sheetWidth * scale,
                height: sheetHeight * scale,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
