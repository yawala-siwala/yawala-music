import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../state/app_state.dart';
import '../../state/music_player_state.dart';
import '../widgets/music_card.dart';
import '../widgets/music_toolbar.dart';

/// Browsable library with a filter bar. Tapping a track loads the visible
/// (filtered) list into the player queue and opens the dashboard.
class MusicLibraryView extends StatelessWidget {
  const MusicLibraryView({
    super.key,
    required this.state,
    required this.player,
    this.onOpenPlayer,
  });

  final MusicState state;
  final MusicPlayerState player;
  final VoidCallback? onOpenPlayer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yawala Music')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = state.items.toList(growable: false);
          if (items.isEmpty) {
            return const Center(
              child: Text('Nothing found - try a different search.'),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              return TrackCard(
                item: items[index],
                onTap: () {
                  player.loadQueue(items);
                  unawaited(player.selectTrack(index));
                  onOpenPlayer?.call();
                },
              );
            },
          );
        },
      ),
      floatingActionButton: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          return FloatingActionButton(
            tooltip: 'Play / pause',
            onPressed: player.hasQueue
                ? () => unawaited(player.togglePlayPause())
                : null,
            child: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
          );
        },
      ),
    );
  }
}
