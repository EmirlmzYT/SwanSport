import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../widgets/console_table.dart';
import 'preference_storage.dart';

final consolePreferenceStorageProvider = Provider<ConsolePreferenceStorage>(
  (ref) => createConsolePreferenceStorage(),
);

/// Authentication is the only source of account identity. Loading/logout uses
/// ephemeral defaults, never a previous account's preferences.
final consolePreferenceAccountProvider = Provider<String?>((ref) {
  final session = ref.watch(authSessionProvider);
  return session.isLoading || session.hasError
      ? null
      : session.valueOrNull?.user.id;
});
final consolePreferenceClubProvider = Provider<String?>((ref) {
  final account = ref.watch(consolePreferenceAccountProvider);
  if (account == null) return null;
  final club = ref.watch(activeClubProvider);
  return club.isLoading || club.hasError ? null : club.valueOrNull?.id;
});

/// Synchronous restoration cannot overwrite a later user choice. Keep the
/// StateProvider API so existing consumers and test overrides remain valid.
StateProvider<T> consolePreference<T>(
  String name, {
  required T Function() fallback,
  required T Function(Object?) decode,
  required Object? Function(T) encode,
  bool clubScoped = false,
}) =>
    StateProvider<T>((ref) {
      final account = ref.watch(consolePreferenceAccountProvider);
      final club = clubScoped ? ref.watch(consolePreferenceClubProvider) : null;
      final key = account == null || (clubScoped && club == null)
          ? null
          : 'swansport.console.v1.${Uri.encodeComponent(account)}.'
              '${clubScoped ? '${Uri.encodeComponent(club!)}.' : ''}$name';
      final storage = ref.watch(consolePreferenceStorageProvider);
      var value = fallback();
      if (key != null) {
        try {
          final raw = storage.read(key);
          if (raw != null) value = decode(jsonDecode(raw));
        } catch (_) {/* Corrupt or blocked storage uses defaults. */}
      }
      // Riverpod 2 supports self-listening; this preserves StateProvider overrides.
      // ignore: deprecated_member_use
      ref.listenSelf((previous, next) {
        if (key != null) {
          try {
            storage.write(key, jsonEncode(encode(next)));
          } catch (_) {}
        }
      });
      return value;
    });

ConsoleTableQuery decodeConsoleQuery(Object? value,
    {String? defaultSort, Set<String> sortKeys = const {}}) {
  if (value is! Map) return ConsoleTableQuery(sortKey: defaultSort);
  final size = value['pageSize'];
  final sort = value['sortKey'];
  final search = value['search'];
  return ConsoleTableQuery(
    pageSize: const [25, 50, 100, 200].contains(size) ? size as int : 50,
    sortKey: sortKeys.contains(sort) ? sort as String : defaultSort,
    ascending: value['ascending'] is bool ? value['ascending'] as bool : true,
    search: search is String && search.length <= 200 ? search : '',
  );
}

Object encodeConsoleQuery(ConsoleTableQuery query) => {
      'pageSize': query.pageSize,
      'sortKey': query.sortKey,
      'ascending': query.ascending,
      'search': query.search,
    };
