import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yawala_music/native/platform_bindings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final binding = MethodChannelMusicBinding();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(musicChannel, null);
  });

  group('MethodChannelMusicBinding with a live native handler', () {
    test('activateAudioSession maps the native payload', () async {
      messenger.setMockMethodCallHandler(musicChannel, (call) async {
        expect(call.method, 'activateAudioSession');
        return {'sessionId': 'sess-1', 'isBackgroundAudioEnabled': true};
      });

      final snapshot = await binding.activateAudioSession();

      expect(snapshot.sessionId, 'sess-1');
      expect(snapshot.isBackgroundAudioEnabled, isTrue);
    });

    test('updateMediaControls forwards the now-playing metadata', () async {
      Map<Object?, Object?>? received;
      messenger.setMockMethodCallHandler(musicChannel, (call) async {
        expect(call.method, 'updateMediaControls');
        received = call.arguments as Map<Object?, Object?>;
        return null;
      });

      await binding.updateMediaControls(
        title: 'Golden Hour',
        artist: 'Monday Lights',
        isPlaying: true,
      );

      expect(received?['title'], 'Golden Hour');
      expect(received?['artist'], 'Monday Lights');
      expect(received?['isPlaying'], true);
    });

    test('background service lifecycle maps state strings', () async {
      messenger.setMockMethodCallHandler(musicChannel, (call) async {
        return call.method == 'startBackgroundService' ? 'running' : 'stopped';
      });

      expect(await binding.startBackgroundService(),
          MusicBackgroundServiceState.running);
      expect(await binding.stopBackgroundService(),
          MusicBackgroundServiceState.stopped);
    });

    test('native errors degrade to fallbacks instead of throwing', () async {
      messenger.setMockMethodCallHandler(musicChannel, (call) async {
        throw PlatformException(code: 'E_AUDIO', message: 'focus denied');
      });

      final snapshot = await binding.activateAudioSession();
      expect(snapshot.sessionId, 'unavailable');
      expect(snapshot.isBackgroundAudioEnabled, isFalse);
    });
  });

  group('channel invocation safety (no native handler registered)', () {
    test('activateAudioSession falls back to an unavailable session',
        () async {
      final snapshot = await binding.activateAudioSession();

      expect(snapshot.sessionId, 'unavailable');
      expect(snapshot.isBackgroundAudioEnabled, isFalse);
    });

    test('lifecycle calls complete without throwing', () async {
      expect(
        await binding.startBackgroundService(),
        MusicBackgroundServiceState.unsupported,
      );
      expect(
        await binding.stopBackgroundService(),
        MusicBackgroundServiceState.unsupported,
      );
      await binding.deactivateAudioSession();
      await binding.updateMediaControls(
        title: 't',
        artist: 'a',
        isPlaying: false,
      );
    });
  });

  group('FallbackMusicBinding', () {
    const fallback = FallbackMusicBinding();

    test('mirrors the safe fallbacks', () async {
      expect(
        (await fallback.activateAudioSession()).sessionId,
        'unavailable',
      );
      expect(
        await fallback.startBackgroundService(),
        MusicBackgroundServiceState.unsupported,
      );
      expect(
        await fallback.stopBackgroundService(),
        MusicBackgroundServiceState.unsupported,
      );
      await fallback.deactivateAudioSession();
      await fallback.updateMediaControls(
        title: 't',
        artist: 'a',
        isPlaying: false,
      );
    });
  });
}
