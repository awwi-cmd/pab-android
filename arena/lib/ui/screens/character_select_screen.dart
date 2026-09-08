import 'package:flame/components.dart' show SpriteAnimationData, Vector2;
import 'package:flame/widgets.dart' show SpriteAnimationWidget;
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/meta_progression.dart';
import '../../data/characters.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/stat_bar.dart';
import 'arena_screen.dart';
import 'shop_screen.dart';
import 'upgrades_screen.dart';

/// PRD §4.4: 2x2 grid. All 4 slots unlocked as of TASKS Phase 8 (real
/// progression-gated unlocking is planned, not built — every slot defaults
/// open for now); the padlock rendering stays keyed off `unlocked` so it
/// still works once locking comes back. Stat bars + raw numbers, plus a
/// derived readout computed live from `StatBlock` (TASKS 2.4-2.7) — never
/// typed in by hand (DECISIONS D-008).
class CharacterSelectScreen extends StatefulWidget {
  const CharacterSelectScreen({super.key});

  static const route = '/character-select';

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  int _selected = 0;

  // Wallet display only (DECISIONS D-047) -- the actual spending happens in
  // UpgradesScreen; reloaded every time we come back from either of the two
  // routes below, since either can change it (Upgrades spends it directly;
  // Shop is a no-op today but will spend it too once it has real content).
  int _coins = 0;

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  Future<void> _loadCoins() async {
    final meta = await MetaProgressionRepository().load();
    if (!mounted) return;
    setState(() => _coins = meta.coins);
  }

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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/ui/currency-counter.png',
                  height: 28,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(width: 8),
                Text(
                  '$_coins',
                  style: const TextStyle(
                    color: ArenaColors.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PixelButton(
                    label: 'SHOP',
                    onPressed: () async {
                      await Navigator.of(context).pushNamed(ShopScreen.route);
                      _loadCoins();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PixelButton(
                    label: 'UPGRADES',
                    onPressed: () async {
                      await Navigator.of(context).pushNamed(UpgradesScreen.route);
                      _loadCoins();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
