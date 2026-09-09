import '../core/stats.dart';
import '../game/attack_behavior.dart';

/// One playable-or-not character slot for the select screen (PRD §4.4/§5.2,
/// DECISIONS D-003). `unlocked` gates both selectability and whether a
/// sprite folder is expected to exist yet.
class CharacterDef {
  const CharacterDef({
    required this.id,
    required this.name,
    required this.descriptor,
    required this.stats,
    required this.spriteFolder,
    required this.spritePrefix,
    required this.attackBehavior,
    this.unlockKillThreshold,
  });

  final String id;
  final String name;
  final String descriptor;
  final StatBlock stats;

  /// e.g. `assets/images/characters/main` — see DECISIONS D-015 for the
  /// `<spritePrefix>-<state>.png` naming inside it.
  final String spriteFolder;

  /// The `<spritePrefix>` in `<spritePrefix>-<state>.png` (DECISIONS D-024)
  /// — was hardcoded to `'main'` before, which only worked because there
  /// was exactly one character. Each character can have its own.
  final String spritePrefix;

  /// How this character attacks (DECISIONS D-024). The demo only
  /// implements [ProjectileAttack], but the hook exists so a melee or
  /// other kind of character doesn't require rewriting `ArenaGame`.
  final AttackBehavior attackBehavior;

  /// Lifetime kills (`MetaProgression.lifetimeKills`, DECISIONS D-055)
  /// needed to unlock this slot. `null` means always unlocked (the
  /// Apprentice) — supersedes the old flat `unlocked` bool from D-028's
  /// "everyone starts unlocked" placeholder, now that real progression-gated
  /// unlocking (TASKS 8.4) is built.
  final int? unlockKillThreshold;

  bool isUnlockedFor(int lifetimeKills) =>
      unlockKillThreshold == null || lifetimeKills >= unlockKillThreshold!;
}

/// The 4 select-screen slots (PRD §5.2). Real unlock-via-progression gating
/// (TASKS 8.4, DECISIONS D-055) as of Phase 13 — the Apprentice is always
/// open, the other 3 gate on lifetime kills (`unlockKillThreshold`,
/// steeper per slot). The Bruiser has its own `KnifeAttack` (D-029), the
/// Skirmisher has `SpiralFireAttack` (D-034), and the Warden has
/// `WardenSlamAttack` (D-056) — all 4 characters now have a distinct kit,
/// closing the last CLAUDE.md §4.12 placeholder.
const List<CharacterDef> kCharacters = [
  CharacterDef(
    id: 'apprentice',
    name: 'The Apprentice',
    descriptor: 'A ranged caster — keep distance, let the bolts do the work.',
    stats: StatBlock(str: 4, vit: 4, dex: 5, intellect: 7),
    spriteFolder: 'assets/images/characters/main',
    spritePrefix: 'main',
    attackBehavior: ProjectileAttack(),
    // unlockKillThreshold omitted -- always unlocked, the starting character.
  ),
  CharacterDef(
    id: 'bruiser',
    name: 'The Bruiser',
    descriptor: 'Throws a spinning knife that cuts through the whole line.',
    stats: StatBlock(str: 8, vit: 7, dex: 3, intellect: 2),
    spriteFolder: 'assets/images/characters/second',
    spritePrefix: 'black',
    // First real distinct kit (TASKS 8.3, DECISIONS D-029) — pierces every
    // enemy in its path instead of stopping at the first, unlike everyone
    // else's ProjectileAttack.
    attackBehavior: KnifeAttack(),
    unlockKillThreshold: 50,
  ),
  CharacterDef(
    id: 'skirmisher',
    name: 'The Skirmisher',
    descriptor: 'Twin spiral flames circle each other on the way to the target.',
    stats: StatBlock(str: 4, vit: 3, dex: 9, intellect: 4),
    spriteFolder: 'assets/images/characters/third',
    spritePrefix: 'third',
    // Second distinct kit (TASKS 8.3, DECISIONS D-034) -- two projectiles
    // orbiting a shared advancing point, converging on the target.
    attackBehavior: SpiralFireAttack(),
    unlockKillThreshold: 150,
  ),
  CharacterDef(
    id: 'warden',
    name: 'The Warden',
    descriptor: 'Slams the ground around it — stand in the middle, hit everyone.',
    stats: StatBlock(str: 3, vit: 9, dex: 4, intellect: 4),
    spriteFolder: 'assets/images/characters/fourth',
    spritePrefix: 'fourth',
    // Third real distinct kit (TASKS 8.3, DECISIONS D-056) -- melee AoE
    // around the player instead of a projectile, fits the VIT-heavy stats.
    attackBehavior: WardenSlamAttack(),
    unlockKillThreshold: 300,
  ),
];
