import 'package:flame/components.dart' show SpriteAnimationData, Vector2;
import 'package:flame/widgets.dart' show SpriteAnimationWidget;
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../data/characters.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/stat_bar.dart';
import 'arena_screen.dart';

/// PRD §4.4: 2x2 grid, slot 1 playable, slots 2-4 locked silhouettes.
/// Stat bars + raw numbers, plus a derived readout computed live from
/// `StatBlock` (TASKS 2.4-2.7) — never typed in by hand (DECISIONS D-008).
class CharacterSelectScreen extends StatefulWidget {
  const CharacterSelectScreen({super.key});

  static const route = '/character-select';

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final character = kCharacters[_selected];
    final stats = character.stats;

    return ScreenScaffold(
      title: 'CHARACTER SELECT',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < kCharacters.length; i++)
                  _SlotTile(
                    character: kCharacters[i],
                    selected: i == _selected,
                    onTap: kCharacters[i].unlocked
                        ? () => setState(() => _selected = i)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              character.name,
              style: const TextStyle(
                color: ArenaColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              character.descriptor,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ArenaColors.textDim),
            ),
            const SizedBox(height: 16),
            StatBar(label: 'STR', value: stats.str, max: 10),
            StatBar(label: 'VIT', value: stats.vit, max: 10),
            StatBar(label: 'DEX', value: stats.dex, max: 10),
            StatBar(label: 'INT', value: stats.intellect, max: 10),
            const SizedBox(height: 12),
            Text(
              'HP ${stats.maxHp.round()} · '
              'DMG ${stats.damagePerHit.round()} · '
              '${stats.attacksPerSec.toStringAsFixed(1)} shots/s · '
              '${stats.moveSpeedPxPerS.round()} speed',
              style: const TextStyle(
                color: ArenaColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            PixelButton(
              label: 'ENTER ARENA',
              onPressed: () => Navigator.of(context).pushNamed(
                ArenaScreen.route,
                arguments: character,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The grid-tile portrait, playing `idle` on loop (PRD §4.4, TASKS 5.13) —
/// the same square you tap to select the character. Uses Flame's
/// `SpriteAnimationWidget` directly — no `GameWidget`/game loop needed for
/// a single looping animation outside the arena.
class _CharacterPortrait extends StatelessWidget {
  const _CharacterPortrait({required this.character});

  final CharacterDef character;

  static const _cellWidth = 16.0;
  static const _cellHeight = 24.0;
  static const _scale = 4.0;

  // The Apprentice's `<prefix>-idle.png` is a known 4-frame delivery
  // (DECISIONS D-015). Unlike the in-arena loader, this widget needs a
  // frame count up front (before the sheet is decoded), so it isn't
  // computed from image width — update this if a future unlocked
  // character's idle sheet has a different frame count.
  static const _idleFrameCount = 4;

  @override
  Widget build(BuildContext context) {
    final root = character.spriteFolder.replaceFirst('assets/images/', '');
    final path = '$root/${character.spritePrefix}-idle.png';
    return SizedBox(
      width: _cellWidth * _scale,
      height: _cellHeight * _scale,
      child: SpriteAnimationWidget.asset(
        path: path,
        data: SpriteAnimationData.sequenced(
          amount: _idleFrameCount,
          stepTime: 0.1,
          textureSize: Vector2(_cellWidth, _cellHeight),
        ),
        paint: Paint()..filterQuality = FilterQuality.none, // D-011
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  final CharacterDef character;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = !character.unlocked;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: locked ? ArenaColors.locked : ArenaColors.surfaceAlt,
          border: Border.all(
            color: selected ? ArenaColors.accent : ArenaColors.surface,
            width: 2,
          ),
        ),
        child: Center(
          child: locked
              ? const Icon(Icons.lock, color: ArenaColors.textDim)
              // FittedBox scales the portrait's fixed native size down to
              // whatever the grid actually gives this tile.
              : FittedBox(
                  fit: BoxFit.contain,
                  child: _CharacterPortrait(character: character),
                ),
        ),
      ),
    );
  }
}
