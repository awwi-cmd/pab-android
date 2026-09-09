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
/// D-029/D-030) is a single 32×32 static image, not a 16×16 sheet cell like
/// the bolt/spark. Base scale 1 would match the bolt's 32×32 on-screen
/// footprint (`kProjectileRenderScale` applied to a 16×16 cell); two
/// on-device tune passes (2026-09-08: +25%, then +20% more) landed on 1.5
/// so pierce reads clearly against multiple stacked enemies.
const double kKnifeRenderScale = 1.5;

/// New effect sheets under `assets/images/vfx/vfx/` (DECISIONS D-033/D-034/
/// D-035) — each is its own 9-cols × 7-rows grid at its own native cell
/// size (not the uniform 16×16/32×32 families above), so each gets a target
/// on-screen **width** here; height is derived from the sheet's own native
/// cell aspect ratio at the call site rather than duplicated as a second
/// magic number. Sizes are first-guess placeholders (same as every other
/// VFX tuning number in this project) — expect a follow-up tune once
/// they're seen on-device.

/// Player hit-splat (D-033): sized off the player's own render width at
/// spawn time, not a hardcoded pixel value, so it can't drift if
/// `kCharacterRenderScale` ever changes. 0.6x width would be the "natural"
/// first guess; developer asked for -25% smaller on top of that before it
/// was ever shipped, hence landing on 0.45x directly.
const double kBloodImpactWidthFactor = 0.45;
// effect_blood-impact.png native cell is 60x63 -- height = width * this.
const double kBloodImpactAspect = 63 / 60;

/// Elite enemy fire glow (D-035) — width is the enemy's own render width
/// (never wider, per the ask), height from `effect_dithered-fire.png`'s
/// native 517x246 cell.
const double kEliteFireAspect = 246 / 517;

/// The Skirmisher's Spiral Fire skill (D-034).
const double kPixelFireWidthPx = 40; // effect_pixel-fire.png cell 173x197
const double kPixelFireAspect = 197 / 173;
const double kSparkleWidthFactor = 1.3; // x player width; sparkles-constelation.png cell 309x313
const double kSparkleAspect = 313 / 309;
const double kSpiralImpactWidthPx = 40; // effect_impact.png cell 305x383
const double kSpiralImpactAspect = 383 / 305;
const double kSpiralExplosionWidthPx = 64; // effect_explosion2.png cell 355x365
const double kSpiralExplosionAspect = 365 / 355;

/// The Skirmisher's cast sparkle opacity (D-034/D-036) -- 0.35 at first
/// ship read as too faint on-device, bumped to 0.5.
const double kSparkleOpacity = 0.5;

/// How long an elite's fire glow takes to fade to nothing once the enemy
/// starts dying (D-036) — see `TrackingSpriteEffect.fadeOutWhen`.
const double kEliteFireFadeOutSec = 0.4;

/// The boss (`boss_map1.png`, DECISIONS D-042) — a 4-cols × 8-rows sheet,
/// native cell 256×192. Rendered noticeably bigger than the 48×72 player/
/// grunts, first-guess placeholder like everything else here.
const double kBossWidthPx = 140;
const double kBossAspect = 192 / 256;

/// "Bright green, like green screen green" (developer's literal ask) — pure
/// chroma-key green, applied as a `ColorFilter.mode(_, BlendMode.srcIn)` on
/// `ProjectileComponent`'s paint so the boss's bolt is the same sprite as
/// the Apprentice's, just recoloured.
const Color kBossBoltTint = Color(0xFF00FF00);

/// The boss's teleport flourish (`effect_anima.png`, 9×7 grid, native cell
/// 429×437) — plays once at the departure point and once at the arrival
/// point (DECISIONS D-042).
const double kAnimaWidthPx = 160;
const double kAnimaAspect = 437 / 429;

/// SFX (DECISIONS D-044) — multiplies `Settings.sfxVolume` (0-100, the
/// user's own slider) rather than replacing it, capped low per the
/// developer's explicit "make sure they are not that loud" ask.
const double kSfxVolumeCap = 0.35;

/// Gems/money/potions (`assets/images/consumables/`, DECISIONS D-043) are
/// all the same native 16×16 cell, 5 columns (rarity tiers) × N animation
/// rows — see `loadColumnAnimation`. One shared render scale, matching
/// `kProjectileRenderScale`'s reasoning: small icon, doesn't need to read
/// as large as a character.
const double kItemRenderScale = 2.5;

/// How close the player has to walk to a gem/potion to collect it.
const double kItemPickupRadiusPx = 28;

/// The 4 new skill VFX (DECISIONS D-049) — same "width here, height derived
/// from the sheet's own native cell aspect ratio" convention as the D-033/
/// D-034/D-035 block above. Damage/cooldown/count numbers for these live in
/// `core/progression.dart`'s `UpgradeAmounts` (gameplay balance), not here
/// (CLAUDE.md §4.3) — this file only ever holds render sizing.

/// Ultimate Mirror (`ultimate-mirror.png`, native cell 128x128, single
/// column of 5 frames).
const double kMirrorWidthPx = 40;
const double kMirrorAspect = 1;

/// Projectile Ray's beam visual (`projectile-ray-beam.png`, native cell
/// 256x64, single column of 6 frames) — stretched to the shot's actual
/// range at the call site, so only its on-screen thickness is fixed here.
/// 2026-09-09 tune (developer's call: "too thin"): +40% (was 28).
const double kRayBeamThicknessPx = 28 * 1.4;

/// Projectile Thunder (`projectile-thunder.png`, native cell 128x256,
/// single row of 4 frames).
/// 2026-09-09 tune (developer's call): +40% size (was 48) — brightness is a
/// render-time boost, not a size constant, see `ArenaGame._strikeThunder`'s
/// `brightness` param on `spawnEffect`.
const double kThunderWidthPx = 48 * 1.4;
const double kThunderAspect = 256 / 128;

/// Defence Crystal (`defence-crystal.png`, native cell 128x128, single row
/// of 6 frames).
const double kDefenceCrystalWidthPx = 32;
const double kDefenceCrystalAspect = 1;

/// Potions float up and down in place while sitting on the ground
/// (developer's explicit ask) — a simple sine offset on top of their own
/// looping sprite animation, not a second spritesheet.
const double kPotionFloatAmplitudePx = 6;
const double kPotionFloatPeriodSec = 1.6;

/// Flame component render order (CLAUDE.md §4.10) — layer via these
/// constants, never a magic `priority:` int on a component.
class ArenaPriority {
  ArenaPriority._();

  static const floor = 0;
  static const groundEffects = 5;
  // Gems/potions (D-043) sit on the ground, above the floor/ground effects
  // but below anything that walks.
  static const pickup = 7;
  static const enemy = 10;
  // Above `enemy` so an elite's fire glow (D-035/D-036) reads on top of the
  // enemy sprite instead of peeking out from behind it.
  static const enemyOverlay = 12;
  static const player = 15;
  static const projectile = 20;
  static const hitEffects = 25;
  static const damageText = 30;
  static const hud = 40;
}
