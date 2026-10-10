import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

Map<String, dynamic> activity({String id = 'program', bool match = false}) => {
      'id': id,
      'program_id': 'program',
      'is_match': match,
      'federation_name': 'Federasyon',
      'office_name': 'İstanbul',
      'season_id': 'season',
      'season_label': '2026',
      'sport_code': 'tenis',
      'city_code': '34',
      'title': 'U16 Şampiyonası',
      'kind': 'tournament',
      'category': 'U16',
      'location': 'Merkez Kort',
      'status': 'open',
      'starts_at': '2026-09-30T21:00:00Z',
      'ends_at': '2026-10-03T21:00:00Z',
      'all_day': true,
    };
UnifiedCalendarEvent clubEvent(String id, String time,
        {String kind = 'training'}) =>
    UnifiedCalendarEvent.club({
      'id': id,
      'event_id': id,
      'club_id': 'club',
      'title': 'Kulüp etkinliği',
      'kind': kind,
      'starts_at': time,
      'status': 'scheduled'
    });
const month = CalendarMonth(2026, 10);
const account = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'athlete',
    coachLevel: 0,
    athleteKind: null);

void main() {
  test('month bounds use Turkey calendar independently of device timezone', () {
    expect(month.from, DateTime.utc(2026, 9, 30, 21));
    expect(month.to, DateTime.utc(2026, 10, 31, 21));
    expect(const CalendarMonth(2026, 12).to, DateTime.utc(2026, 12, 31, 21));
    expect(month, const CalendarMonth(2026, 10));
    expect(month, isNot(const CalendarMonth(2026, 10, sportCode: 'tenis')));
  });
  test(
      'safe parsing rejects missing timestamps and types without fabricating events',
      () {
    final parsed = FederationActivity.fromMap(activity()..['category'] = 7);
    expect(parsed.category, isNull);
    for (final value in [null, 4, 'bad date']) {
      expect(
          () => FederationActivity.fromMap(activity()..['starts_at'] = value),
          throwsFormatException);
    }
    expect(() => UnifiedCalendarEvent.club({'id': 'x'}), throwsFormatException);
    final e = UnifiedCalendarEvent.club({
      'id': 'x',
      'event_id': 'x',
      'club_id': 'c',
      'title': 'x',
      'kind': 'match',
      'status': 'scheduled',
      'starts_at': '2026-10-01T00:00Z',
      'home_score': '9'
    });
    expect(e.clubEvent!.homeScore, isNull);
  });
  test('multi-day official event includes final day and excludes next midnight',
      () {
    final e =
        UnifiedCalendarEvent.official(FederationActivity.fromMap(activity()));
    for (final day in [1, 2, 3])
      expect(e.occursOn(DateTime(2026, 10, day)), isTrue);
    expect(e.occursOn(DateTime(2026, 9, 30)), isFalse);
    expect(e.occursOn(DateTime(2026, 10, 4)), isFalse);
    expect(
        clubEvent('late', '2026-09-30T21:00Z').occursOn(DateTime(2026, 10, 1)),
        isTrue);
    expect(
        clubEvent('late', '2026-09-30T20:59Z').occursOn(DateTime(2026, 10, 1)),
        isFalse);
  });
  test('merge is chronological, immutable and deduplicates within sources', () {
    final official = FederationActivity.fromMap(activity());
    final training = clubEvent('training', '2026-10-02T10:00Z');
    final match = clubEvent('match', '2026-10-01T10:00Z', kind: 'match');
    final rows =
        mergeCalendarEvents([official, official], [training, match, training]);
    expect(rows.map((e) => e.type), [
      CalendarEventType.officialFederation,
      CalendarEventType.clubMatch,
      CalendarEventType.clubTraining
    ]);
    expect(() => rows.clear(), throwsUnsupportedError);
    expect(filterCalendarEvents(rows, day: DateTime(2026, 10, 3)).length, 1);
    expect(filterCalendarEvents(rows, type: CalendarEventType.clubTraining),
        [training]);
    expect(filterCalendarEvents(rows, place: 'Merkez Kort').length, 1);
  });
  test('standalone session has no fabricated RSVP/result event', () {
    final e = UnifiedCalendarEvent.club({
      'id': 'session',
      'event_id': null,
      'session_id': 'session',
      'club_id': 'club',
      'title': 'Teknik',
      'kind': 'training',
      'status': 'live',
      'starts_at': '2026-10-10T10:00Z'
    });
    expect(e.clubEvent, isNull);
    expect(e.sessionId, 'session');
  });
  test(
      'public service sends all real filter parameters; anonymous private service makes no request',
      () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://calendar.test', 'anon',
        httpClient: MockClient((r) async {
      requests.add(r);
      return http.Response(jsonEncode([activity()]), 200,
          headers: {'content-type': 'application/json'}, request: r);
    }));
    addTearDown(client.dispose);
    final service = UnifiedCalendarService(client);
    final rows = await service.activities((
      sportCode: 'tenis',
      cityCode: '34',
      seasonId: 'season',
      from: month.from,
      to: month.to
    ));
    expect(rows.single.title, 'U16 Şampiyonası');
    expect(
        requests.single.url.path, '/rest/v1/rpc/public_federation_activities');
    expect(jsonDecode(requests.single.body), {
      'p_sport': 'tenis',
      'p_city': '34',
      'p_season': 'season',
      'p_from': '2026-10-01',
      'p_to': '2026-11-01'
    });
    expect(await service.clubEntries(month, null), isEmpty);
    expect(requests.length, 1);
  });
  test('federation provider delegates selected sport/city/season to RPC',
      () async {
    final client = SupabaseClient('https://calendar.test', 'anon',
        httpClient: MockClient((r) async {
      expect(jsonDecode(r.body)['p_sport'], 'tenis');
      expect(jsonDecode(r.body)['p_city'], '34');
      expect(jsonDecode(r.body)['p_season'], 'season');
      return http.Response(jsonEncode([activity()]), 200,
          headers: {'content-type': 'application/json'}, request: r);
    }));
    addTearDown(client.dispose);
    final container = ProviderContainer(overrides: [
      isSupabaseEnabledProvider.overrideWithValue(true),
      supabaseClientProvider.overrideWithValue(client)
    ]);
    addTearDown(container.dispose);
    final rows = await container.read(federationActivitiesProvider((
      sportCode: 'tenis',
      cityCode: '34',
      seasonId: 'season',
      from: month.from,
      to: month.to
    )).future);
    expect(rows.single.category, 'U16');
  });
  test(
      'guest month never instantiates private provider and marks every program day',
      () async {
    final container = ProviderContainer(overrides: [
      swanAccessProvider.overrideWithValue(SwanAccess.none),
      federationActivitiesProvider.overrideWith(
          (ref, filter) async => [FederationActivity.fromMap(activity())]),
      calendarClubEntriesProvider
          .overrideWith((ref, month) => throw StateError('private read'))
    ]);
    addTearDown(container.dispose);
    final subscription =
        container.listen(unifiedCalendarMonthProvider(month), (p, n) {});
    addTearDown(subscription.close);
    final data =
        await container.read(unifiedCalendarMonthProvider(month).future);
    expect(data.events.length, 1);
    expect(data.clubUnavailable, isFalse);
    final days = container.read(calendarDayTypesProvider(month));
    expect(days[1], {CalendarEventType.officialFederation});
    expect(days[3], {CalendarEventType.officialFederation});
    expect(days[4], isEmpty);
  });
  test(
      'authenticated provider combines, filters by day/type and clears club data on signout',
      () async {
    final container = ProviderContainer(overrides: [
      swanAccessProvider.overrideWithValue(account),
      federationActivitiesProvider.overrideWith(
          (ref, filter) async => [FederationActivity.fromMap(activity())]),
      calendarClubEntriesProvider.overrideWith((ref, month) async => [
            clubEvent('training', '2026-10-02T10:00Z'),
            clubEvent('match', '2026-10-03T12:00Z', kind: 'match')
          ])
    ]);
    addTearDown(container.dispose);
    final sub =
        container.listen(unifiedCalendarMonthProvider(month), (p, n) {});
    addTearDown(sub.close);
    expect(
        (await container.read(unifiedCalendarMonthProvider(month).future))
            .events
            .length,
        3);
    final rows = await container.read(unifiedCalendarEventsProvider((
      month: month,
      day: DateTime(2026, 10, 2),
      type: CalendarEventType.clubTraining,
      place: null
    )).future);
    expect(rows.single.type, CalendarEventType.clubTraining);
    container.updateOverrides([
      swanAccessProvider.overrideWithValue(SwanAccess.none),
      federationActivitiesProvider.overrideWith(
          (ref, filter) async => [FederationActivity.fromMap(activity())]),
      calendarClubEntriesProvider.overrideWith((ref, month) async => [
            clubEvent('training', '2026-10-02T10:00Z'),
            clubEvent('match', '2026-10-03T12:00Z', kind: 'match')
          ])
    ]);
    expect(
        (await container.read(unifiedCalendarMonthProvider(month).future))
            .events
            .length,
        1);
  });
  for (final failPublic in [true, false]) {
    test(
        'partial source failure keeps successful source and reports failure ($failPublic)',
        () async {
      final container = ProviderContainer(overrides: [
        swanAccessProvider.overrideWithValue(account),
        federationActivitiesProvider.overrideWith((ref, f) async {
          if (failPublic) throw StateError('public unavailable');
          return [FederationActivity.fromMap(activity())];
        }),
        calendarClubEntriesProvider.overrideWith((ref, m) async {
          if (!failPublic) throw StateError('private unavailable');
          return [clubEvent('x', '2026-10-02T12:00Z')];
        })
      ]);
      addTearDown(container.dispose);
      final data =
          await container.read(unifiedCalendarMonthProvider(month).future);
      expect(data.events.length, 1);
      expect(data.officialUnavailable, failPublic);
      expect(data.clubUnavailable, !failPublic);
    });
  }
  test('both public calendar deep links are guest routes', () {
    expect(SwanAccess.isGuestRoute('/calendar'), isTrue);
    expect(SwanAccess.isGuestRoute('/federasyon-takvimi'), isTrue);
  });
}
