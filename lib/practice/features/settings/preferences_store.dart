import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../posts/post.dart';
import 'endpoint_validation.dart';
import 'mutation_queue.dart';

class PreferencesSaveException implements Exception {
  const PreferencesSaveException({this.cause});

  final Object? cause;

  @override
  String toString() => 'Không thể lưu dữ liệu trên thiết bị. Vui lòng thử lại.';
}

/// This store owns confirmed values rather than the plugin's optimistic cache.
class PreferencesStore {
  PreferencesStore(SharedPreferences prefs)
    : _prefs = prefs,
      _darkMode = prefs.get(darkModeKey) is bool
          ? prefs.get(darkModeKey) as bool
          : false,
      _endpoint = _readEndpoint(prefs.get(endpointKey)),
      _favoritesBySource = _readFavoriteSources(
        prefs.get(favoritesBySourceKey),
        prefs.get(favoritesKey),
      );

  static const darkModeKey = 'settings.darkMode';
  static const endpointKey = 'settings.endpoint';
  static const favoritesKey = 'favorites.posts';
  static const favoritesBySourceKey = 'favorites.sources.v2';

  final SharedPreferences _prefs;
  final MutationQueue _writes = MutationQueue();
  bool _darkMode;
  String _endpoint;
  Map<String, List<Post>> _favoritesBySource;

  bool get darkMode => _darkMode;
  String get endpoint => _endpoint;

  /// Legacy API aliases the original JSONPlaceholder namespace.
  List<Post> get favorites => favoritesFor(defaultPostsEndpoint);

  List<Post> favoritesFor(String source) =>
      _favoritesBySource[source] ?? const <Post>[];

  Future<void> saveDarkMode(bool value) => _writes.run(() async {
    await _persist(() => _prefs.setBool(darkModeKey, value));
    _darkMode = value;
  });

  Future<void> saveEndpoint(String value) => _writes.run(() async {
    final endpoint = normalizePostsEndpoint(value);
    await _persist(() => _prefs.setString(endpointKey, endpoint));
    _endpoint = endpoint;
  });

  Future<void> saveFavorites(List<Post> posts) =>
      saveFavoritesFor(defaultPostsEndpoint, posts);

  Future<void> saveFavoritesFor(String source, List<Post> posts) {
    final snapshot = List<Post>.unmodifiable(posts);
    return _writes.run(() async {
      // Merge when this write reaches the queue so another source is not lost.
      final next = <String, List<Post>>{
        ..._favoritesBySource,
        source: snapshot,
      };
      final json = jsonEncode(
        next.map(
          (key, posts) =>
              MapEntry(key, posts.map((post) => post.toJson()).toList()),
        ),
      );
      await _persist(() => _prefs.setString(favoritesBySourceKey, json));
      _favoritesBySource = Map<String, List<Post>>.unmodifiable(next);
    });
  }

  Future<void> _persist(Future<bool> Function() write) async {
    try {
      if (!await write()) throw const PreferencesSaveException();
    } catch (error) {
      // Legacy SharedPreferences mutates its cache before awaiting native writes.
      // Reload it so a new store does not mistake a failed write for saved data.
      try {
        await _prefs.reload();
      } catch (_) {
        // Confirmed values above stay unchanged even if the platform is offline.
      }
      if (error is PreferencesSaveException) rethrow;
      throw PreferencesSaveException(cause: error);
    }
  }

  static String _readEndpoint(Object? value) {
    if (value is String) {
      try {
        return normalizePostsEndpoint(value);
      } on FormatException {
        // Old or corrupt settings must not prevent startup.
      }
    }
    return defaultPostsEndpoint;
  }

  static Map<String, List<Post>> _readFavoriteSources(
    Object? value,
    Object? legacy,
  ) {
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          // A valid v2 map is authoritative, including explicit empty lists.
          // Do not resurrect an old legacy favorite after it has been removed.
          return Map<String, List<Post>>.unmodifiable({
            for (final entry in decoded.entries)
              if (entry.value is List) entry.key: _readSnapshots(entry.value),
          });
        }
      } on FormatException {
        // Recover from the untouched legacy value when the v2 JSON is corrupt.
      }
    }
    return Map<String, List<Post>>.unmodifiable({
      defaultPostsEndpoint: _readLegacyFavorites(legacy),
    });
  }

  static List<Post> _readLegacyFavorites(Object? value) {
    if (value is String) {
      try {
        return _readSnapshots(jsonDecode(value));
      } on FormatException {
        // Malformed stored JSON is treated as an empty list.
      }
    }
    return const <Post>[];
  }

  static List<Post> _readSnapshots(Object? decoded) {
    final posts = <Post>[];
    if (decoded is! List) return const <Post>[];
    final ids = <int>{};
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      try {
        final post = Post.fromJson(item);
        if (ids.add(post.id)) posts.add(post);
      } catch (_) {
        // Recover unaffected snapshots instead of discarding the whole list.
      }
    }
    return List<Post>.unmodifiable(posts);
  }
}
