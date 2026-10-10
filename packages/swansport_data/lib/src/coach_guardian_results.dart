import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'access.dart';
import 'federation_records.dart';
import 'notification_service.dart';
import 'supabase_scope.dart';
import 'unified_calendar.dart';

String _text(Map<dynamic, dynamic> m, String key) {
  final value = m[key];
  if (value is! String || value.isEmpty) throw FormatException('$key eksik');
  return value;
}

class OfficialTeamRoster {
  OfficialTeamRoster.fromMap(Map<dynamic, dynamic> m)
      : participantId = _text(m, 'participant_id'),
        name = _text(m, 'name'),
        sportCode = _text(m, 'sport_code'),
        version = m['version'] is int
            ? m['version'] as int
            : throw const FormatException('version eksik'),
        athleteIds = List.unmodifiable(m['athlete_ids'] is List
            ? (m['athlete_ids'] as List).map((id) => id is String
                ? id
                : throw const FormatException('athlete_ids geçersiz'))
            : throw const FormatException('athlete_ids eksik'));
  final String participantId, name, sportCode;
  final int version;
  final List<String> athleteIds;
}

enum GuardianResultOutcome { won, lost, draw, recorded, dq, dnf }

class GuardianOfficialResult {
  GuardianOfficialResult.fromMap(Map<String, dynamic> m)
      : source = OfficialAchievementSource.fromMap(m),
        childName = _text(m, 'child_name'),
        outcome = switch (m['outcome']) {
          'won' => GuardianResultOutcome.won,
          'lost' => GuardianResultOutcome.lost,
          'draw' => GuardianResultOutcome.draw,
          'dq' => GuardianResultOutcome.dq,
          'dnf' => GuardianResultOutcome.dnf,
          'recorded' => GuardianResultOutcome.recorded,
          _ => throw const FormatException('Resmi sonuç durumu geçersiz'),
        };
  final OfficialAchievementSource source;
  final String childName;
  final GuardianResultOutcome outcome;
  String get outcomeLabel => switch (outcome) {
        GuardianResultOutcome.won => 'Galibiyet',
        GuardianResultOutcome.lost => 'Mağlubiyet',
        GuardianResultOutcome.draw => 'Beraberlik',
        GuardianResultOutcome.dq => 'Diskalifiye (DQ)',
        GuardianResultOutcome.dnf => 'Tamamlamadı (DNF)',
        GuardianResultOutcome.recorded => 'Resmi derece',
      };
}

class GuardianCalendarResult {
  GuardianCalendarResult.fromMap(Map<dynamic, dynamic> m)
      : notificationId = m['notification_id'] is String
            ? m['notification_id'] as String
            : null,
        childId = m['child_id'] is String ? m['child_id'] as String : null,
        result = GuardianOfficialResult.fromMap({
          if (m['summary'] is Map)
            ...Map<String, dynamic>.from(m['summary'] as Map),
          'child_name': _text(m, 'child_name'),
        });
  final String? notificationId, childId;
  final GuardianOfficialResult result;
}

class CoachGuardianService {
  CoachGuardianService(this.client);
  final SupabaseClient client;
  Future<List<OfficialTeamRoster>> rosters(String teamId) async {
    final rows = await client.rpc<List<dynamic>>('official_team_rosters',
        params: {'p_team': teamId});
    return [for (final row in rows) OfficialTeamRoster.fromMap(row as Map)];
  }

  Future<void> publishRoster(
      OfficialTeamRoster roster, List<String> ids, String reason) async {
    if (ids.isEmpty || reason.trim().isEmpty)
      throw const FormatException('Kadro ve gerekçe gerekli');
    await client.rpc<dynamic>('federation_publish_roster', params: {
      'p_participant': roster.participantId,
      'p_athletes': ids,
      'p_reason': reason.trim(),
      'p_expected_version': roster.version,
    });
  }

  Future<GuardianOfficialResult> result(String notificationId) async {
    final row = await client.rpc<Map<String, dynamic>>(
        'guardian_notification_result',
        params: {'p_notification': notificationId});
    return GuardianOfficialResult.fromMap(row);
  }

  Future<GuardianOfficialResult> matchResult(
      String matchId, String childId) async {
    final row = await client.rpc<Map<String, dynamic>>('guardian_match_result',
        params: {'p_match': matchId, 'p_athlete': childId});
    return GuardianOfficialResult.fromMap(row);
  }

  Future<List<GuardianCalendarResult>> calendar(CalendarMonth month) async {
    final rows = await client.rpc<List<dynamic>>('guardian_calendar_results',
        params: {
          'p_from': month.from.toIso8601String(),
          'p_to': month.to.toIso8601String()
        });
    return [for (final row in rows) GuardianCalendarResult.fromMap(row as Map)];
  }

  Stream<void> changes() {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return const Stream.empty();
    final controller = StreamController<void>();
    final channel = client
        .channel('guardian-results:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'profile_id',
              value: uid),
          callback: (payload) {
            if (payload.newRecord['kind'] == 'match_result' &&
                !controller.isClosed) controller.add(null);
          },
        )
        .subscribe();
    // Realtime and FCM give immediate refresh; polling recovers missed messages.
    final poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!controller.isClosed) controller.add(null);
    });
    controller.onCancel = () async {
      poll.cancel();
      await client.removeChannel(channel);
      await controller.close();
    };
    return controller.stream;
  }
}

final coachGuardianServiceProvider = Provider<CoachGuardianService>(
    (ref) => CoachGuardianService(ref.watch(supabaseClientProvider)));
final officialTeamRostersProvider = FutureProvider.autoDispose
    .family<List<OfficialTeamRoster>, String>((ref, team) {
  ref.watch(authSessionProvider);
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(coachGuardianServiceProvider).rosters(team);
});
final guardianNotificationResultProvider = FutureProvider.autoDispose
    .family<GuardianOfficialResult, String>((ref, notification) {
  ref.watch(authSessionProvider);
  if (!ref.watch(isSupabaseEnabledProvider))
    throw StateError('Sunucu bağlantısı gerekli');
  return ref.watch(coachGuardianServiceProvider).result(notification);
});
final guardianCalendarResultsProvider = FutureProvider.autoDispose
    .family<List<GuardianCalendarResult>, CalendarMonth>((ref, month) {
  ref.watch(authSessionProvider);
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(swanAccessProvider).isParent) return const [];
  return ref.watch(coachGuardianServiceProvider).calendar(month);
});
final guardianMatchResultProvider = FutureProvider.autoDispose
    .family<GuardianOfficialResult, ({String matchId, String childId})>(
        (ref, key) {
  ref.watch(authSessionProvider);
  if (!ref.watch(isSupabaseEnabledProvider))
    throw StateError('Sunucu bağlantısı gerekli');
  return ref
      .watch(coachGuardianServiceProvider)
      .matchResult(key.matchId, key.childId);
});

void refreshOfficialResults(Ref ref) {
  ref.invalidate(guardianNotificationResultProvider);
  ref.invalidate(guardianMatchResultProvider);
  ref.invalidate(guardianCalendarResultsProvider);
  ref.invalidate(officialAchievementsProvider);
  ref.invalidate(officialAchievementSourceProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(categorizedNotificationsProvider);
  ref.invalidate(unreadNotificationsProvider);
}

final officialResultRefreshProvider =
    Provider<void Function()>((ref) => () => refreshOfficialResults(ref));
final guardianResultSyncProvider = StreamProvider.autoDispose<void>((ref) {
  ref.watch(authSessionProvider);
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(swanAccessProvider).isParent) return const Stream.empty();
  return ref
      .watch(coachGuardianServiceProvider)
      .changes()
      .map((_) => refreshOfficialResults(ref));
});
