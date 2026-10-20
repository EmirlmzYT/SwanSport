import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'access.dart';
import 'club_data.dart';
import 'feature_flags.dart';
import 'parent_actions.dart';
import 'supabase_scope.dart';

class TodayTrainingRsvp {
  const TodayTrainingRsvp(
      {required this.eventId,
      required this.athleteId,
      required this.title,
      required this.clubName,
      required this.isSelf,
      required this.startsAt,
      this.endsAt,
      this.place,
      this.childName,
      this.response,
      this.responseAt});
  final String eventId, athleteId, title, clubName;
  final bool isSelf;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? place, childName, response;
  // Exact server precision is required for the shared guardian/athlete CAS.
  final String? responseAt;
  String get key => '$eventId:$athleteId';
  factory TodayTrainingRsvp.fromMap(Map<String, dynamic> m) =>
      TodayTrainingRsvp(
        eventId: m['event_id'] as String,
        athleteId: m['athlete_id'] as String,
        title: m['title'] as String,
        clubName: m['club_name'] as String,
        isSelf: m['is_self'] as bool,
        startsAt: DateTime.parse(m['starts_at'] as String).toUtc(),
        endsAt: m['ends_at'] == null
            ? null
            : DateTime.parse(m['ends_at'] as String).toUtc(),
        place: m['place'] as String?,
        childName: m['child_name'] as String?,
        response: m['response'] as String?,
        responseAt: m['response_at'] as String?,
      );
}

class TodayTrainingSnapshot {
  const TodayTrainingSnapshot(
      {required this.serverNow, required this.items, this.accountId});
  final String? accountId;
  final DateTime serverNow;
  final List<TodayTrainingRsvp> items;
  factory TodayTrainingSnapshot.fromMap(Map<String, dynamic> m) =>
      TodayTrainingSnapshot(
        serverNow: DateTime.parse(m['server_now'] as String).toUtc(),
        items: List.unmodifiable((m['items'] as List).map((v) =>
            TodayTrainingRsvp.fromMap(Map<String, dynamic>.from(v as Map)))),
      );
}

class TodayTrainingService {
  TodayTrainingService(this.client);
  final SupabaseClient client;
  Future<TodayTrainingSnapshot> load() async {
    final result =
        await client.rpc<Map<String, dynamic>>('my_today_training_rsvps');
    return TodayTrainingSnapshot.fromMap(result);
  }

  Future<void> respond(TodayTrainingRsvp item, String status) =>
      client.rpc<void>(
        'respond_today_training',
        params: {
          'p_event': item.eventId,
          'p_athlete': item.athleteId,
          'p_status': status,
          'p_expected': item.responseAt,
        },
      );
}

final todayTrainingServiceProvider = Provider<TodayTrainingService>(
  (ref) => TodayTrainingService(ref.watch(supabaseClientProvider)),
);

final todayTrainingRsvpsProvider =
    FutureProvider.autoDispose<TodayTrainingSnapshot?>((ref) async {
  final access = ref.watch(swanAccessProvider);
  if (!access.hasAccount ||
      !(access.isVerifiedAthlete ||
          access.clubRole == 'athlete' ||
          access.isParent) ||
      !ref.watch(featureEnabledProvider(FeatureFlags.sportTrainingSessions)) ||
      !ref.watch(isSupabaseEnabledProvider)) return null;
  final account = ref.watch(
      authSessionProvider.select((session) => session.valueOrNull?.user.id));
  if (account == null) return null;
  // Refresh after a completed request, including day changes and edits elsewhere.
  var disposed = false;
  Timer? timer;
  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
  });
  try {
    final data = await ref.watch(todayTrainingServiceProvider).load();
    return TodayTrainingSnapshot(
        serverNow: data.serverNow, items: data.items, accountId: account);
  } finally {
    if (!disposed)
      timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  }
});

/// Captures the account before writing; a late response cannot refresh a new account.
final respondTodayTrainingProvider =
    Provider<Future<void> Function(TodayTrainingRsvp, String)>((ref) {
  var active = true;
  ref.onDispose(() => active = false);
  final service = ref.watch(todayTrainingServiceProvider);
  final account =
      ref.watch(authSessionProvider.select((s) => s.valueOrNull?.user.id));
  return (item, status) async {
    if (!active ||
        account == null ||
        ref.read(authSessionProvider).valueOrNull?.user.id != account ||
        !ref.read(swanAccessProvider).hasAccount ||
        !ref.read(featureEnabledProvider(FeatureFlags.sportTrainingSessions))) {
      throw StateError('Antrenman yanıtı için oturum ve erişim gerekli.');
    }
    try {
      await service.respond(item, status);
    } finally {
      if (active &&
          ref.read(authSessionProvider).valueOrNull?.user.id == account) {
        ref.invalidate(todayTrainingRsvpsProvider);
        ref.invalidate(myEventRsvpProvider(item.eventId));
        ref.invalidate(eventRsvpSummaryProvider(item.eventId));
        ref.invalidate(eventRosterProvider(item.eventId));
        ref.invalidate(parentActionsProvider);
      }
    }
  };
});
