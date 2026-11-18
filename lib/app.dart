import 'package:material_ui/material_ui.dart';

import 'package:yawala_core/yawala_core.dart';

import 'state/app_state.dart';
import 'state/music_player_state.dart';
import 'ui/screens/home_screen.dart';

/// Root widget for Yawala Music.
class YawalaApp extends StatelessWidget {
  const YawalaApp({
    super.key,
    required this.state,
    required this.player,
  });

  final MusicState state;
  final MusicPlayerState player;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yawala Music',
      debugShowCheckedModeBanner: false,
      theme: buildYawalaTheme(seedColor: YawalaColors.music),
      darkTheme: buildYawalaTheme(
        brightness: Brightness.dark,
        seedColor: YawalaColors.music,
      ),
      themeMode: ThemeMode.system,
      home: MusicHomeScreen(state: state, player: player),
    );
  }
}
