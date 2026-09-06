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

/// The 4 select-screen slots (PRD §5.2). Only slot 1 is unlocked/playable
/// for the demo; slots 2-4 are data so the select screen has something to
/// render behind the padlock (DECISIONS D-003) — they have no sprites.
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
    descriptor: 'Locked.',
    stats: StatBlock(str: 8, vit: 7, dex: 3, intellect: 2),
    spriteFolder: '',
    spritePrefix: '',
    // Unused while locked -- ProjectileAttack is a placeholder, not a
    // design commitment. A melee kit is the obvious real fit here.
    attackBehavior: ProjectileAttack(),
    unlocked: false,
  ),
  CharacterDef(
    id: 'skirmisher',
    name: 'The Skirmisher',
    descriptor: 'Locked.',
    stats: StatBlock(str: 4, vit: 3, dex: 9, intellect: 4),
    spriteFolder: '',
    spritePrefix: '',
    attackBehavior: ProjectileAttack(),
    unlocked: false,
  ),
  CharacterDef(
    id: 'warden',
    name: 'The Warden',
    descriptor: 'Locked.',
    stats: StatBlock(str: 3, vit: 9, dex: 4, intellect: 4),
    spriteFolder: '',
    spritePrefix: '',
    attackBehavior: ProjectileAttack(),
    unlocked: false,
  ),
];
