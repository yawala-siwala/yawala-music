import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../widgets/music_card.dart';
import '../widgets/music_toolbar.dart';

/// Main screen of Yawala Music: toolbar, tracks list and primary action.
class MusicHomeScreen extends StatelessWidget {
  const MusicHomeScreen({super.key, required this.state});

  final MusicState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yawala Music')),
      body: Column(
        children: [
          MusicToolbar(state: state),
          Expanded(
            child: ListenableBuilder(
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
                  itemBuilder: (context, index) =>
                      TrackCard(item: items[index]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Play / pause',
        onPressed: state.togglePlayback,
        child: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}