import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';
import 'supabase_athletes.dart';

/// ---------------------------------------------------------------------------
/// Performans modülü — test kayıtları ve bireysel gelişim planı.
/// ---------------------------------------------------------------------------

// Kategorilerin etiketi, ikonu ve rengi burada değil — `IconData`/`Color`
// Flutter arayüz türleri olduğu için bu paket onlara bağlanamaz. Sunum
// sabitleri uygulamada:
// apps/swansport_app/lib/features/performance_analytics/presentation/test_categories.dart

class TestRecord {
  const TestRecord({
    required this.id,
    required this.athleteId,
    required this.category,
    required this.testName,
    required this.value,
    required this.unit,
    required this.testDate,
    this.lowerIsBetter = false,
    this.note,
  });

  final String id;
  final String athleteId;
  final String category;
  final String testName;
  final num value;
  final String unit;
  final DateTime testDate;
  final bool lowerIsBetter;
  final String? note;

  String get valueLabel =>
      '${value.toString().replaceAll(RegExp(r'\.0$'), '')}${unit.isEmpty ? '' : ' $unit'}';

  factory TestRecord.fromMap(Map<String, dynamic> m) => TestRecord(
        id: m['id'] as String,
        athleteId: m['athlete_id'] as String,
        category: (m['category'] as String?) ?? 'surat',
        testName: (m['test_name'] as String?) ?? '',
        value: (m['value'] as num?) ?? 0,
        unit: (m['unit'] as String?) ?? '',
        lowerIsBetter: (m['lower_is_better'] as bool?) ?? false,
        testDate:
            DateTime.tryParse('${m['test_date']}') ?? DateTime.now(),
        note: m['note'] as String?,
      );
}

/// Aynı test adının zaman içindeki seyri.
class TestSeries {
  const TestSeries({required this.name, required this.records});

  final String name;
  final List<TestRecord> records; // eskiden yeniye

  String get category => records.first.category;
  TestRecord get latest => records.last;
  bool get lowerIsBetter => records.first.lowerIsBetter;

  /// Son iki ölçüm arasındaki değişim (yüzde). Ölçüm tekse null.
  double? get changePercent {
    if (records.length < 2) return null;
    final prev = records[records.length - 2].value;
    if (prev == 0) return null;
    return ((latest.value - prev) / prev) * 100;
  }

  /// Değişim sporcunun lehine mi?
  bool? get improved {
    final c = changePercent;
    if (c == null || c == 0) return null;
    return lowerIsBetter ? c < 0 : c > 0;
  }
}

class DevelopmentGoal {
  const DevelopmentGoal({
    required this.id,
    required this.athleteId,
    required this.title,
    required this.category,
    required this.progress,
    required this.status,
    this.targetDate,
    this.note,
    this.testName,
    this.baselineValue,
    this.targetValue,
    this.lastValue,
    this.measuredAt,
  });

  final String id;
  final String athleteId;
  final String title;
  final String category;
  final int progress;
  final String status; // active | done | at_risk
  final DateTime? targetDate;
  final String? note;

  /// Bu hedefi ölçen testin adı (0044).
  ///
  /// Doluysa `progress` **elle girilmiyor**: yeni ölçüm eklendiğinde
  /// veritabanı tetikleyicisi hesaplıyor. Boşsa eski davranış sürüyor —
  /// mevcut hedefler bozulmasın diye ikisi bir arada yaşıyor.
  final String? testName;

  final double? baselineValue;
  final double? targetValue;

  /// Hedefe bağlı en son ölçüm ve ne zaman alındığı.
  final double? lastValue;
  final DateTime? measuredAt;

  /// Ölçüme bağlı mı, elle mi takip ediliyor.
  bool get isMeasured =>
      testName != null && baselineValue != null && targetValue != null;

  String get statusLabel => switch (status) {
        'done' => 'Tamamlandı',
        'at_risk' => 'Riskli',
        _ => 'Sürüyor',
      };

  factory DevelopmentGoal.fromMap(Map<String, dynamic> m) => DevelopmentGoal(
        id: m['id'] as String,
        athleteId: m['athlete_id'] as String,
        title: (m['title'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'surat',
        progress: (m['progress'] as int?) ?? 0,
        status: (m['status'] as String?) ?? 'active',
        targetDate: m['target_date'] == null
            ? null
            : DateTime.tryParse('${m['target_date']}'),
        note: m['note'] as String?,
        testName: m['test_name'] as String?,
        baselineValue: (m['baseline_value'] as num?)?.toDouble(),
        targetValue: (m['target_value'] as num?)?.toDouble(),
        lastValue: (m['last_value'] as num?)?.toDouble(),
        measuredAt: m['measured_at'] == null
            ? null
            : DateTime.tryParse('${m['measured_at']}')?.toLocal(),
      );
}

class PerformanceService {
  PerformanceService(this._c);
  final SupabaseClient _c;

  Future<List<TestRecord>> tests(String athleteId) async {
    final rows = await _c
        .from('performance_tests')
        .select('id, athlete_id, category, test_name, value, unit, '
            'lower_is_better, test_date, note')
        .eq('athlete_id', athleteId)
        .order('test_date');
    return (rows as List)
        .map((r) => TestRecord.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Testleri adına göre gruplar (seyir çizebilmek için).
  Future<List<TestSeries>> series(String athleteId) async {
    final all = await tests(athleteId);
    final byName = <String, List<TestRecord>>{};
    for (final t in all) {
      byName.putIfAbsent(t.testName, () => []).add(t);
    }
    final out = byName.entries
        .map((e) => TestSeries(name: e.key, records: e.value))
        .toList();
    out.sort((a, b) => b.latest.testDate.compareTo(a.latest.testDate));
    return out;
  }

  Future<void> addTest({
    required String athleteId,
    required String category,
    required String testName,
    required num value,
    String unit = '',
    bool lowerIsBetter = false,
    DateTime? date,
    String? note,
  }) async {
    await _c.from('performance_tests').insert({
      'athlete_id': athleteId,
      'category': category,
      'test_name': testName.trim(),
      'value': value,
      'unit': unit.trim(),
      'lower_is_better': lowerIsBetter,
      'test_date':
          (date ?? DateTime.now()).toIso8601String().split('T').first,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'assessor_id': _c.auth.currentUser?.id,
    });
  }

  Future<void> removeTest(String id) async {
    await _c.from('performance_tests').delete().eq('id', id);
  }

  // ------------------------------ hedefler -----------------------------
  Future<List<DevelopmentGoal>> goals(String athleteId) async {
    final rows = await _c
        .from('development_goals')
        .select('id, athlete_id, title, category, progress, status, '
            'target_date, note, test_name, baseline_value, target_value, '
            'last_value, measured_at')
        .eq('athlete_id', athleteId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => DevelopmentGoal.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Hedef ekler.
  ///
  /// [testName], [baselineValue] ve [targetValue] birlikte verilirse hedef
  /// **ölçülebilir** olur: ilerlemesi bir daha elle girilmez, o testten yeni
  /// bir ölçüm geldiğinde veritabanı tetikleyicisi hesaplar (0044).
  ///
  /// Üçü birden ya verilir ya hiçbiri; yarısı dolu bir hedef ilerleme
  /// hesaplayamaz ve sessizce yanlış görünürdü. Şema da bunu kısıtlıyor.
  Future<void> addGoal({
    required String athleteId,
    required String title,
    String category = 'surat',
    DateTime? targetDate,
    String? note,
    String? testName,
    double? baselineValue,
    double? targetValue,
  }) async {
    final measured = testName != null &&
        testName.trim().isNotEmpty &&
        baselineValue != null &&
        targetValue != null;

    if (measured && baselineValue == targetValue) {
      throw ArgumentError(
          'Başlangıç ve hedef aynı olamaz — ilerleme hesaplanamaz.');
    }

    await _c.from('development_goals').insert({
      'athlete_id': athleteId,
      'title': title.trim(),
      'category': category,
      if (targetDate != null)
        'target_date': targetDate.toIso8601String().split('T').first,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (measured) 'test_name': testName.trim(),
      if (measured) 'baseline_value': baselineValue,
      if (measured) 'target_value': targetValue,
      'created_by': _c.auth.currentUser?.id,
    });
  }

  /// İlerlemeyi elle ayarlar — **yalnızca ölçüme bağlı olmayan hedeflerde**.
  ///
  /// Ölçülebilir hedefte bunu çağırmak, bir sonraki ölçümde tetikleyicinin
  /// üstüne yazacağı bir değer girmek olur; kullanıcıya kalıcı görünen ama
  /// kalıcı olmayan bir değişiklik en kötü tür geri bildirimdir.
  Future<void> setGoalProgress(String id, int progress) async {
    final p = progress.clamp(0, 100);
    await _c.from('development_goals').update({
      'progress': p,
      'status': p >= 100 ? 'done' : 'active',
    }).eq('id', id);
  }

  Future<void> removeGoal(String id) async {
    await _c.from('development_goals').delete().eq('id', id);
  }

  /// Kulüp geneli özet.
  Future<List<({String athleteId, String name, int tests, int goals, int progress, DateTime? lastTest})>>
      overview(String clubId) async {
    final rows = await _c
        .rpc<List<dynamic>>('performance_overview', params: {'p_club': clubId});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return (
        athleteId: m['athlete_id'] as String,
        name: ((m['full_name'] as String?) ?? '').trim(),
        tests: (m['test_count'] as int?) ?? 0,
        goals: (m['goal_count'] as int?) ?? 0,
        progress: (m['avg_progress'] as int?) ?? 0,
        lastTest: m['last_test'] == null
            ? null
            : DateTime.tryParse('${m['last_test']}'),
      );
    }).toList();
  }
}

// =============================== Provider'lar ==============================

final performanceServiceProvider = Provider<PerformanceService>((ref) {
  return PerformanceService(ref.watch(supabaseClientProvider));
});

final testSeriesProvider =
    FutureProvider.autoDispose.family<List<TestSeries>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(performanceServiceProvider).series(id);
});

final goalsProvider =
    FutureProvider.autoDispose.family<List<DevelopmentGoal>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(performanceServiceProvider).goals(id);
});

final performanceOverviewProvider = FutureProvider.autoDispose<
    List<({String athleteId, String name, int tests, int goals, int progress, DateTime? lastTest})>>(
  (ref) async {
    final club = await ref.watch(activeClubProvider.future);
    if (club == null) return const [];
    return ref.watch(performanceServiceProvider).overview(club.id);
  },
);
