import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_scope.dart';

class PublicSportProgram {
  const PublicSportProgram(
      {required this.id,
      required this.name,
      required this.sportCode,
      required this.cityCode,
      required this.seasonLabel,
      required this.startsOn,
      required this.endsOn});
  final String id, name, sportCode, cityCode, seasonLabel, startsOn, endsOn;
  factory PublicSportProgram.fromMap(Map<String, dynamic> m) =>
      PublicSportProgram(
          id: m['id'] as String,
          name: m['name'] as String,
          sportCode: m['sport_code'] as String,
          cityCode: m['city_code'] as String,
          seasonLabel: m['season_label'] as String,
          startsOn: m['starts_on'] as String,
          endsOn: m['ends_on'] as String);
}

class PublicProgramMatch {
  const PublicProgramMatch(
      {required this.id,
      required this.startsAt,
      required this.location,
      required this.homeName,
      required this.awayName,
      required this.status});
  final String id, status;
  final DateTime startsAt;
  final String? location, homeName, awayName;
  factory PublicProgramMatch.fromMap(Map<String, dynamic> m) =>
      PublicProgramMatch(
          id: m['id'] as String,
          startsAt: DateTime.parse(m['starts_at'] as String),
          location: m['location'] as String?,
          homeName: m['home_name'] as String?,
          awayName: m['away_name'] as String?,
          status: m['status'] as String);
}

/// Guest reads exclusively use Phase B's published-program RPC allowlist.
class PublicProgramService {
  PublicProgramService(this._client);
  final SupabaseClient _client;
  Future<List<PublicSportProgram>> programs() async {
    final rows = await _client.rpc<List<dynamic>>('public_sport_programs');
    return rows
        .map((r) =>
            PublicSportProgram.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<PublicProgramMatch>> fixture(String org) async {
    final rows = await _client
        .rpc<List<dynamic>>('public_program_fixture', params: {'p_org': org});
    return rows
        .map((r) =>
            PublicProgramMatch.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}

final publicProgramServiceProvider = Provider<PublicProgramService>(
    (ref) => PublicProgramService(ref.watch(supabaseClientProvider)));
final publicSportProgramsProvider =
    FutureProvider.autoDispose<List<PublicSportProgram>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(publicProgramServiceProvider).programs();
});
final publicProgramFixtureProvider = FutureProvider.autoDispose
    .family<List<PublicProgramMatch>, String>((ref, org) {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(publicProgramServiceProvider).fixture(org);
});
