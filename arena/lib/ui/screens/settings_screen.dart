import 'package:flutter/material.dart';

import '../../core/bgm_controller.dart';
import '../../core/constants.dart';
import '../../core/meta_progression.dart';
import '../../core/settings.dart';
import '../../core/sfx_player.dart';
import '../../data/characters.dart';
import '../../game/arena_game.dart';
import '../widgets/pixel_button.dart';
import '../widgets/screen_scaffold.dart';

/// Route arguments for [SettingsScreen]. Passing a live [debugGame] (only
/// done from the arena's Pause Menu, DECISIONS D-025) is what makes the
/// debug section appear — Settings reached from the main menu passes no
/// arguments, so `debugGame` is null and that section doesn't exist there.
class SettingsScreenArgs {
  const SettingsScreenArgs({this.debugGame});
  final ArenaGame? debugGame;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const route = '/settings';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = SettingsRepository();
  final _metaRepo = MetaProgressionRepository();
  Settings? _settings;

  /// DECISIONS D-059: loaded unconditionally (unlike the arena-only debug
  /// tools below, gated on [SettingsScreenArgs.debugGame]) so the currency
  /// debug section works from Settings off the main menu too, where no
  /// `ArenaGame` exists to read a live wallet off of.
  MetaProgression? _meta;

  @override
  void initState() {
    super.initState();
    _repo.load().then((loaded) => setState(() => _settings = loaded));
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final meta = await _metaRepo.load();
    if (!mounted) return;
    setState(() => _meta = meta);
  }

  Future<void> _update(Settings next) async {
    // DECISIONS D-062: unlike SFX volume (read fresh per one-shot play),
    // the BGM stack is already looping -- it needs to react live, not just
    // on the next track that happens to start. Compared before the
    // setState below overwrites `_settings` with `next`.
    if (next.musicVolume != _settings?.musicVolume) {
      BgmController.instance.setMasterVolume(next.musicVolume);
    }
    // DECISIONS D-076: SfxPlayer (button taps and every other one-shot SFX)
    // needs the same live push BGM already gets -- a one-shot fired right
    // after moving this slider should reflect it immediately, same as BGM.
    if (next.sfxVolume != _settings?.sfxVolume) {
      SfxPlayer.instance.setVolumeMultiplier(next.sfxVolume);
    }
    setState(() => _settings = next);
    await _repo.save(next);
  }

  Future<void> _adjustCoins(int delta) async {
    await _metaRepo.debugAdjustCoins(delta);
    _loadMeta();
  }

  Future<void> _adjustGems(int delta) async {
    await _metaRepo.debugAdjustGems(delta);
    _loadMeta();
  }

  Future<void> _resetWallet() async {
    await _metaRepo.debugResetWallet();
    _loadMeta();
  }

  /// Highest `unlockKillThreshold` across `kCharacters` clears every gate in
  /// one tap (`MetaProgressionRepository.debugSetLifetimeKills` never lowers
  /// the real count, so this can't re-lock anything).
  Future<void> _unlockAllCharacters() async {
    final maxThreshold = kCharacters
        .map((c) => c.unlockKillThreshold ?? 0)
        .fold(0, (a, b) => a > b ? a : b);
    await _metaRepo.debugSetLifetimeKills(maxThreshold);
    _loadMeta();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      return const ScreenScaffold(
        title: 'SETTINGS',
        child: Center(
          child: CircularProgressIndicator(color: ArenaColors.accent),
        ),
      );
    }

    final showJoystickSide =
        settings.controlScheme != ControlScheme.dragAnywhere;
    final debugGame =
        (ModalRoute.of(context)?.settings.arguments as SettingsScreenArgs?)
            ?.debugGame;

    return ScreenScaffold(
      title: 'SETTINGS',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _SectionLabel('CONTROL SCHEME'),
          RadioGroup<ControlScheme>(
            groupValue: settings.controlScheme,
            onChanged: (value) =>
                _update(settings.copyWith(controlScheme: value)),
            child: Column(
              children: [
                for (final scheme in ControlScheme.values)
                  RadioListTile<ControlScheme>(
                    value: scheme,
                    activeColor: ArenaColors.accent,
                    title: Text(
                      _controlSchemeLabel(scheme),
                      style: const TextStyle(color: ArenaColors.textPrimary),
                    ),
                  ),
              ],
            ),
          ),
          if (showJoystickSide) ...[
            const SizedBox(height: 16),
            _SectionLabel('JOYSTICK SIDE'),
            RadioGroup<JoystickSide>(
              groupValue: settings.joystickSide,
              onChanged: (value) =>
                  _update(settings.copyWith(joystickSide: value)),
              child: Column(
                children: [
                  for (final side in JoystickSide.values)
                    RadioListTile<JoystickSide>(
                      value: side,
                      activeColor: ArenaColors.accent,
                      title: Text(
                        side == JoystickSide.left ? 'Left' : 'Right',
                        style:
                            const TextStyle(color: ArenaColors.textPrimary),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _SectionLabel('SFX VOLUME'),
          Slider(
            value: settings.sfxVolume.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: ArenaColors.accent,
            label: '${settings.sfxVolume}',
            onChanged: (value) =>
                _update(settings.copyWith(sfxVolume: value.round())),
          ),
          const SizedBox(height: 8),
          _SectionLabel('MUSIC VOLUME'),
          Slider(
            value: settings.musicVolume.toDouble(),
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: ArenaColors.accent,
            label: '${settings.musicVolume}',
            onChanged: (value) =>
                _update(settings.copyWith(musicVolume: value.round())),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: settings.showFps,
            activeThumbColor: ArenaColors.accent,
            title: const Text(
              'Show FPS',
              style: TextStyle(color: ArenaColors.textPrimary),
            ),
            onChanged: (value) => _update(settings.copyWith(showFps: value)),
          ),
          if (_meta case final meta?) ...[
            const SizedBox(height: 24),
            _SectionLabel('DEBUG'),
            const SizedBox(height: 8),
            Text(
              'Coins: ${meta.coins}   Gems: ${meta.gems}',
              style: const TextStyle(
                color: ArenaColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PixelButton(
                    label: '+100 COINS',
                    onPressed: () => _adjustCoins(100),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PixelButton(
                    label: '-100 COINS',
                    onPressed: () => _adjustCoins(-100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PixelButton(
                    label: '+50 GEMS',
                    onPressed: () => _adjustGems(50),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PixelButton(
                    label: '-50 GEMS',
                    onPressed: () => _adjustGems(-50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PixelButton(
                    label: 'RESET WALLET',
                    onPressed: _resetWallet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PixelButton(
                    label: 'UNLOCK ALL CHARACTERS',
                    onPressed: _unlockAllCharacters,
                  ),
                ),
              ],
            ),
            Text(
              'Lifetime kills: ${meta.lifetimeKills} '
              '(unlock thresholds up to '
              '${kCharacters.map((c) => c.unlockKillThreshold ?? 0).fold(0, (a, b) => a > b ? a : b)})',
              style: const TextStyle(color: ArenaColors.textDim, fontSize: 12),
            ),
          ],
          if (debugGame != null) ...[
            const SizedBox(height: 24),
            SwitchListTile(
              value: debugGame.debugGodMode,
              activeThumbColor: ArenaColors.danger,
              title: const Text(
                'God mode',
                style: TextStyle(color: ArenaColors.textPrimary),
              ),
              onChanged: (value) =>
                  setState(() => debugGame.debugGodMode = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: PixelButton(
                    label: 'GRANT LEVEL UP',
                    onPressed: () => setState(debugGame.debugGrantLevelUp),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Queued: ${debugGame.pendingLevelUps} — plays out once you '
              'close the pause menu.',
              style: const TextStyle(
                color: ArenaColors.textDim,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: PixelButton(
                    label: 'END ROUND',
                    onPressed: debugGame.debugEndRound,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Ends the round once you close the pause menu — kills/score/'
              'coins/gems carry over exactly like a real death.',
              style: TextStyle(
                color: ArenaColors.textDim,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _controlSchemeLabel(ControlScheme scheme) {
    switch (scheme) {
      case ControlScheme.floatingJoystick:
        return 'Floating joystick';
      case ControlScheme.fixedJoystick:
        return 'Fixed joystick';
      case ControlScheme.dragAnywhere:
        return 'Drag anywhere';
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: ArenaColors.textDim, letterSpacing: 2),
    );
  }
}
