import 'package:flutter/material.dart';

/// Design-time canvas. UI and the arena world lay out against this size and
/// get letterboxed on other aspect ratios (PRD §8.4).
const double kDesignWidth = 360;
const double kDesignHeight = 800;

/// App palette. Dark, pixel-friendly. Referenced everywhere so a look change
/// is an edit here, not a hunt through the widget tree.
class ArenaColors {
  ArenaColors._();

  static const background = Color(0xFF10121A);
  static const surface = Color(0xFF1B1E2B);
  static const surfaceAlt = Color(0xFF262B3D);
  static const accent = Color(0xFF6CE0B8);
  static const accentDim = Color(0xFF3E8C6E);
  static const danger = Color(0xFFE0526C);
  static const textPrimary = Color(0xFFEDEFF7);
  static const textDim = Color(0xFF8B90A6);
  static const locked = Color(0xFF3A3E4E);
}

/// Characters are authored at 16×24 px (DECISIONS D-015, superseding
/// D-011's assumed 32×32). This is the integer scale they render at on the
/// 360-wide design canvas — integer keeps nearest-neighbour filtering
/// crisp. Tunable: it's the only place this number lives.
const double kCharacterRenderScale = 3;

/// Projectile/VFX sheets are 16×16 (smaller cell than characters) — a
/// smaller integer scale keeps a bolt from reading larger than it should
/// next to a 48×72 (16×24 × 3) player.
const double kProjectileRenderScale = 2;

/// Floor/border tiles (`assets/images/scenes/`) are authored at 32×32.
const double kFloorTileRenderScale = 2;

/// The Bruiser's knife projectile (`vfx/projectiles/knife_*.png`, DECISIONS
/// D-029) is a single 32×32 static image, not a 16×16 sheet cell like the
/// bolt/spark. Base scale 1 would match the bolt's 32×32 on-screen
/// footprint (`kProjectileRenderScale` applied to a 16×16 cell); 1.25 is a
/// deliberate +25% tune (2026-09-08) so pierce reads clearly against
/// multiple stacked enemies.
const double kKnifeRenderScale = 1.25;

/// Flame component render order (CLAUDE.md §4.10) — layer via these
/// constants, never a magic `priority:` int on a component.
class ArenaPriority {
  ArenaPriority._();

  static const floor = 0;
  static const groundEffects = 5;
  static const enemy = 10;
  static const player = 15;
  static const projectile = 20;
  static const hitEffects = 25;
  static const damageText = 30;
  static const hud = 40;
}
