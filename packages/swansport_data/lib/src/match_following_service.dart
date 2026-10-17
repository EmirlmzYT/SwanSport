import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feature_flags.dart';
import 'live_match_models.dart';
import 'match_following_models.dart';
import 'supabase_scope.dart';

class MatchFollowingService {
  MatchFollowingService(this.client);
  final SupabaseClient client;
  void _id(String id){if(!isPublicMatchId(id))throw ArgumentError('Geçersiz maç kimliği');}
  Future<MatchFollowState?> fetchState(String matchId) async {
    _id(matchId);final row=await client.rpc<Object?>('get_match_follow_status',params:{'p_match_id':matchId});
    return row==null?null:MatchFollowState.fromMap(Map<String,dynamic>.from(row as Map<dynamic,dynamic>));
  }
  Future<bool> toggleFollow(String matchId) async {
    _id(matchId);return client.rpc<bool>('toggle_match_follow',params:{'p_match_id':matchId});
  }
  /// Explicit desired state is safe to resend after an uncertain response.
  Future<bool> setFollow(String matchId,{required bool follow}) async {
    _id(matchId);return client.rpc<bool>('set_match_follow',params:{'p_match_id':matchId,'p_follow':follow});
  }
}
final Provider<MatchFollowingService> matchFollowingServiceProvider=Provider<MatchFollowingService>(
  (ref)=>MatchFollowingService(ref.watch(supabaseClientProvider)));
final AutoDisposeFutureProviderFamily<MatchFollowState?,String> matchFollowStateProvider=
  FutureProvider.autoDispose.family<MatchFollowState?,String>((ref,id) async {
    if(!ref.watch(isSupabaseEnabledProvider)||!ref.watch(featureEnabledProvider(FeatureFlags.liveMatchNotifications)))return null;
    if(ref.watch(authSessionProvider).valueOrNull?.user.id==null)return null;
    var disposed=false;ref.onDispose(()=>disposed=true);
    try{return await ref.watch(matchFollowingServiceProvider).fetchState(id);}
    finally{if(!disposed){final timer=Timer(const Duration(seconds:30),ref.invalidateSelf);ref.onDispose(timer.cancel);}}
  });
final AutoDisposeFutureProviderFamily<bool,String> isMatchFollowedProvider=FutureProvider.autoDispose.family<bool,String>(
  (ref,id) async {
    if (ref.watch(authSessionProvider.select((s) => s.valueOrNull?.user.id)) == null) return false;
    return (await ref.watch(matchFollowStateProvider(id).future))?.isFollowed ?? false;
  });
