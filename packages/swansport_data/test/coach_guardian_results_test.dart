import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

SwanAccess access(int level,
        {String role = 'coach',
        String status = 'approved',
        String sport = 'tenis',
        DateTime? expiry}) =>
    SwanAccess(
      isPlatformAdmin: false,
      clubRole: role,
      coachLevel: 5,
      athleteKind: null,
      sportCredentials: [
        CredentialRow(
            id: 'c',
            kind: 'coach',
            status: status,
            sportCode: sport,
            coachLevel: level,
            expiresOn: expiry)
      ],
    );
Map<String, dynamic> source({String outcome = 'won'}) => {
      'match_id': 'match',
      'name': 'Lig',
      'sport_code': 'tenis',
      'version': 1,
      'current_version': 2,
      'starts_at': '2026-10-10T12:00Z',
      'result': '2–0',
      'scores': [
        {'label': 'Set 1', 'home': 6, 'away': 2}
      ],
      'child_name': 'Çocuk',
      'outcome': outcome,
    };
void main() {
  for (final level in [1, 2, 3, 4, 5]) {
    test('same-sport level $level has correct official roster authority', () {
      final a = access(level);
      expect(a.isHeadCoachForSport('tenis'), level >= 3);
      expect(a.isAssistantCoachForSport('tenis'), level <= 2);
      expect(a.isHeadCoachForSport('yuzme'), false);
      expect(a.canPublishClubPosts,
          true); // Training/community staff capability remains.
    });
  }
  test(
      'role/aggregated level/platform admin/pending/expired never replace sport credential',
      () {
    expect(access(5, status: 'pending').isHeadCoachForSport('tenis'), false);
    expect(
        access(5, expiry: DateTime(2000)).isHeadCoachForSport('tenis'), false);
    expect(access(1, role: 'club_admin').isHeadCoachForSport('tenis'), true);
    expect(
        const SwanAccess(
                isPlatformAdmin: true,
                clubRole: null,
                coachLevel: 5,
                athleteKind: null)
            .isHeadCoachForSport('tenis'),
        false);
    expect(access(3).isHeadCoachForSport('tenis', at: DateTime.utc(2090)),
        true); // legacy null expiry
    expect(SwanAccess.none.isHeadCoachForSport('tenis'), false);
  });
  test(
      'roster uses existing RPC, reason/version, guardian card uses only private RPC',
      () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.supabase.co', 'key',
        httpClient: MockClient((r) async {
      requests.add(r);
      final name = r.url.path.split('/').last;
      if (name == 'guardian_notification_result' ||
          name == 'guardian_match_result')
        return http.Response(jsonEncode(source()), 200,
            request: r, headers: {'content-type': 'application/json'});
      return http.Response(jsonEncode('revision'), 200,
          request: r, headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final service = CoachGuardianService(client);
    final roster = OfficialTeamRoster.fromMap({
      'participant_id': 'p',
      'name': 'Lig',
      'sport_code': 'tenis',
      'version': 4,
      'athlete_ids': ['a']
    });
    await service.publishRoster(roster, ['a'], ' Onay ');
    expect(requests.single.url.path, '/rest/v1/rpc/federation_publish_roster');
    expect(jsonDecode(requests.single.body), {
      'p_participant': 'p',
      'p_athletes': ['a'],
      'p_reason': 'Onay',
      'p_expected_version': 4
    });
    final result = await service.result('notification');
    expect(result.outcome, GuardianResultOutcome.won);
    expect(result.source.currentVersion, 2);
    expect(requests.last.url.path, '/rest/v1/rpc/guardian_notification_result');
    expect(jsonDecode(requests.last.body), {'p_notification': 'notification'});
    expect((await service.matchResult('match', 'child')).outcome,
        GuardianResultOutcome.won);
    expect(jsonDecode(requests.last.body),
        {'p_match': 'match', 'p_athlete': 'child'});
    await expectLater(
        service.publishRoster(roster, [], 'x'), throwsFormatException);
    expect(requests.length, 3);
  });
  test('notification deep link uses notification identity, DM stays separate',
      () {
    NotificationRow n(String kind) => NotificationRow(
        id: 'notification',
        kind: kind,
        title: 'x',
        createdAt: DateTime(2026),
        entityType: 'official_result',
        entityId: 'child');
    expect(n('match_result').resultRoute,
        '/resmi-sonuc?notification=notification');
    expect(n('message').resultRoute, isNull);
  });
  test('safe roster parser rejects malformed records', () {
    expect(() => OfficialTeamRoster.fromMap({'participant_id': 'x'}),
        throwsFormatException);
    expect(
        () => OfficialTeamRoster.fromMap({
              'participant_id': 'p',
              'name': 'x',
              'sport_code': 'tenis',
              'version': '1',
              'athlete_ids': <String>[]
            }),
        throwsFormatException);
  });
  test('guest calendar does not construct private guardian providers',
      () async {
    final container = ProviderContainer(overrides: [
      swanAccessProvider.overrideWithValue(SwanAccess.none),
      federationActivitiesProvider.overrideWith((ref, filter) async => []),
      guardianCalendarResultsProvider
          .overrideWith((ref, month) => throw StateError('guest private read')),
    ]);
    addTearDown(container.dispose);
    expect(
        (await container.read(
                unifiedCalendarMonthProvider(const CalendarMonth(2026, 10))
                    .future))
            .events,
        isEmpty);
  });
  test(
      'guardian calendar refresh replaces result revision and deduplicates public match',
      () async {
    var version = 1;
    final container = ProviderContainer(overrides: [
      swanAccessProvider.overrideWithValue(const SwanAccess(
          isPlatformAdmin: false,
          clubRole: null,
          coachLevel: 0,
          athleteKind: null,
          guardianAthleteIds: {'child'})),
      federationActivitiesProvider.overrideWith((ref, filter) async => [
            FederationActivity.fromMap({
              'id': 'match',
              'program_id': 'p',
              'title': 'Lig',
              'sport_code': 'tenis',
              'season_id': 's',
              'season_label': '2026',
              'federation_name': 'F',
              'office_name': 'O',
              'kind': 'league',
              'status': 'played',
              'starts_at': '2026-10-10T12:00Z',
              'is_match': true
            })
          ]),
      calendarClubEntriesProvider.overrideWith((ref, month) async => []),
      guardianCalendarResultsProvider.overrideWith((ref, month) async => [
            GuardianCalendarResult.fromMap({
              'notification_id': 'n$version',
              'child_name': 'Çocuk',
              'summary': {
                ...source(outcome: version == 1 ? 'won' : 'lost'),
                'version': version
              }
            })
          ]),
    ]);
    addTearDown(container.dispose);
    const month = CalendarMonth(2026, 10);
    final subscription =
        container.listen(unifiedCalendarMonthProvider(month), (_, __) {});
    addTearDown(subscription.close);
    final first =
        await container.read(unifiedCalendarMonthProvider(month).future);
    expect(first.events.length, 1);
    expect(first.events.single.guardianResult!.result.outcome,
        GuardianResultOutcome.won);
    version = 2;
    container.read(officialResultRefreshProvider)();
    final latest =
        await container.read(unifiedCalendarMonthProvider(month).future);
    expect(latest.events.length, 1);
    expect(latest.events.single.guardianResult!.result.outcome,
        GuardianResultOutcome.lost);
  });
}
