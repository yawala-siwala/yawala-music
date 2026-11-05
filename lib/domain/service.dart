import 'model.dart';

/// Data access for the music library.
///
/// The boilerplate serves [Track.seedLibrary]; swap the implementation for a
/// native media scanner via `platform_bindings.dart`.
class MusicService {
  const MusicService();

  Future<List<Track>> list() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(Track.seedLibrary);
  }
}