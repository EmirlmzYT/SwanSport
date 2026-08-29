import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_athletes.dart';
import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Uygulama geneli Supabase veri katmanı — kimlik + tüm alanlar.
/// Kadro/sporcu için: features/athlete_workspace/data/supabase_athletes.dart
/// ---------------------------------------------------------------------------

// ============================ Kimlik (profil) ==============================
class ProfileInfo {
  const ProfileInfo({required this.id, required this.fullName, this.role});
  final String id;
  final String fullName;
  final String? role;

  String get firstName => fullName.split(' ').first;
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts.last[0] : '';
    return '$a$b'.toUpperCase();
  }
}

final currentProfileProvider = FutureProvider<ProfileInfo?>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return null;
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;
  final row = await client
      .from('profiles')
      .select('id, full_name')
      .eq('id', uid)
      .maybeSingle();
  final club = await ref.watch(activeClubProvider.future);
  if (row == null) return null;
  return ProfileInfo(
    id: row['id'] as String,
    fullName: ((row['full_name'] as String?) ?? '').trim().isEmpty
        ? 'Kullanıcı'
        : row['full_name'] as String,
    role: club?.role,
  );
});

// ============================== Satır modelleri ============================
class AnnouncementRow {
  const AnnouncementRow(
      {required this.title,
      required this.body,
      required this.pinned,
      required this.createdAt});
  final String title;
  final String body;
  final bool pinned;
  final DateTime createdAt;
  factory AnnouncementRow.fromMap(Map<String, dynamic> m) => AnnouncementRow(
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        pinned: (m['pinned'] as bool?) ?? false,
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ??
            DateTime.now(),
      );
}

class EventRow {
  const EventRow(
      {required this.id,
      required this.title,
      required this.place,
      required this.kind,
      required this.startsAt,
      this.endsAt,
      this.opponent,
      this.homeScore,
      this.awayScore});
  final String id;
  final String? opponent;
  final int? homeScore;
  final int? awayScore;

  /// Skor girilmiş mi?
  bool get hasResult => homeScore != null && awayScore != null;
  String get scoreLabel => hasResult ? '$homeScore - $awayScore' : '';
  final String title;
  final String? place;
  final String kind;
  final DateTime startsAt;
  final DateTime? endsAt;
  factory EventRow.fromMap(Map<String, dynamic> m) => EventRow(
        id: (m['id'] as String?) ?? '',
        opponent: m['opponent'] as String?,
        homeScore: m['home_score'] as int?,
        awayScore: m['away_score'] as int?,
        title: (m['title'] as String?) ?? '',
        place: m['place'] as String?,
        kind: (m['kind'] as String?) ?? 'training',
        startsAt:
            DateTime.tryParse('${m['starts_at']}')?.toLocal() ?? DateTime.now(),
        endsAt: m['ends_at'] == null
            ? null
            : DateTime.tryParse('${m['ends_at']}')?.toLocal(),
      );
  String get kindLabel => switch (kind) {
        'match' => 'Maç',
        'meeting' => 'Toplantı',
        'other' => 'Etkinlik',
        _ => 'Antrenman',
      };
}

/// Bir sporcunun etkinlik için verdiği katılım yanıtı.
class EventRsvp {
  const EventRsvp({required this.status, this.note, required this.updatedAt});
  final String status;
  final String? note;
  final DateTime updatedAt;
}

/// Yetkili kulüp personeli için kimlik içermeyen katılım toplamları.
class EventRsvpSummary {
  const EventRsvpSummary({
    required this.attending,
    required this.uncertain,
    required this.unavailable,
  });
  final int attending;
  final int uncertain;
  final int unavailable;
}

class InvoiceRow {
  const InvoiceRow(
      {required this.id,
      required this.label,
      required this.amount,
      required this.status,
      this.athleteName});
  final String id;
  final String label;
  final num amount;
  final String status;
  final String? athleteName;
  bool get isPaid => status == 'paid';
  factory InvoiceRow.fromMap(Map<String, dynamic> m) {
    final ath = m['athletes'];
    String? name;
    if (ath is Map) {
      name = '${ath['first_name'] ?? ''} ${ath['last_name'] ?? ''}'.trim();
    }
    return InvoiceRow(
      id: (m['id'] as String?) ?? '',
      label: (m['label'] as String?) ?? '',
      amount: (m['amount'] as num?) ?? 0,
      status: (m['status'] as String?) ?? 'pending',
      athleteName: (name == null || name.isEmpty) ? null : name,
    );
  }
}

// InjuryRow burada da tanımlıydı; `club_ops_service.dart` içindeki sürümün
// dar bir kopyasıydı (athleteId ve createdAt yoktu). İki dosya ayrı ayrı
// import edildiği sürece çakışma görünmüyordu — veri katmanı tek pakete
// toplanınca ortaya çıktı. Geniş olan tekil kaynak olarak kaldı.

/// Izgaradaki tek bir yoklama hücresi.
class AttendanceMark {
  const AttendanceMark({
    required this.eventId,
    required this.athleteId,
    required this.status,
    required this.takenAt,
  });

  final String eventId;
  final String athleteId;

  /// present | absent | excused (public.attendance_status)
  final String status;
  final DateTime takenAt;

  factory AttendanceMark.fromMap(Map<String, dynamic> m) => AttendanceMark(
        eventId: (m['event_id'] as String?) ?? '',
        athleteId: (m['athlete_id'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'present',
        takenAt:
            DateTime.tryParse('${m['taken_at']}')?.toLocal() ?? DateTime.now(),
      );
}

/// Yoklama hücresindeki bir değişikliğin sunucu tarafındaki denetim kaydı.
///
/// Yalnızca kulüp personeli, `attendance_audit` RPC'si üzerinden okuyabilir.
/// Bu model arayüz bilgisi taşımaz; hem mobil hem konsol aynı kaynağı kullanır.
class AttendanceAuditRow {
  const AttendanceAuditRow({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.athleteId,
    required this.status,
    required this.createdAt,
    this.athleteName,
    this.previousStatus,
    this.actorName,
  });

  final String id;
  final String? eventId;
  final String eventTitle;
  final String? athleteId;
  final String? athleteName;
  final String? previousStatus;
  final String status;
  final String? actorName;
  final DateTime createdAt;

  factory AttendanceAuditRow.fromMap(Map<String, dynamic> map) =>
      AttendanceAuditRow(
        id: (map['id'] as String?) ?? '',
        eventId: map['event_id'] as String?,
        eventTitle: (map['event_title'] as String?) ?? 'Etkinlik',
        athleteId: map['athlete_id'] as String?,
        athleteName: map['athlete_name'] as String?,
        previousStatus: map['previous_status'] as String?,
        status: (map['status'] as String?) ?? 'present',
        actorName: map['actor_name'] as String?,
        createdAt: DateTime.tryParse('${map['created_at']}')?.toLocal() ??
            DateTime.now(),
      );
}

class DocRow {
  const DocRow({required this.name, required this.kind, this.sizeLabel});
  final String name;
  final String kind;
  final String? sizeLabel;
  factory DocRow.fromMap(Map<String, dynamic> m) => DocRow(
        name: (m['name'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? 'file',
        sizeLabel: m['size_label'] as String?,
      );
}

class TeamRow {
  const TeamRow(
      {required this.id, required this.name, this.ageGroup, this.gender});
  final String id;
  final String name;
  final String? ageGroup;
  final String? gender;
  factory TeamRow.fromMap(Map<String, dynamic> m) => TeamRow(
        id: (m['id'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        ageGroup: m['age_group'] as String?,
        gender: m['gender'] as String?,
      );
}

// =============================== Servis ====================================
class ClubDataService {
  ClubDataService(this._c);
  final SupabaseClient _c;

  Future<List<AnnouncementRow>> announcements(String clubId) async {
    final rows = await _c
        .from('announcements')
        .select('title, body, pinned, created_at')
        .eq('club_id', clubId)
        .order('pinned', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => AnnouncementRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addAnnouncement(
      String clubId, String title, String body, bool pinned) async {
    await _c.from('announcements').insert({
      'club_id': clubId,
      'author_id': _c.auth.currentUser?.id,
      'title': title,
      'body': body,
      'pinned': pinned,
    });
  }

  /// Kulübün etkinlikleri.
  ///
  /// [from]/[to] verilmezse hepsi döner — mobil uygulama böyle çağırıyor.
  /// Konsolun takvimi ise yalnızca görünen haftayı/ayı ister.
  Future<List<EventRow>> events(
    String clubId, {
    DateTime? from,
    DateTime? to,
    String? kind,
  }) async {
    var q = _c
        .from('events')
        .select('id, title, place, kind, starts_at, ends_at, '
            'opponent, home_score, away_score')
        .eq('club_id', clubId);

    if (from != null) q = q.gte('starts_at', from.toUtc().toIso8601String());
    if (to != null) q = q.lt('starts_at', to.toUtc().toIso8601String());
    if (kind != null && kind.isNotEmpty) q = q.eq('kind', kind);

    final rows = await q.order('starts_at');
    return (rows as List)
        .map((r) => EventRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Bir tarih aralığındaki tüm yoklama kayıtları.
  ///
  /// Konsolun sporcu × antrenman ızgarasını besler. Izgaranın ekseni tarih
  /// değil **etkinlik**: `attendance` tablosu `(event_id, athlete_id)` üzerinde
  /// tekil, yani bir yoklama her zaman bir antrenmana ait. Serbest tarihe
  /// yazmak aynı gün için ikinci bir kayıt üretirdi.
  Future<List<AttendanceMark>> attendanceMarks(
    String clubId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _c
        .from('attendance')
        .select('event_id, athlete_id, status, taken_at')
        .eq('club_id', clubId)
        .not('event_id', 'is', null)
        .gte('taken_at', from.toUtc().toIso8601String())
        .lt('taken_at', to.toUtc().toIso8601String());
    return (rows as List)
        .map((r) => AttendanceMark.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Tek hücreyi yazar (ızgarada bir tıklama).
  ///
  /// `(event_id, athlete_id)` tekil olduğu için upsert; aynı sporcuyu aynı
  /// antrenmanda ikinci kez işaretlemek yeni satır değil güncelleme olur.
  /// Geçmişe dönük düzeltme de böyle çalışıyor.
  Future<void> markAttendance({
    required String clubId,
    required String eventId,
    required String athleteId,
    required String status,
  }) async {
    await _c.from('attendance').upsert({
      'club_id': clubId,
      'event_id': eventId,
      'athlete_id': athleteId,
      'status': status,
    }, onConflict: 'event_id,athlete_id');
  }

  /// Bir antrenmandaki tüm sporcuları aynı duruma çeker (sütun işaretleme).
  Future<void> markAttendanceBulk({
    required String clubId,
    required String eventId,
    required List<String> athleteIds,
    required String status,
  }) async {
    if (athleteIds.isEmpty) return;
    await _c.from('attendance').upsert([
      for (final id in athleteIds)
        {
          'club_id': clubId,
          'event_id': eventId,
          'athlete_id': id,
          'status': status,
        },
    ], onConflict: 'event_id,athlete_id');
  }

  /// En yeni yoklama değişiklikleri. Yetki kontrolü doğrudan RPC'dedir;
  /// istemcinin görünümü bu kontrolün yerine geçmez.
  Future<List<AttendanceAuditRow>> attendanceAudit(
    String clubId, {
    int limit = 50,
  }) async {
    final rows = await _c.rpc<List<dynamic>>('attendance_audit', params: {
      'p_club': clubId,
      'p_limit': limit,
    });
    return rows
        .map((row) =>
            AttendanceAuditRow.fromMap((row as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addEvent(String clubId, String title, String? place, String kind,
      DateTime startsAt, DateTime? endsAt) async {
    await _c.from('events').insert({
      'club_id': clubId,
      'title': title,
      if (place != null && place.isNotEmpty) 'place': place,
      'kind': kind,
      'starts_at': startsAt.toUtc().toIso8601String(),
      if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
    });
  }

  Future<List<InvoiceRow>> invoices(String clubId) async {
    final rows = await _c
        .from('invoices')
        .select('id, label, amount, status, '
            'athletes(first_name, last_name)')
        .eq('club_id', clubId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => InvoiceRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<DocRow>> documents(String clubId) async {
    final rows = await _c
        .from('documents')
        .select('name, kind, size_label')
        .eq('club_id', clubId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => DocRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<TeamRow>> teams(String clubId) async {
    final rows = await _c
        .from('teams')
        .select('id, name, age_group, gender')
        .eq('club_id', clubId)
        .order('name');
    return (rows as List)
        .map((r) => TeamRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  // --------------------------- kayıt oluşturma ---------------------------

  /// Yeni tesis ekler.
  /// Sakatlık/sağlık kaydı ekler.
  Future<void> addInjury(String clubId, String athleteId, String status,
      {String? note}) async {
    await _c.from('injuries').insert({
      'club_id': clubId,
      'athlete_id': athleteId,
      'status': status,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  /// Aidat/fatura oluşturur. [amount] TL cinsinden.
  Future<void> addInvoice(String clubId, String label, num amount,
      {String? athleteId, String status = 'pending'}) async {
    await _c.from('invoices').insert({
      'club_id': clubId,
      'label': label,
      'amount': amount,
      'status': status,
      if (athleteId != null) 'athlete_id': athleteId,
    });
  }

  /// Yeni takım kurar.
  Future<void> addTeam(String clubId, String name,
      {String? ageGroup, String? gender}) async {
    await _c.from('teams').insert({
      'club_id': clubId,
      'name': name,
      if (ageGroup != null && ageGroup.isNotEmpty) 'age_group': ageGroup,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
    });
  }

  /// Belge kaydı ekler (dosya zaten Storage'a yüklenmiş olmalı).
  Future<void> addDocument(String clubId, String name, String kind,
      {String? sizeLabel}) async {
    await _c.from('documents').insert({
      'club_id': clubId,
      'name': name,
      'kind': kind,
      if (sizeLabel != null && sizeLabel.isNotEmpty) 'size_label': sizeLabel,
    });
  }

  // --------------------------- kayıt güncelleme --------------------------

  /// Faturanın durumunu değiştirir (ödendi / bekliyor / gecikti).
  Future<void> setInvoiceStatus(String invoiceId, String status) async {
    await _c.from('invoices').update({'status': status}).eq('id', invoiceId);
  }

  /// Sakatlık kaydının durumunu günceller.
  Future<void> setInjuryStatus(String injuryId, String status) async {
    await _c.from('injuries').update({'status': status}).eq('id', injuryId);
  }

  /// Maç sonucunu kaydeder.
  Future<void> setEventResult(
    String eventId, {
    String? opponent,
    int? homeScore,
    int? awayScore,
    String? note,
  }) async {
    await _c.from('events').update({
      if (opponent != null && opponent.isNotEmpty) 'opponent': opponent,
      if (homeScore != null) 'home_score': homeScore,
      if (awayScore != null) 'away_score': awayScore,
      if (note != null && note.isNotEmpty) 'result_note': note,
    }).eq('id', eventId);
  }

  Future<void> setEventRsvp(String eventId, String status, {String? note}) =>
      _c.rpc<void>('set_event_rsvp', params: {
        'p_event': eventId,
        'p_status': status,
        'p_note': note,
      });

  Future<EventRsvp?> myEventRsvp(String eventId) async {
    final rows = await _c.rpc<List<dynamic>>('my_event_rsvp', params: {
      'p_event': eventId,
    });
    if (rows.isEmpty) return null;
    final row = (rows.first as Map).cast<String, dynamic>();
    return EventRsvp(
      status: row['status'] as String,
      note: row['note'] as String?,
      updatedAt: DateTime.tryParse('${row['updated_at']}')?.toLocal() ??
          DateTime.now(),
    );
  }

  Future<EventRsvpSummary> eventRsvpSummary(String eventId) async {
    final rows = await _c.rpc<List<dynamic>>('event_rsvp_summary', params: {
      'p_event': eventId,
    });
    final row = rows.isEmpty
        ? const <String, dynamic>{}
        : (rows.first as Map).cast<String, dynamic>();
    return EventRsvpSummary(
      attending: (row['attending'] as num?)?.toInt() ?? 0,
      uncertain: (row['uncertain'] as num?)?.toInt() ?? 0,
      unavailable: (row['unavailable'] as num?)?.toInt() ?? 0,
    );
  }

  // ----------------------------- takım kadrosu ---------------------------

  /// Takımdaki sporcular.
  Future<List<({String id, String athleteId, String name, String? jersey})>>
      teamRoster(String teamId) async {
    final rows = await _c
        .from('team_memberships')
        .select('id, athlete_id, jersey_number, '
            'athletes(first_name, last_name)')
        .eq('team_id', teamId);
    return (rows as List).map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final a = m['athletes'];
      final first = a is Map ? (a['first_name'] as String?) ?? '' : '';
      final last = a is Map ? (a['last_name'] as String?) ?? '' : '';
      return (
        id: m['id'] as String,
        athleteId: m['athlete_id'] as String,
        name: '$first $last'.trim(),
        jersey: m['jersey_number'] as String?,
      );
    }).toList();
  }

  Future<void> addToTeam(String teamId, String athleteId,
      {String? jersey}) async {
    await _c.from('team_memberships').insert({
      'team_id': teamId,
      'athlete_id': athleteId,
      if (jersey != null && jersey.isNotEmpty) 'jersey_number': jersey,
    });
  }

  Future<void> removeFromTeam(String membershipId) async {
    await _c.from('team_memberships').delete().eq('id', membershipId);
  }

  // ------------------------------ yoklama --------------------------------

  // attendanceSummary burada değil — `club_ops_service.dart` içinde. İkisi de
  // aynı `attendance_summary` RPC'sini çağırıyordu; farkları yalnızca dönüş
  // tipiydi (record vs. AttendanceStat). Alanları birebir aynı olduğu için
  // sınıf olan sürüm tutuldu; `reports_screen.dart` zaten onu bekliyordu.

  // ---------------------------- kulüp profili ----------------------------

  Future<void> updateClubProfile(String clubId,
      {String? bio, String? logoPath, String? city}) async {
    await _c.rpc<void>('update_club_profile', params: {
      'p_club': clubId,
      if (bio != null) 'p_bio': bio,
      if (logoPath != null) 'p_logo': logoPath,
      if (city != null) 'p_city': city,
    });
  }

  /// Yoklamayı kaydeder (event_id opsiyonel; her sporcu için durum).
  Future<void> saveAttendance(
      String clubId, Map<String, String> athleteStatus) async {
    final rows = athleteStatus.entries
        .map((e) => {
              'club_id': clubId,
              'athlete_id': e.key,
              'status': e.value,
              'taken_at': DateTime.now().toUtc().toIso8601String(),
            })
        .toList();
    if (rows.isEmpty) return;
    await _c.from('attendance').insert(rows);
  }
}

// =============================== Provider'lar ==============================
final clubDataServiceProvider = Provider<ClubDataService>((ref) {
  return ClubDataService(ref.watch(supabaseClientProvider));
});

Future<T> _forClub<T>(Ref ref,
    Future<T> Function(ClubDataService s, String clubId) run, T empty) async {
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return empty;
  return run(ref.watch(clubDataServiceProvider), club.id);
}

final announcementsProvider = FutureProvider.autoDispose<List<AnnouncementRow>>(
    (ref) => _forClub(ref, (s, id) => s.announcements(id), const []));

final eventsProvider = FutureProvider.autoDispose<List<EventRow>>(
    (ref) => _forClub(ref, (s, id) => s.events(id), const []));

final myEventRsvpProvider =
    FutureProvider.autoDispose.family<EventRsvp?, String>((ref, eventId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return null;
  return ref.watch(clubDataServiceProvider).myEventRsvp(eventId);
});

final eventRsvpSummaryProvider = FutureProvider.autoDispose
    .family<EventRsvpSummary, String>((ref, eventId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return const EventRsvpSummary(attending: 0, uncertain: 0, unavailable: 0);
  }
  return ref.watch(clubDataServiceProvider).eventRsvpSummary(eventId);
});

final invoicesProvider = FutureProvider.autoDispose<List<InvoiceRow>>(
    (ref) => _forClub(ref, (s, id) => s.invoices(id), const []));

// injuriesProvider burada değil — `club_ops_service.dart` içinde. Orada da
// aynısı tanımlıydı; ikisi aynı sorguyu yapıyordu. Sakatlık yazma işlemleri
// (addInjury/updateInjury/removeInjury) zaten ClubOpsService'te olduğu için
// okuma da orada kaldı.

final documentsProvider = FutureProvider.autoDispose<List<DocRow>>(
    (ref) => _forClub(ref, (s, id) => s.documents(id), const []));

final teamsProvider = FutureProvider.autoDispose<List<TeamRow>>(
    (ref) => _forClub(ref, (s, id) => s.teams(id), const []));

/// Bir takımın kadrosu.
final teamRosterProvider = FutureProvider.autoDispose.family<
    List<({String id, String athleteId, String name, String? jersey})>,
    String>((ref, teamId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(clubDataServiceProvider).teamRoster(teamId);
});
