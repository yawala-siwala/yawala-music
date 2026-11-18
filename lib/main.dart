import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'domain/service.dart';
import 'native/platform_bindings.dart';
import 'state/app_state.dart';
import 'state/music_player_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final library = MusicState(service: const MusicService());
  final player = MusicPlayerState(native: bootMusicNative());
  unawaited(library.reload().then((_) => player.loadQueue(library.allItems)));
  runApp(YawalaApp(state: library, player: player));
}
