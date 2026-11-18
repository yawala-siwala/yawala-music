import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:yawala_core/yawala_core.dart';

import '../../state/music_player_state.dart';

/// Compact now-playing bar docked above the navigation bar. Tap it to open
/// the full player dashboard.
class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key, required this.player, this.onOpen});

  final MusicPlayerState player;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final track = player.currentTrack;
        if (track == null) {
          return const SizedBox.shrink();
        }
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.surfaceContainerHighest,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: YawalaSpacing.md,
                vertical: YawalaSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(YawalaRadii.medium),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primaryContainer,
                          scheme.secondaryContainer,
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.album_rounded,
                      size: 22,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: YawalaSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          track.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Play / pause',
                    onPressed: () => unawaited(player.togglePlayPause()),
                    icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: () => unawaited(player.next()),
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
