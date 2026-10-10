import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('guest and identity decisions stay centralized and admin cannot bypass',
      () {
    for (final action in SwanAction.values) {
      expect(SwanAccess.none.decisionFor(action),
          SwanActionDecision.accountRequired);
    }
    const admin = SwanAccess(
        isPlatformAdmin: true,
        clubRole: 'coach',
        coachLevel: 5,
        athleteKind: null);
    expect(admin.decisionFor(SwanAction.clubApplication),
        SwanActionDecision.identityRequired);
    expect(admin.decisionFor(SwanAction.message), SwanActionDecision.allowed);
    expect(SwanAccess.isGuestRoute('/federasyon-takvimi'), isTrue);
    expect(SwanAccess.isGuestRoute('/sohbet'), isFalse);
    expect(SwanAccess.isGuestRoute('/athlete-detail'), isFalse);
  });

  test(
      'guest/fixture profile and program reads stay empty without constructing a client',
      () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await c.read(currentProfileProvider.future), isNull);
    expect(c.read(swanAccessProvider), SwanAccess.none);
    expect(await c.read(publicSportProgramsProvider.future), isEmpty);
    expect(await c.read(publicProgramFixtureProvider('org').future), isEmpty);
  });

  test(
      'a cached profile cannot keep access open after the auth session disappears',
      () async {
    final c = ProviderContainer(overrides: [
      isSupabaseEnabledProvider.overrideWithValue(true),
      authSessionProvider.overrideWith((ref) => Stream.value(null)),
      currentProfileProvider.overrideWith((ref) async => const ProfileInfo(
          id: 'old-account', fullName: 'Cached', role: 'club_admin')),
    ]);
    addTearDown(c.dispose);
    await c.read(authSessionProvider.future);
    await c.read(currentProfileProvider.future);
    expect(c.read(swanAccessProvider), SwanAccess.none);
  });

  test(
      'anonymous programs and fixture use only published RPCs with correct parameters',
      () async {
    final requests = <String>[];
    final client = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((r) async {
      requests.add(r.url.path);
      if (r.url.path.endsWith('public_sport_programs')) {
        return http.Response(
            jsonEncode([
              {
                'id': 'org',
                'name': 'Program',
                'sport_code': 'tenis',
                'city_code': '34',
                'season_label': '2026',
                'starts_on': '2026-10-10',
                'ends_on': '2026-12-01'
              }
            ]),
            200,
            request: r);
      }
      expect(jsonDecode(r.body), {'p_org': 'org'});
      return http.Response(
          jsonEncode([
            {
              'id': 'match',
              'starts_at': '2026-10-10T10:00:00Z',
              'location': 'Kort',
              'home_name': 'Club A',
              'away_name': 'Club B',
              'status': 'scheduled'
            }
          ]),
          200,
          request: r);
    }));
    addTearDown(client.dispose);
    final service = PublicProgramService(client);
    expect((await service.programs()).single.name, 'Program');
    expect((await service.fixture('org')).single.homeName, 'Club A');
    expect(requests, [
      '/rest/v1/rpc/public_sport_programs',
      '/rest/v1/rpc/public_program_fixture'
    ]);
  });

  test(
      'anonymous RSS metadata uses its public RPC without reading the admin table',
      () async {
    final client = SupabaseClient('https://example.supabase.co', 'test',
        httpClient: MockClient((r) async {
      expect(r.url.path, '/rest/v1/rpc/public_news_sources');
      return http.Response(
          '[{"id":"source","name":"Sport","url":"https://example.com/rss","active":true}]',
          200,
          request: r);
    }));
    addTearDown(client.dispose);
    expect((await NewsService(client).sources()).single.name, 'Sport');
  });
}
