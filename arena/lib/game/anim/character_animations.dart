import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import 'anim_state.dart';
import 'sheet_loader.dart';

/// Loads a character's `<prefix>-<state>.png` sheets into a
/// `Map<AnimState, SpriteAnimation>` (DECISIONS D-015: one PNG per state,
/// 16×24 cell; D-024: prefix is per-character, not hardcoded to `'main'`).
/// Only the six states required for the demo (PRD §8.1) are loaded —
/// `dash`/`fly`/`warp` etc. stay unset until the skills phase actually
/// plays them (D-012).
class CharacterAnimations {
  CharacterAnimations._(this._animations);

  final Map<AnimState, SpriteAnimation> _animations;

  static const cellWidth = 16.0;
  static const cellHeight = 24.0;

  /// Total on-screen duration for one-shot states that PRD §6.5 ties to a
  /// specific gameplay timing. Everything else uses [_defaultStepTime].
  static const _spawnDurationSec = 1.0; // PRD §6.5: controls locked for 1.0s
  static const _defaultStepTime = 0.1;

  static const Map<AnimState, String> _fileNames = {
    AnimState.idle: 'idle',
    AnimState.run: 'run',
    AnimState.fire: 'fire',
    AnimState.spawn: 'spawn',
    AnimState.hurt: 'hurt',
    AnimState.death: 'die',
  };

  static const Set<AnimState> _looping = {AnimState.idle, AnimState.run};

  Map<AnimState, SpriteAnimation> get all => _animations;

  static Future<CharacterAnimations> load(
    String spriteFolder,
    String spritePrefix,
  ) async {
    final root = spriteFolder.replaceFirst('assets/images/', '');
    final animations = <AnimState, SpriteAnimation>{};

    for (final entry in _fileNames.entries) {
      final state = entry.key;
      final path = '$root/$spritePrefix-${entry.value}.png';
      final frameCount = await _frameCountOf(path);
      final stepTime = state == AnimState.spawn
          ? _spawnDurationSec / frameCount
          : _defaultStepTime;
      animations[state] = await loadSheetAnimation(
        path,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        stepTime: stepTime,
        loop: _looping.contains(state),
      );
    }

    return CharacterAnimations._(animations);
  }

  static Future<int> _frameCountOf(String path) async {
    // Flame.images caches by path, so this doesn't decode the sheet twice —
    // the real load right after reuses the same cached Image.
    final image = await Flame.images.load(path);
    return (image.width / cellWidth).round();
  }
}
