import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:yawala_core/yawala_core.dart';

import '../../domain/model.dart';
import '../../state/music_player_state.dart';

/// Material 3 player dashboard: album art placeholder, scrub bar, track
/// metadata and responsive transport controls (play/pause, skip, repeat,
/// shuffle). Layout adapts between single-column (phone) and two-pane
/// (desktop) arrangements.
class PlayerDashboard extends StatefulWidget {
  const PlayerDashboard({super.key, required this.player});

  final MusicPlayerState player;

  @override
  State<PlayerDashboard> createState() => _PlayerDashboardState();
}

class _PlayerDashboardState extends State<PlayerDashboard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.player.isPlaying) {
        widget.player.tick();
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.player,
      builder: (context, _) {
        final player = widget.player;
        final track = player.currentTrack;
        if (track == null) {
          return const Center(
            child: Text('Queue is empty - pick a track from the library.'),
          );
        }
        final wide = MediaQuery.sizeOf(context).width >= 720;
        final art = _buildAlbumArt(context);
        final metadata = _buildMetadata(context, track);
        final scrubber = _buildScrubBar(context, player);
        final controls = _buildTransportControls(context, player);

        if (wide) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(YawalaSpacing.xl),
              child: Row(
                children: [
                  Expanded(flex: 2, child: art),
                  const SizedBox(width: YawalaSpacing.xl),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        metadata,
                        const SizedBox(height: YawalaSpacing.xl),
                        scrubber,
                        const SizedBox(height: YawalaSpacing.lg),
                        controls,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(YawalaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                art,
                const SizedBox(height: YawalaSpacing.xl),
                metadata,
                const SizedBox(height: YawalaSpacing.lg),
                scrubber,
                const SizedBox(height: YawalaSpacing.lg),
                controls,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumArt(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(YawalaRadii.large),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primaryContainer, scheme.secondaryContainer],
          ),
        ),
        child: Icon(
          Icons.album_rounded,
          size: 96,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, Track track) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.displayName,
          style: theme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: YawalaSpacing.xs),
        Text(
          track.subtitle,
          style: theme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: YawalaSpacing.xs),
        Text(
          'Track ${(widget.player.currentIndex ?? 0) + 1} of ${widget.player.queue.length}',
          style: theme.labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildScrubBar(BuildContext context, MusicPlayerState player) {
    final theme = Theme.of(context).textTheme;
    final maxSeconds = player.duration.inSeconds.toDouble();
    return Column(
      children: [
        Slider(
          value: player.position.inSeconds
              .clamp(0, maxSeconds == 0 ? 1 : maxSeconds.toInt())
              .toDouble(),
          max: maxSeconds == 0 ? 1 : maxSeconds,
          onChanged: (value) =>
              player.seekTo(Duration(seconds: value.round())),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDuration(player.position), style: theme.labelMedium),
            Text(
              '-${formatDuration(player.duration - player.position)}',
              style: theme.labelMedium,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransportControls(BuildContext context, MusicPlayerState player) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Shuffle',
          onPressed: player.toggleShuffle,
          icon: const Icon(Icons.shuffle),
          color: player.isShuffling ? scheme.primary : null,
        ),
        IconButton(
          tooltip: 'Previous',
          onPressed: () => unawaited(player.previous()),
          icon: const Icon(Icons.skip_previous),
          iconSize: 36,
        ),
        const SizedBox(width: YawalaSpacing.md),
        IconButton.filled(
          tooltip: 'Play / pause',
          onPressed: () => unawaited(player.togglePlayPause()),
          icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
          iconSize: 36,
        ),
        const SizedBox(width: YawalaSpacing.md),
        IconButton(
          tooltip: 'Next',
          onPressed: () => unawaited(player.next()),
          icon: const Icon(Icons.skip_next),
          iconSize: 36,
        ),
        IconButton(
          tooltip: 'Repeat',
          onPressed: player.cycleRepeatMode,
          icon: Icon(
            player.repeatMode == RepeatMode.one
                ? Icons.repeat_one
                : Icons.repeat,
          ),
          color: player.repeatMode == RepeatMode.off ? null : scheme.primary,
        ),
      ],
    );
  }
}
