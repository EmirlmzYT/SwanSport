import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
const _id='10000000-0000-0000-0000-000000000001';
Session _session(String id)=>Session(accessToken:'fixture',tokenType:'bearer',user:User(
  id:id,appMetadata:{},userMetadata:{},aud:'authenticated',createdAt:'2020-01-01T00:00:00Z'));
class _Service extends MatchFollowingService {
  _Service(super.client);
  int calls=0;
  Completer<MatchFollowState?>? pending;
  @override Future<MatchFollowState?> fetchState(String matchId)async{
    calls++;if(pending!=null)return await pending!.future;
    return MatchFollowState(matchId:matchId,isFollowed:true,source:'club');
  }
}
void main(){
  test('safe DTO and UUID notification route; follows only need account, not identity',(){
    final state=MatchFollowState.fromMap({'match_id':_id,'is_followed':true,'notify_score':false,'source':'club','athlete_id':'private'});
    expect(state.isFollowed,isTrue);expect(state.notifyScore,isFalse);expect(state.source,'club');
    expect(SwanAccess.none.decisionFor(SwanAction.matchFollow),SwanActionDecision.accountRequired);
    const access=SwanAccess(isPlatformAdmin:false,clubRole:null,coachLevel:0,athleteKind:null);
    expect(access.decisionFor(SwanAction.matchFollow),SwanActionDecision.allowed);
    final notice=NotificationRow(id:'n',kind:'match_live',title:'Skor',createdAt:DateTime.utc(2026),entityType:'match',entityId:_id);
    expect(notice.liveMatchRoute,'/canli-mac/$_id');
    expect(NotificationRow(id:'n',kind:'match_live',title:'Skor',createdAt:DateTime.utc(2026),entityType:'match',entityId:'../../auth').liveMatchRoute,isNull);
  });
  test('service exact RPC args, explicit desired-state retry and hidden result',()async{
    final requests=<http.Request>[];final client=SupabaseClient('https://example.supabase.co', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false),httpClient:MockClient((r)async{
      requests.add(r);return http.Response(r.url.path.endsWith('get_match_follow_status')?'null':'true',200,headers:{'content-type':'application/json'},request:r);
    }));addTearDown(client.dispose);final service=MatchFollowingService(client);
    expect(await service.fetchState(_id),isNull);expect(await service.toggleFollow(_id),isTrue);
    expect(await service.setFollow(_id,follow:true),isTrue);expect(await service.setFollow(_id,follow:true),isTrue);
    expect(requests.map((r)=>r.url.path),['/rest/v1/rpc/get_match_follow_status','/rest/v1/rpc/toggle_match_follow','/rest/v1/rpc/set_match_follow','/rest/v1/rpc/set_match_follow']);
    expect(jsonDecode(requests.last.body),{'p_match_id':_id,'p_follow':true});
    await expectLater(service.setFollow('invalid',follow:true),throwsArgumentError);expect(requests.length,4);
  });
  test('disabled fixture and no-session providers do not access backend',()async{
    final c=ProviderContainer(overrides:[featureEnabledProvider(FeatureFlags.liveMatchNotifications).overrideWithValue(true),
      authSessionProvider.overrideWith((_)=>Stream.value(null))]);addTearDown(c.dispose);
    expect(await c.read(matchFollowStateProvider(_id).future),isNull);expect(await c.read(isMatchFollowedProvider(_id).future),isFalse);
  });
  testWidgets('status polling is session-scoped and cancelled when no observer remains',(tester)async{
    final client=(await tester.runAsync(() async => SupabaseClient('https://example.supabase.co', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false))))!;addTearDown(() => tester.runAsync(client.dispose));final service=_Service(client);
    final sessions=StreamController<Session?>();addTearDown(sessions.close);
    final c=ProviderContainer(overrides:[isSupabaseEnabledProvider.overrideWithValue(true),
      featureEnabledProvider(FeatureFlags.liveMatchNotifications).overrideWithValue(true),
      authSessionProvider.overrideWith((_)=>sessions.stream),matchFollowingServiceProvider.overrideWithValue(service)]);addTearDown(c.dispose);
    final sub=c.listen(isMatchFollowedProvider(_id),(_,__){});sessions.add(_session('first'));await tester.pump(Duration.zero);await tester.pump(Duration.zero);
    expect(service.calls,1);expect(c.read(isMatchFollowedProvider(_id)).valueOrNull,isTrue);
    await tester.pump(const Duration(seconds:31));await tester.pump();expect(service.calls,2);
    sessions.add(null);await tester.pump(Duration.zero);await tester.pump(Duration.zero);expect(c.read(isMatchFollowedProvider(_id)).valueOrNull,isFalse);
    final count=service.calls;await tester.pump(const Duration(seconds:60));expect(service.calls,count);sub.close();
    c.dispose();await tester.pump(Duration.zero);
  });
  testWidgets('late status completion after disposal cannot start another poll',(tester)async{
    final client=(await tester.runAsync(() async => SupabaseClient('https://example.supabase.co', 'test', authOptions: const AuthClientOptions(autoRefreshToken: false))))!;addTearDown(() => tester.runAsync(client.dispose));
    final service=_Service(client)..pending=Completer<MatchFollowState?>();
    final c=ProviderContainer(overrides:[isSupabaseEnabledProvider.overrideWithValue(true),
      featureEnabledProvider(FeatureFlags.liveMatchNotifications).overrideWithValue(true),authSessionProvider.overrideWith((_)=>Stream.value(_session('first'))),
      matchFollowingServiceProvider.overrideWithValue(service)]);
    c.listen(matchFollowStateProvider(_id),(_,__){});await tester.pump();await tester.pump();
    await tester.pump(const Duration(seconds:60));expect(service.calls,1);c.dispose();service.pending!.complete(null);
    await tester.pump();await tester.pump(const Duration(seconds:60));expect(service.calls,1);expect(tester.takeException(),isNull);
  });
}
