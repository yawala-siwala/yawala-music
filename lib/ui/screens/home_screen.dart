import 'package:material_ui/material_ui.dart';

import '../../state/app_state.dart';
import '../../state/music_player_state.dart';
import 'library_view.dart';
import 'player_dashboard.dart';
import '../widgets/mini_player_bar.dart';

/// Shell for Yawala Music: a Material 3 navigation bar switching between
/// the library and the player dashboard, with a mini-player docked above
/// the navigation while browsing.
class MusicHomeScreen extends StatefulWidget {
  const MusicHomeScreen({
    super.key,
    required this.state,
    required this.player,
  });

  final MusicState state;
  final MusicPlayerState player;

  @override
  State<MusicHomeScreen> createState() => _MusicHomeScreenState();
}

class _MusicHomeScreenState extends State<MusicHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          MusicLibraryView(
            state: widget.state,
            player: player,
            onOpenPlayer: () => setState(() => _tab = 1),
          ),
          PlayerDashboard(player: player),
        ],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_tab == 0 && player.currentTrack != null)
                MiniPlayerBar(
                  player: player,
                  onOpen: () => setState(() => _tab = 1),
                ),
              NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (index) =>
                    setState(() => _tab = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.library_music_outlined),
                    selectedIcon: Icon(Icons.library_music),
                    label: 'Library',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.album_outlined),
                    selectedIcon: Icon(Icons.album),
                    label: 'Now playing',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
