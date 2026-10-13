import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

final _session = {
  'access_token':'test-token','refresh_token':'refresh','expires_in':3600,
  'token_type':'bearer','user':{'id':'me','aud':'authenticated',
    'created_at':'2026-10-13T00:00:00Z','app_metadata':<String,dynamic>{},
    'user_metadata':<String,dynamic>{}}
};
final _role = {'id':'r','federation_id':'f','profile_id':'me','role':'president',
  'city_code':null,'starts_on':'2026-01-01','ends_on':'2090-01-01','revoked_at':null};

void main() {
  Future<SupabaseClient> clientFor(Future<http.Response> Function(http.Request) handle) async {
    final client = SupabaseClient('https://example.supabase.co', 'test', httpClient: MockClient((r) async {
      if (r.url.path.endsWith('/token')) return response(_session, r);
      return handle(r);
    }));
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(email:'test@example.com', password:'test-password');
    return client;
  }
  test('own role queries explicitly filter current profile and retain no private fields', () async {
    final client = await clientFor((r) async {
      expect(r.url.path, '/rest/v1/federation_roles');
      expect(r.url.queryParameters['profile_id'], 'eq.me');
      expect(r.url.queryParameters['revoked_at'], 'is.null');
      expect(r.url.queryParameters['select'], isNot(contains('*')));
      return response([_role], r);
    });
    final rows = await SportsRolesService(client).fetchMyFederationRoles();
    expect(rows.single.role, FederationRoleKind.president);
    expect(() => rows.clear(), throwsUnsupportedError);
  });
  test('assignment response and lineup write send exact 0110 signatures; successful writes notify', () async {
    var changes = 0;
    final bodies = <Map<String,dynamic>>[];
    final paths = <String>[];
    final client = await clientFor((r) async {
      paths.add(r.url.path); bodies.add(jsonDecode(r.body) as Map<String,dynamic>);
      return response(null, r);
    });
    final service = SportsRolesService(client, onChanged: () => changes++);
    await service.respondMatchAssignment('o', false, reason:'Unavailable');
    await service.verifyMatchLineup('m', ['a'], ['b'], notes:'Signed', homeSubs:['c']);
    expect(paths, ['/rest/v1/rpc/respond_match_assignment','/rest/v1/rpc/referee_verify_lineup']);
    expect(bodies[0], {'p_official_id':'o','p_accept':false,'p_reason':'Unavailable'});
    expect(bodies[1], {'p_match_id':'m','p_home_roster':['a'],'p_away_roster':['b'],
      'p_notes':'Signed','p_home_substitutes':['c'],'p_away_substitutes':<String>[]});
    expect(changes, 2);
  });
  test('failed writes propagate error and do not signal a successful update', () async {
    var changes = 0;
    final client = await clientFor((r) async => http.Response(
      jsonEncode({'code':'42501','message':'Denied','details':null,'hint':null}),403,
      headers:{'content-type':'application/json'},request:r));
    await expectLater(SportsRolesService(client, onChanged:() => changes++)
      .respondMatchAssignment('o',true), throwsA(isA<PostgrestException>()));
    expect(changes, 0);
  });
  test('approval side uses RPC; real id is read under existing RLS, no raw official match query', () async {
    final paths = <String>[];
    final client = await clientFor((r) async {
      paths.add(r.url.path);
      if (r.url.path.endsWith('/match_approved_lineups')) {
        expect(jsonDecode(r.body), {'p_match_id':'m'});
        return response([{'participant_id':'p','side':'away','starter_athlete_ids':['a'],
          'substitute_athlete_ids':<String>[],'verified_by':null,
          'verified_at':'2026-10-13T00:00:00Z','is_locked':true,'notes':null}],r);
      }
      expect(r.url.queryParameters['select'], 'id,participant_id');
      expect(r.url.queryParameters['match_id'], 'eq.m');
      return response([{'id':'real-id','participant_id':'p'}],r);
    });
    final result = await SportsRolesService(client).fetchMatchLineupApprovals('m');
    expect(result.single.id, 'real-id');
    expect(result.single.matchId, 'm');
    expect(result.single.side, MatchLineupSide.away);
    expect(paths, ['/rest/v1/rpc/match_approved_lineups','/rest/v1/match_lineup_approvals']);
  });
  test('empty/inaccessible projection makes no fallback query', () async {
    var calls = 0;
    final client = await clientFor((r) async {
      calls++; expect(r.url.path, '/rest/v1/rpc/match_approved_lineups');
      return response([],r);
    });
    expect(await SportsRolesService(client).fetchMatchLineupApprovals('m'), isEmpty);
    expect(calls,1);
  });
  test('match filter uses p_status; accepted officials expose only the public projection', () async {
    var calls = 0;
    final client = await clientFor((r) async {
      calls++;
      if (r.url.path.endsWith('/my_referee_matches')) {
        expect(jsonDecode(r.body), {'p_status':'accepted'});
        return response([{'official_id':'o','match_id':'m','duty':'head_referee',
          'status':'accepted','assigned_at':'2026-10-13T00:00:00Z',
          'starts_at':null,'location':null,'sport_code':'tenis',
          'home_club_name':null,'away_club_name':null,'decline_reason':null}],r);
      }
      expect(r.url.path, '/rest/v1/rpc/accepted_match_officials');
      expect(jsonDecode(r.body), {'p_match_id':'m'});
      return response([{'name':'Official','duty':'head_referee'}],r);
    });
    final service = SportsRolesService(client);
    expect((await service.fetchMyRefereeMatches(status:'accepted')).single.officialId, 'o');
    expect((await service.fetchAcceptedMatchOfficials('m')).single.name, 'Official');
    await expectLater(service.fetchMyRefereeMatches(status:'unknown'), throwsArgumentError);
    expect(calls,2);
  });
  test('medical authority comes from existing server predicate; admin rest remains independent', () async {
    final client = await clientFor((r) async {
      if (r.url.path.endsWith('/club_memberships')) {
        expect(r.url.queryParameters['select'], 'club_id,role');
        expect(r.url.queryParameters['profile_id'], 'eq.me');
        expect(r.url.queryParameters['status'], 'eq.active');
        return response([{'club_id':'coach-club','role':'coach'},
          {'club_id':'doctor-club','role':'member'}], r);
      }
      expect(r.url.path, '/rest/v1/rpc/is_authorized_health_officer');
      return response((jsonDecode(r.body) as Map)['p_club']=='doctor-club',r);
    });
    final authority = await SportsRolesService(client).fetchMyClubAuthority();
    expect(authority.medicalClubIds, {'doctor-club'});
    expect(authority.administrativeClubIds, {'coach-club'});
  });
  test('fixtures and guests return empty roles, never instantiate a Supabase service', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(myFederationRolesProvider.future), isEmpty);
    expect(await container.read(myRefereeProfileProvider.future), isNull);
    expect(await container.read(myClubStaffRolesProvider.future), isEmpty);
    expect(await container.read(myRefereeMatchesProvider(null).future), isEmpty);
    expect(await container.read(matchLineupApprovalsProvider('m').future), isEmpty);
    expect(await container.read(acceptedMatchOfficialsProvider('m').future), isEmpty);
  });
  test('account logout invalidates private provider values', () async {
    final sessions = StreamController<Session?>();
    addTearDown(sessions.close);
    final client = await clientFor((r) async => response([_role],r));
    final container = ProviderContainer(overrides:[
      authSessionProvider.overrideWith((ref) => sessions.stream),
      sportsRolesServiceProvider.overrideWithValue(SportsRolesService(client)),
    ]);
    addTearDown(container.dispose);
    container.listen(myFederationRolesProvider, (_, __) {});
    await container.read(myFederationRolesProvider.future);
    sessions.add(Session.fromJson(_session));
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(myFederationRolesProvider.future), hasLength(1));
    sessions.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(myFederationRolesProvider.future), isEmpty);
  });
}

http.Response response(Object? body, http.Request request) => http.Response(
  jsonEncode(body), 200, headers:{'content-type':'application/json; charset=utf-8'},request:request);
