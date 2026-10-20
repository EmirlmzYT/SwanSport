import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_scope.dart';

class SeasonRosterSource {
  SeasonRosterSource.fromMap(Map<String, dynamic> m)
      : seasonId = m['season_id'] as String,
        seasonLabel = m['season_label'] as String,
        teamId = m['team_id'] as String,
        teamName = m['team_name'] as String,
        athletes = List.unmodifiable((m['athletes'] as List)
            .map((a) => (id: a['id'] as String, name: a['name'] as String)));
  final String seasonId, seasonLabel, teamId, teamName;
  final List<({String id, String name})> athletes;
  String get key => '$seasonId:$teamId';
}

final seasonRosterSourcesProvider = FutureProvider.autoDispose
    .family<List<SeasonRosterSource>, String>((ref, club) async {
  ref.watch(authSessionProvider);
  final rows = await ref
      .watch(supabaseClientProvider)
      .rpc<List<dynamic>>('season_roster_sources', params: {'p_club': club});
  return rows
      .map((r) =>
          SeasonRosterSource.fromMap(Map<String, dynamic>.from(r as Map)))
      .toList();
});
