import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test(
      'match DTO has immutable officials and redacted/null excuses remain null',
      () {
    final m = FederationConsoleMatch.fromMap({
      'id': 'm',
      'program': 'Lig',
      'sport_code': 'tenis',
      'status': 'scheduled',
      'officials': [
        {
          'id': 'o',
          'duty': 'head_referee',
          'status': 'declined',
          'decline_reason': null
        }
      ]
    });
    expect(m.officials.single.declineReason, isNull);
    expect(() => m.officials.clear(), throwsUnsupportedError);
  });
  test(
      'report decodes masked subjects and numeric decisions without private identity fields',
      () {
    final r = FederationDisciplinaryReport.fromMap({
      'match_id': 'm',
      'revision_id': 'v',
      'program': 'Lig',
      'sport_code': 'tenis',
      'signed_at': '2026-10-13T12:00:00Z',
      'notes': 'Note',
      'can_decide': false,
      'athletes': [
        {'athlete_id': 'a', 'club_id': 'c', 'reference': '#A3F91C'}
      ],
      'red_cards': [
        {'athlete_id': 'a'}
      ],
      'decisions': [
        {
          'id': 'd',
          'athlete_id': 'a',
          'penalty_type': 'fine',
          'reason': 'Decision',
          'created_at': '2026-10-13T12:00:00Z',
          'fine_amount': 100
        }
      ]
    });
    expect(r.athletes.single.reference, '#A3F91C');
    expect(r.decisions.single.fineAmount, 100.0);
    expect(r.canDecide, isFalse);
    expect(() => r.redCardAthleteIds.clear(), throwsUnsupportedError);
  });
  test(
      'query identity includes federationId, sportCode, city, search and server offset',
      () {
    expect(
      const FederationMatchQuery(
          federationId: 'fed-1',
          sportCode: 'futbol',
          cityCode: '34',
          offset: 50),
      const FederationMatchQuery(
          federationId: 'fed-1',
          sportCode: 'futbol',
          cityCode: '34',
          offset: 50),
    );
    expect(
      const FederationMatchQuery(
          federationId: 'fed-1', sportCode: 'futbol', cityCode: '34'),
      isNot(const FederationMatchQuery(
          federationId: 'fed-2', sportCode: 'basketbol', cityCode: '34')),
    );
    expect(const FederationMatchQuery(cityCode: '34'),
        isNot(const FederationMatchQuery(cityCode: '06')));
  });
  test(
      'service uses exact narrow RPC parameters, filters matches by sportCode, and never queries raw official tables',
      () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.com', 'test',
        httpClient: MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('federation_console_matches')) {
        return http.Response(
          jsonEncode({
            'total': 2,
            'rows': [
              {
                'id': 'm1',
                'program': 'Futbol Lig',
                'sport_code': 'futbol',
                'status': 'scheduled',
                'officials': []
              },
              {
                'id': 'm2',
                'program': 'Basket Lig',
                'sport_code': 'basketbol',
                'status': 'scheduled',
                'officials': []
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
      return http.Response('"id"', 200,
          headers: {'content-type': 'application/json'}, request: request);
    }));
    addTearDown(client.dispose);
    final s = FederationConsoleService(client);
    final page = await s.matches(const FederationMatchQuery(
        federationId: 'fed-1',
        sportCode: 'futbol',
        cityCode: '34',
        offset: 50,
        search: 'Lig'));
    expect(jsonDecode(requests.first.body), {
      'p_city': '34',
      'p_offset': 50,
      'p_search': 'Lig',
      'p_from': null,
      'p_until': null
    });
    expect(page.rows.map((r) => r.id), ['m1']);
    expect(page.total, 1);
    await s.assignMatchOfficial('m', 'p', MatchOfficialDuty.headReferee);
    expect(requests.last.url.path, endsWith('/rpc/assign_match_official'));
    expect(jsonDecode(requests.last.body),
        {'p_match_id': 'm', 'p_profile_id': 'p', 'p_duty': 'head_referee'});
    await s.allocateOfficialMatchFacility(
        'm', 'fac-1', DateTime.utc(2026, 11, 2, 14));
    expect(requests.last.url.path,
        endsWith('/rpc/allocate_official_match_facility'));
    expect(jsonDecode(requests.last.body), {
      'p_match_id': 'm',
      'p_facility_id': 'fac-1',
      'p_ends_at': '2026-11-02T14:00:00.000Z'
    });
    final b = FederationBulletinService(client);
    await b.publishDisciplinaryBulletin(
        decisionId: 'dec-1', publicSummary: '1 maç men cezası');
    expect(
        requests.last.url.path, endsWith('/rpc/publish_disciplinary_bulletin'));
    expect(jsonDecode(requests.last.body),
        {'p_decision_id': 'dec-1', 'p_public_summary': '1 maç men cezası'});
    await b.publishMatchNotice(
        matchId: 'm1',
        noticeType: 'match_postponed',
        publicSummary: 'Ertelendi');
    expect(requests.last.url.path,
        endsWith('/rpc/publish_federation_match_notice'));
    expect(jsonDecode(requests.last.body), {
      'p_match_id': 'm1',
      'p_notice_type': 'match_postponed',
      'p_public_summary': 'Ertelendi'
    });
  });
}
