import 'package:flame/components.dart';

import 'sheet_loader.dart';

/// The three delivered enemy skins — visual variety only, one stats profile
/// (developer's call: PRD §9 keeps "more than one enemy type" out of scope
/// for the demo, so this is reskins of the same grunt, not new enemies).
enum EnemySkin { one, two, three }

/// Loads `enemy-<skin>-run.png` / `enemy-<skin>-die.png` for every
/// [EnemySkin] — same naming/layout convention as `CharacterAnimations`
/// (DECISIONS D-015), just a different root folder.
class EnemyAnimations {
  EnemyAnimations._(this._run, this._death);

  final Map<EnemySkin, SpriteAnimation> _run;
  final Map<EnemySkin, SpriteAnimation> _death;

  static const cellWidth = 16.0;
  static const cellHeight = 24.0;
  static const _root = 'characters/enemies';

  SpriteAnimation runFor(EnemySkin skin) => _run[skin]!;
  SpriteAnimation deathFor(EnemySkin skin) => _death[skin]!;

  static Future<EnemyAnimations> load() async {
    final run = <EnemySkin, SpriteAnimation>{};
    final death = <EnemySkin, SpriteAnimation>{};

    for (final skin in EnemySkin.values) {
      final name = skin.name;
      run[skin] = await loadSheetAnimation(
        '$_root/enemy-$name-run.png',
        cellWidth: cellWidth,
        cellHeight: cellHeight,
      );
      death[skin] = await loadSheetAnimation(
        '$_root/enemy-$name-die.png',
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        loop: false,
      );
    }

    return EnemyAnimations._(run, death);
  }
}
