import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'federation_bulletin_models.dart';
import 'supabase_scope.dart';

typedef FederationBulletinFilter = ({
  String? sportCode,
  String? cityCode,
  int offset,
  int limit,
});

class FederationBulletinService {
  FederationBulletinService(this.client);
  final SupabaseClient client;

  Future<List<FederationDisciplinaryItem>> fetchDisciplinaryBulletin({
    String? sportCode,
    String? cityCode,
    int offset = 0,
    int limit = 50,
  }) async {
    final rows = await client.rpc<List<dynamic>>(
      'public_federation_disciplinary_bulletin',
      params: {
        'p_sport': sportCode,
        'p_city': cityCode,
        'p_offset': offset,
        'p_limit': limit,
      },
    );
    return List<FederationDisciplinaryItem>.unmodifiable([
      for (final r in rows)
        FederationDisciplinaryItem.fromMap(
          Map<String, dynamic>.from(r as Map<dynamic, dynamic>),
        ),
    ]);
  }

  Future<List<FederationNoticeItem>> fetchNotices({
    String? sportCode,
    String? cityCode,
    int offset = 0,
    int limit = 50,
  }) async {
    final rows = await client.rpc<List<dynamic>>(
      'public_federation_notices',
      params: {
        'p_sport': sportCode,
        'p_city': cityCode,
        'p_offset': offset,
        'p_limit': limit,
      },
    );
    return List<FederationNoticeItem>.unmodifiable([
      for (final r in rows)
        FederationNoticeItem.fromMap(
          Map<String, dynamic>.from(r as Map<dynamic, dynamic>),
        ),
    ]);
  }
}

final federationBulletinServiceProvider = Provider<FederationBulletinService>(
  (ref) => FederationBulletinService(ref.watch(supabaseClientProvider)),
);

final federationDisciplinaryBulletinProvider = FutureProvider.autoDispose
    .family<List<FederationDisciplinaryItem>, FederationBulletinFilter>(
        (ref, filter) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  var disposed = false;
  ref.onDispose(() => disposed = true);
  try {
    return await ref
        .watch(federationBulletinServiceProvider)
        .fetchDisciplinaryBulletin(
          sportCode: filter.sportCode,
          cityCode: filter.cityCode,
          offset: filter.offset,
          limit: filter.limit,
        );
  } finally {
    if (!disposed) {
      final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
      ref.onDispose(timer.cancel);
    }
  }
});

final federationNoticesProvider = FutureProvider.autoDispose
    .family<List<FederationNoticeItem>, FederationBulletinFilter>(
        (ref, filter) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  var disposed = false;
  ref.onDispose(() => disposed = true);
  try {
    return await ref.watch(federationBulletinServiceProvider).fetchNotices(
          sportCode: filter.sportCode,
          cityCode: filter.cityCode,
          offset: filter.offset,
          limit: filter.limit,
        );
  } finally {
    if (!disposed) {
      final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
      ref.onDispose(timer.cancel);
    }
  }
});
