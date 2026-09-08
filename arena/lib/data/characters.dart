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
    required this.unlocked,
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

  final bool unlocked;
}

/// The 4 select-screen slots (PRD §5.2). All 4 are unlocked and playable as
/// of TASKS Phase 8 — real unlock-via-progression gating is planned but not
/// built yet, so every slot defaults open for now. Slots 2-4 all share the
/// Apprentice's `ProjectileAttack` as a placeholder until each gets its own
/// `AttackBehavior` (CLAUDE.md §4.12).
const List<CharacterDef> kCharacters = [
  CharacterDef(
    id: 'apprentice',
    name: 'The Apprentice',
    descriptor: 'A ranged caster — keep distance, let the bolts do the work.',
    stats: StatBlock(str: 4, vit: 4, dex: 5, intellect: 7),
    spriteFolder: 'assets/images/characters/main',
    spritePrefix: 'main',
    attackBehavior: ProjectileAttack(),
    unlocked: true,
  ),
  CharacterDef(
    id: 'bruiser',
    name: 'The Bruiser',
    descriptor: 'A heavy hitter — bolts for now, a melee kit is planned.',
    stats: StatBlock(str: 8, vit: 7, dex: 3, intellect: 2),
    spriteFolder: 'assets/images/characters/second',
    spritePrefix: 'black',
    // Placeholder: same bolt as the Apprentice (TASKS Phase 8) until the
    // Bruiser gets its own AttackBehavior — melee is the obvious real fit.
    attackBehavior: ProjectileAttack(),
    unlocked: true,
  ),
  CharacterDef(
    id: 'skirmisher',
    name: 'The Skirmisher',
    descriptor: 'Fast and precise — bolts for now, a real kit is planned.',
    stats: StatBlock(str: 4, vit: 3, dex: 9, intellect: 4),
    spriteFolder: 'assets/images/characters/third',
    spritePrefix: 'third',
    attackBehavior: ProjectileAttack(),
    unlocked: true,
  ),
  CharacterDef(
    id: 'warden',
    name: 'The Warden',
    descriptor: 'Tough and steady — bolts for now, a real kit is planned.',
    stats: StatBlock(str: 3, vit: 9, dex: 4, intellect: 4),
    spriteFolder: 'assets/images/characters/fourth',
    spritePrefix: 'fourth',
    attackBehavior: ProjectileAttack(),
    unlocked: true,
  ),
];
