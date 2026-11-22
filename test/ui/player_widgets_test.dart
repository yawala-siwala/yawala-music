import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:material_ui/material_ui.dart' hide RepeatMode;

import 'package:yawala_music/domain/model.dart';
import 'package:yawala_music/domain/service.dart';
import 'package:yawala_music/native/platform_bindings.dart';
import 'package:yawala_music/state/app_state.dart';
import 'package:yawala_music/state/music_player_state.dart';
import 'package:yawala_music/ui/screens/home_screen.dart';
import 'package:yawala_music/ui/screens/player_dashboard.dart';
import 'package:yawala_music/ui/widgets/mini_player_bar.dart';

/// No-op native binding: widget journeys never leave the host.
class NoopMusicBinding implements MusicNativeBinding {
  @override
  Future<MusicSessionSnapshot> activateAudioSession() async =>
      const MusicSessionSnapshot(
        sessionId: 'widget-session',
        isBackgroundAudioEnabled: true,
      );

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
      MusicBackgroundServiceState.running;

  @override
  Future<MusicBackgroundServiceState> stopBackgroundService() async =>
      MusicBackgroundServiceState.stopped;
}

void main() {
  testWidgets('dashboard shows an empty-queue placeholder without crashing',
      (tester) async {
    final player = MusicPlayerState(native: NoopMusicBinding());

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PlayerDashboard(player: player))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Queue is empty - pick a track from the library.'),
        findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('dashboard journey: metadata, transport and scrub bar stay in '
      'sync on a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = MusicPlayerState(native: NoopMusicBinding());
    player.loadQueue([Track.seedLibrary[0], Track.seedLibrary[1]]);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PlayerDashboard(player: player))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Golden Hour'), findsOneWidget);
    expect(find.text('Monday Lights - Sundial'), findsOneWidget);
    expect(find.text('Track 1 of 2'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    // Play/pause toggles through the filled transport button. While the
    // player is playing, the dashboard's one-second ticker keeps the frame
    // pipeline busy - pump single frames, never pumpAndSettle.
    await tester.tap(find.byTooltip('Play / pause'));
    await tester.pump();
    expect(player.isPlaying, isTrue);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byTooltip('Play / pause'));
    await tester.pumpAndSettle();
    expect(player.isPlaying, isFalse);

    // Dragging the scrub bar moves the thumb without fighting the tick;
    // releasing commits the seek (player is paused here, so settle is safe).
    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(player.position, greaterThan(Duration.zero));

    // Next advances to the second track (and auto-resumes playback).
    await tester.tap(find.byTooltip('Next'));
    await tester.pump();
    expect(player.currentIndex, 1);
    expect(find.text('Neon Drift'), findsOneWidget);
    expect(find.text('Track 2 of 2'), findsOneWidget);
  });

  testWidgets('dashboard renders the two-pane layout on wide viewports',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = MusicPlayerState(native: NoopMusicBinding());
    player.loadQueue([Track.seedLibrary[0], Track.seedLibrary[1]]);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PlayerDashboard(player: player))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Golden Hour'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byTooltip('Shuffle'), findsOneWidget);
    expect(find.byTooltip('Repeat'), findsOneWidget);
  });

  testWidgets('mini-player hides without a track and drives transport',
      (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final player = MusicPlayerState(native: NoopMusicBinding());

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MiniPlayerBar(player: player))),
    );
    await tester.pump();

    expect(find.text('Golden Hour'), findsNothing); // hidden while empty

    player.loadQueue([Track.seedLibrary[0]]);
    await tester.pumpAndSettle();

    expect(find.text('Golden Hour'), findsOneWidget);
    expect(find.text('Monday Lights - Sundial'), findsOneWidget);

    await tester.tap(find.byTooltip('Play / pause'));
    await tester.pump();
    expect(player.isPlaying, isTrue);

    // Single-track queue with repeat off: next() stops playback instead
    // of crashing or wrapping.
    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(player.isPlaying, isFalse);
  });

  testWidgets('home shell journey: library tap loads the queue and opens '
      'the player; mini-player only shows on the library tab',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = MusicState(service: const MusicService());
    final player = MusicPlayerState(native: NoopMusicBinding());
    // reload() awaits a Future.delayed - fire it and let pumpAndSettle
    // advance the fake clock (same rule as the files app journeys).
    unawaited(state.reload());

    await tester.pumpWidget(
      MaterialApp(home: MusicHomeScreen(state: state, player: player)),
    );
    await tester.pumpAndSettle();

    // Library tab is active and the queue is empty, so the only visible
    // 'Golden Hour' is the track card (the empty-queue dashboard shows no
    // metadata yet).
    expect(find.text('Golden Hour'), findsOneWidget);
    expect(find.byIcon(Icons.album), findsNothing);

    // Tap the first track: the visible (unfiltered) library becomes the
    // queue, playback starts and the shell switches to the dashboard.
    await tester.tap(find.text('Golden Hour'));
    await tester.pump();

    expect(player.hasQueue, isTrue);
    expect(player.currentTrack?.id, 'yt-01');
    expect(player.isPlaying, isTrue);
    // The dashboard is the active IndexedStack child; the library list
    // stays built-but-inactive underneath it.
    expect(find.text('Track 1 of 8'), findsOneWidget);
    expect(find.byIcon(Icons.album), findsOneWidget);

    // Back to the library: the mini-player is docked above navigation and
    // the dashboard remains built behind the IndexedStack (both expose a
    // 'Play / pause' control).
    await tester.tap(find.text('Library'));
    await tester.pump();
    expect(find.text('Golden Hour'), findsNWidgets(2));
    expect(find.byTooltip('Play / pause'), findsNWidgets(2));
  });
}
