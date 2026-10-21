import 'package:flutter/foundation.dart';

import 'endpoint_validation.dart';
import 'mutation_queue.dart';
import 'preferences_store.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider({required PreferencesStore store}) : _store = store;

  final PreferencesStore _store;
  final MutationQueue _mutations = MutationQueue();
  bool _disposed = false;

  static const defaultEndpoint = defaultPostsEndpoint;

  bool get darkMode => _store.darkMode;
  String get endpoint => _store.endpoint;

  Future<void> setDarkMode(bool value) => _mutations.run(() async {
    await _store.saveDarkMode(value);
    if (!_disposed) notifyListeners();
  });

  Future<void> setEndpoint(String value) => _mutations.run(() async {
    await _store.saveEndpoint(value);
    if (!_disposed) notifyListeners();
  });

  static String? validateEndpoint(String? value) {
    try {
      normalizePostsEndpoint(value ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
