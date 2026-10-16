import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('catalog merge drops unknown codes and deduplicates real branches', () {
    expect(catalogSportsFor(['yuzme', 'okculuk', 'yuzme', null, 'unknown'])
        .map((s) => s.code).toSet(), {'yuzme', 'okculuk'});
    expect(catalogSportsFor(['archery', 'okculuk']), hasLength(1));
    expect(matchesTrainingSportContext('football', 'futbol'), isTrue);
    expect(matchesTrainingSportContext('yuzme', 'okculuk'), isFalse);
  });
  test('single branch auto-selects; explicit All and catalog browsing remain filters only', () {
    final container = ProviderContainer(overrides: [
      activeClubProvider.overrideWith((ref) async => null),
      sportContextOptionsProvider.overrideWithValue(AsyncData(catalogSportsFor(['yuzme']))),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(effectiveSportContextProvider, (_, __) {});
    addTearDown(subscription.close);
    expect(container.read(effectiveSportContextProvider), 'yuzme');
    container.read(selectedSportContextProvider.notifier).state = '*';
    expect(container.read(effectiveSportContextProvider), isNull);
    container.read(selectedSportContextProvider.notifier).state = 'satranc';
    expect(container.read(effectiveSportContextProvider), 'satranc');
    container.read(selectedSportContextProvider.notifier).state = 'unknown';
    expect(container.read(effectiveSportContextProvider), 'yuzme');
  });
  test('multiple branches require choice; changing club resets previous selection', () async {
    final container = ProviderContainer(overrides: [
      activeClubProvider.overrideWith((ref) async => ClubRef(
        id: ref.watch(selectedClubIdProvider) ?? 'first', name: 'Fixture')),
      sportContextOptionsProvider.overrideWithValue(AsyncData(catalogSportsFor(['yuzme', 'okculuk']))),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(effectiveSportContextProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(activeClubProvider.future);
    expect(container.read(effectiveSportContextProvider), isNull);
    container.read(selectedSportContextProvider.notifier).state = 'okculuk';
    expect(container.read(effectiveSportContextProvider), 'okculuk');
    container.read(selectedClubIdProvider.notifier).state = 'second';
    await container.read(activeClubProvider.future);
    expect(container.read(selectedSportContextProvider), isNull);
  });
  test('pure accountant never constructs a client or subscribes to athletic history', () async {
    final session = Session(accessToken: 'fixture', tokenType: 'bearer', user: User(
      id: 'accountant', appMetadata: {}, userMetadata: {}, aud: 'authenticated', createdAt: '2020-01-01T00:00:00Z'));
    final container = ProviderContainer(overrides: [
      isSupabaseEnabledProvider.overrideWithValue(true),
      authSessionProvider.overrideWith((ref) => Stream.value(session)),
      swanAccessProvider.overrideWithValue(const SwanAccess(isPlatformAdmin: false,
        clubRole: null, coachLevel: 0, athleteKind: null, accountantClubIds: {'club'})),
      supabaseClientProvider.overrideWith((ref) => throw StateError('No athletic client permitted')),
      myTrainingHistoryProvider.overrideWith((ref) => throw StateError('No athletic history permitted')),
    ]);
    addTearDown(container.dispose);
    await container.read(authSessionProvider.future);
    expect(await container.read(myActiveSportsProvider.future), isEmpty);
    expect(await container.read(activeClubSportsProvider.future), isEmpty);
  });
}
