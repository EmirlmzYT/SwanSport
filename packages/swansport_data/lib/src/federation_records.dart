import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

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
