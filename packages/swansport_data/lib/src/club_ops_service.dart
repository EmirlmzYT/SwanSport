import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';
import 'supabase_athletes.dart';

/// ---------------------------------------------------------------------------
/// Kulüp işletme verisi — tesisler, sağlık kayıtları ve belgeler.
///
/// Bu üç tablo şemada baştan beri vardı ama ekranlar sahte veriyle çalışıyordu.
/// Yetki kuralları mevcut: kulüp üyesi okur, kulüp görevlisi yazar.
/// ---------------------------------------------------------------------------

class FacilityRow {
  const FacilityRow({
    required this.id,
    required this.name,
    required this.occupancy,
    required this.status,
    this.kind,
  });

  final String id;
  final String name;
  final int occupancy; // 0..100
  final String status;
  final String? kind;

  bool get isBusy => occupancy >= 80;

  factory FacilityRow.fromMap(Map<String, dynamic> m) => FacilityRow(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        kind: m['kind'] as String?,
        occupancy: (m['occupancy'] as int?) ?? 0,
        status: (m['status'] as String?) ?? 'Müsait',
      );
}

class InjuryRow {
  const InjuryRow({
    required this.id,
    required this.athleteId,
    required this.athleteName,
    required this.status,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String athleteId;
  final String athleteName;

  /// fit | pending | injured (public.fitness_status)
  final String status;
  final DateTime createdAt;
  final String? note;

  String get statusLabel => switch (status) {
        'injured' => 'Sakat',
        'pending' => 'Takipte',
        _ => 'Sağlam',
      };

  factory InjuryRow.fromMap(Map<String, dynamic> m) {
    final a = (m['athletes'] as Map?)?.cast<String, dynamic>();
    final name = [
      (a?['first_name'] as String?) ?? '',
      (a?['last_name'] as String?) ?? '',
    ].join(' ').trim();
    return InjuryRow(
      id: m['id'] as String,
      athleteId: m['athlete_id'] as String,
      athleteName: name.isEmpty ? 'Sporcu' : name,
      status: (m['status'] as String?) ?? 'fit',
      note: m['note'] as String?,
      createdAt:
          DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
    );
  }
}

class DocumentRow {
  const DocumentRow({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdAt,
    this.sizeLabel,
  });

  final String id;
  final String name;
  final String kind;
  final DateTime createdAt;
  final String? sizeLabel;

  factory DocumentRow.fromMap(Map<String, dynamic> m) => DocumentRow(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? 'file',
        sizeLabel: m['size_label'] as String?,
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ??
            DateTime.now(),
      );
}

/// Tesisin haftalık yükü — elle girilen doluluk yerine takvimden hesaplanır.
class FacilityLoad {
  const FacilityLoad({
    required this.facilityId,
    required this.name,
    required this.status,
    required this.eventCount,
    required this.busyMinutes,
    required this.loadPercent,
    this.kind,
    this.nextStartsAt,
    this.nextTitle,
  });

  final String facilityId;
  final String name;
  final String status;
  final int eventCount;
  final int busyMinutes;
  final int loadPercent;
  final String? kind;
  final DateTime? nextStartsAt;
  final String? nextTitle;

  bool get isIdle => eventCount == 0;

  /// "6 saat 30 dk" biçiminde okunur süre.
  String get busyLabel {
    final h = busyMinutes ~/ 60;
    final m = busyMinutes % 60;
    if (h == 0) return '$m dk';
    return m == 0 ? '$h saat' : '$h saat $m dk';
  }

  factory FacilityLoad.fromMap(Map<String, dynamic> m) => FacilityLoad(
        facilityId: m['facility_id'] as String,
        name: (m['name'] as String?) ?? '',
        kind: m['kind'] as String?,
        status: (m['status'] as String?) ?? 'Müsait',
        eventCount: (m['event_count'] as int?) ?? 0,
        busyMinutes: (m['busy_minutes'] as int?) ?? 0,
        loadPercent: (m['load_percent'] as int?) ?? 0,
        nextStartsAt: m['next_starts'] == null
            ? null
            : DateTime.tryParse('${m['next_starts']}')?.toLocal(),
        nextTitle: m['next_title'] as String?,
      );
}

/// Bir tesisin programındaki tek satır.
class FacilitySlot {
  const FacilitySlot({
    required this.id,
    required this.title,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    this.teamName,
    this.conflictSource,
  });

  final String id;
  final String title;
  final String kind;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? teamName;
  final String? conflictSource;

  factory FacilitySlot.fromMap(Map<String, dynamic> m) => FacilitySlot(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? 'training',
        startsAt:
            DateTime.tryParse('${m['starts_at']}')?.toLocal() ?? DateTime.now(),
        endsAt:
            DateTime.tryParse('${m['ends_at']}')?.toLocal() ?? DateTime.now(),
        teamName: m['team_name'] as String?,
        conflictSource: m['conflict_source'] as String?,
      );
}

class FacilityReservation {
  const FacilityReservation({
    required this.id,
    required this.clubId,
    required this.facilityId,
    required this.title,
    required this.kind,
    required this.startsAt,
    required this.endsAt,
    this.reservedByName,
    this.reservedByPhone,
    this.reservedByProfileId,
    required this.status,
    required this.fee,
    this.invoiceId,
    this.notes,
    this.createdAt,
  });

  final String id, clubId, facilityId, title, kind, status;
  final DateTime startsAt, endsAt;
  final String? reservedByName,
      reservedByPhone,
      reservedByProfileId,
      invoiceId,
      notes;
  final double fee;
  final DateTime? createdAt;

  factory FacilityReservation.fromMap(Map<String, dynamic> m) =>
      FacilityReservation(
        id: m['id'] as String,
        clubId: (m['club_id'] as String?) ?? '',
        facilityId: (m['facility_id'] as String?) ?? '',
        title: (m['title'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? 'rental',
        startsAt:
            DateTime.tryParse('${m['starts_at']}')?.toLocal() ?? DateTime.now(),
        endsAt:
            DateTime.tryParse('${m['ends_at']}')?.toLocal() ?? DateTime.now(),
        reservedByName: m['reserved_by_name'] as String?,
        reservedByPhone: m['reserved_by_phone'] as String?,
        reservedByProfileId: m['reserved_by_profile_id'] as String?,
        status: (m['status'] as String?) ?? 'confirmed',
        fee: (m['fee'] as num?)?.toDouble() ?? 0.0,
        invoiceId: m['invoice_id'] as String?,
        notes: m['notes'] as String?,
        createdAt: m['created_at'] == null
            ? null
            : DateTime.tryParse('${m['created_at']}')?.toLocal(),
      );
}

/// Yoklama özeti satırı.
class AttendanceStat {
  const AttendanceStat({
    required this.athleteId,
    required this.name,
    required this.present,
    required this.absent,
    required this.total,
    required this.rate,
  });

  final String athleteId;
  final String name;
  final int present;
  final int absent;
  final int total;
  final int rate;
}

class ClubOpsService {
  ClubOpsService(this._c);
  final SupabaseClient _c;

  // ------------------------------- tesisler --------------------------------
  Future<List<FacilityRow>> facilities(String clubId) async {
    final rows = await _c
        .from('facilities')
        .select('id, name, kind, occupancy, status')
        .eq('club_id', clubId)
        .order('name');
    return (rows as List)
        .map((r) => FacilityRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addFacility(String clubId, String name,
      {String? kind, int occupancy = 0, String status = 'Müsait'}) async {
    await _c.from('facilities').insert({
      'club_id': clubId,
      'name': name.trim(),
      if (kind != null && kind.trim().isNotEmpty) 'kind': kind.trim(),
      'occupancy': occupancy.clamp(0, 100),
      'status': status,
    });
  }

  Future<void> updateFacility(String id,
      {int? occupancy, String? status}) async {
    await _c.from('facilities').update({
      if (occupancy != null) 'occupancy': occupancy.clamp(0, 100),
      if (status != null) 'status': status,
    }).eq('id', id);
  }

  Future<void> removeFacility(String id) async {
    await _c.from('facilities').delete().eq('id', id);
  }

  // -------------------------------- sağlık ---------------------------------
  Future<List<InjuryRow>> injuries(String clubId) async {
    final rows = await _c
        .from('injuries')
        .select('id, athlete_id, status, note, created_at, '
            'athletes(first_name, last_name)')
        .eq('club_id', clubId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => InjuryRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addInjury(String clubId, String athleteId, String status,
      {String? note}) async {
    await _c.from('injuries').insert({
      'club_id': clubId,
      'athlete_id': athleteId,
      'status': status,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<void> updateInjury(String id, {String? status, String? note}) async {
    await _c.from('injuries').update({
      if (status != null) 'status': status,
      if (note != null) 'note': note.trim().isEmpty ? null : note.trim(),
    }).eq('id', id);
  }

  Future<void> removeInjury(String id) async {
    await _c.from('injuries').delete().eq('id', id);
  }

  // -------------------------------- belgeler -------------------------------
  Future<List<DocumentRow>> documents(String clubId) async {
    final rows = await _c
        .from('documents')
        .select('id, name, kind, size_label, created_at')
        .eq('club_id', clubId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => DocumentRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addDocument(String clubId, String name,
      {String kind = 'file', String? sizeLabel}) async {
    await _c.from('documents').insert({
      'club_id': clubId,
      'name': name.trim(),
      'kind': kind,
      if (sizeLabel != null) 'size_label': sizeLabel,
    });
  }

  Future<void> removeDocument(String id) async {
    await _c.from('documents').delete().eq('id', id);
  }

  // --------------------------- tesis ↔ takvim ------------------------------

  /// Haftalık tesis yükü (takvimden hesaplanır).
  Future<List<FacilityLoad>> facilityLoad(String clubId) async {
    final rows = await _c
        .rpc<List<dynamic>>('facility_load', params: {'p_club': clubId});
    return rows
        .map((r) => FacilityLoad.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Tesisin önümüzdeki günlerdeki programı.
  Future<List<FacilitySlot>> facilitySchedule(String facilityId,
      {int days = 7}) async {
    final rows = await _c.rpc<List<dynamic>>('facility_schedule',
        params: {'p_facility': facilityId, 'p_days': days});
    return rows
        .map((r) => FacilitySlot.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Haftalık tekrarlayan etkinlik serisi oluşturur; kaç kayıt ürediğini döner.
  ///
  /// [weekdays] ISO gün numaraları: 1 Pazartesi … 7 Pazar.
  Future<int> createEventSeries({
    required String clubId,
    required String title,
    required String kind,
    required DateTime from,
    required DateTime until,
    required int hour,
    required int minute,
    required List<int> weekdays,
    int minutes = 90,
    String? facilityId,
    String? place,
  }) async {
    return await _c.rpc<int>('create_event_series', params: {
      'p_club': clubId,
      'p_title': title.trim(),
      'p_kind': kind,
      'p_from': from.toIso8601String().split('T').first,
      'p_until': until.toIso8601String().split('T').first,
      'p_hour': hour,
      'p_minute': minute,
      'p_minutes': minutes,
      'p_weekdays': weekdays,
      if (facilityId != null) 'p_facility': facilityId,
      if (place != null && place.trim().isNotEmpty) 'p_place': place.trim(),
    });
  }

  /// Tesis veya takım ile çakışan etkinlikler ve tesis rezervasyonları.
  Future<List<FacilitySlot>> conflicts({
    required String facilityId,
    required DateTime start,
    DateTime? end,
    String? excludeEventId,
    String? teamId,
  }) async {
    final rows = await _c.rpc<List<dynamic>>('facility_conflicts', params: {
      'p_facility': facilityId,
      'p_start': start.toUtc().toIso8601String(),
      if (end != null) 'p_end': end.toUtc().toIso8601String(),
      if (excludeEventId != null) 'p_exclude': excludeEventId,
      if (teamId != null) 'p_team': teamId,
    });
    return rows
        .map((r) => FacilitySlot.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Tesis rezervasyonu oluşturur; çakışma kararı sunucuda tekrar doğrulanır.
  Future<String> createFacilityReservation({
    required String clubId,
    required String facilityId,
    required String title,
    String kind = 'rental',
    required DateTime startsAt,
    required DateTime endsAt,
    String? reservedByName,
    String? reservedByPhone,
    double fee = 0,
    String? notes,
    bool allowConflict = false,
  }) async {
    final res = await _c.rpc<dynamic>('create_facility_reservation', params: {
      'p_club': clubId,
      'p_facility': facilityId,
      'p_title': title.trim(),
      'p_kind': kind,
      'p_starts': startsAt.toUtc().toIso8601String(),
      'p_ends': endsAt.toUtc().toIso8601String(),
      'p_by_name': reservedByName?.trim(),
      'p_by_phone': reservedByPhone?.trim(),
      'p_fee': fee,
      'p_allow_conflict': allowConflict,
      if (notes != null && notes.trim().isNotEmpty) 'p_notes': notes.trim(),
    });
    return res.toString();
  }

  Future<void> cancelFacilityReservation(String reservationId) async {
    await _c.rpc<void>('cancel_facility_reservation', params: {
      'p_reservation_id': reservationId,
    });
  }

  Future<List<FacilityReservation>> facilityReservations(
      String facilityId) async {
    final rows = await _c
        .from('facility_reservations')
        .select('*')
        .eq('facility_id', facilityId)
        .order('starts_at', ascending: true);
    return rows.map((r) => FacilityReservation.fromMap(r)).toList();
  }

  /// Dar kapsamlı tesis rezervasyon sütunları.
  /// Kişisel ve hassas verileri (reserved_by_phone, reserved_by_name, fee, notes,
  /// reserved_by_profile_id, created_by) dışarıda tutar.
  static const facilityPublicReservationColumns =
      'id, facility_id, club_id, title, kind, starts_at, ends_at, status';

  /// Dar kapsamlı, PII içermeyen tesis rezervasyonları sorgusu.
  /// Yalnızca id, facility_id, club_id, title, kind, starts_at, ends_at, status çeker.
  Future<List<FacilityReservation>> narrowFacilityReservations(
    String facilityId, {
    int limit = 50,
  }) async {
    final rows = await _c
        .from('facility_reservations')
        .select(facilityPublicReservationColumns)
        .eq('facility_id', facilityId)
        .inFilter('status', const ['pending', 'confirmed'])
        .order('starts_at', ascending: true)
        .limit(limit);
    return rows.map((r) => FacilityReservation.fromMap(r)).toList();
  }

  /// Etkinlik oluşturur. Tesis seçilirse yer adı ondan alınır.
  Future<void> createEvent({
    required String clubId,
    required String title,
    required String kind,
    required DateTime startsAt,
    DateTime? endsAt,
    String? facilityId,
    String? place,
    String? teamId,
  }) async {
    await _c.rpc<void>('create_event', params: {
      'p_club': clubId,
      'p_title': title.trim(),
      'p_kind': kind,
      'p_starts': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'p_ends': endsAt.toUtc().toIso8601String(),
      if (facilityId != null) 'p_facility': facilityId,
      if (place != null && place.trim().isNotEmpty) 'p_place': place.trim(),
      if (teamId != null) 'p_team': teamId,
    });
  }

  // ------------------------------- yoklama ---------------------------------
  Future<List<AttendanceStat>> attendanceSummary(String clubId,
      {int days = 90}) async {
    final rows = await _c.rpc<List<dynamic>>('attendance_summary',
        params: {'p_club': clubId, 'p_days': days});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return AttendanceStat(
        athleteId: m['athlete_id'] as String,
        name: ((m['full_name'] as String?) ?? '').trim(),
        present: (m['present'] as int?) ?? 0,
        absent: (m['absent'] as int?) ?? 0,
        total: (m['total'] as int?) ?? 0,
        rate: (m['rate'] as int?) ?? 0,
      );
    }).toList();
  }

  /// Bugünden sonraki etkinlik sayısı.
  Future<int> upcomingEvents(String clubId) async {
    final rows = await _c
        .from('events')
        .select('id')
        .eq('club_id', clubId)
        .gte('starts_at', DateTime.now().toIso8601String());
    return (rows as List).length;
  }

  Future<int> announcementCount(String clubId) async {
    final rows =
        await _c.from('announcements').select('id').eq('club_id', clubId);
    return (rows as List).length;
  }
}

// =============================== Provider'lar ==============================

final clubOpsServiceProvider = Provider<ClubOpsService>((ref) {
  return ClubOpsService(ref.watch(supabaseClientProvider));
});

final facilitiesProvider =
    FutureProvider.autoDispose<List<FacilityRow>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(clubOpsServiceProvider).facilities(club.id);
});

final injuriesProvider =
    FutureProvider.autoDispose<List<InjuryRow>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(clubOpsServiceProvider).injuries(club.id);
});

final clubDocumentsProvider =
    FutureProvider.autoDispose<List<DocumentRow>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(clubOpsServiceProvider).documents(club.id);
});

final facilityLoadProvider =
    FutureProvider.autoDispose<List<FacilityLoad>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(clubOpsServiceProvider).facilityLoad(club.id);
});

final facilityScheduleProvider = FutureProvider.autoDispose
    .family<List<FacilitySlot>, String>((ref, facilityId) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <FacilitySlot>[]);
  }
  return ref.watch(clubOpsServiceProvider).facilitySchedule(facilityId);
});

final attendanceSummaryProvider =
    FutureProvider.autoDispose<List<AttendanceStat>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(clubOpsServiceProvider).attendanceSummary(club.id);
});

final facilityReservationsProvider = FutureProvider.autoDispose
    .family<List<FacilityReservation>, String>((ref, facilityId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(clubOpsServiceProvider).facilityReservations(facilityId);
});

final narrowFacilityReservationsProvider = FutureProvider.autoDispose
    .family<List<FacilityReservation>, String>((ref, facilityId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref
      .watch(clubOpsServiceProvider)
      .narrowFacilityReservations(facilityId);
});
