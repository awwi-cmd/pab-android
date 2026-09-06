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
