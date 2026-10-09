import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feature_flags.dart';
import 'supabase_scope.dart';

class CourtWaitEntry {
  const CourtWaitEntry({
    required this.id,
    required this.courtId,
    required this.courtName,
    required this.startsAt,
    required this.status,
    required this.position,
    this.offeredUntil,
  });
  final String id, courtId, courtName, status;
  final DateTime startsAt;
  final DateTime? offeredUntil;
  final int position;
  bool get canLeave => status == 'waiting' || status == 'offered';
  bool get canAccept =>
      status == 'offered' &&
      offeredUntil != null &&
      offeredUntil!.isAfter(DateTime.now()) &&
      startsAt.isAfter(DateTime.now());
  String get label => switch (status) {
        'waiting' => 'Bekliyor',
        'offered' => 'Sana ayrıldı',
        'claimed' => 'Sıra alındı',
        'cancelled' => 'Vazgeçildi',
        _ => 'Süresi doldu'
      };
  factory CourtWaitEntry.fromMap(Map<String, dynamic> m) => CourtWaitEntry(
        id: m['id'] as String,
        courtId: m['court_id'] as String,
        courtName: m['court_name'] as String,
        startsAt: DateTime.parse(m['starts_at'] as String),
        status: m['status'] as String,
        position: (m['position'] as num).toInt(),
        offeredUntil: m['offered_until'] == null && m['status'] != 'offered'
            ? null
            : DateTime.parse(m['offered_until'] as String),
      );
}

class TurfDuty {
  const TurfDuty({
    required this.id,
    required this.fieldId,
    required this.fieldName,
    required this.venueName,
    required this.issuer,
    required this.validUntil,
    required this.inviteUntil,
    required this.status,
  });
  final String id, fieldId, fieldName, venueName, status;
  final bool issuer;
  final DateTime validUntil, inviteUntil;
  bool get live =>
      (status == 'invited' || status == 'active') &&
      validUntil.isAfter(DateTime.now());
  String get label => switch (status) {
        'active' => 'Aktif görev',
        'invited' => 'Davet bekliyor',
        'revoked' => 'Geri alındı',
        _ => 'Süresi doldu'
      };
  factory TurfDuty.fromMap(Map<String, dynamic> m) => TurfDuty(
        id: m['id'] as String,
        fieldId: m['field_id'] as String,
        fieldName: m['field_name'] as String,
        venueName: m['venue_name'] as String,
        issuer: m['issuer'] as bool,
        validUntil: DateTime.parse(m['valid_until'] as String),
        inviteUntil: DateTime.parse(m['invite_until'] as String),
        status: m['status'] as String,
      );
}

class TurfDutyPage {
  const TurfDutyPage(this.items, this.hasMore);
  final List<TurfDuty> items;
  final bool hasMore;
  factory TurfDutyPage.fromMap(Map<String, dynamic> m) => TurfDutyPage(
        (m['items'] as List)
            .map((r) => TurfDuty.fromMap((r as Map).cast<String, dynamic>()))
            .toList(),
        m['has_more'] as bool,
      );
}

class TurfDutyInvite {
  const TurfDutyInvite({
    required this.code,
    required this.validUntil,
    required this.inviteUntil,
  });
  final String code;
  final DateTime validUntil, inviteUntil;
  factory TurfDutyInvite.fromMap(Map<String, dynamic> m) => TurfDutyInvite(
        code: m['code'] as String,
        validUntil: DateTime.parse(m['valid_until'] as String),
        inviteUntil: DateTime.parse(m['invite_until'] as String),
      );
}

class SahaOperationsService {
  SahaOperationsService(this.client);
  final SupabaseClient client;
  Future<List<CourtWaitEntry>> waitlist() async => (await client
          .rpc<List<dynamic>>('my_court_waitlist'))
      .map((r) => CourtWaitEntry.fromMap((r as Map).cast<String, dynamic>()))
      .toList();
  Future<String> joinWait(String court, DateTime start) => client.rpc<String>(
        'join_court_waitlist',
        params: {'p_court': court, 'p_start': start.toUtc().toIso8601String()},
      );
  Future<void> leaveWait(String id) =>
      client.rpc<void>('leave_court_waitlist', params: {'p_id': id});
  Future<String> acceptWait(String id, {int guests = 0, int needed = 0}) =>
      client.rpc<String>(
        'accept_court_waitlist',
        params: {'p_id': id, 'p_guests': guests, 'p_needed': needed},
      );
  Future<TurfDutyPage> duties({int offset = 0}) async {
    final result = await client
        .rpc<dynamic>('my_turf_duties', params: {'p_offset': offset});
    return TurfDutyPage.fromMap((result as Map).cast<String, dynamic>());
  }

  Future<TurfDutyInvite> createDuty(String field, int hours, String op) async {
    final result = await client.rpc<dynamic>(
      'create_turf_duty',
      params: {'p_field': field, 'p_hours': hours, 'p_op': op},
    );
    return TurfDutyInvite.fromMap((result as Map).cast<String, dynamic>());
  }

  Future<String> redeemDuty(String code) =>
      client.rpc<String>('redeem_turf_duty', params: {'p_code': code.trim()});
  Future<void> revokeDuty(String id) =>
      client.rpc<void>('revoke_turf_duty', params: {'p_id': id});
  Future<Set<String>> delegatedFields() async =>
      (await client.rpc<List<dynamic>>('my_delegated_turf_fields'))
          .cast<String>()
          .toSet();
}

final sahaOperationsServiceProvider = Provider<SahaOperationsService>(
  (ref) => SahaOperationsService(ref.watch(supabaseClientProvider)),
);
final courtWaitlistProvider =
    FutureProvider.autoDispose<List<CourtWaitEntry>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(featureEnabledProvider(FeatureFlags.courtWaitlist))) {
    return Future.value([]);
  }
  ref.watch(authSessionProvider);
  final timer =
      Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(sahaOperationsServiceProvider).waitlist();
});
final turfDutiesProvider =
    FutureProvider.autoDispose.family<TurfDutyPage, int>((ref, offset) {
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(featureEnabledProvider(FeatureFlags.turfDelegation))) {
    return Future.value(const TurfDutyPage([], false));
  }
  ref.watch(authSessionProvider);
  final timer =
      Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(sahaOperationsServiceProvider).duties(offset: offset);
});
final delegatedTurfFieldIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(featureEnabledProvider(FeatureFlags.turfDelegation))) {
    return {};
  }
  ref.watch(authSessionProvider);
  var disposed = false;
  Timer? timer;
  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
  });
  final result =
      await ref.watch(sahaOperationsServiceProvider).delegatedFields();
  if (!disposed && result.isNotEmpty) {
    timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ref.invalidateSelf(),
    );
  }
  return result;
});
String sahaTime(DateTime value) {
  final d = value.toUtc().add(const Duration(hours: 3));
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
