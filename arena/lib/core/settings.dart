import 'package:shared_preferences/shared_preferences.dart';

import 'game_config.dart';

/// The three control schemes (PRD §7 / DECISIONS D-006). Read once at arena
/// entry — never live-switched mid-round.
enum ControlScheme { floatingJoystick, fixedJoystick, dragAnywhere }

/// Only meaningful for the two joystick schemes.
enum JoystickSide { left, right }

/// Immutable settings snapshot. Persisted via [SettingsRepository].
class Settings {
  const Settings({
    required this.controlScheme,
    required this.joystickSide,
    required this.sfxVolume,
    required this.musicVolume,
    required this.showFps,
  });

  final ControlScheme controlScheme;
  final JoystickSide joystickSide;
  final int sfxVolume; // 0-100
  final int musicVolume; // 0-100
  final bool showFps;

  /// `sfxVolume`/`musicVolume` are `GameConfig`-backed (DECISIONS D-090) —
  /// a developer-editable "starting audio level" for a fresh install, read
  /// from `assets/config/game_config.json`. Only matters until the player
  /// actually touches a slider themselves — [SettingsRepository.load] only
  /// falls back to this when nothing's been saved yet. No longer `const`
  /// for the same reason `kCharacters`/`EnemyStats`/etc. aren't anymore.
  static Settings get defaults => Settings(
    controlScheme: ControlScheme.floatingJoystick,
    joystickSide: JoystickSide.left,
    sfxVolume: GameConfig.instance.startingSfxVolume,
    musicVolume: GameConfig.instance.startingMusicVolume,
    showFps: false,
  );

  Settings copyWith({
    ControlScheme? controlScheme,
    JoystickSide? joystickSide,
    int? sfxVolume,
    int? musicVolume,
    bool? showFps,
  }) {
    return Settings(
      controlScheme: controlScheme ?? this.controlScheme,
      joystickSide: joystickSide ?? this.joystickSide,
      sfxVolume: sfxVolume ?? this.sfxVolume,
      musicVolume: musicVolume ?? this.musicVolume,
      showFps: showFps ?? this.showFps,
    );
  }
}

/// Reads/writes [Settings] to `SharedPreferences`. No state-management
/// library (DECISIONS D-002) — screens own their own copy and persist on
/// every change, so "survives an app kill" falls out for free.
class SettingsRepository {
  static const _kControlScheme = 'settings.controlScheme';
  static const _kJoystickSide = 'settings.joystickSide';
  static const _kSfxVolume = 'settings.sfxVolume';
  static const _kMusicVolume = 'settings.musicVolume';
  static const _kShowFps = 'settings.showFps';

  Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Settings(
      controlScheme: ControlScheme.values[
          prefs.getInt(_kControlScheme) ??
              Settings.defaults.controlScheme.index],
      joystickSide: JoystickSide.values[
          prefs.getInt(_kJoystickSide) ??
              Settings.defaults.joystickSide.index],
      sfxVolume: prefs.getInt(_kSfxVolume) ?? Settings.defaults.sfxVolume,
      musicVolume:
          prefs.getInt(_kMusicVolume) ?? Settings.defaults.musicVolume,
      showFps: prefs.getBool(_kShowFps) ?? Settings.defaults.showFps,
    );
  }

  Future<void> save(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kControlScheme, settings.controlScheme.index);
    await prefs.setInt(_kJoystickSide, settings.joystickSide.index);
    await prefs.setInt(_kSfxVolume, settings.sfxVolume);
    await prefs.setInt(_kMusicVolume, settings.musicVolume);
    await prefs.setBool(_kShowFps, settings.showFps);
  }
}
