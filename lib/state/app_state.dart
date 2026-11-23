import 'package:flutter/foundation.dart';

import '../domain/model.dart';
import '../domain/service.dart';
import '../native/platform_bindings.dart';

/// Owns the observable state of Yawala Music: filtered tracks, loading
/// flag and app-scoped runtime flags. Widgets rebuild via notifyListeners.
class MusicState extends ChangeNotifier {
  MusicState({required MusicService service, MusicNativeBinding? native})
      : _service = service,
        _native = native;

  final MusicService _service;

  /// Optional direct native access, used to ask for media-read permission
  /// before the first index pass on platforms that support it.
  final MusicNativeBinding? _native;
  String _filter = '';
  bool _loading = false;
  List<Track> _items = const [];
  bool _libraryAccessRequested = false;

  Track? _nowPlaying;
  bool _isPlaying = false;

  Track? get nowPlaying => _nowPlaying;
  bool get isPlaying => _isPlaying;


  /// Every library track regardless of the active filter.
  List<Track> get allItems => List.unmodifiable(_items);

  Iterable<Track> get items => _filter.isEmpty
      ? _items
      : _items.where((item) => item.matches(_filter.toLowerCase()));

  bool get isLoading => _loading;

  /// Result of the platform library-permission request, if one was made.
  bool? get lastLibraryAccessGrant => _lastAccessGrant;
  bool? _lastAccessGrant;

  void setFilter(String value) {
    _filter = value.trim().toLowerCase();
    notifyListeners();
  }

  /// Resumes or pauses playback. Replace the body with native audio-session
  /// calls once the platform bindings are wired up.
  void togglePlayback() {
    _nowPlaying ??= _items.isEmpty ? null : _items.first;
    if (_nowPlaying != null) {
      _isPlaying = !_isPlaying;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    _loading = true;
    notifyListeners();
    try {
      _items = await _service.list();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Full app boot: ask the platform for media-read access (when it can
  /// ask), then index the library. Platforms without the capability fall
  /// straight through to [reload]. The capability probe widens to `Object?`
  /// because flow analysis cannot promote to an unrelated interface.
  Future<void> load() async {
    final Object? capability = _native;
    if (capability is MediaLibraryIndexingBinding && !_libraryAccessRequested) {
      _libraryAccessRequested = true;
      _lastAccessGrant = await capability.requestLibraryAccess();
    }
    await reload();
  }
}