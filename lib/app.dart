import 'package:flutter/material.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
        ),
      ),
      home: MusicHomeScreen(state: state),
    );
  }
}