import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'domain/service.dart';
import 'native/platform_bindings.dart';
import 'state/app_state.dart';
import 'state/music_player_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final native = bootMusicNative();
  final library = MusicState(
    service: MusicService(native: native),
    native: native,
  );
  final player = MusicPlayerState(
    native: native,
    playback: native is AudioPlaybackBinding ? native : null,
  );
  unawaited(library.load().then((_) => player.loadQueue(library.allItems)));
  runApp(YawalaApp(state: library, player: player));
}
