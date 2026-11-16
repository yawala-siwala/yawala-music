import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'domain/service.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = MusicState(service: const MusicService());
  unawaited(state.reload());
  runApp(YawalaApp(state: state));
}