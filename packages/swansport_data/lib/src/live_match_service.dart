import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feature_flags.dart';
import 'live_match_models.dart';
import 'supabase_scope.dart';

class LiveMatchService {
  LiveMatchService(this.client);
  final SupabaseClient client;
  Map<String,dynamic> _map(Map<dynamic,dynamic> row) {
    final m=Map<String,dynamic>.from(row);
    for(final key in ['home_club_logo','away_club_logo']) {
      final value=m[key];
      if(value is String && value.isNotEmpty) {
        final uri=Uri.tryParse(value);
        m[key]=uri?.hasScheme==true ? (uri!.scheme=='https' ? value : null)
          : client.storage.from('post-media').getPublicUrl(value);
      }
    }
    return m;
  }
  static void _id(String id) {if(!isPublicMatchId(id))throw ArgumentError('Geçersiz maç kimliği');}
  Future<List<PublicLiveMatchSummary>> fetchLiveMatches({String? sport,String? city}) async {
    final rows=await client.rpc<dynamic>('public_live_matches',params:{'p_sport':sport,'p_city':city});
    return List.unmodifiable([for(final row in rows as List)PublicLiveMatchSummary.fromMap(_map(row as Map))]);
  }
  Future<PublicLiveMatchDetail?> fetchPublicMatchState(String matchId) async {
    _id(matchId);final row=await client.rpc<dynamic>('match_public_live_state',params:{'p_match_id':matchId});
    return row==null ? null : PublicLiveMatchDetail.fromMap(_map(row as Map));
  }
  Future<PublicMatchRoster?> fetchPublicMatchRoster(String matchId) async {
    _id(matchId);final row=await client.rpc<dynamic>('match_public_roster',params:{'p_match_id':matchId});
    return row==null ? null : PublicMatchRoster.fromMap(Map<String,dynamic>.from(row as Map));
  }
}

final Provider<LiveMatchService> liveMatchServiceProvider=Provider<LiveMatchService>((ref)=>LiveMatchService(ref.watch(supabaseClientProvider)));
final AutoDisposeFutureProviderFamily<List<PublicLiveMatchSummary>,String?> publicLiveMatchesForSportProvider=FutureProvider.autoDispose.family<List<PublicLiveMatchSummary>,String?>((ref,sport) async {
  if(!ref.watch(isSupabaseEnabledProvider) || !ref.watch(featureEnabledProvider(FeatureFlags.liveMatchHub)))return const [];
  var disposed=false;ref.onDispose(()=>disposed=true);
  try {return await ref.watch(liveMatchServiceProvider).fetchLiveMatches(sport:sport);}
  finally {if(!disposed){final timer=Timer(const Duration(seconds:30),ref.invalidateSelf);ref.onDispose(timer.cancel);}}
});
final AutoDisposeFutureProvider<List<PublicLiveMatchSummary>> publicLiveMatchesProvider=FutureProvider.autoDispose<List<PublicLiveMatchSummary>>((ref) async {
  if(!ref.watch(isSupabaseEnabledProvider) || !ref.watch(featureEnabledProvider(FeatureFlags.liveMatchHub)))return const [];
  var disposed=false;ref.onDispose(()=>disposed=true);
  try {return await ref.watch(liveMatchServiceProvider).fetchLiveMatches();}
  finally {if(!disposed){final timer=Timer(const Duration(seconds:30),ref.invalidateSelf);ref.onDispose(timer.cancel);}}
});
final AutoDisposeFutureProviderFamily<PublicLiveMatchDetail?,String> publicMatchLiveStateProvider=FutureProvider.autoDispose.family<PublicLiveMatchDetail?,String>((ref,id) async {
  if(!ref.watch(isSupabaseEnabledProvider) || !ref.watch(featureEnabledProvider(FeatureFlags.liveMatchHub)))return null;
  var disposed=false;ref.onDispose(()=>disposed=true);
  PublicLiveMatchDetail? result=null;
  try {
    result=await ref.watch(liveMatchServiceProvider).fetchPublicMatchState(id);
    return result;
  } finally {
    if(!disposed){final timer=Timer(Duration(seconds:result?.summary.isLive==true?10:30),ref.invalidateSelf);ref.onDispose(timer.cancel);}
  }
});
final AutoDisposeFutureProviderFamily<PublicMatchRoster?,String> publicMatchRosterProvider=FutureProvider.autoDispose.family<PublicMatchRoster?,String>((ref,id) async {
  if(!ref.watch(isSupabaseEnabledProvider) || !ref.watch(featureEnabledProvider(FeatureFlags.liveMatchHub)))return null;
  // Poll only after the request finishes; slow requests cannot overlap forever.
  var disposed=false;ref.onDispose(()=>disposed=true);
  try {return await ref.watch(liveMatchServiceProvider).fetchPublicMatchRoster(id);}
  finally {if(!disposed){final timer=Timer(const Duration(seconds:10),ref.invalidateSelf);ref.onDispose(timer.cancel);}}
});
