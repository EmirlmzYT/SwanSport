import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_branch_engine/swansport_branch_engine.dart';

import 'athlete_profile_service.dart';
import 'club_data.dart';
import 'supabase_athletes.dart';
import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Branşa özel antrenman oturumları (0071–0073).
///
/// Bu katman **yalnızca** veri: model, sorgu, RPC sarmalayıcısı ve sağlayıcı.
/// `Widget`, `Color`, `IconData` ya da tema yok. Aşama makinesi ve skor
/// kuralları `swansport_branch_engine`'de — ikisi de Flutter'sız test
/// edilebiliyor.
///
/// SPORCU KİMLİĞİ HER YERDE `athletes.id`. `profiles.id` değil: küçük yaştaki
/// sporcuların giriş profili olmayabiliyor. Profil → sporcu köprüsü zaten var
/// (`athleteByProfileProvider`), yeniden yazılmadı.
///
/// KİŞİSEL OTURUM ANTRENÖRE GÖRÜNMÜYOR. Bu servis onu ayrıca gizlemiyor;
/// gizleyen RLS (0071). Burada saklamak "gerçek güvenlik" olmazdı.
/// ---------------------------------------------------------------------------

// ================================ Modeller =================================

/// Antrenman şablonu. Sürümlü ve yerinde değişmez — düzenleme yeni satır
/// yazıyor, geçmiş oturumların anlamı değişmiyor.
class TrainingProtocol {
  const TrainingProtocol({
    required this.id,
    required this.name,
    required this.sportCode,
    required this.version,
    required this.config,
    this.clubId,
    this.description,
    this.published = false,
  });

  factory TrainingProtocol.fromMap(Map<String, dynamic> m) => TrainingProtocol(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        sportCode: (m['sport_code'] as String?) ?? '',
        version: (m['version'] as num?)?.toInt() ?? 1,
        config: TrainingProtocolConfig.fromMap(
            (m['config'] as Map?)?.cast<String, Object?>() ?? const {}),
        clubId: m['club_id'] as String?,
        description: m['description'] as String?,
        published: (m['published'] as bool?) ?? false,
      );

  final String id;
  final String name;
  final String sportCode;
  final int version;
  final TrainingProtocolConfig config;

  /// `null` ise platform şablonu — her kulüp kullanabiliyor.
  final String? clubId;
  final String? description;
  final bool published;

  bool get isPlatformTemplate => clubId == null;

  /// Sürüm 1'den sonrası "v3" diye gösteriliyor; ilk sürümde etiket gürültü.
  String? get versionLabel => version > 1 ? 'v$version' : null;

  /// Branş kelimeleri — okçulukta "ok", başka branşta başka.
  BranchDefinitionContract? get branch => branchByCode(sportCode);
}

/// Canlı ya da geçmiş bir oturum.
class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.clubId,
    required this.kind,
    required this.status,
    required this.phase,
    required this.currentSet,
    required this.setCount,
    required this.rhythm,
    required this.protocolName,
    this.phaseEndsAt,
    this.paused = false,
    this.joinCode,
    this.athleteId,
    this.eventId,
  });

  factory TrainingSession.fromMap(Map<String, dynamic> m) => TrainingSession(
        id: (m['session_id'] ?? m['id']) as String,
        clubId: (m['club_id'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? 'club',
        status: (m['status'] as String?) ?? 'live',
        phase: SessionPhase.parse(m['current_phase'] as String?),
        currentSet: (m['current_set'] as num?)?.toInt() ?? 1,
        setCount: (m['set_count'] as num?)?.toInt() ?? 1,
        rhythm: SessionRhythm.parse(m['rhythm'] as String?),
        protocolName: (m['protocol_name'] as String?) ?? 'Antrenman',
        phaseEndsAt: _time(m['phase_ends_at']),
        paused: (m['paused'] as bool?) ?? false,
        joinCode: m['join_code'] as String?,
        athleteId: m['athlete_id'] as String?,
        eventId: m['event_id'] as String?,
      );

  final String id;
  final String clubId;

  /// `club` | `personal`
  final String kind;

  /// `live` | `review` | `completed` | `cancelled`
  final String status;
  final SessionPhase phase;
  final int currentSet;
  final int setCount;
  final SessionRhythm rhythm;
  final String protocolName;
  final DateTime? phaseEndsAt;
  final bool paused;
  final String? joinCode;
  final String? athleteId;
  final String? eventId;

  bool get isPersonal => kind == 'personal';
  bool get isLive => status == 'live';

  /// Antrenör onayı bekliyor mu — oturum bitti ama kilitlenmedi.
  bool get awaitingApproval => status == 'review';

  String get statusLabel => switch (status) {
        'live' => 'Canlı',
        'review' => 'Onay bekliyor',
        'completed' => 'Tamamlandı',
        _ => 'İptal edildi',
      };

  /// Kalan süre. Duraklatılmışsa donuyor, süresiz aşamada `null`.
  Duration? remainingAt(DateTime now) => remaining(
        endsAt: phaseEndsAt,
        now: now,
        pausedAt: paused ? phaseEndsAt : null,
      );

  /// Süre doldu mu. Dolduğunda sistem **kendiliğinden ilerlemiyor**.
  bool expiredAt(DateTime now) =>
      !paused && phaseExpired(endsAt: phaseEndsAt, now: now);
}

/// Sporcunun bir setteki sonucu.
class TrainingSet {
  const TrainingSet({
    required this.id,
    required this.setNo,
    this.totalScore,
    this.unitCount,
    this.locked = false,
    this.entries = const [],
  });

  factory TrainingSet.fromMap(Map<String, dynamic> m) => TrainingSet(
        id: m['id'] as String,
        setNo: (m['set_no'] as num?)?.toInt() ?? 1,
        totalScore: (m['total_score'] as num?)?.toDouble(),
        unitCount: (m['unit_count'] as num?)?.toInt(),
        locked: m['locked_at'] != null,
        entries: [
          for (final e in (m['training_set_entries'] as List? ?? const []))
            (e as Map)['score'] as num?,
        ],
      );

  final String id;
  final int setNo;

  /// `null` = **eksik sonuç**, sıfır değil.
  final double? totalScore;
  final int? unitCount;
  final bool locked;
  final List<num?> entries;

  bool get isMissing => isSetMissing(totalScore);
}

/// Antrenör sonuç ekranındaki bir sporcu satırı.
///
/// Sütun adları `session_summary` (0072) ile **birebir**. Eskiden bir RPC 8
/// sütun döndürürken Dart 10 alan okuyordu ve `??` yedekleri farkı gizledi;
/// o yüzden burada yedek yok, alanlar testte tek tek doğrulanıyor.
class SessionSummaryRow {
  const SessionSummaryRow({
    required this.athleteId,
    required this.athleteName,
    required this.setsDone,
    required this.setsExpected,
    required this.missingSets,
    required this.unitsRecorded,
    required this.unitsExpected,
    required this.progression,
    required this.locked,
    required this.reviewFlags,
    this.lane,
    this.totalScore,
    this.avgSet,
    this.bestSet,
    this.scoreBuckets = const {},
    this.rpe,
  });

  factory SessionSummaryRow.fromMap(Map<String, dynamic> m) =>
      SessionSummaryRow(
        athleteId: m['athlete_id'] as String,
        athleteName: (m['athlete_name'] as String?) ?? '',
        setsDone: (m['sets_done'] as num?)?.toInt() ?? 0,
        setsExpected: (m['sets_expected'] as num?)?.toInt() ?? 0,
        missingSets: (m['missing_sets'] as num?)?.toInt() ?? 0,
        unitsRecorded: (m['units_recorded'] as num?)?.toInt() ?? 0,
        unitsExpected: (m['units_expected'] as num?)?.toInt() ?? 0,
        progression: [
          for (final v in (m['progression'] as List? ?? const []))
            (v as num?)?.toDouble(),
        ],
        locked: (m['locked'] as bool?) ?? false,
        reviewFlags: [
          for (final f in (m['review_flags'] as List? ?? const [])) f as String,
        ],
        lane: (m['lane'] as num?)?.toInt(),
        totalScore: (m['total_score'] as num?)?.toDouble(),
        avgSet: (m['avg_set'] as num?)?.toDouble(),
        bestSet: (m['best_set'] as num?)?.toDouble(),
        scoreBuckets: {
          for (final e in ((m['score_buckets'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
        rpe: (m['rpe'] as num?)?.toInt(),
      );

  final String athleteId;
  final String athleteName;
  final int setsDone;
  final int setsExpected;
  final int missingSets;
  final int unitsRecorded;
  final int unitsExpected;

  /// Set ilerleyişi: `46 → 51 → 49 → 54`. `null` üye = girilmemiş set.
  final List<double?> progression;
  final bool locked;

  /// Antrenör inceleme uyarıları. Hepsi "bak" demek, "yanlış" demek değil.
  final List<String> reviewFlags;
  final int? lane;
  final double? totalScore;
  final double? avgSet;
  final double? bestSet;

  /// `{"10": 4, "9": 7}` — yalnızca detaylı girişte dolu.
  final Map<String, int> scoreBuckets;
  final int? rpe;

  bool get hasScore => setsDone > 0;
  bool get needsReview => reviewFlags.isNotEmpty;

  String flagLabel(String flag) => switch (flag) {
        'skor_yok' => 'Skor girmemiş',
        'eksik_set' => 'Eksik set var',
        'az_atis' => 'Hedefin yarısından az atış',
        'son_sette_dusus' => 'Son sette belirgin düşüş',
        _ => flag,
      };
}

/// Oturumun toplu özeti. `session_overview` (0072) ile birebir.
class SessionOverview {
  const SessionOverview({
    required this.joinedCount,
    required this.completedCount,
    required this.noScoreCount,
    required this.awaitingLock,
    required this.unitsRecorded,
    required this.unitsExpected,
    required this.protocolName,
    required this.protocolVersion,
    required this.setCount,
    required this.status,
    this.teamTotal,
    this.sessionAvg,
  });

  factory SessionOverview.fromMap(Map<String, dynamic> m) => SessionOverview(
        joinedCount: (m['joined_count'] as num?)?.toInt() ?? 0,
        completedCount: (m['completed_count'] as num?)?.toInt() ?? 0,
        noScoreCount: (m['no_score_count'] as num?)?.toInt() ?? 0,
        awaitingLock: (m['awaiting_lock'] as num?)?.toInt() ?? 0,
        unitsRecorded: (m['units_recorded'] as num?)?.toInt() ?? 0,
        unitsExpected: (m['units_expected'] as num?)?.toInt() ?? 0,
        protocolName: (m['protocol_name'] as String?) ?? '',
        protocolVersion: (m['protocol_version'] as num?)?.toInt() ?? 1,
        setCount: (m['set_count'] as num?)?.toInt() ?? 0,
        status: (m['status'] as String?) ?? 'live',
        teamTotal: (m['team_total'] as num?)?.toDouble(),
        sessionAvg: (m['session_avg'] as num?)?.toDouble(),
      );

  final int joinedCount;
  final int completedCount;
  final int noScoreCount;
  final int awaitingLock;
  final int unitsRecorded;
  final int unitsExpected;
  final String protocolName;
  final int protocolVersion;
  final int setCount;
  final String status;
  final double? teamTotal;
  final double? sessionAvg;
}

/// Sporcunun geçmişindeki bir satır.
class TrainingHistoryEntry {
  const TrainingHistoryEntry({
    required this.sessionId,
    required this.kind,
    required this.protocolName,
    required this.sportCode,
    required this.startedAt,
    required this.status,
    required this.setsDone,
    required this.setCount,
    this.totalScore,
    this.bestSet,
    this.avgSet,
    this.rpe,
  });

  factory TrainingHistoryEntry.fromMap(Map<String, dynamic> m) =>
      TrainingHistoryEntry(
        sessionId: m['session_id'] as String,
        kind: (m['kind'] as String?) ?? 'club',
        protocolName: (m['protocol_name'] as String?) ?? '',
        sportCode: (m['sport_code'] as String?) ?? '',
        startedAt: _time(m['started_at']) ?? DateTime.now(),
        status: (m['status'] as String?) ?? 'completed',
        setsDone: (m['sets_done'] as num?)?.toInt() ?? 0,
        setCount: (m['set_count'] as num?)?.toInt() ?? 0,
        totalScore: (m['total_score'] as num?)?.toDouble(),
        bestSet: (m['best_set'] as num?)?.toDouble(),
        avgSet: (m['avg_set'] as num?)?.toDouble(),
        rpe: (m['rpe'] as num?)?.toInt(),
      );

  final String sessionId;
  final String kind;
  final String protocolName;
  final String sportCode;
  final DateTime startedAt;
  final String status;
  final int setsDone;
  final int setCount;
  final double? totalScore;
  final double? bestSet;
  final double? avgSet;
  final int? rpe;

  bool get isPersonal => kind == 'personal';

  /// Kişisel antrenman rozeti — bunu yalnızca sporcunun kendisi görüyor.
  String get kindLabel => isPersonal ? 'Bireysel' : 'Kulüp';

  bool get isComplete => setCount > 0 && setsDone >= setCount;
}

/// Oturumdaki bir katılımcı.
class SessionParticipant {
  const SessionParticipant({
    required this.athleteId,
    required this.name,
    this.lane,
  });

  final String athleteId;
  final String name;
  final int? lane;
}

// ================================= Servis ==================================

class TrainingSessionService {
  const TrainingSessionService(this._db);

  final SupabaseClient _db;

  // --- Şablonlar ---

  /// Kulübün kullanabileceği şablonlar: kendi şablonları + platform
  /// şablonları. RLS ikisini de zaten süzüyor.
  Future<List<TrainingProtocol>> protocols({
    required String clubId,
    String? sportCode,
  }) async {
    var q = _db
        .from('training_protocols')
        .select('id, club_id, sport_code, name, description, version, '
            'config, published')
        .isFilter('archived_at', null)
        .or('club_id.eq.$clubId,club_id.is.null');
    if (sportCode != null) q = q.eq('sport_code', sportCode);

    final rows = await q.order('club_id', nullsFirst: false).order('name');
    return [
      for (final r in rows as List)
        TrainingProtocol.fromMap((r as Map).cast<String, dynamic>()),
    ];
  }

  Future<String> createProtocol({
    required String clubId,
    required String sportCode,
    required String name,
    required TrainingProtocolConfig config,
    String? description,
  }) async {
    final res = await _db.rpc<String>('create_training_protocol', params: {
      'p_club': clubId,
      'p_sport': sportCode,
      'p_name': name,
      'p_description': description,
      'p_config': config.toMap(),
    });
    return res;
  }

  /// Düzenleme yeni sürüm yazıyor; eski satır ve ona bağlı oturumlar duruyor.
  Future<String> reviseProtocol({
    required String protocolId,
    String? name,
    String? description,
    TrainingProtocolConfig? config,
  }) async {
    final res = await _db.rpc<String>('revise_training_protocol', params: {
      'p_protocol': protocolId,
      'p_name': name,
      'p_description': description,
      'p_config': config?.toMap(),
    });
    return res;
  }

  // --- Oturum yaşam döngüsü ---

  /// Kulüp oturumu başlat. Dönen kayıtta katılım kodu var.
  Future<({String id, String joinCode})> startClubSession({
    required String clubId,
    required String protocolId,
    String? eventId,
    String? teamId,
    SessionRhythm rhythm = SessionRhythm.shared,
  }) async {
    final res = await _db.rpc<dynamic>('start_training_session', params: {
      'p_club': clubId,
      'p_protocol': protocolId,
      'p_event': eventId,
      'p_team': teamId,
      'p_rhythm': rhythm.name,
    }) as Map;
    return (id: res['id'] as String, joinCode: res['join_code'] as String);
  }

  /// Bireysel antrenman. Bu kayıt yalnızca sporcunun kendi geçmişinde.
  Future<String> startPersonalSession({
    required String protocolId,
    String? clubId,
  }) async {
    final res = await _db.rpc<dynamic>('start_personal_session', params: {
      'p_protocol': protocolId,
      'p_club': clubId,
    }) as Map;
    return res['id'] as String;
  }

  /// Katılım kodu ile oturuma gir.
  ///
  /// Kod doğru olsa bile başka kulübün ya da başka takımın oturumuna
  /// girilemiyor — kapsamı sunucu kesiyor.
  Future<String> joinByCode(String code) async {
    final res = await _db.rpc<dynamic>('join_training_session', params: {
      'p_code': code.trim().toUpperCase(),
    }) as Map;
    return res['session_id'] as String;
  }

  Future<TrainingSession?> byId(String sessionId) async {
    final rows = await _db
        .from('training_sessions')
        .select('id, club_id, kind, status, current_phase, current_set, '
            'rhythm, phase_ends_at, paused_at, join_code, athlete_id, '
            'event_id, training_protocols(name, config)')
        .eq('id', sessionId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;

    final m = (list.first as Map).cast<String, dynamic>();
    final proto = (m['training_protocols'] as Map?)?.cast<String, dynamic>();
    final cfg = TrainingProtocolConfig.fromMap(
        (proto?['config'] as Map?)?.cast<String, Object?>() ?? const {});
    return TrainingSession.fromMap({
      ...m,
      'paused': m['paused_at'] != null,
      'protocol_name': proto?['name'],
      'set_count': cfg.setCount,
    });
  }

  /// Şablon yapılandırması — sayaç ve skor sınırları buradan.
  Future<TrainingProtocolConfig?> configOf(String sessionId) async {
    final rows = await _db
        .from('training_sessions')
        .select('training_protocols(config)')
        .eq('id', sessionId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    final proto = ((list.first as Map)['training_protocols'] as Map?)
        ?.cast<String, dynamic>();
    if (proto == null) return null;
    return TrainingProtocolConfig.fromMap(
        (proto['config'] as Map?)?.cast<String, Object?>() ?? const {});
  }

  /// Aşamayı ilerlet. [phase] verilirse atlama sayılıyor ve denetim izine
  /// gerekçesiyle yazılıyor.
  Future<void> advancePhase(
    String sessionId, {
    SessionPhase? phase,
    String? reason,
  }) =>
      _db.rpc<void>('advance_session_phase', params: {
        'p_session': sessionId,
        'p_phase': phase?.name,
        'p_reason': reason,
      });

  Future<void> setPaused(String sessionId, bool paused, {String? reason}) =>
      _db.rpc<void>('set_training_pause', params: {
        'p_session': sessionId,
        'p_paused': paused,
        'p_reason': reason,
      });

  // --- Skor ---

  /// Set sonucunu kaydet.
  ///
  /// [entries] verilirse toplam sunucuda hesaplanıyor; `null` üyeler
  /// atılmamış ok demek ve **sıfır sayılmıyor**.
  Future<void> submitSet({
    required String sessionId,
    required int setNo,
    num? total,
    List<num?>? entries,
  }) =>
      _db.rpc<void>('submit_set_score', params: {
        'p_session': sessionId,
        'p_set_no': setNo,
        'p_total': total,
        'p_entries': entries,
      });

  Future<List<TrainingSet>> mySets(String sessionId, String athleteId) async {
    final rows = await _db
        .from('training_sets')
        .select('id, set_no, total_score, unit_count, locked_at, '
            'training_set_entries(seq, score)')
        .eq('session_id', sessionId)
        .eq('athlete_id', athleteId)
        .order('set_no');
    return [
      for (final r in rows as List)
        TrainingSet.fromMap((r as Map).cast<String, dynamic>()),
    ];
  }

  /// Öz değerlendirme. Hepsi isteğe bağlı; boş bırakmak kaydı engellemiyor.
  Future<void> saveAssessment({
    required String sessionId,
    required String athleteId,
    int? rpe,
    List<String> tags = const [],
    String? note,
  }) =>
      _db.from('training_self_assessments').upsert({
        'session_id': sessionId,
        'athlete_id': athleteId,
        'rpe': rpe,
        'tags': tags,
        'note': note,
      });

  // --- Antrenör tarafı ---

  Future<List<SessionParticipant>> participants(String sessionId) async {
    final rows = await _db
        .from('training_session_participants')
        .select('athlete_id, lane, athletes(first_name, last_name)')
        .eq('session_id', sessionId);
    return [
      for (final r in rows as List)
        () {
          final m = (r as Map);
          final a = (m['athletes'] as Map?) ?? const {};
          return SessionParticipant(
            athleteId: m['athlete_id'] as String,
            name: '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'.trim(),
            lane: (m['lane'] as num?)?.toInt(),
          );
        }(),
    ];
  }

  /// Kulvar atama — isteğe bağlı. `null` vermek atamayı kaldırıyor.
  Future<void> assignLane(String sessionId, String athleteId, int? lane) =>
      _db.rpc<void>('assign_session_lane', params: {
        'p_session': sessionId,
        'p_athlete': athleteId,
        'p_lane': lane,
      });

  Future<List<SessionSummaryRow>> summary(String sessionId) async {
    final rows = await _db.rpc<dynamic>('session_summary',
        params: {'p_session': sessionId}) as List;
    return [
      for (final r in rows)
        SessionSummaryRow.fromMap((r as Map).cast<String, dynamic>()),
    ];
  }

  Future<SessionOverview?> overview(String sessionId) async {
    final rows = await _db.rpc<dynamic>('session_overview',
        params: {'p_session': sessionId}) as List;
    if (rows.isEmpty) return null;
    return SessionOverview.fromMap((rows.first as Map).cast<String, dynamic>());
  }

  /// Onayla ve kilitle. Sonrasında sporcu skoruna dokunamıyor.
  Future<int> lockResults(String sessionId) async {
    final res = await _db.rpc<dynamic>('lock_session_results', params: {
      'p_session': sessionId,
    });
    return (res as num).toInt();
  }

  /// Kilitli sonucu düzelt — gerekçe zorunlu, eski/yeni değer denetim izinde.
  Future<void> correctLockedSet({
    required String setId,
    required num total,
    required String reason,
    List<num?>? entries,
  }) =>
      _db.rpc<void>('correct_locked_set', params: {
        'p_set': setId,
        'p_total': total,
        'p_reason': reason,
        'p_entries': entries,
      });

  /// Yoklama ekranındaki İPUCU. Bu çağrı yoklama işaretlemiyor.
  Future<Set<String>> attendanceHint(String eventId) async {
    final rows = await _db.rpc<dynamic>('session_attendance_hint',
        params: {'p_event': eventId}) as List;
    return {
      for (final r in rows) (r as Map)['athlete_id'] as String,
    };
  }

  // --- Sporcu tarafı ---

  Future<List<TrainingHistoryEntry>> history({int limit = 30}) async {
    final rows = await _db.rpc<dynamic>('my_training_history',
        params: {'p_limit': limit}) as List;
    return [
      for (final r in rows)
        TrainingHistoryEntry.fromMap((r as Map).cast<String, dynamic>()),
    ];
  }

  Future<TrainingSession?> myLiveSession() async {
    final rows = await _db.rpc<dynamic>('my_live_training_session') as List;
    if (rows.isEmpty) return null;
    return TrainingSession.fromMap((rows.first as Map).cast<String, dynamic>());
  }
}

DateTime? _time(Object? raw) {
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
  return null;
}

// =============================== Sağlayıcılar ==============================

final trainingSessionServiceProvider = Provider<TrainingSessionService>((ref) {
  return TrainingSessionService(ref.watch(supabaseClientProvider));
});

/// Kulübün şablonları + platform şablonları.
final trainingProtocolsProvider =
    FutureProvider.autoDispose<List<TrainingProtocol>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final club = await ref.watch(activeClubProvider.future);
  if (club == null) return const [];
  return ref.watch(trainingSessionServiceProvider).protocols(clubId: club.id);
});

/// Tek oturum. Canlı ekran bunu yenileyerek aşamayı izliyor.
final trainingSessionProvider = FutureProvider.autoDispose
    .family<TrainingSession?, String>((ref, sessionId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return null;
  return ref.watch(trainingSessionServiceProvider).byId(sessionId);
});

final sessionConfigProvider = FutureProvider.autoDispose
    .family<TrainingProtocolConfig?, String>((ref, sessionId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return null;
  return ref.watch(trainingSessionServiceProvider).configOf(sessionId);
});

final sessionParticipantsProvider = FutureProvider.autoDispose
    .family<List<SessionParticipant>, String>((ref, sessionId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(trainingSessionServiceProvider).participants(sessionId);
});

final sessionSummaryProvider = FutureProvider.autoDispose
    .family<List<SessionSummaryRow>, String>((ref, sessionId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(trainingSessionServiceProvider).summary(sessionId);
});

final sessionOverviewProvider = FutureProvider.autoDispose
    .family<SessionOverview?, String>((ref, sessionId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return null;
  return ref.watch(trainingSessionServiceProvider).overview(sessionId);
});

/// Sporcunun kendi geçmişi — kulüp ve bireysel oturumlar bir arada.
final myTrainingHistoryProvider =
    FutureProvider.autoDispose<List<TrainingHistoryEntry>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(trainingSessionServiceProvider).history();
});

/// Sporcunun şu an içinde olduğu canlı oturum. Ana Sayfa "Bugün" bloğu ve
/// sporcu ana ekranı bunu soruyor.
final myLiveSessionProvider =
    FutureProvider.autoDispose<TrainingSession?>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return null;
  return ref.watch(trainingSessionServiceProvider).myLiveSession();
});

/// Sporcunun bir oturumdaki kendi setleri.
final mySessionSetsProvider = FutureProvider.autoDispose
    .family<List<TrainingSet>, String>((ref, sessionId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null) return const [];
  // Profil → sporcu köprüsü zaten var; ikinci bir yol açılmadı.
  final athlete = await ref.watch(athleteByProfileProvider(profile.id).future);
  if (athlete == null) return const [];
  return ref
      .watch(trainingSessionServiceProvider)
      .mySets(sessionId, athlete.id);
});

/// Antrenörün yoklama ekranındaki ipucu: oturuma katılan sporcular.
/// Bu küme yoklama İŞARETLEMİYOR.
final attendanceHintProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, eventId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const {};
  return ref.watch(trainingSessionServiceProvider).attendanceHint(eventId);
});
