import 'dart:async';
import 'dart:math';

import 'package:flame_audio/flame_audio.dart';

import 'constants.dart';
import 'settings.dart';

/// App-wide one-shot SFX player (DECISIONS D-076, pooled playback D-079) —
/// a second singleton alongside `BgmController` (`core/bgm_controller.dart`),
/// same "read Settings once at boot, update live off the slider" shape, but
/// for short one-shot sounds instead of the one looping BGM track.
/// Centralized here rather than on `ArenaGame` (which already has its own
/// tiny `_playSfx` for the original explosion/death SFX, DECISIONS D-044)
/// because most of these need to play from plain menu screens that have no
/// live `ArenaGame` at all — every button's tap sound, most obviously.
///
/// DECISIONS D-079 ("sounds not synced to player actions," "the game
/// froze — I suspect is the sounds," BGM randomly stopping/restarting,
/// persistent static): the original version of this class called
/// `FlameAudio.play(file, ...)` fresh on every single trigger, which builds
/// a brand-new native `AudioPlayer` and never disposes it — pooling
/// (`AudioPool`) fixed the leak, but D-079's pools used the default
/// `PlayerMode.mediaPlayer`, which turned out to be the wrong backend for
/// this load and caused a *worse* problem (DECISIONS D-081, "sound got
/// really desynced... 5-6 seconds behind... the game crashed"). Confirmed
/// from an actual device log, not just theory:
/// - A real `FATAL EXCEPTION` killed the app: `MediaPlayer.prepareAsync`
///   threw `IllegalStateException` from inside `WrappedPlayer.onCompletion
///   -> stop() -> prepareAsync()` — `audioplayers`' own mediaPlayer-mode
///   pool tries to re-prepare a `MediaPlayer` for reuse the instant it
///   finishes playing, and that reset raced badly under the trigger rate
///   footsteps alone produce (~3/sec).
/// - Separately, `BgmController`'s own player (also `PlayerMode.
///   mediaPlayer`, D-075) logged `TimeoutException after 0:00:30: Future
///   not completed` inside `AudioPlayer._completePrepared` — the exact
///   "BGM stops and restarts" symptom, caused by dozens of *other*
///   `MediaPlayer` instances (the SFX pools) all competing for the same
///   native media pipeline BGM's own single long-lived stream needs.
/// `PlayerMode.mediaPlayer` wraps Android's heavyweight `MediaPlayer` —
/// built for one long-lived stream (exactly right for BGM), not rapid
/// repeated short clips. `PlayerMode.lowLatency` wraps `SoundPool`, the
/// Android API actually designed for this load (pre-decoded, no
/// prepare-per-play state machine to race) — every pooled sound below now
/// explicitly requests it. The one real cost: `AudioPool`'s own doc warns
/// a `lowLatency` pool's players are *not* auto-returned to the pool on
/// completion (that auto-return is exactly the `onCompletion ->
/// prepareAsync()` codepath that crashed), so [_playPooledAsync] returns
/// each one manually after a fixed delay generous enough for any of these
/// short clips to have finished.
class SfxPlayer {
  SfxPlayer._();
  static final SfxPlayer instance = SfxPlayer._();

  final Random _random = Random();

  double _volumeMultiplier = Settings.defaults.sfxVolume / 100;

  /// Read once at app boot (`ArenaApp.initState`, alongside `BgmController.
  /// setMasterVolume`) and again live any time the SFX Volume slider moves
  /// (`SettingsScreen._update`).
  void setVolumeMultiplier(int sfxVolumePercent) {
    _volumeMultiplier = sfxVolumePercent.clamp(0, 100) / 100;
  }

  /// Every one-shot here is capped the same way `ArenaGame._playSfx`'s
  /// original two are (`kSfxVolumeCap`, "make sure they are not that
  /// loud," DECISIONS D-044) — [relativeVolume] scales further down from
  /// there for a sound that's either especially frequent (footsteps, the
  /// chest-card flicker) or just shouldn't compete with the rest.
  double _effectiveVolume(double relativeVolume) =>
      _volumeMultiplier * kSfxVolumeCap * relativeVolume;

  /// One pool per sound file, created the first time it's actually needed
  /// (or up front by [preload]) and kept for the app's whole lifetime —
  /// same "outlives any one screen" shape `BgmController`'s single player
  /// already has. Built via `AudioPool.create` directly (not `FlameAudio.
  /// createPool`, which doesn't expose `playerMode` at all) so every pool
  /// explicitly runs `PlayerMode.lowLatency` (DECISIONS D-081) — the plain
  /// `'assets/audio/$file'` path matches `FlameAudio.audioCache`'s own
  /// `'assets/audio/'` prefix without needing to depend on that mutable
  /// global's current value.
  final Map<String, Future<AudioPool>> _pools = {};

  /// How long a pooled `lowLatency` player is held before being returned to
  /// its pool (DECISIONS D-081) — `lowLatency` pools skip the automatic
  /// return-on-completion `mediaPlayer` pools get (see class doc), so this
  /// does it by hand instead. Generous for every clip actually pooled here
  /// (all well under a second); a little late is harmless; the pool just
  /// creates one more player on demand in the meantime.
  static const _returnDelay = Duration(seconds: 2);

  Future<AudioPool> _poolFor(
    String file, {
    int minPlayers = 2,
    int maxPlayers = 4,
  }) {
    return _pools.putIfAbsent(
      file,
      () => AudioPool.create(
        source: AssetSource('assets/audio/$file'),
        minPlayers: minPlayers,
        maxPlayers: maxPlayers,
        playerMode: PlayerMode.lowLatency,
      ),
    );
  }

  /// Every file [_playPooled] can be asked to play — kept as one list so
  /// [preload] can warm them all without repeating each path a second time.
  static const _pooledFiles = [
    'core/sfx_tap_input.ogg',
    'core/sfx_player-damage.ogg',
    'core/player-projectile-shoot.wav',
    'core/level-up-sound.wav',
    'core/step-concrete-one.ogg',
    'core/step-concrete-two.ogg',
    'core/chest-card-chosen.wav',
  ];

  /// Kicks off every pool's creation up front (DECISIONS D-079) — called
  /// once at app boot (`ArenaApp.initState`, alongside `BgmController.
  /// start`) so the very first tap/footstep/shot in a session doesn't pay
  /// the one-time pool-warmup cost itself.
  void preload() {
    for (final file in _pooledFiles) {
      unawaited(_poolFor(file));
    }
  }

  /// Sound files with a play already in flight (DECISIONS D-081) — a
  /// defense-in-depth cap on top of the `playerMode` fix itself: a trigger
  /// that arrives while the previous one for the *same* file is still
  /// mid-setup is simply dropped rather than queued, so a burst can never
  /// pile up regardless of how slow a device's audio stack is that moment.
  /// Alternating sounds (the two footstep files) aren't affected — each
  /// has its own independent key.
  final Set<String> _inFlight = {};

  void _playPooled(String file, {double relativeVolume = 1.0}) {
    final volume = _effectiveVolume(relativeVolume);
    if (volume <= 0) return;
    if (!_inFlight.add(file)) return; // already starting -- drop, don't queue
    unawaited(_playPooledAsync(file, volume));
  }

  Future<void> _playPooledAsync(String file, double volume) async {
    try {
      final pool = await _poolFor(file);
      final stop = await pool.start(volume: volume);
      // `lowLatency` pools don't auto-return their player on completion
      // (see class doc) -- this does it by hand once the clip has surely
      // finished.
      unawaited(Future.delayed(_returnDelay, stop));
    } finally {
      _inFlight.remove(file);
    }
  }

  /// "Basically all buttons should have that sound" (DECISIONS D-076) —
  /// played by the shared button widgets (`PixelButton`/`CarouselArrow`/
  /// `ScreenScaffold`'s back button) and `ui/widgets/tap_sfx.dart`'s
  /// `withTapSfx` wrapper for every other raw button in the app. Quieter
  /// than most (`_tapRelativeVolume`) — it fires on nearly every
  /// interaction, so it can't compete with rarer, more important cues.
  static const _tapRelativeVolume = 0.5;
  void playTap() =>
      _playPooled('core/sfx_tap_input.ogg', relativeVolume: _tapRelativeVolume);

  /// `PlayerComponent.takeDamage` — every hit that actually lands.
  void playDamage() => _playPooled('core/sfx_player-damage.ogg');

  /// `PlayerComponent.playFire` only (DECISIONS D-076, "not power-ups") —
  /// that method is the one shared hook every base `AttackBehavior`
  /// (`ProjectileAttack`/`KnifeAttack`/`SpiralFireAttack`/
  /// `WardenSlamAttack`) already calls once per shot/swing; Ray/Thunder/
  /// Aura/Mirror never call it, so this can't leak into any of them.
  void playProjectileShoot() => _playPooled('core/player-projectile-shoot.wav');

  /// `ArenaGame.grantXp`/`debugGrantLevelUp`, once per level actually
  /// gained.
  void playLevelUp() => _playPooled('core/level-up-sound.wav');

  /// `PlayerComponent`'s footstep timer, alternating true/false per step —
  /// quiet and frequent, same reasoning as the tap SFX, and the single
  /// highest-frequency sound in the app (the original motivation for
  /// pooling in the first place).
  static const _footstepRelativeVolume = 0.45;
  void playFootstep(bool alternate) => _playPooled(
    alternate ? 'core/step-concrete-two.ogg' : 'core/step-concrete-one.ogg',
    relativeVolume: _footstepRelativeVolume,
  );

  /// The chest reveal's landing payoff (`_ChestRevealOverlayState`) — once,
  /// when the spin actually stops on the real card.
  void playChestCardChosen() => _playPooled('core/chest-card-chosen.wav');

  /// The chest reveal's per-swap flicker (DECISIONS D-076, developer's
  /// spec verbatim: "play it once with every card swap and change its
  /// pitch each time... make sure each sound interrupts the other one so
  /// they don't play over another. Make sure the volume isn't too loud").
  /// Deliberately *not* pooled like everything else above — pitch varies
  /// per call, which a pool's fixed, pre-`setSource`'d players don't
  /// support. DECISIONS D-081: [_cardSelectBusy] guards against the spin's
  /// fastest steps (down to 45ms apart) firing a second call before the
  /// first one's own stop-dispose-create-play-repitch chain finishes —
  /// without it, two overlapping calls could each create a player while
  /// racing to read/write `_cardSelectPlayer`, which is exactly the kind
  /// of unguarded concurrent native-player churn that crashed the app
  /// elsewhere in this class (see the class doc). A dropped swap just
  /// means one flicker step plays silently — imperceptible against 22+
  /// steps, and far safer than racing.
  static const _cardSelectRelativeVolume = 0.6;
  static const _cardSelectMinPitch = 0.85;
  static const _cardSelectMaxPitch = 1.3;
  AudioPlayer? _cardSelectPlayer;
  bool _cardSelectBusy = false;

  void playChestCardSelect() {
    final volume = _effectiveVolume(_cardSelectRelativeVolume);
    if (volume <= 0) return;
    if (_cardSelectBusy) return;
    _cardSelectBusy = true;
    unawaited(_playChestCardSelect(volume));
  }

  Future<void> _playChestCardSelect(double volume) async {
    try {
      // Cut the previous swap's sound off outright before starting the
      // next one -- "make sure each sound interrupts the other" -- rather
      // than reusing one held player, which `setPlaybackRate`'s own doc
      // warns must be called *after* `play()`/`resume()`, not before.
      final previous = _cardSelectPlayer;
      _cardSelectPlayer = null;
      await previous?.stop();
      unawaited(previous?.dispose());

      final player = AudioPlayer()..audioCache = FlameAudio.audioCache;
      await player.play(
        AssetSource('core/chest-card-select.wav'),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
      final pitch =
          _cardSelectMinPitch +
          _random.nextDouble() * (_cardSelectMaxPitch - _cardSelectMinPitch);
      await player.setPlaybackRate(pitch);
      _cardSelectPlayer = player;
    } finally {
      _cardSelectBusy = false;
    }
  }
}
