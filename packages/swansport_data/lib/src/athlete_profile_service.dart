import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Detaylı sporcu profili.
///
/// Yetki ayrımı: sportif veriyi (mevki, forma no, ölçüler, başarılar) kulüp
/// yönetir; kişisel veriyi (ad, avatar, biyografi) sporcunun kendisi. Kulüpsüz
/// (ferdi) sporcu her ikisini de kendisi yönetir.
/// ---------------------------------------------------------------------------

class AthleteSportInfo {
  const AthleteSportInfo({
    required this.id,
    required this.fullName,
    this.clubId,
    this.clubName,
    this.position,
    this.status,
    this.jerseyNumber,
    this.heightCm,
    this.weightKg,
    this.dominantSide,
    this.branch,
    this.startedAt,
  });

  final String id;
  final String fullName;
  final String? clubId;
  final String? clubName;
  final String? position;
  final String? status;
  final int? jerseyNumber;
  final int? heightCm;
  final num? weightKg;
  final String? dominantSide;
  final String? branch;
  final DateTime? startedAt;

  bool get isIndividual => clubId == null;

  /// Vitrinde gösterilecek bir bilgi var mı?
  bool get hasDetails =>
      position != null ||
      jerseyNumber != null ||
      heightCm != null ||
      weightKg != null ||
      branch != null ||
      dominantSide != null;

  /// Kaç yıldır sporda?
  int? get yearsActive {
    if (startedAt == null) return null;
    final y = DateTime.now().difference(startedAt!).inDays ~/ 365;
    return y <= 0 ? null : y;
  }

  factory AthleteSportInfo.fromMap(Map<String, dynamic> m) {
    final first = (m['first_name'] as String?) ?? '';
    final last = (m['last_name'] as String?) ?? '';
    return AthleteSportInfo(
      id: m['id'] as String,
      fullName: '$first $last'.trim(),
      clubId: m['club_id'] as String?,
      clubName: m['club_name'] as String?,
      position: m['position'] as String?,
      status: m['status'] as String?,
      jerseyNumber: m['jersey_number'] as int?,
      heightCm: m['height_cm'] as int?,
      weightKg: m['weight_kg'] as num?,
      dominantSide: m['dominant_side'] as String?,
      branch: m['branch'] as String?,
      startedAt: m['started_at'] == null
          ? null
          : DateTime.tryParse('${m['started_at']}'),
    );
  }
}

class Achievement {
  const Achievement({
    required this.id,
    required this.athleteId,
    required this.title,
    required this.category,
    this.placement,
    this.eventDate,
    this.location,
    this.note,
  });

  final String id;
  final String athleteId;
  final String title;
  final String category; // derece | rekor | ödül | seçilme
  final int? placement;
  final DateTime? eventDate;
  final String? location;
  final String? note;

  /// 1., 2., 3. için madalya rengi mantığı ekranda kullanılır.
  bool get isPodium => placement != null && placement! >= 1 && placement! <= 3;

  String get placementLabel => switch (placement) {
        1 => '1. — Altın',
        2 => '2. — Gümüş',
        3 => '3. — Bronz',
        final p? => '$p.',
        _ => '',
      };

  String get categoryLabel => switch (category) {
        'rekor' => 'Rekor',
        'ödül' => 'Ödül',
        'seçilme' => 'Seçilme',
        _ => 'Derece',
      };

  factory Achievement.fromMap(Map<String, dynamic> m) => Achievement(
        id: m['id'] as String,
        athleteId: m['athlete_id'] as String,
        title: (m['title'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'derece',
        placement: m['placement'] as int?,
        eventDate: m['event_date'] == null
            ? null
            : DateTime.tryParse('${m['event_date']}'),
        location: m['location'] as String?,
        note: m['note'] as String?,
      );
}

class AthleteProfileService {
  AthleteProfileService(this._c);
  final SupabaseClient _c;

  /// Bir profile bağlı sporcu kaydı (varsa).
  Future<AthleteSportInfo?> byProfile(String profileId) async {
    final row = await _c
        .from('athlete_public')
        .select()
        .eq('profile_id', profileId)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return AthleteSportInfo.fromMap(row);
  }

  /// Sporcu kaydını doğrudan id ile getirir.
  Future<AthleteSportInfo?> byId(String athleteId) async {
    final row = await _c
        .from('athlete_public')
        .select()
        .eq('id', athleteId)
        .maybeSingle();
    if (row == null) return null;
    return AthleteSportInfo.fromMap(row);
  }

  Future<List<Achievement>> achievements(String athleteId) async {
    final rows = await _c
        .from('athlete_achievements')
        .select('id, athlete_id, title, category, placement, event_date, '
            'location, note')
        .eq('athlete_id', athleteId)
        .order('event_date', ascending: false, nullsFirst: false);
    return (rows as List)
        .map((r) => Achievement.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> addAchievement({
    required String athleteId,
    required String title,
    String category = 'derece',
    int? placement,
    DateTime? eventDate,
    String? location,
    String? note,
  }) async {
    await _c.from('athlete_achievements').insert({
      'athlete_id': athleteId,
      'title': title.trim(),
      'category': category,
      if (placement != null) 'placement': placement,
      if (eventDate != null)
        'event_date': eventDate.toIso8601String().split('T').first,
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'created_by': _c.auth.currentUser?.id,
    });
  }

  Future<void> removeAchievement(String id) async {
    await _c.from('athlete_achievements').delete().eq('id', id);
  }

  /// Sportif bilgileri güncelle (yetki veritabanında denetlenir).
  Future<void> updateSportInfo(
    String athleteId, {
    String? position,
    int? jersey,
    int? height,
    num? weight,
    String? dominantSide,
    String? branch,
    String? license,
  }) async {
    await _c.rpc<void>('update_athlete_sport_info', params: {
      'p_athlete': athleteId,
      if (position != null) 'p_position': position,
      if (jersey != null) 'p_jersey': jersey,
      if (height != null) 'p_height': height,
      if (weight != null) 'p_weight': weight,
      if (dominantSide != null) 'p_dominant_side': dominantSide,
      if (branch != null) 'p_branch': branch,
      if (license != null) 'p_license': license,
    });
  }

  /// Bu sporcunun sportif verisini düzenleyebilir miyim?
  Future<bool> canManage(String athleteId) async {
    final res = await _c
        .rpc<bool>('can_manage_athlete', params: {'p_athlete': athleteId});
    return res;
  }
}

// =============================== Provider'lar ==============================

final athleteProfileServiceProvider = Provider<AthleteProfileService>((ref) {
  return AthleteProfileService(ref.watch(supabaseClientProvider));
});

/// Bir profile bağlı sporcu kaydı.

/// Sporcu kartının içi — dijital sporcu CV'si (0046).
///
/// **Neden ayrı bir RPC:** kart dört tablodan besleniyor (katılım, hedefler,
/// başarılar, ölçümler). Dördünü ayrı çekmek kartı açan her ekranda dört
/// gidiş-dönüş demekti; kart bir sayfa değil, bir bakışta okunan şey.
class AthleteCard {
  const AthleteCard({
    required this.trainings,
    required this.attendancePct,
    required this.goalsDone,
    required this.goalsActive,
    required this.achievements,
    this.lastTest,
    this.clubName,
    this.teamName,
  });

  static const empty = AthleteCard(
    trainings: 0,
    attendancePct: 0,
    goalsDone: 0,
    goalsActive: 0,
    achievements: 0,
  );

  factory AthleteCard.fromMap(Map<String, dynamic> m) => AthleteCard(
        trainings: (m['trainings'] as num?)?.toInt() ?? 0,
        attendancePct: (m['attendance_pct'] as num?)?.toInt() ?? 0,
        goalsDone: (m['goals_done'] as num?)?.toInt() ?? 0,
        goalsActive: (m['goals_active'] as num?)?.toInt() ?? 0,
        achievements: (m['achievements'] as num?)?.toInt() ?? 0,
        lastTest: m['last_test'] == null
            ? null
            : DateTime.tryParse('${m['last_test']}'),
        clubName: m['club_name'] as String?,
        teamName: m['team_name'] as String?,
      );

  final int trainings;
  final int attendancePct;
  final int goalsDone;
  final int goalsActive;
  final int achievements;
  final DateTime? lastTest;
  final String? clubName;
  final String? teamName;

  /// Gösterilecek bir şey var mı.
  ///
  /// Hepsi sıfırsa kartta boş sayılar dizmek yerine hiç göstermemek doğru:
  /// "0 antrenman, %0 katılım" bir sporcu kartında iyi durmuyor ve yeni
  /// kaydolan herkes böyle başlıyor.
  bool get hasData =>
      trainings > 0 || goalsDone > 0 || goalsActive > 0 || achievements > 0;
}

/// Sporcu kartının verisi.
final athleteCardProvider =
    FutureProvider.autoDispose.family<AthleteCard, String>((ref, athleteId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return AthleteCard.empty;
  final client = ref.watch(supabaseClientProvider);
  try {
    final rows = await client
        .rpc<dynamic>('athlete_card', params: {'p_athlete': athleteId});
    final list = (rows as List?) ?? const [];
    if (list.isEmpty) return AthleteCard.empty;
    return AthleteCard.fromMap(
        Map<String, dynamic>.from(list.first as Map));
  } catch (_) {
    // 0046 çalıştırılmadıysa fonksiyon yok. Kart eski hâliyle (yalnızca ad
    // ve QR) çalışmaya devam etsin; hata göstermek kartı kullanılamaz yapardı.
    return AthleteCard.empty;
  }
});

final athleteByProfileProvider =
    FutureProvider.autoDispose.family<AthleteSportInfo?, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(null);
  return ref.watch(athleteProfileServiceProvider).byProfile(id);
});

/// Sporcu kaydının başarıları.
final achievementsProvider =
    FutureProvider.autoDispose.family<List<Achievement>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(athleteProfileServiceProvider).achievements(id);
});

/// Sportif veriyi düzenleme yetkisi.
final canManageAthleteProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(false);
  return ref.watch(athleteProfileServiceProvider).canManage(id);
});
