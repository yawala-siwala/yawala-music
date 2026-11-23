import 'package:flutter/services.dart';

import 'package:yawala_core/yawala_core.dart';

/// Native contract for Yawala Music.
///
/// Channel: `com.yawalasiwala/music`
///
/// | Method | Purpose | Android / iOS | Desktop |
/// | --- | --- | --- | --- |
/// | `activateAudioSession` | Configure the audio session (category, mixing) | AudioFocusRequest / AVAudioSession | WASAPI / PulseAudio session |
/// | `deactivateAudioSession` | Release the session | abandon focus / deactivate | release |
/// | `updateMediaControls` | Lock-screen / media-notification metadata | MediaSession + foreground service / MPRemoteCommandCenter | SMTC / MPRIS |
/// | `startBackgroundService` | Background audio lifecycle | Android foreground service / iOS background-audio mode | n/a (window keeps process alive) |
/// | `stopBackgroundService` | Stop background playback | stop service / end background task | n/a |
/// | `listLibrary` | Index the device media library | MediaStore.Audio.Media | MPMediaQuery / filesystem scan |
/// | `requestLibraryAccess` | Ask for media read permission | READ_MEDIA_AUDIO dialog | n/a |
/// | `prepare`/`play`/`pause`/`seek`/`stop`/`position`/`release` | Real audio playback | MediaPlayer + AudioAttributes | platform player |
///
/// Every call goes through [NativeChannelGateway] and therefore resolves to
/// safe fallbacks instead of throwing on platforms without a handler.
const MethodChannel musicChannel = MethodChannel('com.yawalasiwala/music');

/// Snapshot of the platform audio session state.
class MusicSessionSnapshot {
  const MusicSessionSnapshot({
    required this.sessionId,
    required this.isBackgroundAudioEnabled,
  });

  /// Safe response used when the platform has no audio-session support.
  const MusicSessionSnapshot.fallback()
      : sessionId = 'unavailable',
        isBackgroundAudioEnabled = false;

  factory MusicSessionSnapshot.fromMap(Map<Object?, Object?>? map) {
    return MusicSessionSnapshot(
      sessionId: (map?['sessionId'] as String?) ?? 'unavailable',
      isBackgroundAudioEnabled:
          (map?['isBackgroundAudioEnabled'] as bool?) ?? false,
    );
  }

  final String sessionId;
  final bool isBackgroundAudioEnabled;
}

/// Lifecycle state of the background audio service.
enum MusicBackgroundServiceState { running, stopped, unsupported }

/// Parses the wire representation sent by native hosts.
MusicBackgroundServiceState musicBackgroundServiceStateFrom(String? value) {
  return switch (value) {
    'running' => MusicBackgroundServiceState.running,
    'stopped' => MusicBackgroundServiceState.stopped,
    _ => MusicBackgroundServiceState.unsupported,
  };
}

/// Contract every platform host implements for Yawala Music.
abstract interface class MusicNativeBinding {
  /// Configures the platform audio session and returns its snapshot.
  Future<MusicSessionSnapshot> activateAudioSession();

  /// Releases the platform audio session.
  Future<void> deactivateAudioSession();

  /// Pushes now-playing metadata to lock-screen / media controls.
  Future<void> updateMediaControls({
    required String title,
    required String artist,
    required bool isPlaying,
  });

  /// Starts the background playback service (Android foreground service /
  /// iOS background-audio mode).
  Future<MusicBackgroundServiceState> startBackgroundService();

  /// Stops the background playback service.
  Future<MusicBackgroundServiceState> stopBackgroundService();
}

/// Optional capability: real device library indexing (MediaStore on
/// Android). Detected with an `is` check at the service layer, so bindings
/// without the capability keep working unchanged.
abstract interface class MediaLibraryIndexingBinding {
  /// Returns the indexed device library. An empty list means the device
  /// library is empty or read access was denied (no fake demo tracks are
  /// substituted); `null` means the platform cannot index and the caller
  /// should fall back to the bundled sample library.
  Future<List<Track>?> listLibrary();

  /// Asks the platform for read access to the media library. Returns the
  /// grant result, or `null` when the platform cannot ask.
  Future<bool?> requestLibraryAccess();
}

/// Optional capability: real platform audio playback. When present, the
/// player state machine drives the native engine and reads wall-clock
/// positions from it instead of advancing a simulated one-second clock.
abstract interface class AudioPlaybackBinding {
  /// Loads [source] (file path or content URI) and prepares the decoder;
  /// returns whether media is ready for playback.
  Future<bool> prepare(String source);

  /// Starts or resumes playback of the prepared media.
  Future<void> play();

  /// Suspends playback, keeping the load position.
  Future<void> pause();

  /// Seeks the prepared media to [positionMs].
  Future<void> seek(int positionMs);

  /// Halts playback and rewinds to the start (media stays prepared).
  Future<void> stop();

  /// Real playback position in milliseconds, or `null` when nothing is
  /// prepared.
  Future<int?> position();

  /// Releases the engine and its decoded resources.
  Future<void> release();
}

/// Real implementation that speaks to the host platform over
/// [musicChannel], mapping failures to safe fallbacks.
class MethodChannelMusicBinding
    implements MusicNativeBinding, MediaLibraryIndexingBinding,
        AudioPlaybackBinding {
  MethodChannelMusicBinding({MethodChannel? channel})
      : _gateway = NativeChannelGateway(
          channel: channel ?? musicChannel,
          context: 'music.native',
        );

  final NativeChannelGateway _gateway;

  @override
  Future<MusicSessionSnapshot> activateAudioSession() async {
    final result =
        await _gateway.invoke<Map<Object?, Object?>>('activateAudioSession');
    return result.fold(
      ok: MusicSessionSnapshot.fromMap,
      err: (_, __) => const MusicSessionSnapshot.fallback(),
    );
  }

  @override
  Future<void> deactivateAudioSession() {
    return _gateway.invokeVoid('deactivateAudioSession');
  }

  @override
  Future<void> updateMediaControls({
    required String title,
    required String artist,
    required bool isPlaying,
  }) {
    return _gateway.invokeVoid('updateMediaControls', <String, Object?>{
      'title': title,
      'artist': artist,
      'isPlaying': isPlaying,
    });
  }

  @override
  Future<MusicBackgroundServiceState> startBackgroundService() async {
    final result =
        await _gateway.invoke<String>('startBackgroundService');
    return musicBackgroundServiceStateFrom(result.valueOrNull);
  }

  @override
  Future<MusicBackgroundServiceState> stopBackgroundService() async {
    final result = await _gateway.invoke<String>('stopBackgroundService');
    return musicBackgroundServiceStateFrom(result.valueOrNull);
  }

  @override
  Future<List<Track>?> listLibrary() async {
    final result = await _gateway.invoke<List<Object?>>('listLibrary');
    return result.fold(
      ok: (entries) => entries == null
          ? null
          : <Track>[
              for (final entry in entries)
                if (entry is Map<Object?, Object?>) Track.fromMap(entry),
            ],
      err: (_, __) => null,
    );
  }

  @override
  Future<bool?> requestLibraryAccess() async {
    final result = await _gateway.invoke<bool>('requestLibraryAccess');
    return result.fold(ok: (granted) => granted, err: (_, __) => null);
  }

  @override
  Future<bool> prepare(String source) async {
    final result = await _gateway.invoke<bool>(
      'prepare',
      <String, Object?>{'source': source},
    );
    return result.fold(ok: (ready) => ready ?? false, err: (_, __) => false);
  }

  @override
  Future<void> play() => _gateway.invokeVoid('play');

  @override
  Future<void> pause() => _gateway.invokeVoid('pause');

  @override
  Future<void> seek(int positionMs) {
    return _gateway.invokeVoid('seek', <String, Object?>{
      'positionMs': positionMs,
    });
  }

  @override
  Future<void> stop() => _gateway.invokeVoid('stop');

  @override
  Future<int?> position() async {
    final result = await _gateway.invoke<int>('position');
    return result.fold(ok: (ms) => ms, err: (_, __) => null);
  }

  @override
  Future<void> release() => _gateway.invokeVoid('release');
}

/// No-op implementation for tests and platforms without any native host.
class FallbackMusicBinding implements MusicNativeBinding {
  const FallbackMusicBinding();

  @override
  Future<MusicSessionSnapshot> activateAudioSession() async =>
      const MusicSessionSnapshot.fallback();

  @override
  Future<void> deactivateAudioSession() async {}

  @override
  Future<void> updateMediaControls({
    required String title,
    required String artist,
    required bool isPlaying,
  }) async {}

  @override
  Future<MusicBackgroundServiceState> startBackgroundService() async =>
      MusicBackgroundServiceState.unsupported;

  @override
  Future<MusicBackgroundServiceState> stopBackgroundService() async =>
      MusicBackgroundServiceState.unsupported;
}

/// Boots the platform binding for the current OS.
MusicNativeBinding bootMusicNative() => MethodChannelMusicBinding();
