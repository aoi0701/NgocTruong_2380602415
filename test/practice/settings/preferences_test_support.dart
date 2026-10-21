import 'dart:async';

import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

// Fake only the native boundary: real SharedPreferences caching and serialization
// remain active, including its cache-before-native-write behavior.
class ControlledPreferencesPlatform extends InMemorySharedPreferencesStore {
  ControlledPreferencesPlatform() : super.empty();

  Completer<void>? gate;
  bool failNextWrite = false;
  bool throwNextWrite = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final pendingGate = gate;
    gate = null;
    if (pendingGate != null) await pendingGate.future;
    if (throwNextWrite) {
      throwNextWrite = false;
      throw StateError('Native storage unavailable');
    }
    if (failNextWrite) {
      failNextWrite = false;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}
