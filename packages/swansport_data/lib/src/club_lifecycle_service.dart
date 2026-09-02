import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'club_data.dart';
import 'supabase_athletes.dart';
import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Kulüp yaşam döngüsü: uygunluk kilidi, sağlık kısıtı, idempotent yoklama,
/// destek merkezi ve operasyon riski.
///
/// EN ÖNEMLİ SÖZLEŞME: **sağlık kısıtını arayüzden kaldırmanın yolu yok.**
/// Burada `clearRestriction` var ama sunucu yalnızca yetkili sağlık
/// görevlisinden kabul ediyor; kulüp yöneticisi çağırırsa hata alıyor. Bu
/// istemci kısıtı değil — düğmeyi gizlemek koruma olmaz.
/// ---------------------------------------------------------------------------

/// Sporcunun sahaya çıkma durumu.
class Eligibility {
  const Eligibility({
    required this.blocked,
    required this.status,
    required this.reasonCode,
    required this.reasonLabel,
  });

  const Eligibility.unknown()
      : blocked = false,
        status = 'eligible',
        reasonCode = 'ok',
        reasonLabel = 'Uygun';

  /// **Yalnızca kesin engelde** true. İdari eksik (inceleme sürüyor) bunu
  /// true yapmıyor — ikisini aynı bayrağa toplamak, idari bir eksiği tıbbi
  /// bir engel gibi gösterirdi.
  final bool blocked;

  /// eligible | restricted | awaiting_verification
  final String status;
  final String reasonCode;
  final String reasonLabel;

  bool get isEligible => status == 'eligible';
  bool get awaitingVerification => status == 'awaiting_verification';

  /// Erişilebilirlik: renk tek başına bilgi taşımasın diye metin etiketi.
  String get badgeLabel => switch (status) {
        'restricted' => 'Kısıtlı',
        'awaiting_verification' => 'Onay bekliyor',
        _ => 'Uygun',
      };

  factory Eligibility.fromMap(Map<String, dynamic> m) => Eligibility(
        blocked: (m['blocked'] as bool?) ?? false,
        status: (m['status'] as String?) ?? 'eligible',
        reasonCode: (m['reason_code'] as String?) ?? 'ok',
        reasonLabel: (m['reason_label'] as String?) ?? 'Uygun',
      );
}

/// Uygunluk tablosunun bir satırı. Yönetici görünümü — **teşhis yok**.
class EligibilityRow {
  const EligibilityRow({
    required this.athleteId,
    required this.athleteRef,
    required this.status,
    required this.reasonLabel,
  });

  final String athleteId;
  final String athleteRef;
  final String status;
  final String reasonLabel;

  bool get isRestricted => status == 'restricted';

  factory EligibilityRow.fromMap(Map<String, dynamic> m) => EligibilityRow(
        athleteId: (m['athlete_id'] as String?) ?? '',
        athleteRef: (m['athlete_ref'] as String?) ?? '—',
        status: (m['status'] as String?) ?? 'eligible',
        reasonLabel: (m['reason_label'] as String?) ?? '',
      );
}

/// Sağlık kısıtı kaydı.
///
/// **Teşhis, rapor metni ve doktor notu bu tipte YOK** — sunucuda da yok.
/// Yalnızca durum, tarihler ve bir belge referansı var.
class HealthRestriction {
  const HealthRestriction({
    required this.id,
    required this.athleteId,
    required this.status,
    required this.startDate,
    this.reevaluationDate,
    this.endDate,
    this.evidenceRef,
  });

  final String id;
  final String athleteId;

  /// restricted | under_review | cleared
  final String status;
  final DateTime startDate;
  final DateTime? reevaluationDate;
  final DateTime? endDate;
  final String? evidenceRef;

  bool get isActive => status == 'restricted' || status == 'under_review';

  String get statusLabel => switch (status) {
        'restricted' => 'Kısıtlı',
        'under_review' => 'İncelemede',
        'cleared' => 'Kaldırıldı',
        _ => status,
      };

  factory HealthRestriction.fromMap(Map<String, dynamic> m) =>
      HealthRestriction(
        id: m['id'] as String,
        athleteId: (m['athlete_id'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'under_review',
        startDate: DateTime.tryParse('${m['start_date']}') ?? DateTime.now(),
        reevaluationDate: m['reevaluation_date'] == null
            ? null
            : DateTime.tryParse('${m['reevaluation_date']}'),
        endDate: m['end_date'] == null
            ? null
            : DateTime.tryParse('${m['end_date']}'),
        evidenceRef: m['evidence_ref'] as String?,
      );
}

/// Yoklama yazma sonucu.
///
/// [conflicts] boş değilse **hiçbiri sessizce çözülmedi**: her biri
/// antrenöre gösterilmeli. Tasarımın tamamının sebebi bu.
class AttendanceOpResult {
  const AttendanceOpResult({
    required this.applied,
    required this.conflicts,
    required this.replayed,
  });

  final int applied;
  final List<AttendanceConflict> conflicts;

  /// true ise bu işlem daha önce işlenmişti; sonuç önbellekten geldi.
  final bool replayed;

  bool get hasConflicts => conflicts.isNotEmpty;

  factory AttendanceOpResult.fromMap(Map<String, dynamic> m) =>
      AttendanceOpResult(
        applied: (m['applied'] as num?)?.toInt() ?? 0,
        replayed: (m['replayed'] as bool?) ?? false,
        conflicts: ((m['conflicts'] as List?) ?? const [])
            .map((e) =>
                AttendanceConflict.fromMap((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Tek bir çakışma. İstemci bunu "sen X dedin, şu an Y yazıyor" diye
/// gösteriyor ve kararı antrenöre bırakıyor.
class AttendanceConflict {
  const AttendanceConflict({
    required this.athleteId,
    required this.reason,
    this.sentStatus,
    this.currentStatus,
    this.sentVersion,
    this.currentVersion,
  });

  final String athleteId;

  /// version_mismatch | deleted
  final String reason;
  final String? sentStatus;
  final String? currentStatus;
  final int? sentVersion;
  final int? currentVersion;

  bool get wasDeleted => reason == 'deleted';

  factory AttendanceConflict.fromMap(Map<String, dynamic> m) =>
      AttendanceConflict(
        athleteId: (m['athlete_id'] as String?) ?? '',
        reason: (m['reason'] as String?) ?? 'version_mismatch',
        sentStatus: m['sent_status'] as String?,
        currentStatus: m['current_status'] as String?,
        sentVersion: (m['sent_version'] as num?)?.toInt(),
        currentVersion: (m['current_version'] as num?)?.toInt(),
      );
}

/// Operasyon riski gerekçesi.
///
/// Tek bir puan değil, **liste**. "Risk: 72" kimseye ne yapacağını söylemiyor;
/// "4 hesapsız mali hareket var" söylüyor.
class RiskReason {
  const RiskReason({
    required this.code,
    required this.label,
    required this.severity,
    required this.qty,
    required this.route,
  });

  final String code;
  final String label;

  /// kritik | dikkat | dusuk
  final String severity;
  final int qty;
  final String route;

  bool get isCritical => severity == 'kritik' && qty > 0;
  bool get isActive => qty > 0;

  /// Erişilebilirlik: seviye metin olarak da veriliyor, renkle sınırlı değil.
  String get severityLabel => switch (severity) {
        'kritik' => 'Kritik risk',
        'dikkat' => 'Dikkat gerekli',
        _ => 'Düşük risk',
      };

  factory RiskReason.fromMap(Map<String, dynamic> m) => RiskReason(
        code: (m['code'] as String?) ?? '',
        label: (m['label'] as String?) ?? '',
        severity: (m['severity'] as String?) ?? 'dusuk',
        qty: (m['qty'] as num?)?.toInt() ?? 0,
        route: (m['route'] as String?) ?? '/',
      );
}

/// Kulübün genel risk durumu — gerekçelerden türetiliyor.
class OperationalRisk {
  const OperationalRisk(this.reasons);

  final List<RiskReason> reasons;

  List<RiskReason> get active =>
      reasons.where((r) => r.isActive).toList();

  int get criticalCount => reasons.where((r) => r.isCritical).length;

  /// kritik > dikkat > dusuk
  String get level {
    if (reasons.any((r) => r.isCritical)) return 'kritik';
    if (reasons.any((r) => r.isActive && r.severity == 'dikkat')) {
      return 'dikkat';
    }
    return 'dusuk';
  }

  String get levelLabel => switch (level) {
        'kritik' => 'Kritik risk',
        'dikkat' => 'Dikkat gerekli',
        _ => 'Düşük risk',
      };
}

/// Destek talebi.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.createdAt,
    this.body,
  });

  final String id;
  final String subject;
  final String? body;

  /// new | under_review | awaiting_user_response | resolved | closed
  final String status;
  final DateTime createdAt;

  String get statusLabel => switch (status) {
        'new' => 'Yeni',
        'under_review' => 'İnceleniyor',
        'awaiting_user_response' => 'Yanıtın bekleniyor',
        'resolved' => 'Çözüldü',
        'closed' => 'Kapandı',
        _ => status,
      };

  bool get isOpen => status != 'resolved' && status != 'closed';

  factory SupportTicket.fromMap(Map<String, dynamic> m) => SupportTicket(
        id: m['id'] as String,
        subject: (m['subject'] as String?) ?? '',
        body: m['body'] as String?,
        status: (m['status'] as String?) ?? 'new',
        createdAt: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
      );
}

// ================================= Servis ==================================

class ClubLifecycleService {
  ClubLifecycleService(this._c);

  final SupabaseClient _c;

  // ------------------------------------------------------------- uygunluk
  Future<Eligibility> eligibility(String athleteId) async {
    final rows = await _c
        .rpc<List<dynamic>>('eligibility_gate', params: {'p_athlete': athleteId});
    if (rows.isEmpty) return const Eligibility.unknown();
    return Eligibility.fromMap((rows.first as Map).cast<String, dynamic>());
  }

  Future<List<EligibilityRow>> eligibilityBoard(String clubId) async {
    final rows = await _c.rpc<List<dynamic>>('club_eligibility_board',
        params: {'p_club': clubId});
    return rows
        .map((e) => EligibilityRow.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // --------------------------------------------------------------- sağlık
  Future<List<HealthRestriction>> restrictions(String athleteId) async {
    final rows = await _c
        .from('health_restrictions')
        .select()
        .eq('athlete_id', athleteId)
        .order('start_date', ascending: false);
    return rows
        .map((e) =>
            HealthRestriction.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// İnceleme talebi açar. `restricted` yalnızca sağlık görevlisinden kabul
  /// ediliyor; antrenör `under_review` açabiliyor.
  Future<String> openRestriction(String athleteId,
          {String status = 'under_review',
          DateTime? reevaluation,
          String? evidenceRef}) =>
      _c.rpc<String>('open_health_restriction', params: {
        'p_athlete': athleteId,
        'p_status': status,
        'p_reevaluation': reevaluation?.toIso8601String(),
        'p_evidence': evidenceRef,
      });

  /// Kısıtı kaldırır.
  ///
  /// **Sunucu yalnızca yetkili sağlık görevlisinden kabul ediyor.** Kulüp
  /// yöneticisi ya da platform yöneticisi çağırırsa hata alıyor; bu metodun
  /// varlığı bir yetki değil, yalnızca bir çağrı sarmalayıcısı.
  Future<void> clearRestriction(String restrictionId, String note) =>
      _c.rpc<void>('clear_health_restriction',
          params: {'p_restriction': restrictionId, 'p_note': note});

  Future<void> setHealthOfficer(String clubId, String profileId, bool grant,
          {String? note}) =>
      _c.rpc<void>('set_health_officer', params: {
        'p_club': clubId,
        'p_profile': profileId,
        'p_grant': grant,
        'p_note': note,
      });

  // -------------------------------------------------------------- yoklama
  Future<List<RosterEntry>> roster(String eventId) async {
    final rows = await _c.rpc<List<dynamic>>('event_roster_versioned',
        params: {'p_event': eventId});
    return rows
        .map((e) =>
            RosterEntry.fromVersionedMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Yoklamayı yazar.
  ///
  /// [opId] işlem başına bir kez üretilir ve tekrar denemede **aynı kalır**.
  /// [marks] her biri `athlete_id`, `status` ve okunan `version` taşır.
  Future<AttendanceOpResult> saveAttendance({
    required String eventId,
    required String opId,
    required List<Map<String, dynamic>> marks,
  }) async {
    final res = await _c.rpc<dynamic>('save_attendance_ops', params: {
      'p_event': eventId,
      'p_op_id': opId,
      'p_marks': marks,
    });
    return AttendanceOpResult.fromMap((res as Map).cast<String, dynamic>());
  }

  // ----------------------------------------------------------------- risk
  Future<OperationalRisk> risk(String clubId) async {
    final rows = await _c
        .rpc<List<dynamic>>('club_operational_risk', params: {'p_club': clubId});
    return OperationalRisk(rows
        .map((e) => RiskReason.fromMap((e as Map).cast<String, dynamic>()))
        .toList());
  }

  // ---------------------------------------------------------------- destek
  /// Destek talebi açar.
  ///
  /// [context] otomatik toplanan bağlam (ekran adı, sürüm). Sunucu bunu
  /// **ayrıca** ayıklıyor: istemcinin temizlemesine güvenmek, eski bir
  /// uygulama sürümünün ham veri göndermesini engellemiyor.
  Future<String> openTicket({
    required String subject,
    required String body,
    Map<String, dynamic> context = const {},
    String? clubId,
  }) =>
      _c.rpc<String>('open_support_ticket', params: {
        'p_subject': subject,
        'p_body': body,
        'p_context': context,
        'p_club': clubId,
      });

  Future<List<SupportTicket>> myTickets() async {
    final rows = await _c
        .from('support_tickets')
        .select('id, subject, body, status, created_at')
        .order('created_at', ascending: false)
        .limit(50);
    return rows
        .map((e) => SupportTicket.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

// =============================== Provider'lar ==============================

final clubLifecycleServiceProvider = Provider<ClubLifecycleService>((ref) {
  return ClubLifecycleService(ref.watch(supabaseClientProvider));
});

final eligibilityProvider = FutureProvider.autoDispose
    .family<Eligibility, String>((ref, athleteId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return const Eligibility.unknown();
  }
  return ref.watch(clubLifecycleServiceProvider).eligibility(athleteId);
});

final eligibilityBoardProvider =
    FutureProvider.autoDispose<List<EligibilityRow>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(clubLifecycleServiceProvider).eligibilityBoard(club.id);
});

final operationalRiskProvider =
    FutureProvider.autoDispose<OperationalRisk>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return const OperationalRisk([]);
  }
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const OperationalRisk([]);
  return ref.watch(clubLifecycleServiceProvider).risk(club.id);
});

final versionedRosterProvider = FutureProvider.autoDispose
    .family<List<RosterEntry>, String>((ref, eventId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(clubLifecycleServiceProvider).roster(eventId);
});

final myTicketsProvider =
    FutureProvider.autoDispose<List<SupportTicket>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(clubLifecycleServiceProvider).myTickets();
});
