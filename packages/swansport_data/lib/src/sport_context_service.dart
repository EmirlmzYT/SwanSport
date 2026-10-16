import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_branch_engine/swansport_branch_engine.dart';

import 'access.dart';
import 'sports_catalog.dart';
import 'supabase_athletes.dart';
import 'supabase_scope.dart';
import 'training_session_service.dart';
import 'verification_service.dart';

class ClubTrainingSportsService {
  ClubTrainingSportsService(this._save, this._changed);
  final Future<int> Function(String, List<String>) _save;
  final void Function() _changed;
  Future<int> setClubTrainingSports({required String clubId, required List<String> sportCodes}) async {
    final count = await _save(clubId, List.unmodifiable(sportCodes));
    _changed();
    return count;
  }
}

final Provider<ClubTrainingSportsService> clubTrainingSportsServiceProvider = Provider<ClubTrainingSportsService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  var disposed = false;
  ref.onDispose(() => disposed = true);
  return ClubTrainingSportsService((clubId, codes) => client.rpc<int>('set_club_training_sports',
    params: {'p_club_id': clubId, 'p_sport_codes': codes}), () {
      if (disposed) return;
      ref.invalidate(activeClubSportsProvider);
      ref.invalidate(sportContextOptionsProvider);
      ref.invalidate(clubTrainingSportsProvider);
    });
});

/// Editable selection is distinct from the effective union (registry/main/team sports).
final AutoDisposeFutureProviderFamily<List<String>, String> clubTrainingSportsProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, clubId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final uid = ref.watch(authSessionProvider).valueOrNull?.user.id;
  if (uid == null) return const [];
  final rows = await ref.watch(supabaseClientProvider).from('club_training_sports')
      .select('sport_code').eq('club_id', clubId);
  return List.unmodifiable(rows.map((r) => r['sport_code'] as String));
});

List<SportItem> catalogSportsFor(Iterable<String?> codes) {
  final unique = codes.whereType<String>().map(_canonicalSport).toSet();
  return List.unmodifiable(SportsCatalog.all.where((s) => unique.contains(s.code)));
}

String _canonicalSport(String code) {
  try { return branchTrainingProfileFor(code).sportCode; }
  on FormatException { return code; }
}

bool matchesTrainingSportContext(String sportCode, String? context) =>
    context == null || _canonicalSport(sportCode) == _canonicalSport(context);

final AutoDisposeFutureProvider<List<SportItem>> activeClubSportsProvider =
    FutureProvider.autoDispose<List<SportItem>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final uid = ref.watch(authSessionProvider).valueOrNull?.user.id;
  final access = ref.watch(swanAccessProvider);
  if (uid == null || (access.isAccountant && !access.isClubStaff)) return const [];
  final client = ref.watch(supabaseClientProvider);
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  final rows = await client.rpc<List<dynamic>>('my_training_club_sports', params: {'p_club_id': club.id});
  return catalogSportsFor(rows.map((r) => (r as Map)['sport_code'] as String?));
});

final AutoDisposeFutureProvider<List<SportItem>> myActiveSportsProvider =
    FutureProvider.autoDispose<List<SportItem>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final uid = ref.watch(authSessionProvider).valueOrNull?.user.id;
  final access = ref.watch(swanAccessProvider);
  if (uid == null || (access.isAccountant && !access.isClubStaff && access.athleteKind == null)) return const [];
  final client = ref.watch(supabaseClientProvider);
  final credentialsFuture = ref.watch(myCredentialsProvider.future);
  final historyFuture = ref.watch(myTrainingHistoryProvider.future);
  final results = await Future.wait<Object>([credentialsFuture, historyFuture]);
  final credentials = results[0] as List<CredentialRow>;
  final codes = <String?>[
    for (final c in credentials) if (c.isValidOn(DateTime.now())) c.sportCode,
  ];
  final memberships = await client.from('club_memberships')
      .select('teams(sport_code)').eq('profile_id', uid).eq('status', 'active');
  for (final membership in memberships) {
    final team = membership['teams'];
    if (team is Map) codes.add(team['sport_code'] as String?);
  }
  // Only the signed-in user's athlete keys; never request names or other rosters.
  final athletes = await client.from('athletes').select('id').eq('profile_id', uid).eq('status', 'active');
  if (athletes.isNotEmpty) {
    final teams = await client.from('team_memberships').select('season_id,teams(sport_code),seasons(is_active)')
        .inFilter('athlete_id', athletes.map((a) => a['id'] as String).toList());
    for (final membership in teams) {
      final season = membership['seasons'];
      if (membership['season_id'] != null && (season is! Map || season['is_active'] != true)) continue;
      final team = membership['teams'];
      if (team is Map) codes.add(team['sport_code'] as String?);
    }
  }
  final history = results[1] as List<TrainingHistoryEntry>;
  codes.addAll(history.map((h) => h.sportCode));
  return catalogSportsFor(codes);
});

final AutoDisposeProvider<AsyncValue<List<SportItem>>> sportContextOptionsProvider =
    Provider.autoDispose<AsyncValue<List<SportItem>>>((ref) {
  final access = ref.watch(swanAccessProvider);
  final club = ref.watch(activeClubProvider).valueOrNull;
  return access.isClubStaff && club != null
      ? ref.watch(activeClubSportsProvider) : ref.watch(myActiveSportsProvider);
});

/// '*' is an explicit All selection; null means automatic single-sport context.
/// A scope change destroys the previous selection rather than leaking it to a new account.
final StateProvider<String?> selectedSportContextProvider = StateProvider<String?>((ref) {
  ref.watch(authSessionProvider.select((s) => s.valueOrNull?.user.id));
  ref.watch(activeClubProvider.select((c) => c.valueOrNull?.id));
  return null;
});

final AutoDisposeProvider<String?> effectiveSportContextProvider = Provider.autoDispose<String?>((ref) {
  final selection = ref.watch(selectedSportContextProvider);
  if (selection == '*') return null;
  if (SportsCatalog.findByCode(selection) != null) return selection;
  final sports = ref.watch(sportContextOptionsProvider).valueOrNull;
  return sports?.length == 1 ? sports!.single.code : null;
});
