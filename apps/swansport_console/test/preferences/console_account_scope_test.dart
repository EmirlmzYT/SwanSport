import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_console/app/preferences/console_account_scope.dart';
import 'package:swansport_console/app/preferences/console_preferences.dart';
import 'package:swansport_console/app/preferences/preference_storage.dart';

final _cachedRows = StateProvider<String>((ref) => 'empty');
final _setting = consolePreference<String>('account-scope-test',
    fallback: () => 'light', decode: (v) => v == 'dark' ? 'dark' : 'light',
    encode: (v) => v);
Session session(String id, {String token = 'test'}) => Session(
    accessToken: token,
    tokenType: 'bearer',
    user: User(
        id: id,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z'));
void main() {
  testWidgets('account scope discards rows and preserves configured overrides',
      (tester) async {
    final auth = StreamController<Session?>();
    final client = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    final store = MemoryConsolePreferenceStorage();
    final outer = ProviderContainer(overrides: [
      authSessionProvider.overrideWith((ref) => auth.stream),
      supabaseClientProvider.overrideWithValue(client),
      supabaseConfigProvider.overrideWithValue(const SupabaseConfig(
          url: 'https://example.supabase.co', anonKey: 'test')),
      consolePreferenceStorageProvider.overrideWithValue(store),
    ]);
    addTearDown(() async {
      outer.dispose();
      await auth.close();
      await tester.runAsync(client.dispose);
    });
    ProviderContainer? inner;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: outer,
      child: ConsoleAccountScope(
          overrides: [_cachedRows.overrideWith((ref) => 'configured empty')],
          child: Consumer(builder: (context, ref, _) {
        ref.watch(authSessionProvider);
            inner = ProviderScope.containerOf(context, listen: false);
            return const SizedBox();
          })),
    ));
    auth.add(session('alice'));
    await tester.pump();
    await tester.pump();
    final alice = inner!;
    expect(alice.read(authSessionProvider).valueOrNull?.user.id, 'alice');
    expect(alice.read(consolePreferenceAccountProvider), 'alice');
    alice.read(_cachedRows.notifier).state = 'alice private rows';
    alice.read(_setting.notifier).state = 'dark';
    expect(identical(alice.read(supabaseClientProvider), client), true);
    expect(
        identical(alice.read(consolePreferenceStorageProvider), store), true);
    auth.add(session('alice', token: 'refreshed-token'));
    await tester.pump();
    await tester.pump();
    expect(identical(inner, alice), true);
    expect(inner!.read(_cachedRows), 'alice private rows');
    expect(inner!.read(_setting), 'dark');
    expect(inner!.read(authSessionProvider).valueOrNull?.accessToken,
        'refreshed-token');
    expect(inner!.read(consolePreferenceAccountProvider), 'alice');
    auth.add(session('bob'));
    await tester.pump();
    await tester.pump();
    expect(identical(inner, alice), false);
    expect(inner!.read(authSessionProvider).valueOrNull?.user.id, 'bob');
    expect(inner!.read(consolePreferenceAccountProvider), 'bob');
    expect(inner!.read(_setting), 'light');
    expect(inner!.read(_cachedRows), 'configured empty');
    inner!.read(_cachedRows.notifier).state = 'bob private rows';
    auth.add(null);
    await tester.pump();
    await tester.pump();
    expect(inner!.read(_cachedRows), 'configured empty');
    expect(inner!.read(authSessionProvider).valueOrNull, null);
    expect(inner!.read(consolePreferenceAccountProvider), null);
    await tester.pumpWidget(const SizedBox());
  });
}
