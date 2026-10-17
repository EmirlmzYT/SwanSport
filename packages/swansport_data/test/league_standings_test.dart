import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

const _id='10000000-0000-0000-0000-000000000001';
Map<String,dynamic> _row()=>{'rank':1,'participant_id':_id,'participant_name':'Kulüp',
  'played':3,'won':1,'drawn':1,'lost':1,'goals_for':3,'goals_against':4,'goal_diff':-1,'points':4,
  'form':['W','D','L'],'is_provisional':true};
class _Service extends LeagueStandingsService {
  _Service(super.client);
  int calls=0;
  Completer<List<LeagueStandingsRow>>? pending;
  bool fail=false;
  @override Future<List<LeagueStandingsRow>> fetchStandings(String orgId,{bool includeLive=false}){
    calls++;if(fail)return Future.error(StateError('offline'));
    return pending?.future??Future.value([LeagueStandingsRow.fromMap(_row())]);
  }
}
void main(){
  test('standings DTO preserves negative difference and immutable form/table without private payloads',(){
    final row=LeagueStandingsRow.fromMap({..._row(),'athlete_id':'private','form':['W','D','L','private']});
    expect(row.goalDiff,-1);expect(row.points,4);expect(row.form,['W','D','L']);expect(row.isProvisional,isTrue);
    expect(()=>row.form.add('W'),throwsUnsupportedError);
    final table=LeagueStandingsTable(orgId:_id,sportCode:'futbol',isLive:true,rows:[row]);
    expect(()=>table.rows.clear(),throwsUnsupportedError);
    final context=MatchStandingsContext.fromMap({'org_id':_id,'name':'Lig','sport_code':'tenis','home_participant_id':_id});
    expect(context.orgId,_id);expect(context.awayParticipantId,isNull);
  });
  test('service uses exact public RPC parameters, empty/null and safe logo conversion',()async{
    final requests=<http.Request>[];
    final client=SupabaseClient('https://example.supabase.co', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false),httpClient:MockClient((r)async{
      requests.add(r);final path=r.url.path;
      return http.Response(path.endsWith('public_league_standings')?jsonEncode([{..._row(),'club_logo':'club/logo.png'}])
        :path.endsWith('match_public_standings_context')?'null':'[]',200,headers:{'content-type':'application/json'},request:r);
    }));addTearDown(client.dispose);final service=LeagueStandingsService(client);
    final rows=await service.fetchStandings(_id,includeLive:true);
    expect(rows.single.clubLogo,contains('/storage/v1/object/public/post-media/club/logo.png'));
    expect(jsonDecode(requests.first.body),{'p_org_id':_id,'p_include_live':true});
    expect(await service.leagues(),isEmpty);expect(await service.matchContext(_id),isNull);
    expect(requests.map((r)=>r.url.path),['/rest/v1/rpc/public_league_standings','/rest/v1/rpc/public_standings_leagues','/rest/v1/rpc/match_public_standings_context']);
    await expectLater(service.fetchStandings('invalid'),throwsArgumentError);
    await expectLater(service.matchContext('invalid'),throwsArgumentError);expect(requests.length,3);
  });
  test('disabled fixture performs no backend calls',()async{
    final c=ProviderContainer();addTearDown(c.dispose);
    expect(await c.read(leagueStandingsProvider((orgId:_id,includeLive:true)).future),isEmpty);
    expect(await c.read(standingsLeaguesProvider.future),isEmpty);
    expect(await c.read(matchStandingsContextProvider(_id).future),isNull);
  });
  testWidgets('live 10s and official 30s polling stop after last subscription',(tester)async{
    final client=(await tester.runAsync(() async => SupabaseClient('https://example.supabase.co', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false))))!;addTearDown(() => tester.runAsync(client.dispose));
    final service=_Service(client);final c=ProviderContainer(overrides:[isSupabaseEnabledProvider.overrideWithValue(true),
      featureEnabledProvider(FeatureFlags.leagueStandings).overrideWithValue(true),leagueStandingsServiceProvider.overrideWithValue(service)]);
    addTearDown(c.dispose);
    final live=c.listen(leagueStandingsProvider((orgId:_id,includeLive:true)),(_,__){});
    final official=c.listen(leagueStandingsProvider((orgId:_id,includeLive:false)),(_,__){});
    await tester.pump();expect(service.calls,2);await tester.pump(const Duration(seconds:11));await tester.pump();expect(service.calls,3);
    await tester.pump(const Duration(seconds:20));await tester.pump();expect(service.calls,6);
    live.close();official.close();await tester.pump(Duration.zero);await tester.pump(Duration.zero);final count=service.calls;
    await tester.pump(const Duration(seconds:60));expect(service.calls,count);
  });
  testWidgets('slow request has no overlapping timer and late completion after disposal is safe',(tester)async{
    final client=(await tester.runAsync(() async => SupabaseClient('https://example.supabase.co', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false))))!;addTearDown(() => tester.runAsync(client.dispose));
    final service=_Service(client)..pending=Completer<List<LeagueStandingsRow>>();
    final c=ProviderContainer(overrides:[isSupabaseEnabledProvider.overrideWithValue(true),
      featureEnabledProvider(FeatureFlags.leagueStandings).overrideWithValue(true),leagueStandingsServiceProvider.overrideWithValue(service)]);
    final sub=c.listen(leagueStandingsProvider((orgId:_id,includeLive:true)),(_,__){});
    await tester.pump();await tester.pump(const Duration(seconds:60));expect(service.calls,1);
    sub.close();c.dispose();service.pending!.complete([]);await tester.pump();
    await tester.pump(const Duration(seconds:60));expect(service.calls,1);expect(tester.takeException(),isNull);
  });
  testWidgets('failed polling exposes error then retries without stale table',(tester)async{
    final client=(await tester.runAsync(() async => SupabaseClient('https://example.supabase.co', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false))))!;addTearDown(() => tester.runAsync(client.dispose));
    final service=_Service(client)..fail=true;final c=ProviderContainer(overrides:[isSupabaseEnabledProvider.overrideWithValue(true),
      featureEnabledProvider(FeatureFlags.leagueStandings).overrideWithValue(true),leagueStandingsServiceProvider.overrideWithValue(service)]);
    addTearDown(c.dispose);final p=leagueStandingsProvider((orgId:_id,includeLive:true));
    final sub=c.listen(p,(_,__){});addTearDown(sub.close);await tester.pump();expect(c.read(p).hasError,isTrue);
    service.fail=false;await tester.pump(const Duration(seconds:11));await tester.pump();expect(c.read(p).asData?.value.length,1);
    sub.close();c.dispose();await tester.pump(Duration.zero);
  });
}
