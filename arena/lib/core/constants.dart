import 'package:flutter/material.dart';

/// Design-time canvas. UI and the arena world lay out against this size and
/// get letterboxed on other aspect ratios (PRD §8.4).
const double kDesignWidth = 360;
const double kDesignHeight = 800;

/// App palette (DECISIONS D-010 — replaced a cool mint/navy palette that
/// read as sleek sci-fi, out of place for a medieval game; "iron and gold
/// by torchlight" now: warm near-black/charcoal neutrals, an antique-gold
/// accent instead of mint, oxblood instead of pink-red, parchment-cream
/// text instead of cool white). Referenced everywhere so a look change is
/// an edit here, not a hunt through the widget tree — every name/role kept
/// identical to the palette this replaced, so nothing else needed to
/// change to pick this up.
class ArenaColors {
  ArenaColors._();

  static const background = Color(0xFF14100D);
  static const surface = Color(0xFF221C17);
  static const surfaceAlt = Color(0xFF352C23);
  static const accent = Color(0xFFC9A448);
  static const accentDim = Color(0xFF8A6F32);
  static const danger = Color(0xFF9C2F2A);

  /// A warm copper, not `danger`'s oxblood (DECISIONS D-083, developer's
  /// call: "get rid of that bright red for exclusives... a little bit more
  /// warm, but still pricking players' attention") — the LevelUp screen's
  /// EXCLUSIVE badge/stripe/warning (`arena_screen.dart`) is the one user
  /// of this; `danger` itself is untouched everywhere else it's used (God
  /// Mode's switch, the debug DIE button, ROUND OVER) — those are
  /// genuinely "danger," exclusivity is more "notice this."
  static const warning = Color(0xFFB9722E);
  static const textPrimary = Color(0xFFEBE0CC);
  static const textDim = Color(0xFFA69884);
  static const locked = Color(0xFF463B31);

  /// The XP bar's fill (DECISIONS D-091, "make xp bar yellow") — HP reuses
  /// [danger] (already read as "red" everywhere else it's used) rather than
  /// a second near-duplicate color. Warmed toward gold alongside the rest
  /// of the palette (D-010), not the old palette's cooler lemon-yellow.
  static const xp = Color(0xFFD4AF3D);
}

/// Shared corner radius for every bordered panel/card app-wide (DECISIONS
/// D-010, "the buttons are very sharp compared to the text" — the flat,
/// zero-radius look was app-wide, not just `PixelButton`) — one number so
/// every card/badge/button reads as the same design language instead of
/// each screen picking its own rounding.
const double kPanelCornerRadiusPx = 8;

/// HUD bar layout (DECISIONS D-091) — HP and XP now both sit at the top of
/// the screen, stacked, spanning its full width (was: a small fixed-size HP
/// box top-left, a small fixed-size XP box bottom-left). Shared here so
/// `HpBarComponent`/`XpBarComponent` can't drift out of alignment with each
/// other — both read the same margin/height/gap rather than each picking
/// their own.
const double kHudBarSideMarginPx = 24;
const double kHudBarTopMarginPx = 24;
const double kHudBarHeightPx = 14;
const double kHudBarGapPx = 6;

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

/// How much further past the visible edge a projectile has to travel
/// before it's actually considered gone and despawns (DECISIONS D-061,
/// developer's call: "knives spawn [the poof] right when they hit the
/// outside border... despawn when way out outside of screen") — expressed
/// as a multiple of the projectile's own `size.x`, so a bigger sprite (the
/// knife) gets a proportionally bigger margin than a small one (the bolt),
/// rather than one flat pixel number. Every projectile type's zero-bounce
/// despawn check inflates `camera.visibleWorldRect` by `size.x * this`
/// before testing "is it really gone" — the bare (non-inflated) edge is
/// still what boss/mirror bolts bounce *off of* (DECISIONS D-052); this
/// only delays the final despawn once there's nothing left to bounce off.
const double kProjectileDespawnMarginFactor = 1.0;

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

/// The teleport flourish (`effect_anima.png`, 9×7 grid, native cell
/// 429×437), shared by the boss's teleport (DECISIONS D-042) and the
/// chest-opening sequence's own lead-in beat (DECISIONS D-055).
const double kAnimaWidthPx = 160;
const double kAnimaAspect = 437 / 429;

/// The boss's own teleport plays [kAnimaWidthPx] scaled down (DECISIONS
/// D-059, developer's call: "-40% on the boss when he teleports") — a
/// separate constant, not a change to [kAnimaWidthPx] itself, since that one
/// is still shared with the chest-opening sequence, which wasn't asked to
/// change. Applies at both the departure and arrival flourish
/// (`BossComponent._teleportAwayFrom`) — "when he teleports" covers the
/// whole teleport, not just one end of it.
const double kBossAnimaWidthPx = kAnimaWidthPx * 0.6;

/// The chest-opening sequence's own anima flourish (DECISIONS D-071,
/// developer's call: "wayy too big... make it smaller a bit than the
/// chest") — was flat [kAnimaWidthPx] (160px), dwarfing the 96px chest
/// (`32 * kChestRenderScale`) it's supposed to precede. Sized relative to
/// the chest's own rendered width instead (`ChestComponent.size.x *` this
/// factor) — same "derive VFX size from the actual gameplay size" pattern
/// `WardenSlamAttack`'s shockwave already uses — rather than a second flat
/// constant that could drift out of sync with the chest's own size again.
const double kChestAnimaSizeFactor = 0.85;

/// Same ask, the contrast half — a straight pull-toward-grey, same knob
/// `AuraComponent`'s own `_contrast` tune uses (DECISIONS D-032),
/// generalized onto `ArenaGame.spawnEffect` so this one-shot VFX can dial
/// it down too, not just brightness.
const double kChestAnimaContrast = 0.7;

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

/// Chests (`consumables/chest_01.png`..`chest_12.png`, DECISIONS D-055) —
/// native 32x32 cell, rendered bigger than a gem/potion (a chest is a
/// bigger, rarer prize) but smaller than the player. Its own pickup radius,
/// slightly larger than [kItemPickupRadiusPx], to match the bigger sprite.
const double kChestRenderScale = 3;
const double kChestPickupRadiusPx = 36;

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

/// Potions (and, since DECISIONS D-059, gems too — "make it like the potion
/// one," the developer's literal ask) float up and down in place while
/// sitting on the ground — a simple sine offset on top of their own looping
/// sprite animation, not a second spritesheet. Shared by both pickups
/// rather than duplicated so they can't drift apart on a future tune.
const double kItemFloatAmplitudePx = 6;
const double kItemFloatPeriodSec = 1.6;

/// Standing torches (`scenes/torch-standing.png`, DECISIONS D-002) — a
/// solid world obstacle, native 16×16 cell, same render-scale family as
/// gems/potions/vases. Collision radius is deliberately smaller than half
/// the rendered sprite (the flame/base padding around the actual pole
/// shouldn't block movement) — first-guess placeholder like every other
/// collision/VFX size in this project.
const double kTorchRenderScale = 3;
const double kTorchCollisionRadiusPx = 10;

/// Gem vases (`scenes/gem-vase.png`, DECISIONS D-002) — native 16×16 cell,
/// same render-scale family. [kVasePickupRadiusPx] is the touch radius that
/// breaks it (subject to MAGNET like every other pickup radius).
///
/// DECISIONS D-006/D-007 ("make gems launch at once almost 0.125 delay in
/// between, the direction they go is good"): [VaseGemBurstComponent] spawns
/// one gem every [kVaseGemBurstIntervalSec] instead of all of them at once,
/// each launched from the vase's own position out to its landing spot over
/// [kVaseGemLaunchDurationSec] (`GemComponent`'s own `launchFrom`). The
/// scatter distances below were widened from their original (18-42px)
/// values in D-006's first pass ("a generous amount of distance... not too
/// far") — alternating left/right of the vase (not fully random) so even a
/// small gem count visibly reads as "left AND right," the developer's
/// original literal spec, rather than occasionally clustering on one side
/// by chance.
///
/// [kVaseExplosionWidthPx] (D-007, "add an explosion vfx like the 4th
/// character has... make the explosion not that big") reuses the same
/// `explosionAnimation` sheet `WardenSlamAttack`'s own shockwave does
/// (`vfx/vfx/effect_explosion2.png`), sized well below both that (arena-
/// radius-scaled) and the Skirmisher's own `kSpiralExplosionWidthPx` (64) —
/// deliberately small since a vase is a small object, not an AoE hit.
const double kVaseRenderScale = 3;
const double kVasePickupRadiusPx = 30;
const double kVaseGemScatterMinPx = 40;
const double kVaseGemScatterMaxPx = 90;
const double kVaseGemScatterVerticalPx = 24;
const double kVaseGemBurstIntervalSec = 0.125;
const double kVaseGemLaunchDurationSec = 0.35;
const double kVaseExplosionWidthPx = 36;

/// Flame component render order (CLAUDE.md §4.10) — layer via these
/// constants, never a magic `priority:` int on a component.
class ArenaPriority {
  ArenaPriority._();

  static const floor = 0;
  static const groundEffects = 5;
  // Gems/potions (D-043) sit on the ground, above the floor/ground effects
  // but below anything that walks.
  static const pickup = 7;
  // Standing torches (D-002) — solid obstacles, same layer band as pickups
  // but drawn just above them.
  static const obstacle = 8;
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
