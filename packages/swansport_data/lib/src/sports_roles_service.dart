import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'sports_roles_models.dart';
import 'supabase_scope.dart';

class SportsClubAuthority {
  SportsClubAuthority({Set<String> medicalClubIds = const {},
    Set<String> administrativeClubIds = const {}})
    : medicalClubIds = Set.unmodifiable(medicalClubIds),
      administrativeClubIds = Set.unmodifiable(administrativeClubIds);
  final Set<String> medicalClubIds;
  final Set<String> administrativeClubIds;
}

class SportsRolesService {
  SportsRolesService(this._client, {void Function()? onChanged}) : _onChanged = onChanged;
  final SupabaseClient _client;
  final void Function()? _onChanged;
  String? get _uid => _client.auth.currentUser?.id;

  Future<List<FederationRole>> fetchMyFederationRoles() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _client.from('federation_roles')
      .select('id,federation_id,profile_id,role,city_code,starts_on,ends_on,revoked_at')
      .eq('profile_id', uid).isFilter('revoked_at', null);
    return List.unmodifiable(rows.map(FederationRole.fromMap).where((r) => r.isActive));
  }

  Future<RefereeProfile?> fetchMyRefereeProfile() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _client.from('referee_profiles')
      .select('id,profile_id,license_number,badge_tier,sport_code,city_code,is_active')
      .eq('profile_id', uid).maybeSingle();
    return row == null ? null : RefereeProfile.fromMap(row);
  }

  Future<List<ClubStaffRole>> fetchMyClubStaffRoles() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _client.from('club_staff_roles')
      .select('id,club_id,profile_id,role,assigned_at').eq('profile_id', uid);
    return List.unmodifiable(rows.map(ClubStaffRole.fromMap));
  }

  Future<List<RefereeMatchSummary>> fetchMyRefereeMatches({String? status}) async {
    if (_uid == null) return const [];
    if (status != null && !MatchOfficialStatus.values.any((v) => v.name == status)) {
      throw ArgumentError.value(status, 'status');
    }
    final rows = await _client.rpc('my_referee_matches', params: {'p_status': status});
    return _rows(rows, RefereeMatchSummary.fromMap);
  }

  Future<void> respondMatchAssignment(String officialId, bool accept, {String? reason}) async {
    _requireAccount();
    await _client.rpc('respond_match_assignment', params: {
      'p_official_id': officialId, 'p_accept': accept, 'p_reason': reason});
    _onChanged?.call();
  }

  Future<void> verifyMatchLineup(String matchId, List<String> homeRoster,
    List<String> awayRoster, {String? notes, List<String>? homeSubs,
    List<String>? awaySubs}) async {
    _requireAccount();
    await _client.rpc('referee_verify_lineup', params: {
      'p_match_id': matchId, 'p_home_roster': homeRoster, 'p_away_roster': awayRoster,
      'p_notes': notes, 'p_home_substitutes': homeSubs ?? const <String>[],
      'p_away_substitutes': awaySubs ?? const <String>[]});
    _onChanged?.call();
  }

  Future<List<MatchLineupApproval>> fetchMatchLineupApprovals(String matchId) async {
    if (_uid == null) return const [];
    final rows = await _client.rpc('match_approved_lineups', params: {'p_match_id': matchId});
    final projected = _rows(rows, (m) => m);
    if (projected.isEmpty) return const [];
    // 0111 deliberately exposes only the approved eight columns. Get real row
    // IDs through existing RLS, never fabricate an ID or guess the side.
    final ids = await _client.from('match_lineup_approvals')
      .select('id,participant_id').eq('match_id', matchId);
    final byParticipant = {for (final row in ids)
      row['participant_id'] as String: row['id'] as String};
    return List.unmodifiable([
      for (final row in projected)
        if (byParticipant.containsKey(row['participant_id']))
          MatchLineupApproval.fromMap({...row,
            'id': byParticipant[row['participant_id']], 'match_id': matchId}),
    ]);
  }

  Future<List<AcceptedMatchOfficial>> fetchAcceptedMatchOfficials(String matchId) async {
    final rows = await _client.rpc('accepted_match_officials', params: {'p_match_id': matchId});
    return _rows(rows, AcceptedMatchOfficial.fromMap);
  }

  Future<SportsClubAuthority> fetchMyClubAuthority() async {
    final uid = _uid;
    if (uid == null) return SportsClubAuthority();
    // Only own membership identifiers/roles; never subscribe to athlete names.
    final memberships = await _client.from('club_memberships')
      .select('club_id,role').eq('profile_id', uid).eq('status', 'active');
    final medical = <String>{};
    final administrative = <String>{};
    for (final row in memberships) {
      final clubId = row['club_id'] as String;
      if (row['role'] == 'coach' || row['role'] == 'club_admin') administrative.add(clubId);
      // The existing server predicate checks permission + revocation + membership.
      if (await _client.rpc('is_authorized_health_officer', params: {'p_club': clubId}) == true) {
        medical.add(clubId);
      }
    }
    return SportsClubAuthority(medicalClubIds: medical, administrativeClubIds: administrative);
  }

  void _requireAccount() {
    if (_uid == null) throw StateError('Giriş gerekli');
  }
  static List<T> _rows<T>(dynamic rows, T Function(Map<String, dynamic>) parse) =>
    List.unmodifiable((rows as List).map((row) => parse(Map<String, dynamic>.from(row as Map))));
}

final sportsRolesServiceProvider = Provider<SportsRolesService?>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return null;
  var disposed = false;
  ref.onDispose(() => disposed = true);
  return SportsRolesService(ref.watch(supabaseClientProvider), onChanged: () {
    if (disposed) return;
    ref.invalidate(myRefereeMatchesProvider);
    ref.invalidate(matchLineupApprovalsProvider);
    ref.invalidate(acceptedMatchOfficialsProvider);
  });
});

// All private providers re-evaluate on account changes; no fabricated fixture roles.
final myFederationRolesProvider = FutureProvider<List<FederationRole>>((ref) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) return const [];
  return await ref.watch(sportsRolesServiceProvider)?.fetchMyFederationRoles() ?? const [];
});
final myRefereeProfileProvider = FutureProvider<RefereeProfile?>((ref) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) return null;
  return await ref.watch(sportsRolesServiceProvider)?.fetchMyRefereeProfile();
});
final myClubStaffRolesProvider = FutureProvider<List<ClubStaffRole>>((ref) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) return const [];
  return await ref.watch(sportsRolesServiceProvider)?.fetchMyClubStaffRoles() ?? const [];
});
final mySportsClubAuthorityProvider = FutureProvider<SportsClubAuthority>((ref) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) return SportsClubAuthority();
  return await ref.watch(sportsRolesServiceProvider)?.fetchMyClubAuthority() ?? SportsClubAuthority();
});
final myRefereeMatchesProvider = FutureProvider.family<List<RefereeMatchSummary>, String?>((ref, status) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) return const [];
  return await ref.watch(sportsRolesServiceProvider)?.fetchMyRefereeMatches(status: status) ?? const [];
});
final matchLineupApprovalsProvider = FutureProvider.family<List<MatchLineupApproval>, String>((ref, matchId) async {
  final session = ref.watch(authSessionProvider).valueOrNull;
  if (session == null) return const [];
  return await ref.watch(sportsRolesServiceProvider)?.fetchMatchLineupApprovals(matchId) ?? const [];
});
final acceptedMatchOfficialsProvider = FutureProvider.family<List<AcceptedMatchOfficial>, String>((ref, matchId) async {
  ref.watch(authSessionProvider);
  return await ref.watch(sportsRolesServiceProvider)?.fetchAcceptedMatchOfficials(matchId) ?? const [];
});
