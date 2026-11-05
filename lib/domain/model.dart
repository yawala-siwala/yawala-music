import 'package:yawala_core/yawala_core.dart';

/// A playable audio track in the Yawala Music library.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.filePath,
  });

  /// Sample library used by the boilerplate service until the native media
  /// scanner is wired up through `platform_bindings.dart`.
  static const List<Track> seedLibrary = [
    Track(
      id: 'yt-01',
      title: 'Golden Hour',
      artist: 'Monday Lights',
      album: 'Sundial',
      duration: Duration(seconds: 214),
      filePath: '/music/sundial/golden_hour.flac',
    ),
    Track(
      id: 'yt-02',
      title: 'Neon Drift',
      artist: 'Kite Theory',
      album: 'Skyline EP',
      duration: Duration(seconds: 189),
      filePath: '/music/skyline_ep/neon_drift.flac',
    ),
    Track(
      id: 'yt-03',
      title: 'Paper Boats',
      artist: 'Yumi & the Harbours',
      album: 'Tidelines',
      duration: Duration(seconds: 245),
      filePath: '/music/tidelines/paper_boats.flac',
    ),
    Track(
      id: 'yt-04',
      title: 'Slow Static',
      artist: 'Dwarf Galaxy',
      album: 'Longwave',
      duration: Duration(seconds: 302),
      filePath: '/music/longwave/slow_static.flac',
    ),
    Track(
      id: 'yt-05',
      title: 'Concrete Bloom',
      artist: 'Fermata Ghost',
      album: 'City Gardens',
      duration: Duration(seconds: 198),
      filePath: '/music/city_gardens/concrete_bloom.flac',
    ),
    Track(
      id: 'yt-06',
      title: 'Blue Hour Bird',
      artist: 'Monday Lights',
      album: 'Sundial',
      duration: Duration(seconds: 176),
      filePath: '/music/sundial/blue_hour_bird.flac',
    ),
    Track(
      id: 'yt-07',
      title: 'Salt Air Anthem',
      artist: 'Romeo Volt',
      album: 'Coastlines',
      duration: Duration(seconds: 233),
      filePath: '/music/coastlines/salt_air_anthem.flac',
    ),
    Track(
      id: 'yt-08',
      title: 'Midnight Rearview',
      artist: 'Kite Theory',
      album: 'Skyline EP',
      duration: Duration(seconds: 261),
      filePath: '/music/skyline_ep/midnight_rearview.flac',
    ),
  ];

  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;

  /// Absolute path, content URI or stream URL handed to the platform player.
  final String filePath;

  String get displayName => title;
  String get subtitle => '$artist - $album';
  String get meta => formatDuration(duration);

  bool matches(String query) =>
      displayName.toLowerCase().contains(query) ||
      artist.toLowerCase().contains(query);

  @override
  String toString() => 'Track($id, $title, $artist)';
}