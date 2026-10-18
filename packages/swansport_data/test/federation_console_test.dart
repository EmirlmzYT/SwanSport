import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('match DTO has immutable officials and redacted/null excuses remain null', () {
    final m = FederationConsoleMatch.fromMap({'id': 'm', 'program': 'Lig', 'sport_code': 'tenis', 'status': 'scheduled',
      'officials': [{'id': 'o', 'duty': 'head_referee', 'status': 'declined', 'decline_reason': null}]});
    expect(m.officials.single.declineReason, isNull);
    expect(() => m.officials.clear(), throwsUnsupportedError);
  });
  test('report decodes masked subjects and numeric decisions without private identity fields', () {
    final r = FederationDisciplinaryReport.fromMap({'match_id': 'm', 'revision_id': 'v', 'program': 'Lig',
      'sport_code': 'tenis', 'signed_at': '2026-10-13T12:00:00Z', 'notes': 'Note', 'can_decide': false,
      'athletes': [{'athlete_id': 'a', 'club_id': 'c', 'reference': '#A3F91C'}],
      'red_cards': [{'athlete_id': 'a'}], 'decisions': [{'id': 'd', 'athlete_id': 'a', 'penalty_type': 'fine',
        'reason': 'Decision', 'created_at': '2026-10-13T12:00:00Z', 'fine_amount': 100}]});
    expect(r.athletes.single.reference, '#A3F91C');expect(r.decisions.single.fineAmount, 100.0);
    expect(r.canDecide, isFalse);expect(() => r.redCardAthleteIds.clear(), throwsUnsupportedError);
  });
  test('query identity includes city, search and server offset', () {
    expect(const FederationMatchQuery(cityCode: '34', offset: 50), const FederationMatchQuery(cityCode: '34', offset: 50));
    expect(const FederationMatchQuery(cityCode: '34'), isNot(const FederationMatchQuery(cityCode: '06')));
  });
  test('service uses exact narrow RPC parameters and never raw official tables', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.com', 'test', httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(request.url.path.endsWith('federation_console_matches') ? '{"total":0,"rows":[]}' : '"id"', 200,
        headers: {'content-type': 'application/json'}, request: request);
    }));
    addTearDown(client.dispose);
    final s = FederationConsoleService(client);
    await s.matches(const FederationMatchQuery(cityCode: '34', offset: 50, search: 'Lig'));
    expect(jsonDecode(requests.first.body), {'p_city': '34', 'p_offset': 50, 'p_search': 'Lig', 'p_from': null, 'p_until': null});
    await s.assignMatchOfficial('m', 'p', MatchOfficialDuty.headReferee);
    expect(requests.last.url.path, endsWith('/rpc/assign_match_official'));
    expect(jsonDecode(requests.last.body), {'p_match_id': 'm', 'p_profile_id': 'p', 'p_duty': 'head_referee'});
  });
}
