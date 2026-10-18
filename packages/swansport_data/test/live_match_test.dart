import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

const _id='10000000-0000-0000-0000-000000000001';
Map<String,dynamic> _summary({bool live=false})=>{'match_id':_id,'sport_code':'tenis','status':'scheduled',
  'is_live':live,'is_today':true,'elapsed_seconds':60,'clock_started_at':live?'2026-10-14T10:00:00Z':null,
  'server_now':'2026-10-14T10:01:00Z','sets':<Object>[]};
class _FakeService extends LiveMatchService {
  _FakeService(SupabaseClient client) : super(client);
  int listCalls=0,detailCalls=0;bool live=true;
  @override Future<List<PublicLiveMatchSummary>> fetchLiveMatches({String? sport,String? city})async{
    listCalls++;return [PublicLiveMatchSummary.fromMap(_summary(live:live))];
  }
  @override Future<PublicLiveMatchDetail?> fetchPublicMatchState(String id)async{
    detailCalls++;return PublicLiveMatchDetail.fromMap({..._summary(live:live),'events':<Map<String,dynamic>>[]});
  }
}
void main(){
  test('public models retain unknown score and freeze lists, ignoring private fields',(){
    final detail=PublicLiveMatchDetail.fromMap({..._summary(),'report_notes':'PRIVATE','athlete_id':'secret',
      'events':[{'sequence':1,'kind':'score','athlete_name':'sporcu'},{'sequence':2,'kind':'undo'}]});
    expect(detail.summary.homeScore,isNull);expect(detail.summary.awayScore,isNull);
    expect(detail.events.length,1);expect(()=>detail.events.clear(),throwsUnsupportedError);
    expect(()=>detail.summary.sets.clear(),throwsUnsupportedError);
    final roster=PublicMatchRoster.fromMap({'match_id':_id,'players':[{'name':'sporcu','side':'home','selection':'starter','jersey_number':'7A'}]});
    expect(roster.players.single.jerseyNumber,'7A');expect(()=>roster.players.clear(),throwsUnsupportedError);
  });
  test('server clock plus monotonic elapsed ignores device timezone and freezes paused/final states',(){
    final running=PublicLiveMatchSummary.fromMap(_summary(live:true));
    expect(running.secondsAt(const Duration(seconds:5)),125);
    final paused=PublicLiveMatchSummary.fromMap(_summary());
    expect(paused.secondsAt(const Duration(hours:5)),60);
    final closed=PublicLiveMatchSummary.fromMap({..._summary(live:true),'status':'played','is_live':false});
    expect(closed.secondsAt(const Duration(hours:5)),60);
  });
  test('guest UUID route is strict and private referee routes remain protected',(){
    expect(SwanAccess.isGuestRoute('/canli-skor'),isTrue);
    expect(SwanAccess.isGuestRoute('/canli-mac/$_id'),isTrue);
    for(final path in ['/canli-mac/not-a-uuid','/canli-mac/$_id/admin','https://foreign.example/canli-mac/$_id','/hakem/canli/$_id']){
      expect(SwanAccess.isGuestRoute(path),isFalse);
    }
  });
  test('only public RPCs are called, filter names and explicit empty/hidden payloads are preserved',()async{
    final requests=<http.Request>[];
    final client=SupabaseClient('https://example.supabase.co', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false),httpClient:MockClient((r)async{
      requests.add(r);return http.Response(r.url.path.endsWith('public_live_matches')?'[]':'null',200,
        headers:{'content-type':'application/json'},request:r);
    }));addTearDown(client.dispose);
    final service=LiveMatchService(client);
    expect(await service.fetchLiveMatches(sport:'tenis',city:'34'),isEmpty);
    expect(await service.fetchPublicMatchState(_id),isNull);expect(await service.fetchPublicMatchRoster(_id),isNull);
    expect(requests.map((r)=>r.url.path),['/rest/v1/rpc/public_live_matches','/rest/v1/rpc/match_public_live_state','/rest/v1/rpc/match_public_roster']);
    expect(jsonDecode(requests.first.body),{'p_sport':'tenis','p_city':'34'});
    final before=requests.length;
    await expectLater(service.fetchPublicMatchState('invalid'),throwsArgumentError);expect(requests.length,before);
  });
  test('fixture/off feature performs no backend requests',()async{
    final container=ProviderContainer();addTearDown(container.dispose);
    expect(await container.read(publicLiveMatchesProvider.future),isEmpty);
    expect(await container.read(publicMatchLiveStateProvider(_id).future),isNull);
    expect(await container.read(publicMatchRosterProvider(_id).future),isNull);
  });
  testWidgets('polling is subscription-scoped: list 30s, live detail 10s, timers stop on disposal',(tester)async{
    final client=(await tester.runAsync(() async => SupabaseClient('https://example.supabase.co', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false))))!;addTearDown(() => tester.runAsync(client.dispose));
    final service=_FakeService(client);
    final container=ProviderContainer(overrides:[isSupabaseEnabledProvider.overrideWithValue(true),
      featureEnabledProvider(FeatureFlags.liveMatchHub).overrideWithValue(true),liveMatchServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    final list=container.listen(publicLiveMatchesProvider,(_,__){});
    final detail=container.listen(publicMatchLiveStateProvider(_id),(_,__){});
    await tester.pump();expect(service.listCalls,1);expect(service.detailCalls,1);
    await tester.pump(const Duration(seconds:11));await tester.pump();expect(service.detailCalls,2);expect(service.listCalls,1);
    await tester.pump(const Duration(seconds:20));await tester.pump();expect(service.listCalls,2);
    list.close();detail.close();await tester.pump();await tester.pump();
    final listCount=service.listCalls,detailCount=service.detailCalls;
    await tester.pump(const Duration(seconds:60));expect(service.listCalls,listCount);expect(service.detailCalls,detailCount);
  });
}
