import 'package:flutter_test/flutter_test.dart';

import 'package:yawala_music/domain/model.dart';
import 'package:yawala_music/native/platform_bindings.dart';
import 'package:yawala_music/state/music_player_state.dart';

/// Recording binding that also captures media-control payloads so tests can
/// assert which track metadata reached the lock screen.
class PayloadRecordingBinding implements MusicNativeBinding {
  final List<String> calls = <String>[];
  final List<({String title, String artist, bool isPlaying})> mediaPayloads =
      <({String title, String artist, bool isPlaying})>[];

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
    mediaPayloads.add((title: title, artist: artist, isPlaying: isPlaying));
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
    artist: 'Artist $id',
    album: 'Album',
    duration: Duration(seconds: seconds),
    filePath: '/music/$id.flac',
  );
}

void main() {
  group('MusicPlayerState queue edge cases', () {
    test('loadQueue clamps negative and overflowing start indices', () {
      final player = MusicPlayerState(native: PayloadRecordingBinding());

      player.loadQueue(
        [_track('a', 10), _track('b', 10), _track('c', 10)],
        startIndex: -7,
      );
      expect(player.currentIndex, 0);

      player.loadQueue(
        [_track('a', 10), _track('b', 10), _track('c', 10)],
        startIndex: 99,
      );
      expect(player.currentIndex, 2);
      expect(player.currentTrack?.id, 'c');
    });

    test('play on an empty queue is a safe no-op with no native calls', () async {
      final binding = PayloadRecordingBinding();
      final player = MusicPlayerState(native: binding);

      await player.play();

      expect(player.isPlaying, isFalse);
      expect(binding.calls, isEmpty);
    });

    test('next with no active playhead is a safe no-op', () async {
      final binding = PayloadRecordingBinding();
      final player = MusicPlayerState(native: binding);
      player.loadQueue(const <Track>[]);

      await player.next();
      await player.previous();

      expect(player.currentTrack, isNull);
      expect(binding.calls, isEmpty);
    });

    test('rapid track switching keeps queue, playhead and controls in sync',
        () async {
      final binding = PayloadRecordingBinding();
      final player = MusicPlayerState(native: binding);
      player.loadQueue([
        _track('a', 30),
        _track('b', 30),
        _track('c', 30),
      ]);

      // Simulate fast taps without awaiting in order.
      final switchOne = player.selectTrack(1);
      final switchTwo = player.selectTrack(2);
      await Future.wait([switchOne, switchTwo]);

      expect(player.currentIndex, 2);
      expect(player.currentTrack?.id, 'c');
      expect(player.position, Duration.zero);
      expect(player.isPlaying, isTrue);
      // Session and service boot exactly once despite interleaving.
      expect(binding.count('activate'), 1);
      expect(binding.count('startService'), 1);
      // The last media-control payload reflects the newest selection.
      expect(binding.mediaPayloads.last.title, 'Track c');
    });
  });

  group('MusicPlayerState repeat and shuffle edge cases', () {
    test('single track with repeat-all replays itself forever', () async {
      final binding = PayloadRecordingBinding();
      final player = MusicPlayerState(native: binding);
      player.loadQueue([_track('a', 1)]);
      await player.selectTrack(0);
      player.cycleRepeatMode(); // off -> all

      player.tick();
      await pumpEventQueue();

      expect(player.currentIndex, 0);
      expect(player.position, Duration.zero);
      expect(player.isPlaying, isTrue);
      expect(binding.count('stopService'), 0);
    });

    test('single track with shuffle + repeat-all stays on the track',
        () async {
      final player = MusicPlayerState(native: PayloadRecordingBinding());
      player.loadQueue([_track('a', 1)]);
      await player.selectTrack(0);
      player.toggleShuffle();
      player.cycleRepeatMode(); // off -> all

      await player.next();

      expect(player.currentIndex, 0);
      expect(player.isPlaying, isTrue);
    });

    test('previous at the first track restarts it with repeat off', () async {
      final player = MusicPlayerState(native: PayloadRecordingBinding());
      player.loadQueue([_track('a', 30), _track('b', 30)]);
      await player.selectTrack(0);
      await player.pause();
      player.seekTo(const Duration(seconds: 1));

      await player.previous();

      expect(player.currentIndex, 0);
      expect(player.position, Duration.zero);
      expect(player.isPlaying, isTrue);
    });

    test('seeking to the exact duration advances on the next tick',
        () async {
      final player = MusicPlayerState(native: PayloadRecordingBinding());
      player.loadQueue([_track('a', 30), _track('b', 30)]);
      await player.selectTrack(0);

      player.seekTo(player.duration); // clamp boundary
      expect(player.position, player.duration);

      player.tick();
      await pumpEventQueue();

      expect(player.currentIndex, 1);
    });
  });

  group('MusicPlayerState shutdown edge cases', () {
    test('shutdown without a running service skips the stop call',
        () async {
      final binding = PayloadRecordingBinding();
      final player = MusicPlayerState(native: binding);

      await player.shutdown();

      expect(player.isPlaying, isFalse);
      expect(binding.count('stopService'), 0);
      expect(binding.count('deactivate'), 1);
    });

    test('shutdown is idempotent', () async {
      final binding = PayloadRecordingBinding();
      final player = MusicPlayerState(native: binding);
      player.loadQueue([_track('a', 30)]);
      await player.selectTrack(0);

      await player.shutdown();
      await player.shutdown();

      expect(binding.count('stopService'), 1);
      expect(binding.count('deactivate'), 2);
    });
  });
}
