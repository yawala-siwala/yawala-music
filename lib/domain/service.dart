import 'package:yawala_core/yawala_core.dart';

import '../native/platform_bindings.dart';
import 'model.dart';

/// Data access for the music library.
///
/// Resolution order for [list]:
/// 1. real device indexing, when the injected binding implements
///    [MediaLibraryIndexingBinding] — an empty result is reported as an
///    empty library (no demo tracks are substituted);
/// 2. the bundled sample library when the platform cannot index (binding
///    without the capability, or the channel reports unsupported), so
///    boilerplate platforms and unit tests keep working unchanged.
class MusicService {
  const MusicService({MusicNativeBinding? native}) : _native = native;

  final MusicNativeBinding? _native;

  /// Lists the playable library, trying the native indexer first.
  ///
  /// The capability probe widens the binding to `Object?`: flow analysis
  /// cannot promote a `MusicNativeBinding?` receiver to the unrelated
  /// [MediaLibraryIndexingBinding] interface directly.
  Future<List<Track>> list() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final Object? capability = _native;
    if (capability is MediaLibraryIndexingBinding) {
      final indexed = await capability.listLibrary();
      if (indexed != null) {
        YawalaLog.debug('device library indexed: ${indexed.length} tracks');
        return List.unmodifiable(indexed);
      }
      YawalaLog.debug('device indexing unavailable - using sample library');
    }
    return List.unmodifiable(Track.seedLibrary);
  }
}
