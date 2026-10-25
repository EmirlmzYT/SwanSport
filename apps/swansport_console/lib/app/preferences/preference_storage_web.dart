import 'package:web/web.dart' as web;
import 'preference_storage.dart';

ConsolePreferenceStorage createStorage() => _BrowserStorage();

class _BrowserStorage implements ConsolePreferenceStorage {
  @override
  String? read(String key) => web.window.localStorage.getItem(key);
  @override
  void write(String key, String value) =>
      web.window.localStorage.setItem(key, value);
}
