import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import 'settings.dart';

/// Background music (DECISIONS D-062, simplified by D-064, track swapped by
/// D-073, playback mode fixed by D-075) —
/// `assets/audio/core/electric-eel-fishing.ogg` looping for the whole app
/// lifetime, "the main BGM playing everywhere." The layered
/// Core/boss/death stack (3/1/4.wav) from D-062 was pulled back out
/// (developer's explicit call, 2026-09-10: "Remove all of the BGM, and
/// leave only the main one") — those, and the old base track (2.wav,
/// replaced by this one), are no longer referenced anywhere in this class.
///
/// Plays via [FlameAudio.loopLongAudio] (`PlayerMode.mediaPlayer`), not
/// [FlameAudio.loop] (`PlayerMode.lowLatency`) — DECISIONS D-075, developer
/// report: "static noise when BGM is playing" the moment D-073 switched
/// the track to a full OGG music file. `lowLatency` decodes through
/// `SoundPool`, which Android reserves for short SFX; asking it to hold a
/// whole music track's decoded PCM is exactly the kind of case known to
/// produce audible static/distortion on real devices and emulators alike.
/// `loopLongAudio`'s own doc comment does warn it has "an audio gap between
/// loop iterations" on Android (the trade-off D-073 originally picked
/// `loop` to avoid) — clean audio with a small seam beats a perfectly
/// seamless loop full of static, so this reverses that call. Revisit if the
/// seam turns out to be audible in practice.
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

  static const _basePath = 'core/electric-eel-fishing.ogg';

  /// The base layer fades in over this long on first start (developer's
  /// original call for D-062's layers, kept here since an instant full-
  /// volume start on app boot would be the odd one out against everything
  /// else being a smooth fade).
  static const _fadeDuration = Duration(milliseconds: 2500);
  static const _fadeSteps = 25;

  AudioPlayer? _basePlayer;

  double _masterVolume = Settings.defaults.musicVolume / 100;

  /// True while the app is backgrounded (DECISIONS D-086) — tracked
  /// separately from `_basePlayer == null` because [start] is itself async
  /// and there's a real window (cold launch, then an immediate
  /// minimize/home-press before `FlameAudio.loopLongAudio` finishes
  /// preparing) where [pause] can fire while `_basePlayer` is still null,
  /// see it as a no-op, and then have [start] finish moments later and
  /// begin playing anyway — same "music kept playing when minimized" bug,
  /// just from the other direction. [start] checks this flag once the
  /// player actually exists and pauses immediately instead of fading in if
  /// it's set.
  bool _pausedByLifecycle = false;

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
    _basePlayer = await FlameAudio.loopLongAudio(_basePath, volume: 0);
    if (_pausedByLifecycle) {
      // The app was backgrounded while this was still starting up (see
      // `_pausedByLifecycle`'s doc) -- skip the fade-in cosmetic and land
      // paused at the real target volume, so a later `resume()` plays at
      // the right level instead of silently at the 0 this started at.
      await _basePlayer!.setVolume(_masterVolume);
      await _basePlayer!.pause();
      return;
    }
    unawaited(_fadeVolume(_basePlayer!, _masterVolume));
  }

  /// Called from `ArenaApp`'s `didChangeAppLifecycleState` when the app is
  /// backgrounded (minimized, screen locked, task-switched away from) —
  /// developer report: "music kept playing on device when minimizing the
  /// game." `audioplayers` doesn't stop on its own when Flutter loses
  /// visibility (no OS audio-focus handling is wired up), so this has to be
  /// explicit. `pause()`, not `stop()`, so [resume] picks the track back up
  /// exactly where it left off rather than restarting it.
  Future<void> pause() async {
    _pausedByLifecycle = true;
    await _basePlayer?.pause();
  }

  /// The other half of [pause] — called on `AppLifecycleState.resumed`.
  Future<void> resume() async {
    _pausedByLifecycle = false;
    await _basePlayer?.resume();
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
