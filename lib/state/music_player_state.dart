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
  })  : _native = native,
        _random = random ?? Random();

  final MusicNativeBinding _native;
  final Random _random;

  List<Track> _queue = const <Track>[];
  int? _currentIndex;
  bool _isPlaying = false;
  bool _isShuffling = false;
  RepeatMode _repeatMode = RepeatMode.off;
  Duration _position = Duration.zero;
  bool _sessionActivated = false;
  bool _backgroundServiceRunning = false;

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

  /// Advances the simulated playhead. Called by the UI once per second;
  /// auto-advances the queue when a track finishes.
  void tick({Duration step = const Duration(seconds: 1)}) {
    if (!_isPlaying || _currentIndex == null || _queue.isEmpty) {
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

  /// Starts (or resumes) playback, syncing the audio session, the
  /// background service and the lock-screen media controls.
  Future<void> play() async {
    if (_queue.isEmpty || _currentIndex == null) {
      return;
    }
    await _ensureSessionActivated();
    await _ensureBackgroundService();
    _isPlaying = true;
    notifyListeners();
    await _syncMediaControls();
  }

  /// Pauses playback and updates the media controls.
  Future<void> pause() async {
    if (!_isPlaying) {
      return;
    }
    _isPlaying = false;
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

  /// Seeks the playhead, clamped to the current track's duration.
  void seekTo(Duration position) {
    final limit = duration;
    _position = position < Duration.zero
        ? Duration.zero
        : (position > limit ? limit : position);
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
    _sessionActivated = false;
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
    notifyListeners();
    await _syncMediaControls();
  }

  Future<void> _ensureSessionActivated() async {
    if (_sessionActivated) {
      return;
    }
    await _native.activateAudioSession();
    _sessionActivated = true;
  }

  Future<void> _ensureBackgroundService() async {
    if (_backgroundServiceRunning) {
      return;
    }
    final state = await _native.startBackgroundService();
    _backgroundServiceRunning =
        state == MusicBackgroundServiceState.running;
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
