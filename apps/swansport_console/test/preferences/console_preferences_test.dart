import 'dart:convert';
import 'package:swansport_console/features/finance/ledger_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_console/app/preferences/console_preferences.dart';
import 'package:swansport_console/app/preferences/preference_storage.dart';
import 'package:swansport_console/app/widgets/console_table.dart';

final _account = StateProvider<String?>((ref) => 'alice');
final _club = StateProvider<String?>((ref) => 'club-a');
final _query = consolePreference<ConsoleTableQuery>('test.query',
    clubScoped: true,
    fallback: () => const ConsoleTableQuery(),
    decode: (v) => decodeConsoleQuery(v, sortKeys: const {'name'}),
    encode: encodeConsoleQuery);
final _theme = consolePreference<String>('test.theme',
    fallback: () => 'light',
    decode: (v) => v == 'dark' ? 'dark' : 'light',
    encode: (v) => v);

ProviderContainer container(ConsolePreferenceStorage storage) =>
    ProviderContainer(
      overrides: [
        consolePreferenceStorageProvider.overrideWithValue(storage),
        consolePreferenceAccountProvider
            .overrideWith((ref) => ref.watch(_account)),
        consolePreferenceClubProvider.overrideWith((ref) => ref.watch(_club)),
      ],
    );

class BrokenStorage implements ConsolePreferenceStorage {
  @override
  String? read(String key) => throw StateError('blocked');
  @override
  void write(String key, String value) => throw StateError('full');
}

void main() {
  test('fresh controller restores preferences without stale page offsets', () {
    final store = MemoryConsolePreferenceStorage();
    final first = container(store);
    first.read(_query.notifier).state = const ConsoleTableQuery(
        page: 9,
        pageSize: 100,
        sortKey: 'name',
        ascending: false,
        search: 'text');
    first.dispose();
    final second = container(store);
    addTearDown(second.dispose);
    final restored = second.read(_query);
    expect(restored.page, 0);
    expect(restored.pageSize, 100);
    expect(restored.sortKey, 'name');
    expect(restored.ascending, false);
    expect(restored.search, 'text');
    second.read(_query.notifier).state = const ConsoleTableQuery();
    final third = container(store);
    addTearDown(third.dispose);
    expect(third.read(_query).search, '');
  });
  test('account and club switches and logout synchronously isolate settings',
      () {
    final c = container(MemoryConsolePreferenceStorage());
    addTearDown(c.dispose);
    c.read(_theme.notifier).state = 'dark';
    c.read(_query.notifier).state = const ConsoleTableQuery(pageSize: 100);
    c.read(_club.notifier).state = 'club-b';
    expect(c.read(_query).pageSize, 50);
    expect(c.read(_theme), 'dark');
    c.read(_account.notifier).state = 'bob';
    expect(c.read(_theme), 'light');
    c.read(_account.notifier).state = null;
    c.read(_theme.notifier).state = 'dark';
    c.read(_account.notifier).state = 'bob';
    expect(c.read(_theme), 'light');
    c.read(_account.notifier).state = 'alice';
    c.read(_club.notifier).state = 'club-a';
    expect(c.read(_query).pageSize, 100);
    expect(c.read(_theme), 'dark');
  });
  test('corrupt and invalid storage values use safe defaults', () {
    final store = MemoryConsolePreferenceStorage();
    store.values['swansport.console.v1.alice.club-a.test.query'] =
        '{"page":99,"pageSize":-1,"sortKey":"private","ascending":"yes","search":42}';
    final c = container(store);
    addTearDown(c.dispose);
    final query = c.read(_query);
    expect(query.page, 0);
    expect(query.pageSize, 50);
    expect(query.sortKey, null);
    expect(query.search, '');
    store.values['swansport.console.v1.alice.test.theme'] = '{invalid';
    expect(c.read(_theme), 'light');
  });
  test('read/write failures do not break state updates', () {
    final c = container(BrokenStorage());
    addTearDown(c.dispose);
    expect(c.read(_theme), 'light');
    c.read(_theme.notifier).state = 'dark';
    expect(c.read(_theme), 'dark');
  });
  test('ledger restoration respects date picker bounds and normalizes dates',
      () {
    for (final bounds in [
      {'from': '1900-01-01', 'to': '1901-01-01'},
      {'from': '2199-01-01', 'to': '2200-01-01'},
      {'from': '2026-12-02', 'to': '2026-01-01'},
    ]) {
      final store = MemoryConsolePreferenceStorage();
      store.values['swansport.console.v1.alice.club-a.ledger.range'] =
          jsonEncode(bounds);
      final c = container(store);
      expect(c.read(ledgerRangeProvider), DateRange.thisMonth());
      c.dispose();
    }
    final store = MemoryConsolePreferenceStorage();
    store.values['swansport.console.v1.alice.club-a.ledger.range'] = jsonEncode(
        {'from': '2020-01-01T17:30:00', 'to': '2020-01-03T20:30:00'});
    final c = container(store);
    addTearDown(c.dispose);
    expect(c.read(ledgerRangeProvider),
        DateRange(DateTime(2020), DateTime(2020, 1, 3)));
  });
  test('rapid writes restore the latest choice with no hydration race', () {
    final store = MemoryConsolePreferenceStorage();
    final c = container(store);
    c.read(_theme.notifier).state = 'dark';
    c.read(_theme.notifier).state = 'light';
    c.read(_theme.notifier).state = 'dark';
    c.dispose();
    final restored = container(store);
    addTearDown(restored.dispose);
    expect(restored.read(_theme), 'dark');
  });
}
