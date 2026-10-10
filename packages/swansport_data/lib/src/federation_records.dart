import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';
import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'athlete_profile_service.dart';

enum FederationDuty {
  resultPublisher('result_publisher'),
  programPublisher('program_publisher'),
  licenseRegistrar('license_registrar'),
  clubRegistrar('club_registrar');

  const FederationDuty(this.key);
  final String key;
}

class FederationAppointment {
  const FederationAppointment({
    required this.id,
    required this.sportCode,
    required this.cityCode,
    required this.duty,
    required this.startsOn,
    required this.endsOn,
    this.revokedAt,
  });
  final String id;
  final String sportCode;
  final String? cityCode;
  final FederationDuty duty;
  final DateTime startsOn;
  final DateTime endsOn;
  final DateTime? revokedAt;

  bool authorizes(
    String sport,
    String? city,
    FederationDuty requiredDuty,
    DateTime instant,
  ) {
    final local = instant.toUtc().add(const Duration(hours: 3));
    final day = DateTime.utc(local.year, local.month, local.day);
    return revokedAt == null &&
        sportCode == sport &&
        duty == requiredDuty &&
        (cityCode == null || cityCode == city) &&
        !day.isBefore(
          DateTime.utc(startsOn.year, startsOn.month, startsOn.day),
        ) &&
        !day.isAfter(DateTime.utc(endsOn.year, endsOn.month, endsOn.day));
  }

  factory FederationAppointment.fromMap(Map<String, dynamic> map) =>
      FederationAppointment(
        id: map['id'] as String,
        sportCode: map['sport_code'] as String,
        cityCode: map['city_code'] as String?,
        duty: FederationDuty.values
            .firstWhere((value) => value.key == map['duty']),
        startsOn: DateTime.parse(map['starts_on'] as String),
        endsOn: DateTime.parse(map['ends_on'] as String),
        revokedAt: DateTime.tryParse(map['revoked_at'] as String? ?? ''),
      );
}

/// Only the explicit card fields survive deserialization. No full athlete row.
class FederationResultCard {
  const FederationResultCard({
    required this.matchId,
    required this.sportCode,
    required this.version,
    required this.protocol,
    required this.athletes,
    this.category,
  });
  final String matchId;
  final String sportCode;
  final String? category;
  final int version;
  final Map<String, dynamic>? protocol;
  final List<({String athleteId, String? name})> athletes;
  factory FederationResultCard.fromMap(Map<String, dynamic> map) =>
      FederationResultCard(
        matchId: map['match_id'] as String,
        sportCode: map['sport_code'] as String,
        category: map['category'] as String?,
        version: map['version'] as int,
        protocol: (map['protocol'] as Map?)?.cast<String, dynamic>(),
        athletes: [
          for (final row in map['athletes'] as List? ?? const [])
            (
              athleteId: (row as Map)['athlete_id'] as String,
              name: row['name'] as String?
            ),
        ],
      );
}

/// Online RPC calls only. This service has no persistent/offline write queue.
class FederationRecordsService {
  FederationRecordsService(this._client);
  final SupabaseClient _client;

  Future<List<FederationAppointment>> myAppointments() async {
    if (_client.auth.currentUser == null) return const [];
    final rows = await _client.rpc<dynamic>('my_federation_appointments');
    return [
      for (final row in rows as List)
        FederationAppointment.fromMap((row as Map).cast<String, dynamic>()),
    ];
  }

  Future<FederationResultCard> resultCard(String matchId) async {
    final row = await _client
        .rpc<dynamic>('federation_result_card', params: {'p_match': matchId});
    return FederationResultCard.fromMap((row as Map).cast<String, dynamic>());
  }

  Future<List<FederationPendingMatch>> pendingResults(int offset) async {
    final rows = await _client.rpc<dynamic>('federation_pending_results',
        params: {'p_offset': offset, 'p_limit': 100});
    return [
      for (final row in rows as List)
        FederationPendingMatch.fromMap(Map<String, dynamic>.from(row as Map))
    ];
  }

  Future<List<Achievement>> officialAchievements(String athleteId) async {
    dynamic rows;
    try {
      rows = await _client.rpc<dynamic>('official_athlete_achievements',
          params: {'p_athlete': athleteId});
    } on PostgrestException catch (e) {
      if (e.code == '42501') throw const OfficialCvAccessDenied();
      rethrow;
    }
    return [
      for (final row in rows as List)
        Achievement.fromMap(Map<String, dynamic>.from(row as Map))
    ];
  }

  Future<OfficialAchievementSource> achievementSource(
      String achievementId) async {
    final row = await _client.rpc<dynamic>('official_achievement_source',
        params: {'p_achievement': achievementId});
    if (row is! Map) throw StateError('Resmi müsabaka kaynağı bulunamadı');
    return OfficialAchievementSource.fromMap(Map<String, dynamic>.from(row));
  }

  Future<String> publishOfficialResult(
      {required FederationPendingMatch match,
      required Map<String, dynamic> protocol,
      required String reason}) async {
    final normalized = normalizeOfficialResult(match.sportCode, protocol);
    if (reason.trim().isEmpty)
      throw const FormatException('Yayın gerekçesi gerekli');
    return await _client.rpc<dynamic>('publish_official_match_result', params: {
      'p_match': match.id,
      'p_protocol': normalized,
      'p_reason': reason.trim(),
      'p_expected_version': match.version,
    }) as String;
  }

  Future<String> publishResult({
    required String matchId,
    required Map<String, dynamic> protocol,
    required String reason,
    required int expectedVersion,
  }) async =>
      await _client.rpc<dynamic>(
        'federation_publish_result',
        params: {
          'p_match': matchId,
          'p_protocol': protocol,
          'p_reason': reason,
          'p_expected_version': expectedVersion,
        },
      ) as String;
}

final federationRecordsServiceProvider =
    Provider<FederationRecordsService?>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return null;
  return FederationRecordsService(ref.watch(supabaseClientProvider));
});
final myFederationAppointmentsProvider =
    FutureProvider<List<FederationAppointment>>((ref) async {
  final service = ref.watch(federationRecordsServiceProvider);
  if (service == null) return const [];
  ref.watch(authSessionProvider);
  return service.myAppointments();
});

/// Canonical wire protocol. Times are integer milliseconds; no numeric strings.
Map<String, dynamic> normalizeOfficialResult(
    String sport, Map<String, dynamic> raw) {
  final parsed = validateMatchProtocol(sport, raw);
  if (!parsed.isComplete)
    throw const FormatException('Yalnız tamamlanmış müsabaka yayımlanabilir');
  final result = <String, dynamic>{...raw, 'sport_code': sport};
  if (parsed is AthleticsSwimmingMatchProtocol) {
    result['performances'] = [
      for (final p in parsed.performances)
        {
          'athlete_ref': p.athleteRef,
          'lane': p.lane,
          'heat': p.heat,
          'dq': p.dq,
          'dnf': p.dnf,
          if (p.timeMs != null) 'time_ms': p.timeMs,
          if (p.rank != null) 'rank': p.rank,
        }
    ];
  }
  return result;
}

class FederationPendingMatch {
  const FederationPendingMatch(
      {required this.id,
      required this.name,
      required this.sportCode,
      required this.version,
      this.cityCode,
      this.startsAt,
      this.location,
      this.homeName,
      this.awayName});
  final String id, name, sportCode;
  final String? cityCode, location, homeName, awayName;
  final DateTime? startsAt;
  final int version;
  factory FederationPendingMatch.fromMap(Map<String, dynamic> m) =>
      FederationPendingMatch(
          id: _requiredText(m['match_id'], 'match_id'),
          name: _requiredText(m['org_name'], 'org_name'),
          sportCode: _requiredText(m['sport_code'], 'sport_code'),
          cityCode: m['city_code'] as String?,
          version: _requiredVersion(m['version']),
          startsAt: m['starts_at'] is String
              ? DateTime.tryParse(m['starts_at'] as String)
              : null,
          location: m['location'] as String?,
          homeName: m['home_name'] as String?,
          awayName: m['away_name'] as String?);
}

class OfficialAchievementSource {
  const OfficialAchievementSource(
      {required this.matchId,
      required this.name,
      required this.sportCode,
      required this.version,
      required this.currentVersion,
      this.startsAt,
      this.location,
      this.result,
      this.scores = const []});
  final String matchId, name, sportCode;
  final int version, currentVersion;
  final DateTime? startsAt;
  final String? location, result;
  final List<({String label, int home, int away})> scores;
  factory OfficialAchievementSource.fromMap(Map<String, dynamic> m) =>
      OfficialAchievementSource(
        matchId: _requiredText(m['match_id'], 'match_id'),
        name: _requiredText(m['name'], 'name'),
        sportCode: _requiredText(m['sport_code'], 'sport_code'),
        version: _requiredVersion(m['version']),
        currentVersion: _requiredVersion(m['current_version']),
        startsAt: m['starts_at'] is String
            ? DateTime.tryParse(m['starts_at'] as String)
            : null,
        location: m['location'] is String ? m['location'] as String : null,
        result: m['result'] is String ? m['result'] as String : null,
        scores: [
          if (m['scores'] is List)
            for (final row in m['scores'] as List)
              if (row is Map)
                (
                  label: _requiredText(row['label'], 'score.label'),
                  home: _requiredVersion(row['home']),
                  away: _requiredVersion(row['away'])
                )
        ],
      );
}

final federationPendingResultsProvider = FutureProvider.autoDispose
    .family<List<FederationPendingMatch>, int>((ref, offset) async {
  ref.watch(authSessionProvider);
  final service = ref.watch(federationRecordsServiceProvider);
  return service == null ? const [] : service.pendingResults(offset);
});
final federationResultCardProvider = FutureProvider.autoDispose
    .family<FederationResultCard, String>((ref, id) async {
  ref.watch(authSessionProvider);
  final service = ref.watch(federationRecordsServiceProvider);
  if (service == null) throw StateError('Sunucu bağlantısı gerekli');
  return service.resultCard(id);
});
final officialAchievementsProvider = FutureProvider.autoDispose
    .family<List<Achievement>, String>((ref, id) async {
  ref.watch(authSessionProvider);
  final service = ref.watch(federationRecordsServiceProvider);
  return service == null ? const [] : service.officialAchievements(id);
});
final officialAchievementSourceProvider = FutureProvider.autoDispose
    .family<OfficialAchievementSource, String>((ref, id) async {
  ref.watch(authSessionProvider);
  final service = ref.watch(federationRecordsServiceProvider);
  if (service == null) throw StateError('Sunucu bağlantısı gerekli');
  return service.achievementSource(id);
});

class OfficialCvAccessDenied implements Exception {
  const OfficialCvAccessDenied();
}

String _requiredText(Object? value, String field) {
  if (value is! String || value.isEmpty)
    throw FormatException('$field eksik veya geçersiz');
  return value;
}

int _requiredVersion(Object? value) {
  if (value is! int || value < 0)
    throw const FormatException('Resmi sonuç sürümü eksik veya geçersiz');
  return value;
}
