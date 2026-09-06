import '../core/stats.dart';

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
    required this.unlocked,
  });

  final String id;
  final String name;
  final String descriptor;
  final StatBlock stats;

  /// e.g. `assets/images/characters/main` — see DECISIONS D-015 for the
  /// `main-<state>.png` naming inside it.
  final String spriteFolder;
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
    unlocked: true,
  ),
  CharacterDef(
    id: 'bruiser',
    name: 'The Bruiser',
    descriptor: 'Locked.',
    stats: StatBlock(str: 8, vit: 7, dex: 3, intellect: 2),
    spriteFolder: '',
    unlocked: false,
  ),
  CharacterDef(
    id: 'skirmisher',
    name: 'The Skirmisher',
    descriptor: 'Locked.',
    stats: StatBlock(str: 4, vit: 3, dex: 9, intellect: 4),
    spriteFolder: '',
    unlocked: false,
  ),
  CharacterDef(
    id: 'warden',
    name: 'The Warden',
    descriptor: 'Locked.',
    stats: StatBlock(str: 3, vit: 9, dex: 4, intellect: 4),
    spriteFolder: '',
    unlocked: false,
  ),
];
