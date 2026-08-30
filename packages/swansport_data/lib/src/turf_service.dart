import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Halı saha doluluk panosu.
///
/// courts'tan (packages/swansport_data/lib/src/court_service.dart) ayrı bir
/// dosya: halı saha sahibi bir işletme, kort ise sahipsiz/ücretsiz kamu
/// alanı. İkisi de "saat şeridi" fikrini paylaşıyor ama mülkiyet ve yetki
/// modelleri bambaşka — burada rezervasyon kilidi yok, yalnızca bir yetkili
/// kişinin işaretlediği bir ilan panosu var.
/// ---------------------------------------------------------------------------

class TurfField {
  const TurfField({
    required this.id,
    required this.name,
    required this.venueName,
    required this.opensAt,
    required this.closesAt,
    this.phone,
    this.cityName,
    this.district,
    this.lat,
    this.lng,
    this.distanceMeters,
  });

  final String id;
  final String name;
  final String venueName;
  final String opensAt;
  final String closesAt;
  final String? phone;
  final String? cityName;
  final String? district;
  final double? lat;
  final double? lng;
  final double? distanceMeters;

  String get where => [
        if ((district ?? '').isNotEmpty) district!,
        if ((cityName ?? '').isNotEmpty) cityName!,
      ].join(', ');

  String get distanceLabel {
    final d = distanceMeters;
    if (d == null) return '';
    if (d < 1000) return '${d.round()} m';
    return '${(d / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  TurfField withDistance(double? meters) => TurfField(
        id: id,
        name: name,
        venueName: venueName,
        opensAt: opensAt,
        closesAt: closesAt,
        phone: phone,
        cityName: cityName,
        district: district,
        lat: lat,
        lng: lng,
        distanceMeters: meters,
      );

  factory TurfField.fromMap(Map<String, dynamic> m) {
    final city = m['cities'];
    return TurfField(
      id: m['id'] as String,
      name: (m['name'] as String?) ?? '',
      venueName: (m['venue_name'] as String?) ?? '',
      opensAt: _hhmm(m['opens_at']),
      closesAt: _hhmm(m['closes_at']),
      phone: m['phone'] as String?,
      cityName: city is Map ? city['name'] as String? : null,
      district: m['district'] as String?,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
    );
  }

  static String _hhmm(Object? raw) {
    final s = '${raw ?? ''}';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }
}

/// Haftalık şeritteki tek bir saat hücresi.
class TurfSlot {
  const TurfSlot({
    required this.startsAt,
    required this.occupied,
    this.note,
    this.requestedByMe = false,
  });

  final DateTime startsAt;
  final bool occupied;
  final String? note;

  /// Bu hücreyi ben "istiyorum" diye işaretledim mi — bağlayıcı bir
  /// rezervasyon değil, yalnızca sahanın yöneticisine giden bir haber.
  final bool requestedByMe;

  String get hourLabel =>
      '${startsAt.hour.toString().padLeft(2, '0')}:'
      '${startsAt.minute.toString().padLeft(2, '0')}';

  factory TurfSlot.fromMap(Map<String, dynamic> m) => TurfSlot(
        startsAt:
            DateTime.tryParse('${m['starts_at']}')?.toLocal() ?? DateTime.now(),
        occupied: (m['occupied'] as bool?) ?? false,
        note: m['note'] as String?,
        requestedByMe: (m['requested_by_me'] as bool?) ?? false,
      );
}

class TurfService {
  TurfService(this._c);
  final SupabaseClient _c;

  Future<List<TurfField>> fields({String? cityCode}) async {
    var q = _c
        .from('turf_fields')
        .select('id, name, venue_name, phone, district, lat, lng, '
            'opens_at, closes_at, cities(name)')
        .eq('active', true);
    if (cityCode != null && cityCode.isNotEmpty) {
      q = q.eq('city_code', cityCode);
    }
    final rows = await q.order('venue_name').order('name');
    return (rows as List)
        .map((r) => TurfField.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<TurfSlot>> occupancyGrid(String fieldId, {int days = 7}) async {
    final rows = await _c.rpc<List<dynamic>>('turf_occupancy_grid',
        params: {'p_field': fieldId, 'p_days': days});
    return rows
        .map((r) => TurfSlot.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Hücreyi dolu işaretler. RPC yok — RLS (`is_turf_manager`) yetkisiz
  /// yazmayı zaten reddediyor.
  Future<void> markOccupied({
    required String fieldId,
    required DateTime startsAt,
    String? note,
  }) =>
      _c.from('turf_occupancy').upsert({
        'field_id': fieldId,
        'starts_at': startsAt.toUtc().toIso8601String(),
        'note': note,
        'created_by': _c.auth.currentUser?.id,
      }, onConflict: 'field_id,starts_at');

  Future<void> markFree({
    required String fieldId,
    required DateTime startsAt,
  }) =>
      _c
          .from('turf_occupancy')
          .delete()
          .eq('field_id', fieldId)
          .eq('starts_at', startsAt.toUtc().toIso8601String());

  Future<String> createManagerInvite(String fieldId, {String? email}) async {
    final res = await _c.rpc<String>('create_turf_manager_invite', params: {
      'p_field': fieldId,
      if (email != null && email.trim().isNotEmpty) 'p_email': email.trim(),
    });
    return res;
  }

  /// "Bu saati istiyorum" — bağlayıcı değil, sahanın yöneticilerine bildirim
  /// gider. Aynı kişi aynı hücreye tekrar dokunursa ikinci bir bildirim
  /// gitmez (sunucu tarafında sessizce yutulur).
  Future<void> requestSlot({
    required String fieldId,
    required DateTime startsAt,
  }) =>
      _c.rpc<void>('request_turf_slot', params: {
        'p_field': fieldId,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
      });
}

// =============================== Provider'lar ==============================

final turfServiceProvider = Provider<TurfService>((ref) {
  return TurfService(ref.watch(supabaseClientProvider));
});

final turfFieldsProvider =
    FutureProvider.autoDispose.family<List<TurfField>, String?>((ref, cityCode) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <TurfField>[]);
  }
  return ref.watch(turfServiceProvider).fields(cityCode: cityCode);
});

final turfOccupancyGridProvider =
    FutureProvider.autoDispose.family<List<TurfSlot>, String>((ref, fieldId) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <TurfSlot>[]);
  }
  return ref.watch(turfServiceProvider).occupancyGrid(fieldId);
});

/// Kullanıcının yönettiği sahaların kimlikleri — `myAccountantClubIdsProvider`
/// (expense_service.dart) ile birebir aynı şekilde çalışır.
final myManagedTurfFieldIdsProvider = FutureProvider<Set<String>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const {};
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const {};

  final rows = await client
      .from('turf_field_managers')
      .select('field_id')
      .eq('profile_id', uid)
      .eq('status', 'active');

  return {
    for (final r in rows as List) (r as Map)['field_id'] as String,
  };
});
