import 'preference_storage_stub.dart'
    if (dart.library.js_interop) 'preference_storage_web.dart' as platform;

/// Only non-sensitive console presentation preferences belong in this store.
abstract interface class ConsolePreferenceStorage {
  String? read(String key);
  void write(String key, String value);
}

class MemoryConsolePreferenceStorage implements ConsolePreferenceStorage {
  final Map<String, String> values = {};
  @override
  String? read(String key) => values[key];
  @override
  void write(String key, String value) => values[key] = value;
}

ConsolePreferenceStorage createConsolePreferenceStorage() =>
    platform.createStorage();
