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

/// Real implementation that speaks to the host platform over
/// [musicChannel], mapping failures to safe fallbacks.
class MethodChannelMusicBinding implements MusicNativeBinding {
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
