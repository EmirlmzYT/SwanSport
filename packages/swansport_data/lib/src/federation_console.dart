import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';
import 'sports_roles_models.dart';

List<Map<String, dynamic>> _rows(Object? raw) => (raw as List? ?? const [])
    .map((e) => Map<String, dynamic>.from(e as Map)).toList();
DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);

class FederationConsoleScope {
  const FederationConsoleScope({required this.federationId, required this.name,
    required this.sportCode, required this.role, this.cityCode});
  final String federationId, name, sportCode, role;
  final String? cityCode;
  factory FederationConsoleScope.fromMap(Map<String, dynamic> m) => FederationConsoleScope(
    federationId: m['federation_id'] as String, name: m['federation_name'] as String,
    sportCode: m['sport_code'] as String, role: m['role'] as String, cityCode: m['city_code'] as String?);
}

class ConsoleMatchOfficial {
  const ConsoleMatchOfficial({required this.id, required this.duty, required this.status, this.name, this.declineReason});
  final String id, duty, status;
  final String? name, declineReason;
  factory ConsoleMatchOfficial.fromMap(Map<String, dynamic> m) => ConsoleMatchOfficial(
    id: m['id'] as String, duty: m['duty'] as String, status: m['status'] as String,
    name: m['name'] as String?, declineReason: m['decline_reason'] as String?);
}

class FederationConsoleMatch {
  FederationConsoleMatch({required this.id, required this.program, required this.sportCode,
    required this.status, this.cityCode, this.startsAt, this.location, this.homeName,
    this.awayName, this.facilityName, this.facilityConflictCount, List<ConsoleMatchOfficial> officials = const []}) : officials = List.unmodifiable(officials);
  final String id, program, sportCode, status;
  final String? cityCode, location, homeName, awayName;
  final String? facilityName;
  final int? facilityConflictCount;
  final DateTime? startsAt;
  final List<ConsoleMatchOfficial> officials;
  factory FederationConsoleMatch.fromMap(Map<String, dynamic> m) => FederationConsoleMatch(
    id: m['id'] as String, program: m['program'] as String, sportCode: m['sport_code'] as String,
    cityCode: m['city_code'] as String?, status: m['status'] as String, startsAt: _date(m['starts_at']),
    location: m['location'] as String?, homeName: m['home_name'] as String?, awayName: m['away_name'] as String?,
    facilityName: m['facility_name'] as String?, facilityConflictCount: (m['facility_conflict_count'] as num?)?.toInt(),
    officials: _rows(m['officials']).map(ConsoleMatchOfficial.fromMap).toList());
}

class AvailableReferee {
  const AvailableReferee({required this.profileId, required this.name, required this.badgeTier,
    required this.cityCode, this.lastMatchAt});
  final String profileId, name, badgeTier, cityCode;
  final DateTime? lastMatchAt;
  factory AvailableReferee.fromMap(Map<String, dynamic> m) => AvailableReferee(
    profileId: m['profile_id'] as String, name: m['name'] as String,
    badgeTier: m['badge_tier'] as String, cityCode: m['city_code'] as String, lastMatchAt: _date(m['last_match_at']));
}

class DisciplinarySubject {
  const DisciplinarySubject({required this.athleteId, required this.clubId, required this.reference});
  final String athleteId, clubId, reference;
  factory DisciplinarySubject.fromMap(Map<String, dynamic> m) => DisciplinarySubject(
    athleteId: m['athlete_id'] as String, clubId: m['club_id'] as String, reference: m['reference'] as String);
}

class DisciplinaryDecision {
  const DisciplinaryDecision({required this.id, required this.athleteId, required this.penaltyType,
    required this.reason, required this.createdAt, this.matchBanCount, this.months, this.fineAmount});
  final String id, athleteId, penaltyType, reason;
  final DateTime createdAt;
  final int? matchBanCount, months;
  final double? fineAmount;
  factory DisciplinaryDecision.fromMap(Map<String, dynamic> m) => DisciplinaryDecision(
    id: m['id'] as String, athleteId: m['athlete_id'] as String, penaltyType: m['penalty_type'] as String,
    reason: m['reason'] as String, createdAt: DateTime.parse(m['created_at'] as String),
    matchBanCount: (m['match_ban_count'] as num?)?.toInt(), months: (m['months'] as num?)?.toInt(),
    fineAmount: (m['fine_amount'] as num?)?.toDouble());
}

class FederationDisciplinaryReport {
  FederationDisciplinaryReport({required this.matchId, required this.revisionId, required this.program,
    required this.sportCode, required this.signedAt, required this.notes, required this.canDecide,
    this.cityCode, List<DisciplinarySubject> athletes = const [], List<DisciplinaryDecision> decisions = const [],
    List<String> redCardAthleteIds = const []}) : athletes = List.unmodifiable(athletes),
      decisions = List.unmodifiable(decisions), redCardAthleteIds = List.unmodifiable(redCardAthleteIds);
  final String matchId, revisionId, program, sportCode, notes;
  final String? cityCode;
  final DateTime signedAt;
  final bool canDecide;
  final List<DisciplinarySubject> athletes;
  final List<DisciplinaryDecision> decisions;
  final List<String> redCardAthleteIds;
  factory FederationDisciplinaryReport.fromMap(Map<String, dynamic> m) => FederationDisciplinaryReport(
    matchId: m['match_id'] as String, revisionId: m['revision_id'] as String, program: m['program'] as String,
    sportCode: m['sport_code'] as String, cityCode: m['city_code'] as String?, signedAt: DateTime.parse(m['signed_at'] as String),
    notes: m['notes'] as String, canDecide: m['can_decide'] as bool,
    athletes: _rows(m['athletes']).map(DisciplinarySubject.fromMap).toList(),
    decisions: _rows(m['decisions']).map(DisciplinaryDecision.fromMap).toList(),
    redCardAthleteIds: _rows(m['red_cards']).map((e) => e['athlete_id'] as String).toList());
}

class FederationConsolePage<T> {
  FederationConsolePage({required this.total, required List<T> rows}) : rows = List.unmodifiable(rows);
  final int total;
  final List<T> rows;
}

class LockedRefereeReport {
  const LockedRefereeReport({required this.matchId, required this.revisionId, required this.notes,
    required this.signedAt, required this.redCardCount, this.homeScore, this.awayScore});
  final String matchId, revisionId, notes;
  final DateTime signedAt;
  final int redCardCount;
  final int? homeScore, awayScore;
  factory LockedRefereeReport.fromMap(Map<String, dynamic> m) => LockedRefereeReport(
    matchId: m['match_id'] as String, revisionId: m['revision_id'] as String, notes: m['notes'] as String,
    signedAt: DateTime.parse(m['signed_at'] as String), redCardCount: (m['red_card_count'] as num).toInt(),
    homeScore: (m['home_score'] as num?)?.toInt(), awayScore: (m['away_score'] as num?)?.toInt());
}

class FederationMatchQuery {
  const FederationMatchQuery({this.cityCode, this.offset = 0, this.search = '', this.from, this.until});
  final String? cityCode;
  final int offset;
  final String search;
  final DateTime? from, until;
  @override
  bool operator ==(Object other) => other is FederationMatchQuery && cityCode == other.cityCode && offset == other.offset && search == other.search && from == other.from && until == other.until;
  @override
  int get hashCode => Object.hash(cityCode, offset, search, from, until);
}

class FederationConsoleService {
  FederationConsoleService(this.client);
  final SupabaseClient client;
  Future<List<FederationConsoleScope>> scopes() async => List.unmodifiable(
    _rows(await client.rpc<dynamic>('federation_console_scopes')).map(FederationConsoleScope.fromMap));
  Future<FederationConsolePage<FederationConsoleMatch>> matches(FederationMatchQuery q) async {
    final m = Map<String, dynamic>.from(await client.rpc<dynamic>('federation_console_matches', params: {
      'p_city': q.cityCode, 'p_offset': q.offset, 'p_search': q.search,
      'p_from': q.from?.toUtc().toIso8601String(), 'p_until': q.until?.toUtc().toIso8601String()}) as Map);
    return FederationConsolePage(total: (m['total'] as num).toInt(), rows: _rows(m['rows']).map(FederationConsoleMatch.fromMap).toList());
  }
  Future<List<AvailableReferee>> referees(String matchId) async => List.unmodifiable(
    _rows(await client.rpc<dynamic>('federation_available_referees', params: {'p_match_id': matchId, 'p_city': null})).map(AvailableReferee.fromMap));
  Future<void> assignMatchOfficial(String matchId, String profileId, MatchOfficialDuty duty) async {
    await client.rpc<dynamic>('assign_match_official', params: {'p_match_id': matchId, 'p_profile_id': profileId, 'p_duty': duty.wireName});
  }
  Future<void> allocateOfficialMatchFacility(String matchId, String facilityId, DateTime endsAt) async {
    await client.rpc<dynamic>('allocate_official_match_facility', params: {
      'p_match_id': matchId, 'p_facility_id': facilityId, 'p_ends_at': endsAt.toUtc().toIso8601String()});
  }
  Future<FederationConsolePage<FederationDisciplinaryReport>> reports(int offset) async {
    final m = Map<String, dynamic>.from(await client.rpc<dynamic>('federation_disciplinary_reports', params: {'p_offset': offset}) as Map);
    return FederationConsolePage(total: (m['total'] as num).toInt(), rows: _rows(m['rows']).map(FederationDisciplinaryReport.fromMap).toList());
  }
  Future<void> recordDecision(Map<String, dynamic> payload) async {
    await client.rpc<dynamic>('record_disciplinary_decision', params: payload);
  }
  Future<LockedRefereeReport?> lockedReport(String matchId) async {
    final row = await client.rpc<dynamic>('federation_locked_match_report', params: {'p_match_id': matchId});
    return row == null ? null : LockedRefereeReport.fromMap(Map<String, dynamic>.from(row as Map));
  }
}

final federationConsoleServiceProvider = Provider<FederationConsoleService?>((ref) =>
  ref.watch(isSupabaseEnabledProvider) ? FederationConsoleService(ref.watch(supabaseClientProvider)) : null);
final federationConsoleScopesProvider = FutureProvider.autoDispose<List<FederationConsoleScope>>((ref) {
  ref.watch(authSessionProvider);
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(federationConsoleServiceProvider)?.scopes() ?? Future.value(const []);
});
final federationConsoleMatchesProvider = FutureProvider.autoDispose.family<FederationConsolePage<FederationConsoleMatch>, FederationMatchQuery>((ref, q) {
  ref.watch(authSessionProvider);
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(federationConsoleServiceProvider)?.matches(q) ?? Future.value(FederationConsolePage<FederationConsoleMatch>(total: 0, rows: const []));
});
final federationAvailableRefereesProvider = FutureProvider.autoDispose.family<List<AvailableReferee>, String>((ref, id) {
  ref.watch(authSessionProvider);
  return ref.watch(federationConsoleServiceProvider)?.referees(id) ?? Future.value(const []);
});
final federationDisciplinaryReportsProvider = FutureProvider.autoDispose.family<FederationConsolePage<FederationDisciplinaryReport>, int>((ref, offset) {
  ref.watch(authSessionProvider);
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(federationConsoleServiceProvider)?.reports(offset) ?? Future.value(FederationConsolePage<FederationDisciplinaryReport>(total: 0, rows: const []));
});
final federationLockedReportProvider = FutureProvider.autoDispose.family<LockedRefereeReport?, String>((ref, matchId) {
  ref.watch(authSessionProvider);
  return ref.watch(federationConsoleServiceProvider)?.lockedReport(matchId) ?? Future<LockedRefereeReport?>.value(null);
});
