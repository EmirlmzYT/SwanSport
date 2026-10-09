import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SeasonSetupDraft draft(
        {DateTime? end,
        DateTime? until,
        List<int> days = const [1, 3, 5],
        List<String> athletes = const [],
        String? fee,
        num? amount,
        int due = 10}) =>
    SeasonSetupDraft(
        clubId: 'club',
        label: ' Sezon ',
        startsOn: DateTime(2026, 10, 5),
        endsOn: end ?? DateTime(2027, 9, 30),
        teamName: ' Takım ',
        scheduleUntil: until,
        weekdays: days,
        athleteIds: athletes,
        feeName: fee,
        feeAmount: amount,
        dueDay: due);
void main() {
  test('service sends operation ID and validated payload to the atomic RPC',
      () async {
    final client = SupabaseClient('https://example.invalid', 'test',
        httpClient: MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/open_club_season');
      final body = jsonDecode(request.body) as Map;
      expect(body['p_op'], 'operation');
      expect(body['p_club'], 'club');
      expect(body['p_input'], draft().toMap());
      return http.Response(
          jsonEncode({
            'season_id': 's',
            'team_id': 't',
            'roster_count': 0,
            'event_count': 0,
            'fee_plan_id': null
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request);
    }));
    addTearDown(client.dispose);
    final result = await ClubConfigService(client)
        .openSeason(draft(), operationId: 'operation');
    expect(result.seasonId, 's');
  });
  test('service rejects invalid draft before making a request', () async {
    var requests = 0;
    final client = SupabaseClient('https://example.invalid', 'test',
        httpClient: MockClient((request) async {
      requests++;
      return http.Response('{}', 200);
    }));
    addTearDown(client.dispose);
    await expectLater(
        ClubConfigService(client)
            .openSeason(draft(athletes: ['a', 'a']), operationId: 'op'),
        throwsArgumentError);
    expect(requests, 0);
  });
  test(
      'optional steps are omitted and date-only payload preserves calendar day',
      () {
    final d = draft();
    expect(d.validate(), isNull);
    expect(d.toMap()['label'], 'Sezon');
    expect(d.toMap()['starts_on'], '2026-10-05');
    expect(d.toMap().containsKey('schedule'), isFalse);
    expect(d.toMap().containsKey('fee'), isFalse);
  });
  test('inclusive weekday count and programme boundary', () {
    expect(draft(until: DateTime(2026, 10, 11)).eventCount, 3);
    expect(
        draft(until: DateTime(2027, 1, 3), days: [1, 2, 3, 4, 5, 6, 7])
            .eventCount,
        91);
    expect(draft(until: DateTime(2027, 1, 4)).validate(), isNotNull);
    expect(draft(until: DateTime(2026, 10, 4)).validate(), isNotNull);
    expect(draft(until: DateTime(2026, 10, 11), days: [1, 1]).validate(),
        isNotNull);
  });
  test('season dates and athlete counts cannot exceed limits', () {
    expect(draft(end: DateTime(2027, 10, 5)).validate(), isNull);
    expect(draft(end: DateTime(2027, 10, 6)).validate(), isNotNull);
    expect(draft(athletes: ['a', 'a']).validate(), isNotNull);
    expect(
        draft(athletes: List.generate(201, (i) => '$i')).validate(), isNotNull);
  });
  test('fee precision, finite value and due-day validation', () {
    for (final amount in [
      0,
      -1,
      1.001,
      double.nan,
      double.infinity,
      10000001
    ]) {
      expect(draft(fee: 'Aidat', amount: amount).validate(), isNotNull);
    }
    expect(draft(fee: 'Aidat', amount: 123.45, due: 28).validate(), isNull);
    expect(draft(fee: 'Aidat', amount: 123.45, due: 29).validate(), isNotNull);
  });
  test('result reflects server counts and optional inactive-plan ID', () {
    final r = SeasonSetupResult.fromMap({
      'season_id': 's',
      'team_id': 't',
      'roster_count': 2,
      'event_count': 3,
      'fee_plan_id': null
    });
    expect(r.rosterCount, 2);
    expect(r.eventCount, 3);
    expect(r.feePlanId, isNull);
  });
}
