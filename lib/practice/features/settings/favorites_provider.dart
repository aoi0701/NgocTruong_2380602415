import 'package:flutter/foundation.dart';

import '../posts/post.dart';
import 'mutation_queue.dart';
import 'preferences_store.dart';

class FavoritesProvider extends ChangeNotifier {
  FavoritesProvider({required PreferencesStore store})
    : _store = store,
      _source = store.endpoint;

  final PreferencesStore _store;
  final MutationQueue _mutations = MutationQueue();
  String _source;
  bool _disposed = false;

  List<Post> get favorites => _store.favoritesFor(_source);
  bool contains(int id) => favorites.any((post) => post.id == id);

  void setSource(String source) {
    if (_disposed || _source == source) return;
    _source = source;
    if (!_disposed) notifyListeners();
  }

  Future<void> toggle(Post post) {
    // Capture before enqueueing: switching the screen's source during a slow
    // save must not send this post to a different endpoint's namespace.
    final source = _source;
    return _mutations.run(() async {
      final next = _store.favoritesFor(source).toList();
      final existing = next.indexWhere((item) => item.id == post.id);
      if (existing == -1) {
        next.add(post);
      } else {
        next.removeAt(existing);
      }
      await _store.saveFavoritesFor(source, next);
      if (!_disposed && _source == source) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
