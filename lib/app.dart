import 'package:flutter/material.dart';

import 'package:yawala_core/yawala_core.dart';

import 'state/app_state.dart';
import 'ui/screens/home_screen.dart';

/// Root widget for Yawala Music.
class YawalaApp extends StatelessWidget {
  const YawalaApp({super.key, required this.state});

  final MusicState state;

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
      home: MusicHomeScreen(state: state),
    );
  }
}
