import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feature_flags.dart';
import 'league_standings_models.dart';
import 'live_match_models.dart';
import 'supabase_scope.dart';

typedef LeagueStandingsQuery=({String orgId,bool includeLive});
class LeagueStandingsService {
  LeagueStandingsService(this.client);
  final SupabaseClient client;
  void _id(String id){if(!isPublicMatchId(id))throw ArgumentError('Geçersiz müsabaka kimliği');}
  Future<List<LeagueStandingsRow>> fetchStandings(String orgId,{bool includeLive=false}) async {
    _id(orgId);
    final rows=await client.rpc<List<dynamic>>('public_league_standings',params:{'p_org_id':orgId,'p_include_live':includeLive});
    return List<LeagueStandingsRow>.unmodifiable([for(final row in rows)LeagueStandingsRow.fromMap(_row(row as Map<dynamic,dynamic>))]);
  }
  Map<String,dynamic> _row(Map<dynamic,dynamic> row){
    final m=Map<String,dynamic>.from(row);final value=m['club_logo'];
    if(value is String && value.isNotEmpty){final uri=Uri.tryParse(value);
      m['club_logo']=uri?.hasScheme==true ? (uri!.scheme=='https'?value:null)
        :client.storage.from('post-media').getPublicUrl(value);}
    return m;
  }
  Future<List<StandingsLeague>> leagues() async {
    final rows=await client.rpc<List<dynamic>>('public_standings_leagues');
    return List<StandingsLeague>.unmodifiable([for(final r in rows)StandingsLeague.fromMap(Map<String,dynamic>.from(r as Map<dynamic,dynamic>))]);
  }
  Future<MatchStandingsContext?> matchContext(String matchId) async {
    _id(matchId);final row=await client.rpc<Object?>('match_public_standings_context',params:{'p_match_id':matchId});
    return row==null?null:MatchStandingsContext.fromMap(Map<String,dynamic>.from(row as Map<dynamic,dynamic>));
  }
}
final Provider<LeagueStandingsService> leagueStandingsServiceProvider=Provider<LeagueStandingsService>(
  (ref)=>LeagueStandingsService(ref.watch(supabaseClientProvider)));
final AutoDisposeFutureProviderFamily<List<LeagueStandingsRow>,LeagueStandingsQuery> leagueStandingsProvider=
  FutureProvider.autoDispose.family<List<LeagueStandingsRow>,LeagueStandingsQuery>((ref,q) async {
    if(!ref.watch(isSupabaseEnabledProvider)||!ref.watch(featureEnabledProvider(FeatureFlags.leagueStandings)))return const [];
    var disposed=false;ref.onDispose(()=>disposed=true);
    try{return await ref.watch(leagueStandingsServiceProvider).fetchStandings(q.orgId,includeLive:q.includeLive);}
    finally{if(!disposed){final timer=Timer(Duration(seconds:q.includeLive?10:30),ref.invalidateSelf);ref.onDispose(timer.cancel);}}
  });
final AutoDisposeFutureProvider<List<StandingsLeague>> standingsLeaguesProvider=FutureProvider.autoDispose<List<StandingsLeague>>((ref) async {
  if(!ref.watch(isSupabaseEnabledProvider)||!ref.watch(featureEnabledProvider(FeatureFlags.leagueStandings)))return const [];
  var disposed=false;ref.onDispose(()=>disposed=true);
  try{return await ref.watch(leagueStandingsServiceProvider).leagues();}
  finally{if(!disposed){final timer=Timer(const Duration(seconds:30),ref.invalidateSelf);ref.onDispose(timer.cancel);}}
});
final AutoDisposeFutureProviderFamily<MatchStandingsContext?,String> matchStandingsContextProvider=
  FutureProvider.autoDispose.family<MatchStandingsContext?,String>((ref,id) async {
    if(!ref.watch(isSupabaseEnabledProvider)||!ref.watch(featureEnabledProvider(FeatureFlags.leagueStandings)))return null;
    var disposed=false;ref.onDispose(()=>disposed=true);
    try{return await ref.watch(leagueStandingsServiceProvider).matchContext(id);}
    finally{if(!disposed){final timer=Timer(const Duration(seconds:30),ref.invalidateSelf);ref.onDispose(timer.cancel);}}
  });
