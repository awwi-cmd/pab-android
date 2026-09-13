import 'package:flame/components.dart';

import '../core/economy.dart';
import '../data/characters.dart';
import 'anim/character_animations.dart';
import 'anim/enemy_animations.dart';
import 'anim/sheet_loader.dart';
import 'components/boss.dart';

/// Every `SpriteAnimation`/`Sprite` this game needs, loaded once at arena
/// entry and held here instead of as ~20 separate fields on `ArenaGame`
/// (DECISIONS D-045/D-048 — `arena_game.dart` had grown past CLAUDE.md §5's
/// ~300-line guideline, mostly from this loading block). `ArenaGame` holds
/// one `late GameAssets assets` and exposes the handful other files reach
/// for (`boltAnimation`, `knifeCleanSprite`, ...) as thin getters that
/// delegate here — every existing call site (`AttackBehavior`s,
/// `BossComponent`, `AuraComponent`) is untouched by this split.
class GameAssets {
  GameAssets._({
    required this.characterAnimations,
    required this.enemyAnimations,
    required this.boltAnimation,
    required this.sparkAnimation,
    required this.auraShieldAnimation,
    required this.knifeCleanSprite,
    required this.knifeBloodySprite,
    required this.bloodImpactAnimation,
    required this.eliteFireAnimation,
    required this.pixelFireAnimation,
    required this.sparkleAnimation,
    required this.impactAnimation,
    required this.explosionAnimation,
    required this.animaAnimation,
    required this.mirrorAnimation,
    required this.rayBeamAnimation,
    required this.thunderAnimation,
    required this.defenceCrystalAnimation,
    required this.bossAnimations,
    required this.gemAnimations,
    required this.potionAnimations,
    required this.chestIdleAnimation,
    required this.chestOpeningAnimation,
    required this.torchAnimation,
    required this.vaseAnimation,
  });

  final CharacterAnimations characterAnimations;
  final EnemyAnimations enemyAnimations;
  final SpriteAnimation boltAnimation;
  final SpriteAnimation sparkAnimation;
  final SpriteAnimation auraShieldAnimation;
  final Sprite knifeCleanSprite;
  final Sprite knifeBloodySprite;
  final SpriteAnimation bloodImpactAnimation;
  final SpriteAnimation eliteFireAnimation;
  final SpriteAnimation pixelFireAnimation;
  final SpriteAnimation sparkleAnimation;
  final SpriteAnimation impactAnimation;
  final SpriteAnimation explosionAnimation;
  final SpriteAnimation animaAnimation;

  /// The 4 new skill VFX (DECISIONS D-049).
  final SpriteAnimation mirrorAnimation;
  final SpriteAnimation rayBeamAnimation;
  final SpriteAnimation thunderAnimation;
  final SpriteAnimation defenceCrystalAnimation;

  final Map<BossAnim, SpriteAnimation> bossAnimations;
  final List<SpriteAnimation> gemAnimations; // indexed by ItemRarity
  final List<SpriteAnimation> potionAnimations; // indexed by ItemRarity

  /// Chests (DECISIONS D-055) — [chestIdleAnimation] is a single frame
  /// (`chest_01.png`, the closed chest, also the opening sequence's own
  /// first frame) shown while sitting in the world; [chestOpeningAnimation]
  /// is the full `chest_01.png`..`chest_12.png` sequence, played once when a
  /// player walks up to it.
  final SpriteAnimation chestIdleAnimation;
  final SpriteAnimation chestOpeningAnimation;

  /// World objects (DECISIONS D-002) — [torchAnimation] loops forever (a
  /// standing torch's flame flicker never stops); [vaseAnimation] also
  /// loops (the sheet is 16 near-identical frames, just a subtle shimmer
  /// sweep, not a break sequence — see `VaseComponent`'s own doc comment).
  final SpriteAnimation torchAnimation;
  final SpriteAnimation vaseAnimation;

  /// Loads everything up front — the exact body of `ArenaGame.onLoad()`
  /// before the split, unchanged apart from the 4 new sheets at the end.
  static Future<GameAssets> load(CharacterDef character) async {
    final characterAnimations = await CharacterAnimations.load(
      character.spriteFolder,
      character.spritePrefix,
    );
    final enemyAnimations = await EnemyAnimations.load();
    final boltAnimation = await loadSheetAnimation(
      'vfx/projectiles/projectile-bolt.png',
      cellWidth: 16,
      cellHeight: 16,
      stepTime: 0.08,
    );
    final sparkAnimation = await loadSheetAnimation(
      'vfx/projectiles/projectile-spark.png',
      cellWidth: 16,
      cellHeight: 16,
      stepTime: 0.05,
      loop: false,
    );
    // Aura's shield ring (DECISIONS D-032) -- a 9x7 grid sheet, 60 real
    // frames padded out to a 63-cell rectangle (the last 3 cells of the
    // last row are blank), not a single-row strip like every other sheet
    // in this project.
    final auraShieldAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_electric-shield.png',
      cellWidth: 265,
      cellHeight: 265,
      stepTime: 0.03,
      frameCount: 60,
      amountPerRow: 9,
    );
    // Single static images, not sheets (DECISIONS D-029) -- Sprite.load, not
    // loadSheetAnimation.
    final knifeCleanSprite = await Sprite.load('vfx/projectiles/knife_clean.png');
    final knifeBloodySprite = await Sprite.load('vfx/projectiles/knife_bloody.png');
    // Player hit-splat (DECISIONS D-033) -- one-shot, doesn't loop.
    final bloodImpactAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_blood-impact.png',
      cellWidth: 60,
      cellHeight: 63,
      stepTime: 0.012,
      frameCount: 48,
      amountPerRow: 9,
      loop: false,
    );
    // Elite enemy marker (DECISIONS D-035) -- persistent looping glow, lives
    // as long as the enemy it's tracking does.
    final eliteFireAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_dithered-fire.png',
      cellWidth: 517,
      cellHeight: 246,
      stepTime: 0.05,
      frameCount: 60,
      amountPerRow: 9,
    );
    // Skirmisher's Spiral Fire skill (DECISIONS D-034) -- three sheets:
    // the projectile itself (loops for however long it's in flight), the
    // cast sparkle on the caster's body (one-shot), the hit/kill flourishes
    // (one-shot each, picked by whether that hit was lethal).
    final pixelFireAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_pixel-fire.png',
      cellWidth: 173,
      cellHeight: 197,
      stepTime: 0.03,
      frameCount: 60,
      amountPerRow: 9,
    );
    // Looping (DECISIONS D-036): the Skirmisher's cast sparkle is now an
    // always-on visual for the whole round, not a one-shot per cast, so it
    // needs to keep animating indefinitely rather than freeze on its last
    // frame.
    final sparkleAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_sparkles-constelation.png',
      cellWidth: 309,
      cellHeight: 313,
      stepTime: 0.008,
      frameCount: 60,
      amountPerRow: 9,
    );
    // First real cell is index 1, not 0 -- effect_impact.png's (0,0) cell is
    // blank on this sheet. Included as frame 0 anyway (one invisible ~12ms
    // frame at the very start of a one-shot flash is imperceptible) rather
    // than adding texturePosition-offset support to the loader for it.
    final impactAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_impact.png',
      cellWidth: 305,
      cellHeight: 383,
      stepTime: 0.012,
      frameCount: 29,
      amountPerRow: 9,
      loop: false,
    );
    // Same leading-blank-cell situation as effect_impact.png above.
    final explosionAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_explosion2.png',
      cellWidth: 355,
      cellHeight: 365,
      stepTime: 0.011,
      frameCount: 53,
      amountPerRow: 9,
      loop: false,
    );
    // The boss's teleport flourish (DECISIONS D-042) -- plays once at both
    // the departure and arrival points.
    final animaAnimation = await loadSheetAnimation(
      'vfx/vfx/effect_anima.png',
      cellWidth: 429,
      cellHeight: 437,
      stepTime: 0.02,
      frameCount: 60,
      amountPerRow: 9,
      loop: false,
    );
    // The 4 new skill VFX (DECISIONS D-049) -- grid dimensions confirmed by
    // inspecting each sheet's actual non-blank cells (same method D-042's
    // boss sheet used), not the visual thumbnail:
    // - ultimate-mirror.png: single COLUMN of 5 frames, 128x128 each.
    // - projectile-ray-beam.png: single COLUMN of 6 real frames (a 7th grid
    //   row is blank), 256x64 each -- a wide, short beam texture stretched
    //   to the shot's actual range at the call site (`RayBeamEffectComponent`).
    // - projectile-thunder.png: single ROW of 4 frames, 128x256 each.
    // - defence-crystal.png: single ROW of 6 frames, 128x128 each.
    final mirrorAnimation = await loadColumnAnimation(
      'vfx/projectiles/ultimate-mirror.png',
      cellSize: 128,
      column: 0,
      rows: 5,
      stepTime: 0.1,
    );
    final rayBeamAnimation = await loadSheetAnimation(
      'vfx/projectiles/projectile-ray-beam.png',
      cellWidth: 256,
      cellHeight: 64,
      stepTime: 0.03,
      frameCount: 6,
      amountPerRow: 1,
      loop: false,
    );
    final thunderAnimation = await loadSheetAnimation(
      'vfx/projectiles/projectile-thunder.png',
      cellWidth: 128,
      cellHeight: 256,
      stepTime: 0.04,
      frameCount: 4,
      loop: false,
    );
    final defenceCrystalAnimation = await loadSheetAnimation(
      'vfx/projectiles/defence-crystal.png',
      cellWidth: 128,
      cellHeight: 128,
      stepTime: 0.1,
    );
    // The boss (DECISIONS D-042) -- one 4-cols x 8-rows sheet holding
    // idle/walk/fire/death back to back, in that reading order (not one
    // image per state like every character sheet before it). Frame ranges
    // found by inspecting the sheet's actual non-blank cells: idle is 6
    // frames (rows 0-1), walk 3 (row 2), fire 5 (rows 3-4), death 10
    // (rows 5-7).
    const bossCellWidth = 256.0;
    const bossCellHeight = 192.0;
    final bossAnimations = {
      BossAnim.idle: await loadSheetAnimation(
        'characters/enemies/boss_map1.png',
        cellWidth: bossCellWidth,
        cellHeight: bossCellHeight,
        stepTime: 0.15,
        frameCount: 6,
        amountPerRow: 4,
      ),
      BossAnim.walk: await loadSheetAnimation(
        'characters/enemies/boss_map1.png',
        cellWidth: bossCellWidth,
        cellHeight: bossCellHeight,
        stepTime: 0.12,
        frameCount: 3,
        // No amountPerRow here (unlike the other 3 slices) -- walk fits
        // entirely within row 2, so there's no next row to wrap onto, and
        // Flame's own SpriteAnimationData asserts amount >= amountPerRow
        // when it's given (3 frames can't satisfy amountPerRow: 4).
        // texturePosition alone is enough to select the row.
        texturePosition: Vector2(0, 2 * bossCellHeight),
      ),
      BossAnim.fire: await loadSheetAnimation(
        'characters/enemies/boss_map1.png',
        cellWidth: bossCellWidth,
        cellHeight: bossCellHeight,
        stepTime: 0.08,
        frameCount: 5,
        amountPerRow: 4,
        texturePosition: Vector2(0, 3 * bossCellHeight),
        loop: false,
      ),
      BossAnim.death: await loadSheetAnimation(
        'characters/enemies/boss_map1.png',
        cellWidth: bossCellWidth,
        cellHeight: bossCellHeight,
        stepTime: 0.15,
        frameCount: 10,
        amountPerRow: 4,
        texturePosition: Vector2(0, 5 * bossCellHeight),
        loop: false,
      ),
    };
    // Gems/potions (DECISIONS D-043) -- 5 rarity tiers, left to right, each
    // its own vertical animation strip (loadColumnAnimation, not the
    // row-major loadSheetAnimation every other sheet uses).
    final gemAnimations = [
      for (var tier = 0; tier < ItemRarity.values.length; tier++)
        await loadColumnAnimation(
          'consumables/gems.png',
          cellSize: 16,
          column: tier,
          rows: 9,
          stepTime: 0.1,
        ),
    ];
    final potionAnimations = [
      for (var tier = 0; tier < ItemRarity.values.length; tier++)
        await loadColumnAnimation(
          'consumables/potions.png',
          cellSize: 16,
          column: tier,
          rows: 8,
          stepTime: 0.12,
        ),
    ];
    // Chests (DECISIONS D-055) -- 12 separate whole-image files, not a
    // sheet (`loadFileSequenceAnimation`, sheet_loader.dart), each 32x32.
    final chestFramePaths = [
      for (var i = 1; i <= 12; i++)
        'consumables/chest_${i.toString().padLeft(2, '0')}.png',
    ];
    final chestIdleAnimation = await loadFileSequenceAnimation(
      [chestFramePaths.first],
    );
    final chestOpeningAnimation = await loadFileSequenceAnimation(
      chestFramePaths,
      stepTime: 0.06,
      loop: false,
    );
    // World objects (DECISIONS D-002) -- both native 16x16 cell, single row.
    final torchAnimation = await loadSheetAnimation(
      'scenes/torch-standing.png',
      cellWidth: 16,
      cellHeight: 16,
      stepTime: 0.1,
    );
    final vaseAnimation = await loadSheetAnimation(
      'scenes/gem-vase.png',
      cellWidth: 16,
      cellHeight: 16,
      stepTime: 0.1,
    );
    return GameAssets._(
      characterAnimations: characterAnimations,
      enemyAnimations: enemyAnimations,
      boltAnimation: boltAnimation,
      sparkAnimation: sparkAnimation,
      auraShieldAnimation: auraShieldAnimation,
      knifeCleanSprite: knifeCleanSprite,
      knifeBloodySprite: knifeBloodySprite,
      bloodImpactAnimation: bloodImpactAnimation,
      eliteFireAnimation: eliteFireAnimation,
      pixelFireAnimation: pixelFireAnimation,
      sparkleAnimation: sparkleAnimation,
      impactAnimation: impactAnimation,
      explosionAnimation: explosionAnimation,
      animaAnimation: animaAnimation,
      mirrorAnimation: mirrorAnimation,
      rayBeamAnimation: rayBeamAnimation,
      thunderAnimation: thunderAnimation,
      defenceCrystalAnimation: defenceCrystalAnimation,
      bossAnimations: bossAnimations,
      gemAnimations: gemAnimations,
      potionAnimations: potionAnimations,
      chestIdleAnimation: chestIdleAnimation,
      chestOpeningAnimation: chestOpeningAnimation,
      torchAnimation: torchAnimation,
      vaseAnimation: vaseAnimation,
    );
  }
}
