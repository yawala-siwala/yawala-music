import 'package:flutter_test/flutter_test.dart';

import 'package:yawala_music/domain/model.dart';
import 'package:yawala_music/domain/service.dart';
import 'package:yawala_music/native/platform_bindings.dart';
import 'package:yawala_music/state/app_state.dart';
import 'package:yawala_music/state/music_player_state.dart';

/// Records native calls without implementing any capability (same shape as
/// the CI-verified RecordingMusicBinding).
class PlainRecordingBinding implements MusicNativeBinding {
  final List<String> calls = <String>[];

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
}

/// Scriptable real-playback engine.
class FakeAudioPlaybackBinding implements AudioPlaybackBinding {
  final List<String> calls = <String>[];
  final List<int> seeks = <int>[];
  int? nextPosition;
  bool prepareOk = true;
  String? lastPreparedSource;

  @override
  Future<bool> prepare(String source) async {
    calls.add('prepare');
    lastPreparedSource = source;
    return prepareOk;
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(int positionMs) async {
    calls.add('seek');
    seeks.add(positionMs);
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<int?> position() async {
    calls.add('position');
    return nextPosition;
  }

  @override
  Future<void> release() async => calls.add('release');
}

/// Scriptable MediaStore indexer.
class FakeIndexingBinding extends PlainRecordingBinding
    implements MediaLibraryIndexingBinding {
  List<Track>? library;
  bool? accessGrant;

  @override
  Future<List<Track>?> listLibrary() async => library;

  @override
  Future<bool?> requestLibraryAccess() async => accessGrant;
}

Track _track(String id, int seconds) {
  return Track(
    id: id,
    title: 'Track $id',
    artist: 'Artist $id',
    album: 'Album $id',
    duration: Duration(seconds: seconds),
    filePath: '/music/$id.flac',
  );
}

void main() {
  group('MusicPlayerState real playback', () {
    test('play prepares the current source and starts the engine', () async {
      final engine = FakeAudioPlaybackBinding();
      final player = MusicPlayerState(
        native: PlainRecordingBinding(),
        playback: engine,
      );
      player.loadQueue([_track('a', 30), _track('b', 30)]);

      await player.selectTrack(0);

      expect(engine.lastPreparedSource, '/music/a.flac');
      expect(engine.calls, containsAll(['prepare', 'play']));
      expect(player.isPlaying, isTrue);
    });

    test('resuming the same track does not re-prepare the engine', () async {
      final engine = FakeAudioPlaybackBinding();
      final player = MusicPlayerState(
        native: PlainRecordingBinding(),
        playback: engine,
      );
      player.loadQueue([_track('a', 30), _track('b', 30)]);
      await player.selectTrack(0);
      await player.pause();
      await player.play();

      expect(engine.calls.where((c) => c == 'prepare'), hasLength(1));
      expect(engine.calls.where((c) => c == 'play'), hasLength(2));

      // A different track re-prepares with its own source.
      await player.selectTrack(1);
      expect(engine.calls.where((c) => c == 'prepare'), hasLength(2));
      expect(engine.lastPreparedSource, '/music/b.flac');
    });

    test('pause and seekTo forward to the engine', () async {
      final engine = FakeAudioPlaybackBinding();
      final player = MusicPlayerState(
        native: PlainRecordingBinding(),
        playback: engine,
      );
      player.loadQueue([_track('a', 30)]);
      await player.selectTrack(0);

      await player.pause();
      expect(engine.calls, contains('pause'));

      player.seekTo(const Duration(seconds: 5));
      await pumpEventQueue();
      expect(engine.seeks, [5000]);
    });

    test('tick reads the real engine position when media is prepared',
        () async {
      final engine = FakeAudioPlaybackBinding()..nextPosition = 8000;
      final player = MusicPlayerState(
        native: PlainRecordingBinding(),
        playback: engine,
      );
      player.loadQueue([_track('a', 30)]);
      await player.selectTrack(0);

      player.tick();
      await pumpEventQueue();

      expect(player.position, const Duration(seconds: 8));
      expect(engine.calls, contains('position'));
    });

    test('tick auto-advances at the real end of a track', () async {
      final engine = FakeAudioPlaybackBinding()
        ..nextPosition = 30 * 1000; // track is exactly 30s -> finished
      final player = MusicPlayerState(
        native: PlainRecordingBinding(),
        playback: engine,
      );
      player.loadQueue([_track('a', 30), _track('b', 30)]);
      await player.selectTrack(0);

      player.tick();
      await pumpEventQueue();

      expect(player.currentIndex, 1);
      expect(player.position, Duration.zero);
    });

    test('repeat-one rewinds the real engine instead of advancing', () async {
      final engine = FakeAudioPlaybackBinding()
        ..nextPosition = 30 * 1000;
      final player = MusicPlayerState(
        native: PlainRecordingBinding(),
        playback: engine,
      );
      player.loadQueue([_track('a', 30), _track('b', 30)]);
      await player.selectTrack(0);
      player.cycleRepeatMode();
      player.cycleRepeatMode(); // off -> all -> one

      player.tick();
      await pumpEventQueue();

      expect(player.currentIndex, 0);
      expect(player.position, Duration.zero);
      expect(engine.seeks, contains(0));
    });

    test('a failed prepare keeps the simulated clock running', () async {
      final engine = FakeAudioPlaybackBinding()..prepareOk = false;
      final player = MusicPlayerState(
        native: PlainRecordingBinding(),
        playback: engine,
      );
      player.loadQueue([_track('a', 30)]);
      await player.selectTrack(0);

      player.tick();

      expect(player.position, const Duration(seconds: 1));
      expect(engine.calls, isNot(contains('position')));
    });

    test('end of queue stops the engine; shutdown releases it', () async {
      final engine = FakeAudioPlaybackBinding()
        ..nextPosition = 1 * 1000;
      final native = PlainRecordingBinding();
      final player = MusicPlayerState(native: native, playback: engine);
      player.loadQueue([_track('a', 1)]);
      await player.selectTrack(0);

      player.tick();
      await pumpEventQueue();

      expect(player.isPlaying, isFalse);
      expect(engine.calls, contains('stop'));

      await player.shutdown();
      expect(engine.calls, contains('release'));
    });
  });

  group('MusicState real device indexing', () {
    test('MediaStore tracks replace the sample library', () async {
      final native = FakeIndexingBinding()
        ..accessGrant = true
        ..library = [
          Track(
            id: 'media-1',
            title: 'Real Song',
            artist: 'Real Artist',
            album: 'Real Album',
            duration: const Duration(seconds: 210),
            filePath: 'content://media/external/audio/media/1',
          ),
        ];
      final state = MusicState(
        service: MusicService(native: native),
        native: native,
      );
      await state.load();

      expect(state.items, hasLength(1));
      expect(state.items.single.title, 'Real Song');
      expect(state.items.single.filePath, startsWith('content://'));
      expect(state.lastLibraryAccessGrant, isTrue);
    });

    test('an empty device library stays empty - no demo tracks substituted',
        () async {
      final native = FakeIndexingBinding()
        ..accessGrant = true
        ..library = <Track>[];
      final state = MusicState(
        service: MusicService(native: native),
        native: native,
      );
      await state.load();

      expect(state.items, isEmpty);
    });

    test('a denied permission still indexes (native returns the empty list)',
        () async {
      final native = FakeIndexingBinding()
        ..accessGrant = false
        ..library = <Track>[];
      final state = MusicState(
        service: MusicService(native: native),
        native: native,
      );
      await state.load();

      expect(state.lastLibraryAccessGrant, isFalse);
      expect(state.items, isEmpty);
    });

    test('bindings without the indexing capability keep the seed library',
        () async {
      final state = MusicState(service: const MusicService());
      await state.load();

      expect(state.items, hasLength(Track.seedLibrary.length));
    });

    test('Track.fromMap decodes the native wire format', () {
      final track = Track.fromMap(<Object?, Object?>{
        'id': 'media-99',
        'title': 'Song',
        'artist': 'Artist',
        'album': 'Album',
        'durationMs': 125000,
        'filePath': 'content://media/external/audio/media/99',
      });

      expect(track.id, 'media-99');
      expect(track.duration, const Duration(seconds: 125));
      expect(track.filePath, 'content://media/external/audio/media/99');
    });

    test('MusicService falls back to the seed library on null listings',
        () async {
      final native = FakeIndexingBinding()..library = null;
      final service = MusicService(native: native);

      final tracks = await service.list();

      expect(tracks, hasLength(Track.seedLibrary.length));
    });
  });
}
