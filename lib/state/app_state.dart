import 'package:flutter/foundation.dart';

import '../domain/model.dart';
import '../domain/service.dart';

/// Owns the observable state of Yawala Music: filtered tracks, loading
/// flag and app-scoped runtime flags. Widgets rebuild via notifyListeners.
class MusicState extends ChangeNotifier {
  MusicState({required MusicService service}) : _service = service;

  final MusicService _service;
  String _filter = '';
  bool _loading = false;
  List<Track> _items = const [];

  Track? _nowPlaying;
  bool _isPlaying = false;

  Track? get nowPlaying => _nowPlaying;
  bool get isPlaying => _isPlaying;


  Iterable<Track> get items => _filter.isEmpty
      ? _items
      : _items.where((item) => item.matches(_filter.toLowerCase()));

  bool get isLoading => _loading;

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
}