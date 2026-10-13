import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_scope.dart';

List<Map<String,dynamic>> _rows(Object? rows) => (rows as List? ?? const []).map((m)=>Map<String,dynamic>.from(m as Map)).toList();
class ClubOperationsAuthority {
  const ClubOperationsAuthority({required this.clubId,required this.inventoryRead,required this.inventoryWrite,required this.healthRead,required this.planningRead,this.administrativeWrite=false});
  final String clubId;
  final bool inventoryRead,inventoryWrite,healthRead,planningRead,administrativeWrite;
  factory ClubOperationsAuthority.fromMap(Map<String,dynamic> m)=>ClubOperationsAuthority(clubId:m['club_id'] as String,
    inventoryRead:m['inventory_read'] as bool,inventoryWrite:m['inventory_write'] as bool,healthRead:m['health_read'] as bool,planningRead:m['planning_read'] as bool,administrativeWrite:m['administrative_write']==true);
}
class ClubInventoryItem {
  const ClubInventoryItem({required this.id,required this.name,required this.category,required this.quantity,required this.available,
    required this.damaged,required this.missing,required this.status,this.sportCode});
  final String id,name,category,status;
  final String? sportCode;
  final int quantity,available,damaged,missing;
  factory ClubInventoryItem.fromMap(Map<String,dynamic> m)=>ClubInventoryItem(id:m['id'] as String,name:m['name'] as String,
    category:m['category'] as String,quantity:(m['quantity'] as num).toInt(),available:(m['available'] as num).toInt(),
    damaged:(m['damaged_quantity'] as num).toInt(),missing:(m['missing_quantity'] as num).toInt(),status:m['status'] as String,sportCode:m['sport_code'] as String?);
}
class ClubInventoryAssignment {
  const ClubInventoryAssignment({required this.id,required this.itemName,required this.targetReference,required this.quantity,
    required this.assignedAt,required this.outcome,this.returnedAt,this.notes});
  final String id,itemName,targetReference,outcome;
  final String? notes;
  final int quantity;
  final DateTime assignedAt;
  final DateTime? returnedAt;
  factory ClubInventoryAssignment.fromMap(Map<String,dynamic> m)=>ClubInventoryAssignment(id:m['id'] as String,itemName:m['item_name'] as String,
    targetReference:m['target_reference'] as String,quantity:(m['quantity'] as num).toInt(),assignedAt:DateTime.parse(m['assigned_at'] as String),
    returnedAt:m['returned_at']==null?null:DateTime.parse(m['returned_at'] as String),outcome:m['outcome'] as String,notes:m['notes'] as String?);
}
class ClubInventoryTarget {
  const ClubInventoryTarget({required this.id,required this.kind,required this.label});
  final String id,kind,label;
  factory ClubInventoryTarget.fromMap(Map<String,dynamic> m)=>ClubInventoryTarget(id:m['id'] as String,kind:m['kind'] as String,label:m['label'] as String);
}
class ClubInventoryBoard {
  ClubInventoryBoard({required List<ClubInventoryItem> items,required List<ClubInventoryAssignment> assignments,required List<ClubInventoryTarget> targets})
    :items=List.unmodifiable(items),assignments=List.unmodifiable(assignments),targets=List.unmodifiable(targets);
  final List<ClubInventoryItem> items;
  final List<ClubInventoryAssignment> assignments;
  final List<ClubInventoryTarget> targets;
  factory ClubInventoryBoard.fromMap(Map<String,dynamic> m)=>ClubInventoryBoard(items:_rows(m['items']).map(ClubInventoryItem.fromMap).toList(),
    assignments:_rows(m['assignments']).map(ClubInventoryAssignment.fromMap).toList(),targets:_rows(m['targets']).map(ClubInventoryTarget.fromMap).toList());
}
class ClubHealthOperation {
  const ClubHealthOperation({required this.athleteId,required this.reference,required this.status,required this.reason,required this.blocked,this.restStatus,this.restrictionId});
  final String athleteId,reference,status,reason;
  final String? restStatus,restrictionId;
  final bool blocked;
  factory ClubHealthOperation.fromMap(Map<String,dynamic> m)=>ClubHealthOperation(athleteId:m['athlete_id'] as String,reference:m['reference'] as String,
    status:m['status'] as String,reason:m['reason'] as String,blocked:m['blocked'] as bool,restStatus:m['rest_status'] as String?,restrictionId:m['restriction_id'] as String?);
}
class ClubSportingTeam {
  const ClubSportingTeam({required this.id,required this.name,required this.athleteCount});
  final String id,name;
  final int athleteCount;
  factory ClubSportingTeam.fromMap(Map<String,dynamic> m)=>ClubSportingTeam(id:m['id'] as String,name:m['name'] as String,athleteCount:(m['athlete_count'] as num).toInt());
}
class ClubSportingOverview {
  ClubSportingOverview({required this.athletes,required this.expiringLicenses,required List<ClubSportingTeam> teams,
    this.completedTransfers=0,this.lockedLineups=0,this.present=0,this.late=0,this.absent=0,this.excused=0, List<ClubPlanningLicense> licenses=const []})
      :teams=List.unmodifiable(teams),licenses=List.unmodifiable(licenses);
  final int athletes,expiringLicenses;
  final int completedTransfers,lockedLineups,present,late,absent,excused;
  double? get attendanceRate=>present+late+absent==0?null:100*(present+late)/(present+late+absent);
  final List<ClubSportingTeam> teams;
  final List<ClubPlanningLicense> licenses;
  factory ClubSportingOverview.fromMap(Map<String,dynamic> m){
    final attendance=Map<String,dynamic>.from(m['attendance'] as Map? ?? const {});
    return ClubSportingOverview(athletes:(m['athletes'] as num).toInt(),expiringLicenses:(m['expiring_licenses'] as num).toInt(),teams:_rows(m['teams']).map(ClubSportingTeam.fromMap).toList(),
      completedTransfers:(m['completed_transfers'] as num? ?? 0).toInt(),lockedLineups:(m['locked_lineups'] as num? ?? 0).toInt(),
      present:(attendance['present'] as num? ?? 0).toInt(),late:(attendance['late'] as num? ?? 0).toInt(),absent:(attendance['absent'] as num? ?? 0).toInt(),excused:(attendance['excused'] as num? ?? 0).toInt(),
      licenses:_rows(m['licenses']).map(ClubPlanningLicense.fromMap).toList());
  }
}
class ClubPlanningLicense {
  const ClubPlanningLicense({required this.reference,required this.sportCode,required this.expiresOn});
  final String reference,sportCode;final DateTime expiresOn;
  factory ClubPlanningLicense.fromMap(Map<String,dynamic> m)=>ClubPlanningLicense(reference:m['reference'] as String,sportCode:m['sport_code'] as String,expiresOn:DateTime.parse(m['expires_on'] as String));
}
class ClubStaffOperationsService {
  ClubStaffOperationsService(this.client);
  final SupabaseClient client;
  Future<List<ClubOperationsAuthority>> authority() async=>List.unmodifiable(_rows(await client.rpc('my_club_operations_authority')).map(ClubOperationsAuthority.fromMap));
  Future<ClubInventoryBoard> inventory(String clubId) async=>ClubInventoryBoard.fromMap(Map<String,dynamic>.from(await client.rpc('club_inventory_board',params:{'p_club':clubId}) as Map));
  Future<List<ClubHealthOperation>> health(String clubId) async=>List.unmodifiable(_rows(await client.rpc('club_health_operations',params:{'p_club':clubId})).map(ClubHealthOperation.fromMap));
  Future<ClubSportingOverview> sporting(String clubId) async=>ClubSportingOverview.fromMap(Map<String,dynamic>.from(await client.rpc('club_sporting_overview',params:{'p_club':clubId}) as Map));
  Future<void> write(String rpc,Map<String,dynamic> payload) async {
    if(!const {'inventory_add_item','inventory_assign','inventory_return','set_club_athlete_rest','open_health_restriction','clear_health_restriction'}.contains(rpc))throw ArgumentError('Unsupported club operation');
    await client.rpc(rpc,params:payload);
  }
}
final clubStaffOperationsServiceProvider=Provider<ClubStaffOperationsService?>((ref)=>ref.watch(isSupabaseEnabledProvider)?ClubStaffOperationsService(ref.watch(supabaseClientProvider)):null);
void _refreshAfterDelay(void Function() invalidate,void Function(void Function()) onDispose){final timer=Timer(const Duration(seconds:30),invalidate);onDispose(timer.cancel);}
final myClubOperationsAuthorityProvider=FutureProvider.autoDispose<List<ClubOperationsAuthority>>((ref){
  ref.watch(authSessionProvider);_refreshAfterDelay(ref.invalidateSelf,ref.onDispose);
  return ref.watch(clubStaffOperationsServiceProvider)?.authority()??Future.value(const <ClubOperationsAuthority>[]);
});
final clubInventoryBoardProvider=FutureProvider.autoDispose.family<ClubInventoryBoard,String>((ref,id){
  ref.watch(authSessionProvider);_refreshAfterDelay(ref.invalidateSelf,ref.onDispose);
  final s=ref.watch(clubStaffOperationsServiceProvider);if(s==null)throw StateError('Backend bağlantısı gerekli.');return s.inventory(id);
});
final clubHealthOperationsProvider=FutureProvider.autoDispose.family<List<ClubHealthOperation>,String>((ref,id){
  ref.watch(authSessionProvider);_refreshAfterDelay(ref.invalidateSelf,ref.onDispose);
  final s=ref.watch(clubStaffOperationsServiceProvider);if(s==null)throw StateError('Backend bağlantısı gerekli.');return s.health(id);
});
final clubSportingOverviewProvider=FutureProvider.autoDispose.family<ClubSportingOverview,String>((ref,id){
  ref.watch(authSessionProvider);_refreshAfterDelay(ref.invalidateSelf,ref.onDispose);
  final s=ref.watch(clubStaffOperationsServiceProvider);if(s==null)throw StateError('Backend bağlantısı gerekli.');return s.sporting(id);
});
class ClubOperationState {
  const ClubOperationState({this.busy=false,this.pending=false,this.error});
  final bool busy,pending;
  final String? error;
}
class ClubOperationController extends StateNotifier<ClubOperationState> {
  ClubOperationController(this.service,this.refresh):super(const ClubOperationState());
  final ClubStaffOperationsService? service;
  final void Function() refresh;
  String? _rpc;
  Map<String,dynamic>? _payload;
  bool _disposed=false;
  Future<bool> submit(String rpc,Map<String,dynamic> payload) async {
    if(state.busy||_payload!=null)return false;
    _rpc=rpc;_payload=Map.unmodifiable(payload);return retry();
  }
  Future<bool> retry() async {
    if(state.busy||_rpc==null||_payload==null)return false;
    state=const ClubOperationState(busy:true,pending:true);
    try {
      if(service==null)throw StateError('Backend bağlantısı gerekli.');
      await service!.write(_rpc!,_payload!);
      if(_disposed)return false;
      _rpc=null;_payload=null;state=const ClubOperationState();refresh();return true;
    }catch(e){
      if(_disposed)return false;
      if(e is StateError||(e is PostgrestException&&const {'22023','23514','23502','23505','42501','55000','P0001'}.contains(e.code))){_rpc=null;_payload=null;}
      state=ClubOperationState(pending:_payload!=null,error:_payload==null?'İşlem reddedildi. Yetki, stok ve alanları kontrol edin.':'Sonuç belirsiz. Aynı işlemi tekrar deneyin.');refresh();return false;
    }
  }
  @override void dispose(){_disposed=true;super.dispose();}
}
final clubOperationControllerProvider=StateNotifierProvider.autoDispose.family<ClubOperationController,ClubOperationState,String>((ref,id){
  ref.watch(authSessionProvider.select((v)=>v.valueOrNull?.user.id));
  return ClubOperationController(ref.watch(clubStaffOperationsServiceProvider),(){
    ref.invalidate(clubInventoryBoardProvider(id));ref.invalidate(clubHealthOperationsProvider(id));ref.invalidate(clubSportingOverviewProvider(id));
  });
});
