import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

class _Service extends ClubStaffOperationsService {
  _Service():super(SupabaseClient('https://example.com','test'));
  final writes=<Map<String,dynamic>>[];
  bool fail=false;Completer<void>? waiting;
  @override Future<void> write(String rpc,Map<String,dynamic> payload)async{
    writes.add(Map.of(payload));if(fail)throw Exception('Lost response');if(waiting!=null)await waiting!.future;
  }
}
void main(){
  test('inventory DTOs preserve zero available/damage and immutable lists',(){
    final b=ClubInventoryBoard.fromMap({'items':[{'id':'i','name':'Top','category':'ball','quantity':5,'available':0,'damaged_quantity':3,'missing_quantity':2,'status':'active'}],
      'assignments':[],'targets':[]});
    expect(b.items.single.available,0);expect(b.items.single.damaged,3);expect(()=>b.items.clear(),throwsUnsupportedError);
  });
  test('health DTO has no diagnostic/identity payload and rest is separate from the clinical ID',(){
    final h=ClubHealthOperation.fromMap({'athlete_id':'a','reference':'#A3F91C','status':'restricted','reason':'Health','blocked':true,'rest_status':'rested','restriction_id':'r'});
    expect(h.restrictionId,'r');expect(h.restStatus,'rested');expect(h.blocked,isTrue);
  });
  test('empty attendance is unknown, excused records do not count as absence',(){
    final r=ClubSportingOverview(athletes:0,expiringLicenses:0,teams:[],excused:3);
    expect(r.attendanceRate,isNull);
    expect(ClubSportingOverview(athletes:1,expiringLicenses:0,teams:[],present:2,late:1,absent:1,excused:20).attendanceRate,75);
  });
  test('authority is scoped and role labels cannot manufacture medical or stock permissions',(){
    final a=SwanAccess(isPlatformAdmin:false,clubRole:'parent',coachLevel:0,athleteKind:null,
      clubOperationsAuthority:const [ClubOperationsAuthority(clubId:'c',inventoryRead:true,inventoryWrite:true,healthRead:false,planningRead:false)]);
    expect(a.canManageClubInventory('c'),isTrue);expect(a.canManageClubInventory('foreign'),isFalse);
    expect(a.hasMedicalAuthorityForClub('c'),isFalse);expect(a.canReadClubHealth('c'),isFalse);
  });
  test('lost reply retains identical operation payload; new command blocked until retry succeeds',()async{
    final s=_Service()..fail=true;addTearDown(s.client.dispose);
    final c=ClubOperationController(s,(){});addTearDown(c.dispose);
    expect(await c.submit('inventory_assign',{'p_id':'same','p_quantity':2}),isFalse);
    expect(c.state.pending,isTrue);expect(await c.submit('inventory_assign',{'p_id':'new','p_quantity':1}),isFalse);
    s.fail=false;expect(await c.retry(),isTrue);expect(s.writes,[{'p_id':'same','p_quantity':2},{'p_id':'same','p_quantity':2}]);
  });
  test('disposed controller does not deliver a late success to another account',()async{
    final s=_Service()..waiting=Completer<void>();addTearDown(s.client.dispose);
    final c=ClubOperationController(s,(){});final pending=c.submit('inventory_return',{'p_assignment':'a'});
    c.dispose();s.waiting!.complete();expect(await pending,isFalse);
  });
  test('service uses scoped RPCs only and rejects unrelated mutation names',()async{
    final requests=<http.Request>[];
    final client=SupabaseClient('https://example.com','test',httpClient:MockClient((r)async{
      requests.add(r);return http.Response(r.url.path.endsWith('club_inventory_board')?'{"items":[],"assignments":[],"targets":[]}':'null',200,headers:{'content-type':'application/json'});
    }));addTearDown(client.dispose);
    final s=ClubStaffOperationsService(client);await s.inventory('club');
    expect(requests.single.url.path,endsWith('/rpc/club_inventory_board'));expect(jsonDecode(requests.single.body),{'p_club':'club'});
    await s.write('set_club_athlete_rest',{'p_athlete':'a','p_status':'eligible','p_ends_at':null});
    expect(requests.last.url.path,endsWith('/rpc/set_club_athlete_rest'));
    await expectLater(s.write('delete_profiles',{}),throwsArgumentError);
  });
}
