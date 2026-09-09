import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import 'settings.dart';

/// Layered background music (DECISIONS D-062) — `assets/audio/core/1..4.wav`,
/// all authored at the same 162 BPM and (near enough) identical loop length,
/// meant to be stacked rather than swapped: `2.wav` is the permanent base
/// layer (menus and the arena alike — "playing everywhere"); `3.wav` layers
/// in on top of it for the arena's "Core" phase (actual mob-fighting);
/// `1.wav` layers in further on top once a boss is up; `4.wav` takes over
/// entirely on a real death.
///
/// A process-wide singleton, not tied to any one screen or `ArenaGame`
/// instance — CLAUDE.md §4.5's "`ArenaGame` owns round state" is about a
/// single *round*; this needs to keep playing across every menu screen and
/// survive `ArenaGame` itself being torn down and rebuilt between rounds,
/// same category of "outlives any one screen" state as `Settings`/
/// `MetaProgression`. Uses `package:flame_audio/flame_audio.dart`'s own
/// re-export of `AudioPlayer` (`audioplayers`, already a transitive
/// dependency of the one dependency this project already has for audio) —
/// not a new package, `flame_audio`'s own `FlameAudio.loop`/`Bgm` helpers
/// only ever manage a single track, not several independently-faded layers
/// stacked over each other at once.
class BgmController {
  BgmController._();
  static final BgmController instance = BgmController._();

  static const _basePath = 'core/2.wav';
  static const _corePath = 'core/3.wav';
  static const _bossPath = 'core/1.wav';
  static const _deathPath = 'core/4.wav';

  /// Every new/removed layer fades over this long (developer's call:
  /// "fade it in from 0%-100% in over like 2-3 seconds") — used
  /// symmetrically for fade-outs too (not asked for explicitly, but an
  /// abrupt cut on top of everything else being a smooth crossfade would
  /// be the odd one out).
  static const _fadeDuration = Duration(milliseconds: 2500);
  static const _fadeSteps = 25;

  /// DECISIONS D-062: "3.wav... at 25% less volume than 2.wav" / "1.wav...
  /// with 35% less volume than 2.wav" — relative to the base layer's own
  /// volume, not an independent number.
  static const _coreRelativeVolume = 0.75;
  static const _bossRelativeVolume = 0.65;
  static const _deathRelativeVolume = 1.0;

  AudioPlayer? _basePlayer;
  AudioPlayer? _corePlayer;
  AudioPlayer? _bossPlayer;
  AudioPlayer? _deathPlayer;

  // Bumped every time a layer is (re)started or stopped -- the async
  // fade loops below capture their own generation and bail out the moment
  // it no longer matches, so a rapid enter/leave-core (or similar) can't
  // leave two overlapping fades fighting over the same slot's volume.
  int _coreGen = 0;
  int _bossGen = 0;
  int _deathGen = 0;

  double _masterVolume = Settings.defaults.musicVolume / 100;

  /// Read once at app boot (`ArenaApp`'s `initState`) before [start] is
  /// ever called, and again live any time the player changes the Music
  /// Volume slider (`SettingsScreen._update`) — a looping BGM stack, unlike
  /// one-shot SFX, needs to actually react while it's already playing.
  void setMasterVolume(int musicVolumePercent) {
    _masterVolume = musicVolumePercent.clamp(0, 100) / 100;
    _basePlayer?.setVolume(_masterVolume);
    _corePlayer?.setVolume(_masterVolume * _coreRelativeVolume);
    _bossPlayer?.setVolume(_masterVolume * _bossRelativeVolume);
    _deathPlayer?.setVolume(_masterVolume * _deathRelativeVolume);
  }

  /// Starts the permanent base layer. Called once, from `ArenaApp`'s
  /// `initState` — every other layer only ever starts on top of this one.
  Future<void> start() async {
    if (_basePlayer != null) return; // already running -- app-lifetime singleton
    _basePlayer = await FlameAudio.loop(_basePath, volume: 0);
    unawaited(_fadeVolume(_basePlayer!, _masterVolume, generation: -1));
  }

  /// Entering the arena's "Core" phase (DECISIONS D-062) — layers `3.wav`
  /// in at [_coreRelativeVolume] of the base layer's volume, synced to the
  /// base layer's own loop boundary (see [_startSyncedLayer]).
  Future<void> enterCore() async {
    if (_corePlayer != null) return;
    final gen = ++_coreGen;
    final player = await _startSyncedLayer(_corePath);
    if (gen != _coreGen) {
      // Left Core again before this even finished starting -- don't leave
      // an orphaned player fading itself in on top of nothing.
      unawaited(player.stop());
      unawaited(player.dispose());
      return;
    }
    _corePlayer = player;
    unawaited(
      _fadeVolume(
        player,
        _masterVolume * _coreRelativeVolume,
        generation: gen,
        currentGen: () => _coreGen,
      ),
    );
  }

  /// A boss just spawned — layers `1.wav` in at [_bossRelativeVolume] of
  /// the base layer's volume, synced the same way [enterCore] is.
  Future<void> bossSpawned() async {
    if (_bossPlayer != null) return;
    final gen = ++_bossGen;
    final player = await _startSyncedLayer(_bossPath);
    if (gen != _bossGen) {
      unawaited(player.stop());
      unawaited(player.dispose());
      return;
    }
    _bossPlayer = player;
    unawaited(
      _fadeVolume(
        player,
        _masterVolume * _bossRelativeVolume,
        generation: gen,
        currentGen: () => _bossGen,
      ),
    );
  }

  /// The boss is gone (killed, or the round ended without one already
  /// fading out) — fades `1.wav` back out and stops it.
  Future<void> bossCleared() async {
    final player = _bossPlayer;
    _bossPlayer = null;
    final gen = ++_bossGen;
    await _fadeOutAndStop(player, generation: gen, currentGen: () => _bossGen);
  }

  /// A real death (DECISIONS D-062, "starts playing when you die" —
  /// gated by the caller on an actual death, not every round-over) — fades
  /// every layer currently up back to silence and crossfades `4.wav` in on
  /// top, synced to the base layer's loop boundary same as any other layer.
  Future<void> died() async {
    final corePlayer = _corePlayer;
    _corePlayer = null;
    final bossPlayer = _bossPlayer;
    _bossPlayer = null;
    unawaited(
      _fadeOutAndStop(corePlayer, generation: ++_coreGen, currentGen: () => _coreGen),
    );
    unawaited(
      _fadeOutAndStop(bossPlayer, generation: ++_bossGen, currentGen: () => _bossGen),
    );

    final gen = ++_deathGen;
    final player = await _startSyncedLayer(_deathPath);
    if (gen != _deathGen) {
      unawaited(player.stop());
      unawaited(player.dispose());
      return;
    }
    _deathPlayer = player;
    unawaited(
      _fadeVolume(
        player,
        _masterVolume * _deathRelativeVolume,
        generation: gen,
        currentGen: () => _deathGen,
      ),
    );
  }

  /// Leaving the arena back to a menu (either Round Over's or the Pause
  /// Menu's MAIN MENU button) — fades every non-base layer out, leaving
  /// just `2.wav`, "playing everywhere."
  Future<void> leaveArena() async {
    final corePlayer = _corePlayer;
    _corePlayer = null;
    final bossPlayer = _bossPlayer;
    _bossPlayer = null;
    final deathPlayer = _deathPlayer;
    _deathPlayer = null;
    await Future.wait([
      _fadeOutAndStop(corePlayer, generation: ++_coreGen, currentGen: () => _coreGen),
      _fadeOutAndStop(bossPlayer, generation: ++_bossGen, currentGen: () => _bossGen),
      _fadeOutAndStop(deathPlayer, generation: ++_deathGen, currentGen: () => _deathGen),
    ]);
  }

  /// Starts [path] looping at 0 volume, first waiting for the base layer's
  /// current loop to actually finish (DECISIONS D-062: "must start at the
  /// next cue loop point of the one that's playing already... otherwise
  /// they wont be in sync") — every track shares the same tempo and loop
  /// length, so starting any new layer at the exact instant the base layer
  /// wraps back to its own position 0 keeps every layer in phase with each
  /// other from that point on, not just approximately in time.
  Future<AudioPlayer> _startSyncedLayer(String path) async {
    await _waitForBaseLoopBoundary();
    return FlameAudio.loop(path, volume: 0);
  }

  Future<void> _waitForBaseLoopBoundary() async {
    final base = _basePlayer;
    if (base == null) return; // nothing to sync to yet -- start immediately
    final duration = await base.getDuration();
    final position = await base.getCurrentPosition();
    if (duration == null || position == null) return; // can't tell -- best effort
    final remaining = duration - position;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  /// Ramps [player]'s volume from 0 up to [target] over [_fadeDuration].
  /// [generation]/[currentGen] let a layer that's been stopped/restarted
  /// mid-fade abort cleanly instead of racing a newer fade for the same
  /// slot (the base layer, [generation] `-1`, never gets stopped/restarted
  /// so it has nothing to race and skips the check entirely).
  Future<void> _fadeVolume(
    AudioPlayer player,
    double target, {
    required int generation,
    int Function()? currentGen,
  }) async {
    final stepDelay = Duration(
      milliseconds: _fadeDuration.inMilliseconds ~/ _fadeSteps,
    );
    for (var i = 1; i <= _fadeSteps; i++) {
      await Future.delayed(stepDelay);
      if (currentGen != null && currentGen() != generation) return;
      await player.setVolume(target * i / _fadeSteps);
    }
  }

  /// The reverse of [_fadeVolume] — ramps down from wherever [player]'s
  /// volume currently is, then actually stops/disposes it.
  Future<void> _fadeOutAndStop(
    AudioPlayer? player, {
    required int generation,
    int Function()? currentGen,
  }) async {
    if (player == null) return;
    final startVolume = player.volume;
    final stepDelay = Duration(
      milliseconds: _fadeDuration.inMilliseconds ~/ _fadeSteps,
    );
    for (var i = _fadeSteps - 1; i >= 0; i--) {
      await Future.delayed(stepDelay);
      if (currentGen != null && currentGen() != generation) return;
      await player.setVolume(startVolume * i / _fadeSteps);
    }
    await player.stop();
    await player.dispose();
  }
}
