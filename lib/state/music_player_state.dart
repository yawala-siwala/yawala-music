import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/model.dart';
import '../native/platform_bindings.dart';

/// How playback behaves when a track finishes.
enum RepeatMode { off, all, one }

/// Reactive player state machine for Yawala Music.
///
/// Owns the queue, transport state and background-service synchronisation.
/// All native traffic flows through the [MusicNativeBinding] (which wraps
/// core's [NativeChannelGateway](package:yawala_core)), so every platform
/// call degrades to a safe fallback instead of throwing.
///
/// The UI drives wall-clock progression by calling [tick] (once per second
/// from a timer widget) which keeps the machine fully deterministic in
/// tests - no hidden timers inside the state.
class MusicPlayerState extends ChangeNotifier {
  MusicPlayerState({
    required MusicNativeBinding native,
    Random? random,
    AudioPlaybackBinding? playback,
  })  : _native = native,
        _random = random ?? Random(),
        _playback = playback;

  final MusicNativeBinding _native;
  final Random _random;

  /// Optional real audio engine. When present (and media actually prepared),
  /// positions come from the platform player instead of the simulated
  /// one-second clock.
  final AudioPlaybackBinding? _playback;
  bool _playbackPrepared = false;
  String? _playbackLoadedPath;

  List<Track> _queue = const <Track>[];
  int? _currentIndex;
  bool _isPlaying = false;
  bool _isShuffling = false;
  RepeatMode _repeatMode = RepeatMode.off;
  Duration _position = Duration.zero;
  bool _sessionActivated = false;
  bool _backgroundServiceRunning = false;

  /// In-flight boot jobs, so rapid track switching (interleaved `play()`
  /// calls before the first native round-trip resolves) activates the
  /// session and starts the service exactly once instead of racing.
  Future<void>? _sessionActivationJob;
  Future<void>? _serviceStartJob;

  /// Tracks available for playback, in queue order.
  List<Track> get queue => List.unmodifiable(_queue);

  /// The track loaded into the playhead, if any.
  Track? get currentTrack =>
      _currentIndex == null || _queue.isEmpty ? null : _queue[_currentIndex!];

  int? get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  bool get isShuffling => _isShuffling;
  RepeatMode get repeatMode => _repeatMode;
  Duration get position => _position;
  Duration get duration => currentTrack?.duration ?? Duration.zero;
  bool get isBackgroundServiceRunning => _backgroundServiceRunning;
  bool get hasQueue => _queue.isNotEmpty;

  /// Replaces the queue and parks the playhead at [startIndex] (paused).
  void loadQueue(List<Track> tracks, {int startIndex = 0}) {
    _queue = List.unmodifiable(tracks);
    _currentIndex = _queue.isEmpty
        ? null
        : (startIndex < 0
            ? 0
            : (startIndex >= _queue.length ? _queue.length - 1 : startIndex));
    _position = Duration.zero;
    _isPlaying = false;
    notifyListeners();
  }

  /// Advances the playhead once per second. With a real engine attached and
  /// media prepared, the position is read from the platform player;
  /// otherwise the deterministic simulated clock advances by [step] (also
  /// the fallback when the real source failed to load). Auto-advances the
  /// queue when a track finishes.
  void tick({Duration step = const Duration(seconds: 1)}) {
    if (!_isPlaying || _currentIndex == null || _queue.isEmpty) {
      return;
    }
    if (_playback != null && _playbackPrepared) {
      unawaited(_syncRealPosition());
      return;
    }
    final track = _queue[_currentIndex!];
    final updated = _position + step;
    if (updated >= track.duration) {
      if (_repeatMode == RepeatMode.one) {
        _position = Duration.zero;
        notifyListeners();
        return;
      }
      unawaited(next());
      return;
    }
    _position = updated;
    notifyListeners();
  }

  /// Reads the wall-clock position from the real engine and keeps the
  /// transport (repeat modes, queue auto-advance) in sync with it.
  Future<void> _syncRealPosition() async {
    final binding = _playback;
    if (binding == null) {
      return;
    }
    final ms = await binding.position();
    if (!_isPlaying || _currentIndex == null || _queue.isEmpty) {
      return;
    }
    if (ms == null) {
      // Engine lost its media (unplugged source, error): keep going on the
      // simulated clock rather than freezing.
      _playbackPrepared = false;
      notifyListeners();
      return;
    }
    final track = _queue[_currentIndex!];
    final position = Duration(milliseconds: ms);
    if (position >= track.duration) {
      if (_repeatMode == RepeatMode.one) {
        _position = Duration.zero;
        await binding.seek(0);
        notifyListeners();
        return;
      }
      await next();
      return;
    }
    _position = position;
    notifyListeners();
  }

  /// Prepares/resumes the real engine for the current track. Re-prepares
  /// only when the loaded source actually changed.
  Future<void> _syncPlaybackEngine() async {
    final binding = _playback;
    final track = currentTrack;
    if (binding == null || track == null) {
      return;
    }
    if (_playbackLoadedPath == track.filePath) {
      await binding.play();
      return;
    }
    final ready = await binding.prepare(track.filePath);
    _playbackLoadedPath = ready ? track.filePath : null;
    _playbackPrepared = ready;
    if (ready) {
      await binding.play();
    }
  }

  /// Starts (or resumes) playback, syncing the audio session, the
  /// background service and the lock-screen media controls.
  Future<void> play() async {
    if (_queue.isEmpty || _currentIndex == null) {
      return;
    }
    await _ensureSessionActivated();
    await _ensureBackgroundService();
    _isPlaying = true;
    await _syncPlaybackEngine();
    notifyListeners();
    await _syncMediaControls();
  }

  /// Pauses playback and updates the media controls.
  Future<void> pause() async {
    if (!_isPlaying) {
      return;
    }
    _isPlaying = false;
    await _playback?.pause();
    notifyListeners();
    await _syncMediaControls();
  }

  /// Toggles between play and pause.
  Future<void> togglePlayPause() => _isPlaying ? pause() : play();

  /// Jumps to the track at [index] and starts playing it.
  Future<void> selectTrack(int index) async {
    if (index < 0 || index >= _queue.length) {
      return;
    }
    _currentIndex = index;
    _position = Duration.zero;
    notifyListeners();
    await play();
  }

  /// Skips forward, honouring shuffle and repeat modes. At the end of the
  /// queue with repeat off, playback stops instead of wrapping.
  Future<void> next() async {
    if (_queue.isEmpty || _currentIndex == null) {
      return;
    }
    final nextIndex = _resolveNextIndex();
    if (nextIndex == null) {
      await _stopAtEndOfQueue();
      return;
    }
    _currentIndex = nextIndex;
    _position = Duration.zero;
    notifyListeners();
    await play();
  }

  /// Restarts the current track when more than three seconds have elapsed,
  /// otherwise skips to the previous track.
  Future<void> previous() async {
    if (_queue.isEmpty || _currentIndex == null) {
      return;
    }
    if (_position > const Duration(seconds: 3)) {
      _position = Duration.zero;
      notifyListeners();
      return;
    }
    var target = _currentIndex! - 1;
    if (target < 0) {
      target = _repeatMode == RepeatMode.all ? _queue.length - 1 : 0;
    }
    _currentIndex = target;
    _position = Duration.zero;
    notifyListeners();
    await play();
  }

  /// Seeks the playhead, clamped to the current track's duration. When the
  /// real engine is prepared the seek is forwarded to the platform player.
  void seekTo(Duration position) {
    final limit = duration;
    _position = position < Duration.zero
        ? Duration.zero
        : (position > limit ? limit : position);
    if (_playback != null && _playbackPrepared) {
      unawaited(_playback.seek(_position.inMilliseconds));
    }
    notifyListeners();
  }

  /// Toggles shuffled queue traversal.
  void toggleShuffle() {
    _isShuffling = !_isShuffling;
    notifyListeners();
  }

  /// Cycles repeat mode: off -> all -> one -> off.
  void cycleRepeatMode() {
    _repeatMode = switch (_repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    notifyListeners();
  }

  /// Releases the background service and the platform audio session.
  Future<void> shutdown() async {
    _isPlaying = false;
    if (_backgroundServiceRunning) {
      await _native.stopBackgroundService();
      _backgroundServiceRunning = false;
    }
    await _native.deactivateAudioSession();
    await _playback?.release();
    _playbackPrepared = false;
    _playbackLoadedPath = null;
    _sessionActivated = false;
    _sessionActivationJob = null;
    _serviceStartJob = null;
    notifyListeners();
  }

  int? _resolveNextIndex() {
    if (_queue.isEmpty || _currentIndex == null) {
      return null;
    }
    if (_queue.length == 1) {
      return _repeatMode == RepeatMode.off ? null : _currentIndex;
    }
    if (_isShuffling) {
      var candidate = _random.nextInt(_queue.length);
      if (candidate == _currentIndex) {
        candidate = (candidate + 1) % _queue.length;
      }
      return candidate;
    }
    final next = _currentIndex! + 1;
    if (next >= _queue.length) {
      return _repeatMode == RepeatMode.all ? 0 : null;
    }
    return next;
  }

  Future<void> _stopAtEndOfQueue() async {
    _isPlaying = false;
    _position = duration;
    if (_backgroundServiceRunning) {
      await _native.stopBackgroundService();
      _backgroundServiceRunning = false;
    }
    await _playback?.stop();
    notifyListeners();
    await _syncMediaControls();
  }

  Future<void> _ensureSessionActivated() {
    if (_sessionActivated) {
      return Future<void>.value();
    }
    // Share the in-flight activation so concurrent play() calls boot once.
    return _sessionActivationJob ??= _activateSession();
  }

  Future<void> _activateSession() async {
    await _native.activateAudioSession();
    _sessionActivated = true;
    _sessionActivationJob = null;
  }

  Future<void> _ensureBackgroundService() {
    if (_backgroundServiceRunning) {
      return Future<void>.value();
    }
    return _serviceStartJob ??= _startService();
  }

  Future<void> _startService() async {
    final state = await _native.startBackgroundService();
    _backgroundServiceRunning = state == MusicBackgroundServiceState.running;
    _serviceStartJob = null;
  }

  Future<void> _syncMediaControls() async {
    final track = currentTrack;
    if (track == null) {
      return;
    }
    await _native.updateMediaControls(
      title: track.title,
      artist: track.artist,
      isPlaying: _isPlaying,
    );
  }
}
