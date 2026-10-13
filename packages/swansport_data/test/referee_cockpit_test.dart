import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

class _Service extends RefereeCockpitService {
  _Service(SupabaseClient client):super(client);
  Object? failure;
  Completer<void>? inFlight;
  final requests=<({String rpc,Map<String,dynamic> params})>[];
  @override Future<void> send(String rpc,Map<String,dynamic> params) async {
    requests.add((rpc:rpc,params:Map.from(params)));
    if(failure!=null)throw failure!;
    if(inFlight!=null)await inFlight!.future;
  }
}
class _Controller extends RefereeMutationController {
  _Controller(RefereeCockpitService? service,void Function() refresh):super(service,refresh);
  RefereeMutationState get current => state;
}
void main(){
  SupabaseClient client()=>SupabaseClient('https://example.supabase.co','test');
  test('operation ids are unique UUID v4; Turkey day is stable across UTC boundary',(){
    final values=List.generate(100,(_)=>refereeOperationId());
    expect(values.toSet(),hasLength(100));
    for(final value in values)expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(value),isTrue);
    expect(refereeSameDay(DateTime.utc(2026,10,12,21),DateTime.utc(2026,10,13,12)),isTrue);
    expect(refereeSameDay(DateTime.utc(2026,10,13,21),DateTime.utc(2026,10,13,12)),isFalse);
    expect(refereeSameDay(null,DateTime.now()),isFalse);
  });
  test('private candidate is allowlisted and masked identity has no child name',(){
    final row=RefereeLineupCandidate.fromMap({'athlete_id':'10000000-0000-0000-0000-000000000001',
      'side':'home','name':null,'jersey_number':11,'license_number':'L1','license_expires_on':'2090-01-01',
      'eligibility_status':'medical','eligible':false,'selection':'unselected','national_id':'secret','guardian_phone':'secret'});
    expect(row.name,isNull);expect(row.maskedRef,'#100000');expect(row.eligible,isFalse);
  });
  test('uncertain event retains operation and payload; next event is blocked until identical retry succeeds',()async{
    final c=client();addTearDown(c.dispose);final service=_Service(c)..failure=StateError('connection lost');
    var refreshes=0;final controller=_Controller(service,()=>refreshes++);addTearDown(controller.dispose);
    const params={'p_operation_id':'op','p_expected_version':4,'p_kind':'score'};
    expect(await controller.submit('referee_append_match_event',params),isFalse);
    expect(controller.current.pending,isTrue);
    expect(await controller.submit('referee_append_match_event',{'p_operation_id':'another'}),isFalse);
    service.failure=null;expect(await controller.retry(),isTrue);
    expect(service.requests,hasLength(2));expect(service.requests[0].params,service.requests[1].params);
    expect(controller.current.pending,isFalse);expect(refreshes,2);
  });
  test('definitive version/permission errors clear draft and refresh; no successful commit is claimed',()async{
    final c=client();addTearDown(c.dispose);final service=_Service(c)..failure=const PostgrestException(message:'version changed',code:'40001');
    var refreshes=0;final controller=_Controller(service,()=>refreshes++);addTearDown(controller.dispose);
    expect(await controller.submit('referee_append_match_event',{'p_operation_id':'op'}),isFalse);
    expect(controller.current.pending,isFalse);expect(controller.current.error,contains('version changed'));expect(refreshes,1);
  });
  test('report retry also retains its exact version, note and operation id',()async{
    final c=client();addTearDown(c.dispose);final service=_Service(c)..failure=StateError('timeout');
    final controller=_Controller(service,(){});addTearDown(controller.dispose);
    await controller.submit('referee_submit_match_report',{'p_match_id':'m','p_operation_id':'op','p_expected_version':9,'p_notes':'Signed'});
    service.failure=null;expect(await controller.retry(),isTrue);
    expect(service.requests[1].params,service.requests[0].params);
  });
  test('revocation after a lost response does not discard the unresolved operation id',()async{
    final c=client();addTearDown(c.dispose);final service=_Service(c)..failure=StateError('response lost');
    final controller=_Controller(service,(){});addTearDown(controller.dispose);
    await controller.submit('referee_append_match_event',{'p_operation_id':'op','p_expected_version':1});
    service.failure=const PostgrestException(message:'authority revoked',code:'42501');
    expect(await controller.retry(),isFalse);
    expect(controller.current.pending,isTrue);expect(controller.current.params!['p_operation_id'],'op');
  });
  test('disposed/account-switched controller never reports success to another screen',()async{
    final c=client();addTearDown(c.dispose);final service=_Service(c)..inFlight=Completer<void>();
    var refreshed=false;final controller=_Controller(service,()=>refreshed=true);
    final pending=controller.submit('referee_submit_match_report',{'p_operation_id':'op'});
    await Future<void>.delayed(Duration.zero);controller.dispose();service.inFlight!.complete();
    expect(await pending,isFalse);expect(refreshed,isFalse);
  });
  test('service sends only RPCs and explicit candidate/state keys',()async{
    final calls=<http.Request>[];
    final c=SupabaseClient('https://example.supabase.co','test',httpClient:MockClient((r)async{
      calls.add(r);
      expect(jsonDecode(r.body),{'p_match_id':'m'});
      return http.Response('[]',200,headers:{'content-type':'application/json'},request:r);
    }));addTearDown(c.dispose);
    expect(await RefereeCockpitService(c).candidates('m'),isEmpty);
    expect(calls.single.url.path,'/rest/v1/rpc/referee_lineup_candidates');
  });
  test('notification enters guarded cockpit list, not a caller-provided URL',(){
    final n=NotificationRow(id:'n',kind:'referee_assignment',title:'New duty',createdAt:DateTime.now(),entityType:'match',entityId:'m');
    expect(n.refereeRoute,'/hakem/gorevler');expect(n.resultRoute,isNull);
  });
  test('state arrays and events are immutable, elapsed duration follows server anchor',(){
    final s=RefereeLiveState.fromMap({'match_id':'m','sport_code':'futbol','match_status':'scheduled','version':2,
      'home_score':1,'away_score':0,'period':1,'elapsed_seconds':30,'clock_started_at':'2026-10-13T12:00:00Z',
      'events':[],'active_home':['a'],'active_away':['b'],'bench_home':[],'bench_away':[],'sets':[]});
    expect(s.secondsAt(DateTime.utc(2026,10,13,12,1)),90);
    expect(()=>s.squads['active_home']!.add('x'),throwsUnsupportedError);
    expect(()=>s.events.clear(),throwsUnsupportedError);
  });
}
