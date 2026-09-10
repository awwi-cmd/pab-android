import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import 'settings.dart';

/// Background music (DECISIONS D-062, simplified by D-064) —
/// `assets/audio/core/2.wav` looping for the whole app lifetime, "the main
/// BGM playing everywhere." The layered Core/boss/death stack (3/1/4.wav)
/// from D-062 was pulled back out (developer's explicit call, 2026-09-10:
/// "Remove all of the BGM, and leave only the main one") — the 3 extra
/// layer tracks are no longer referenced anywhere in this class.
///
/// A process-wide singleton, not tied to any one screen or `ArenaGame`
/// instance — CLAUDE.md §4.5's "`ArenaGame` owns round state" is about a
/// single *round*; this needs to keep playing across every menu screen and
/// survive `ArenaGame` itself being torn down and rebuilt between rounds,
/// same category of "outlives any one screen" state as `Settings`/
/// `MetaProgression`. Uses `package:flame_audio/flame_audio.dart`'s own
/// re-export of `AudioPlayer` (`audioplayers`, already a transitive
/// dependency of the one dependency this project already has for audio) —
/// not a new package.
class BgmController {
  BgmController._();
  static final BgmController instance = BgmController._();

  static const _basePath = 'core/2.wav';

  /// The base layer fades in over this long on first start (developer's
  /// original call for D-062's layers, kept here since an instant full-
  /// volume start on app boot would be the odd one out against everything
  /// else being a smooth fade).
  static const _fadeDuration = Duration(milliseconds: 2500);
  static const _fadeSteps = 25;

  AudioPlayer? _basePlayer;

  double _masterVolume = Settings.defaults.musicVolume / 100;

  /// Read once at app boot (`ArenaApp`'s `initState`) before [start] is
  /// ever called, and again live any time the player changes the Music
  /// Volume slider (`SettingsScreen._update`) — a looping BGM, unlike
  /// one-shot SFX, needs to actually react while it's already playing.
  void setMasterVolume(int musicVolumePercent) {
    _masterVolume = musicVolumePercent.clamp(0, 100) / 100;
    _basePlayer?.setVolume(_masterVolume);
  }

  /// Starts the (only) BGM layer. Called once, from `ArenaApp`'s
  /// `initState`.
  Future<void> start() async {
    if (_basePlayer != null) return; // already running -- app-lifetime singleton
    _basePlayer = await FlameAudio.loop(_basePath, volume: 0);
    unawaited(_fadeVolume(_basePlayer!, _masterVolume));
  }

  /// Ramps [player]'s volume from 0 up to [target] over [_fadeDuration].
  Future<void> _fadeVolume(AudioPlayer player, double target) async {
    final stepDelay = Duration(
      milliseconds: _fadeDuration.inMilliseconds ~/ _fadeSteps,
    );
    for (var i = 1; i <= _fadeSteps; i++) {
      await Future.delayed(stepDelay);
      await player.setVolume(target * i / _fadeSteps);
    }
  }
}
