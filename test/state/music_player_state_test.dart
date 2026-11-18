import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:yawala_music/domain/model.dart';
import 'package:yawala_music/native/platform_bindings.dart';
import 'package:yawala_music/state/music_player_state.dart';

/// Records every native call so tests can assert synchronisation order and
/// payloads without a real platform.
class RecordingMusicBinding implements MusicNativeBinding {
  final List<String> calls = <String>[];
  final List<bool> mediaPlayingStates = <bool>[];

  @override
  Future<MusicSessionSnapshot> activateAudioSession() async {
    calls.add('activate');
    return const MusicSessionSnapshot(
      sessionId: 'test-session',
      isBackgroundAudioEnabled: true,
    );
  }

  @override
  Future<void> deactivateAudioSession() async {
    calls.add('deactivate');
  }

  @override
  Future<void> updateMediaControls({
    required String title,
    required String artist,
    required bool isPlaying,
  }) async {
    calls.add('media');
    mediaPlayingStates.add(isPlaying);
  }

  @override
  Future<MusicBackgroundServiceState> startBackgroundService() async {
    calls.add('startService');
    return MusicBackgroundServiceState.running;
  }

  @override
  Future<MusicBackgroundServiceState> stopBackgroundService() async {
    calls.add('stopService');
    return MusicBackgroundServiceState.stopped;
  }

  int count(String call) => calls.where((c) => c == call).length;
}

Track _track(String id, int seconds) {
  return Track(
    id: id,
    title: 'Track $id',
    artist: 'Artist',
    album: 'Album',
    duration: Duration(seconds: seconds),
    filePath: '/music/$id.flac',
  );
}

void main() {
  group('MusicPlayerState transport', () {
    test('selectTrack activates session + service once and syncs controls',
        () async {
      final binding = RecordingMusicBinding();
      final player = MusicPlayerState(native: binding);
      player.loadQueue([_track('a', 30), _track('b', 30)]);

      await player.selectTrack(0);
      expect(player.isPlaying, isTrue);
      expect(binding.count('activate'), 1);
      expect(binding.count('startService'), 1);
      expect(binding.mediaPlayingStates.last, isTrue);

      await player.pause();
      expect(player.isPlaying, isFalse);
      expect(binding.mediaPlayingStates.last, isFalse);

      await player.play();
      // No duplicate session activation or service start.
      expect(binding.count('activate'), 1);
      expect(binding.count('startService'), 1);
      expect(binding.mediaPlayingStates.last, isTrue);
    });

    test('loadQueue parks the playhead at startIndex, paused', () {
      final player = MusicPlayerState(
        native: RecordingMusicBinding(),
      );
      player.loadQueue([_track('a', 10), _track('b', 10), _track('c', 10)]);

      expect(player.hasQueue, isTrue);
      expect(player.currentIndex, 0);
      expect(player.currentTrack?.id, 'a');
      expect(player.isPlaying, isFalse);
      expect(player.position, Duration.zero);
    });

    test('loadQueue with an empty list clears the playhead', () {
      final player = MusicPlayerState(
        native: RecordingMusicBinding(),
      );
      player.loadQueue(const <Track>[]);

      expect(player.hasQueue, isFalse);
      expect(player.currentTrack, isNull);
      expect(player.duration, Duration.zero);
    });

    test('selectTrack ignores out-of-bounds indices', () async {
      final binding = RecordingMusicBinding();
      final player = MusicPlayerState(native: binding);
      player.loadQueue([_track('a', 10)]);

      await player.selectTrack(5);

      expect(binding.calls, isEmpty);
      expect(player.isPlaying, isFalse);
    });
  });

  group('MusicPlayerState progression', () {
    test('tick advances the playhead while playing', () {
      final player = MusicPlayerState(native: RecordingMusicBinding());
      player.loadQueue([_track('a', 30)]);
      player.seekTo(const Duration(seconds: 5));

      player.tick();

      expect(player.position, const Duration(seconds: 6));
    });

    test('tick is a no-op while paused', () {
      final player = MusicPlayerState(native: RecordingMusicBinding());
      player.loadQueue([_track('a', 30)]);

      player.tick();

      expect(player.position, Duration.zero);
    });

    test('auto-advances to the next track when one finishes', () async {
      final binding = RecordingMusicBinding();
      final player = MusicPlayerState(native: binding);
      player.loadQueue([_track('a', 1), _track('b', 30)]);
      await player.selectTrack(0);

      player.tick(); // Track 'a' is 1s long -> finishes now.
      await pumpEventQueue();

      expect(player.currentIndex, 1);
      expect(player.currentTrack?.id, 'b');
      expect(player.position, Duration.zero);
      expect(player.isPlaying, isTrue);
    });

    test('repeat-one restarts the same track', () async {
      final binding = RecordingMusicBinding();
      final player = MusicPlayerState(native: binding);
      player.loadQueue([_track('a', 1), _track('b', 30)]);
      await player.selectTrack(0);
      player.cycleRepeatMode(); // off -> all
      player.cycleRepeatMode(); // all -> one

      player.tick(); // Track ends -> repeats instead of advancing.
      await pumpEventQueue();

      expect(player.currentIndex, 0);
      expect(player.position, Duration.zero);
      expect(player.isPlaying, isTrue);
      expect(binding.count('stopService'), 0);
    });

    test('stops at the end of the queue with repeat off', () async {
      final binding = RecordingMusicBinding();
      final player = MusicPlayerState(native: binding);
      player.loadQueue([_track('a', 1)]);
      await player.selectTrack(0);

      player.tick(); // Single 1s track finishes -> stop.
      await pumpEventQueue();

      expect(player.isPlaying, isFalse);
      expect(player.position, player.duration);
      expect(binding.count('stopService'), 1);
      expect(binding.mediaPlayingStates.last, isFalse);
    });

    test('repeat-all wraps around at the end of the queue', () async {
      final binding = RecordingMusicBinding();
      final player = MusicPlayerState(native: binding);
      player.loadQueue([_track('a', 1), _track('b', 1)]);
      await player.selectTrack(1);
      player.cycleRepeatMode(); // off -> all

      player.tick(); // Track 'b' finishes -> wraps to 'a'.
      await pumpEventQueue();

      expect(player.currentIndex, 0);
      expect(player.isPlaying, isTrue);
    });
  });

  group('MusicPlayerState queue navigation', () {
    test('previous restarts the track after three seconds', () async {
      final binding = RecordingMusicBinding();
      final player = MusicPlayerState(native: binding);
      player.loadQueue([_track('a', 30), _track('b', 30)]);
      await player.selectTrack(1);
      player.seekTo(const Duration(seconds: 10));

      await player.previous();

      expect(player.currentIndex, 1);
      expect(player.position, Duration.zero);
    });

    test('previous skips to the prior track within three seconds', () async {
      final player = MusicPlayerState(native: RecordingMusicBinding());
      player.loadQueue([_track('a', 30), _track('b', 30)]);
      await player.selectTrack(1);

      await player.previous();

      expect(player.currentIndex, 0);
      expect(player.position, Duration.zero);
    });

    test('shuffle picks a deterministic neighbour with an injected Random',
        () async {
      final player = MusicPlayerState(
        native: RecordingMusicBinding(),
        random: Random(1),
      );
      final queue = Track.seedLibrary;
      player.loadQueue(queue);
      await player.selectTrack(0);
      player.toggleShuffle();
      expect(player.isShuffling, isTrue);

      // Mirror the machine's shuffle resolution to compute the expected
      // neighbour deterministically.
      final expectedRaw = Random(1).nextInt(queue.length);
      final expected =
          expectedRaw == 0 ? (expectedRaw + 1) % queue.length : expectedRaw;

      await player.next();

      expect(player.currentIndex, expected);
    });

    test('toggleShuffle toggles state', () {
      final player = MusicPlayerState(native: RecordingMusicBinding());
      expect(player.isShuffling, isFalse);
      player.toggleShuffle();
      expect(player.isShuffling, isTrue);
      player.toggleShuffle();
      expect(player.isShuffling, isFalse);
    });

    test('cycleRepeatMode cycles off -> all -> one -> off', () {
      final player = MusicPlayerState(native: RecordingMusicBinding());
      expect(player.repeatMode, RepeatMode.off);
      player.cycleRepeatMode();
      expect(player.repeatMode, RepeatMode.all);
      player.cycleRepeatMode();
      expect(player.repeatMode, RepeatMode.one);
      player.cycleRepeatMode();
      expect(player.repeatMode, RepeatMode.off);
    });
  });

  group('MusicPlayerState seeking and shutdown', () {
    test('seekTo clamps to the track duration', () {
      final player = MusicPlayerState(native: RecordingMusicBinding());
      player.loadQueue([_track('a', 30)]);
      player.seekTo(const Duration(seconds: -5));
      expect(player.position, Duration.zero);
      player.seekTo(const Duration(hours: 1));
      expect(player.position, player.duration);
    });

    test('shutdown stops the service and deactivates the session', () async {
      final binding = RecordingMusicBinding();
      final player = MusicPlayerState(native: binding);
      player.loadQueue([_track('a', 30)]);
      await player.selectTrack(0);

      await player.shutdown();

      expect(player.isPlaying, isFalse);
      expect(binding.count('stopService'), 1);
      expect(binding.count('deactivate'), 1);
    });
  });
}
