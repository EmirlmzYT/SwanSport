import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'feature_flags.dart';
import 'supabase_scope.dart';

class ReportAthlete {
  const ReportAthlete({required this.id, required this.name, this.clubName});
  final String id, name;
  final String? clubName;
  factory ReportAthlete.fromMap(Map<String, dynamic> m) => ReportAthlete(
        id: m['id'] as String,
        name: m['full_name'] as String,
        clubName: m['club_name'] as String?,
      );
}

class ReportAthletePage {
  const ReportAthletePage(this.athletes, this.hasMore);
  final List<ReportAthlete> athletes;
  final bool hasMore;
  factory ReportAthletePage.fromMap(Map<String, dynamic> m) =>
      ReportAthletePage(
        (m['athletes'] as List)
            .map(
              (r) => ReportAthlete.fromMap((r as Map).cast<String, dynamic>()),
            )
            .toList(),
        m['has_more'] as bool,
      );
}

class ReportAttendance {
  const ReportAttendance({
    required this.present,
    required this.late,
    required this.absent,
    required this.excused,
    required this.unlinked,
    this.rate,
  });
  final int present, late, absent, excused, unlinked;
  final num? rate;
  int get recorded => present + late + absent + excused;
  factory ReportAttendance.fromMap(Map<String, dynamic> m) => ReportAttendance(
        present: (m['present'] as num).toInt(),
        late: (m['late'] as num).toInt(),
        absent: (m['absent'] as num).toInt(),
        excused: (m['excused'] as num).toInt(),
        unlinked: (m['unlinked'] as num).toInt(),
        rate: m['rate'] as num?,
      );
}

class ReportMetric {
  const ReportMetric({
    required this.name,
    required this.category,
    required this.unit,
    required this.lowerIsBetter,
    required this.count,
    required this.first,
    required this.last,
    required this.firstDate,
    required this.lastDate,
  });
  final String name, category, unit;
  final bool lowerIsBetter;
  final int count;
  final num first, last;
  final DateTime firstDate, lastDate;
  num? get change => count < 2 ? null : last - first;
  double? get percent => change == null || first <= 0
      ? null
      : change!.toDouble() / first.toDouble() * 100;
  String get trend => change == null
      ? 'İkinci ölçüm yok'
      : change == 0
          ? 'Değişim yok'
          : (lowerIsBetter ? change! < 0 : change! > 0)
              ? 'Ölçüm yönüne göre lehte'
              : 'Ölçüm yönüne göre aleyhte';
  String get summary => count < 2
      ? '${reportNumber(last)} $unit · karşılaştırma için ikinci ölçüm yok'
      : '${reportNumber(first)} → ${reportNumber(last)} $unit · $trend${percent == null ? '' : ' (${reportNumber(percent!)}%)'}';
  factory ReportMetric.fromMap(Map<String, dynamic> m) => ReportMetric(
        name: m['test_name'] as String,
        category: m['category'] as String,
        unit: m['unit'] as String,
        lowerIsBetter: m['lower_is_better'] as bool,
        count: (m['sample_count'] as num).toInt(),
        first: m['first_value'] as num,
        last: m['last_value'] as num,
        firstDate: DateTime.parse(m['first_date'] as String),
        lastDate: DateTime.parse(m['last_date'] as String),
      );
}

class ReportGoal {
  const ReportGoal({
    required this.title,
    required this.progress,
    required this.status,
    required this.measured,
    required this.createdOn,
    this.targetDate,
  });
  final String title, status;
  final int progress;
  final bool measured;
  final DateTime createdOn;
  final DateTime? targetDate;
  String get statusLabel => switch (status) {
        'done' => 'Tamamlandı',
        'at_risk' => 'Riskli',
        'active' => 'Sürüyor',
        _ => 'Durum bilinmiyor'
      };
  factory ReportGoal.fromMap(Map<String, dynamic> m) => ReportGoal(
        title: m['title'] as String,
        progress: (m['progress'] as num).toInt(),
        status: m['status'] as String,
        measured: m['measured'] as bool,
        createdOn: DateTime.parse(m['created_on'] as String),
        targetDate: m['target_date'] == null
            ? null
            : DateTime.parse(m['target_date'] as String),
      );
}

class DevelopmentReport {
  const DevelopmentReport({
    required this.athlete,
    required this.from,
    required this.to,
    required this.generatedAt,
    required this.fingerprint,
    required this.attendance,
    required this.metrics,
    required this.goals,
  });
  final ReportAthlete athlete;
  final DateTime from, to, generatedAt;
  final String fingerprint;
  final ReportAttendance attendance;
  final List<ReportMetric> metrics;
  final List<ReportGoal> goals;
  factory DevelopmentReport.fromMap(Map<String, dynamic> m) =>
      DevelopmentReport(
        athlete: ReportAthlete.fromMap(
          (m['athlete'] as Map).cast<String, dynamic>(),
        ),
        from: DateTime.parse(m['from'] as String),
        to: DateTime.parse(m['to'] as String),
        generatedAt: DateTime.parse(m['generated_at'] as String),
        fingerprint: m['fingerprint'] as String,
        attendance: ReportAttendance.fromMap(
          (m['attendance'] as Map).cast<String, dynamic>(),
        ),
        metrics: (m['metrics'] as List)
            .map(
              (r) => ReportMetric.fromMap((r as Map).cast<String, dynamic>()),
            )
            .toList(),
        goals: (m['goals'] as List)
            .map(
              (r) => ReportGoal.fromMap((r as Map).cast<String, dynamic>()),
            )
            .toList(),
      );
  List<String> get gaps => [
        if (attendance.recorded == 0)
          'Bu dönemde etkinliğe bağlı yoklama kaydı yok.',
        if (attendance.rate == null)
          'Devam oranı hesaplanamıyor; kaydedilmemiş yoklamalar devamsızlık değildir.',
        if (attendance.unlinked > 0)
          '${attendance.unlinked} etkinliksiz yoklama kaydı orana dahil edilmedi.',
        if (metrics.isEmpty) 'Bu dönemde ölçüm kaydı yok.',
        if (metrics.any((m) => m.count < 2))
          'Bazı testlerde karşılaştırma için ikinci ölçüm yok.',
        if (goals.isEmpty) 'Dönem sonuna kadar açılmış hedef kaydı yok.',
      ];
  String text({bool includeIdentity = false}) {
    final a = attendance;
    return [
      'SwanSport · Dönem gelişim raporu',
      if (includeIdentity)
        'Sporcu: ${athlete.name}${athlete.clubName == null ? '' : ' · ${athlete.clubName}'}',
      'Dönem: ${reportDate(from)} – ${reportDate(to)}',
      'Oluşturma: ${reportDate(generatedAt.toUtc().add(const Duration(hours: 3)))}',
      '',
      'DEVAM · KAYITLI ETKİNLİKLER',
      'Devam oranı: ${a.rate == null ? 'Hesaplanamıyor' : '${reportNumber(a.rate!)}%'}',
      'Katıldı: ${a.present} · Geç geldi: ${a.late} · Gelmedi: ${a.absent} · İzinli: ${a.excused}',
      'Oran = (katıldı + geç geldi) / (katıldı + geç geldi + gelmedi). İzinliler ve kaydedilmemiş yoklamalar paydaya girmez.',
      '',
      'DÖNEM ÖLÇÜMLERİ',
      for (final metric in metrics)
        '${metric.category} · ${metric.name} [${metric.unit.isEmpty ? 'birimsiz' : metric.unit}; ${metric.lowerIsBetter ? 'düşük iyi' : 'yüksek iyi'}] (${metric.count} kayıt): ${metric.summary} · ${reportDate(metric.firstDate)} – ${reportDate(metric.lastDate)}',
      '',
      'HEDEFLER · GÜNCEL DURUM',
      'Dönem sonuna kadar açılan hedeflerin rapor oluşturma anındaki durumu. Geçmiş ilerleme yüzdesi değildir.',
      for (final goal in goals)
        '${goal.title}: ${goal.statusLabel} · %${goal.progress} · ${goal.measured ? 'ölçüme bağlı' : 'elle takip'}${goal.targetDate == null ? '' : ' · hedef tarihi ${reportDate(goal.targetDate!)}'}',
      '',
      'VERİ SINIRLARI',
      ...gaps,
      'Bu özet yalnız sistemde kayıtlı veriyi gösterir.',
    ].join('\n');
  }
}

String reportDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
String reportNumber(num n) => n
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'\.?0+$'), '')
    .replaceAll('.', ',');
String reportIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
typedef DevelopmentReportRequest = ({
  String athleteId,
  DateTime from,
  DateTime to
});

class DevelopmentReportService {
  DevelopmentReportService(this.client);
  final SupabaseClient client;
  Future<ReportAthletePage> athletes({
    String query = '',
    int offset = 0,
  }) async {
    final result = await client.rpc<dynamic>(
      'development_report_athletes',
      params: {'p_query': query, 'p_offset': offset},
    );
    return ReportAthletePage.fromMap((result as Map).cast<String, dynamic>());
  }

  Future<DevelopmentReport> load(DevelopmentReportRequest request) async {
    final result = await client.rpc<dynamic>(
      'athlete_development_report',
      params: {
        'p_athlete': request.athleteId,
        'p_from': reportIsoDate(request.from),
        'p_to': reportIsoDate(request.to),
      },
    );
    return DevelopmentReport.fromMap((result as Map).cast<String, dynamic>());
  }
}

final developmentReportServiceProvider = Provider<DevelopmentReportService>(
  (ref) => DevelopmentReportService(ref.watch(supabaseClientProvider)),
);
final reportAthletesProvider = FutureProvider.autoDispose
    .family<ReportAthletePage, ({String query, int offset})>((ref, args) {
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(featureEnabledProvider(FeatureFlags.developmentReport))) {
    return Future.value(const ReportAthletePage([], false));
  }
  ref.watch(authSessionProvider);
  return ref
      .watch(developmentReportServiceProvider)
      .athletes(query: args.query, offset: args.offset);
});
final developmentReportProvider = FutureProvider.autoDispose
    .family<DevelopmentReport, DevelopmentReportRequest>((ref, request) {
  if (!ref.watch(isSupabaseEnabledProvider) ||
      !ref.watch(featureEnabledProvider(FeatureFlags.developmentReport))) {
    throw StateError('Gelişim raporu kullanılamıyor.');
  }
  ref.watch(authSessionProvider);
  return ref.watch(developmentReportServiceProvider).load(request);
});
