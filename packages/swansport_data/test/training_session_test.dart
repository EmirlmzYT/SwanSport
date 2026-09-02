import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Antrenman oturumu veri katmanı.
///
/// EN ÖNEMLİ TEST GRUBU "SQL ↔ Dart sözleşmesi". Bu depoda bir kez şu oldu:
/// RPC 8 sütun döndürüyordu, Dart 10 alan okuyordu ve `??` yedekleri farkı
/// gizledi — ekran sessizce yanlış veri gösterdi. Aşağıdaki testler
/// migration dosyasındaki `returns table (...)` bloğunu okuyup her sütunun
/// Dart tarafında gerçekten okunduğunu doğruluyor.
void main() {
  final repo = Directory.current.path.replaceAll('\\', '/');
  final root = repo.endsWith('/packages/swansport_data')
      ? repo.substring(0, repo.length - '/packages/swansport_data'.length)
      : repo;

  /// Bir RPC'nin `returns table (...)` sütun adları.
  List<String> sqlColumns(String fn) {
    final src = File('$root/supabase/migrations/0072_training_rpc.sql')
        .readAsStringSync();
    final m = RegExp(
      'create or replace function public\\.$fn\\([^)]*\\)\\s*'
      r'returns table \(([^;]*?)\)\s*\n\s*language',
      dotAll: true,
    ).firstMatch(src);
    expect(m, isNotNull, reason: '$fn için returns table bulunamadı');

    return [
      for (final line in m!.group(1)!.split(','))
        if (RegExp(r'^\s*([a-z_]+)\s+').firstMatch(line) != null)
          RegExp(r'^\s*([a-z_]+)\s+').firstMatch(line)!.group(1)!,
    ];
  }

  final dartSrc = File(
          '$root/packages/swansport_data/lib/src/training_session_service.dart')
      .readAsStringSync();

  group('SQL ↔ Dart sözleşmesi', () {
    test('araç çalışıyor — sütunlar gerçekten okunuyor', () {
      // Boş kümeyi boş kümeyle karşılaştırıp "sorun yok" demek, bu depoda
      // yaşanmış bir hata. Önce aracın kendisi doğrulanıyor.
      expect(sqlColumns('session_summary').length, greaterThan(10));
      expect(sqlColumns('session_overview').length, greaterThan(8));
      expect(sqlColumns('my_training_history').length, greaterThan(8));
    });

    for (final fn in const [
      'session_summary',
      'session_overview',
      'my_training_history',
      'my_live_training_session',
    ]) {
      test('$fn: her sütunun Dart karşılığı var', () {
        final missing = [
          for (final col in sqlColumns(fn))
            if (!dartSrc.contains("m['$col']")) col,
        ];
        expect(missing, isEmpty,
            reason: '$fn şu sütunları döndürüyor ama Dart okumuyor: $missing');
      });
    }

    test('session_summary tam 16 sütun döndürüyor', () {
      // Sayı sabitlenmiş: sütun eklenirse bu test kırılır ve modeli
      // güncellemek zorunda kalırsın. Sessizce kaymasın diye.
      expect(sqlColumns('session_summary').length, 16);
    });
  });

  group('Oturum modeli', () {
    TrainingSession session({
      String status = 'live',
      String phase = 'shoot',
      bool paused = false,
      String? endsAt,
    }) =>
        TrainingSession.fromMap({
          'id': 's1',
          'club_id': 'c1',
          'kind': 'club',
          'status': status,
          'current_phase': phase,
          'current_set': 2,
          'set_count': 6,
          'rhythm': 'shared',
          'protocol_name': 'Puanlı set',
          'phase_ends_at': endsAt,
          'paused': paused,
        });

    test('alanlar okunuyor', () {
      final s = session();
      expect(s.id, 's1');
      expect(s.currentSet, 2);
      expect(s.setCount, 6);
      expect(s.phase, SessionPhase.shoot);
      expect(s.rhythm, SessionRhythm.shared);
      expect(s.isPersonal, isFalse);
      expect(s.isLive, isTrue);
    });

    test('onay bekleyen oturum ayırt ediliyor', () {
      expect(session(status: 'review').awaitingApproval, isTrue);
      expect(session(status: 'review').statusLabel, 'Onay bekliyor');
      expect(session(status: 'completed').awaitingApproval, isFalse);
    });

    test('süre dolduğunda işaretleniyor', () {
      final s = session(endsAt: '2026-09-02T10:00:00Z');
      expect(s.expiredAt(DateTime.utc(2026, 9, 2, 10, 1)), isTrue);
      expect(s.expiredAt(DateTime.utc(2026, 9, 2, 9, 59)), isFalse);
    });

    test('duraklatılmış oturum süresi dolmuş sayılmıyor', () {
      final s = session(endsAt: '2026-09-02T10:00:00Z', paused: true);
      expect(s.expiredAt(DateTime.utc(2026, 9, 2, 12, 0)), isFalse);
    });

    test('süresiz aşamada sayaç yok', () {
      expect(session(phase: 'score').remainingAt(DateTime.utc(2026)), isNull);
    });

    test('kimlik alanı yoksa session_id okunuyor', () {
      // `my_live_training_session` `session_id`, tablo okuması `id` dönüyor.
      final s = TrainingSession.fromMap({'session_id': 'x1'});
      expect(s.id, 'x1');
    });
  });

  group('Set — eksik sıfır değil', () {
    TrainingSet st(Object? total) => TrainingSet.fromMap({
          'id': 't1',
          'set_no': 3,
          'total_score': total,
          'locked_at': null,
        });

    test('girilmemiş set eksik sayılıyor', () {
      expect(st(null).isMissing, isTrue);
      expect(st(null).totalScore, isNull);
    });

    test('sıfır puan eksik DEĞİL', () {
      // İkisi farklı gerçek: biri "atmadı", diğeri "attı ve ıskaladı".
      expect(st(0).isMissing, isFalse);
      expect(st(0).totalScore, 0);
    });

    test('kilit okunuyor', () {
      final locked = TrainingSet.fromMap({
        'id': 't1',
        'set_no': 1,
        'total_score': 27,
        'locked_at': '2026-09-02T10:00:00Z',
      });
      expect(locked.locked, isTrue);
      expect(st(27).locked, isFalse);
    });

    test('tek tek atışlar okunuyor, eksik ok null kalıyor', () {
      final s = TrainingSet.fromMap({
        'id': 't1',
        'set_no': 1,
        'total_score': 18,
        'training_set_entries': [
          {'seq': 1, 'score': 10},
          {'seq': 2, 'score': null},
          {'seq': 3, 'score': 8},
        ],
      });
      expect(s.entries, [10, null, 8]);
      expect(sumEntries(s.entries), 18);
      expect(countEntries(s.entries), 2);
    });
  });

  group('Sonuç satırı', () {
    SessionSummaryRow row({
      List<Object?> progression = const [46, 51, 49],
      List<String> flags = const [],
      Map<String, Object?> buckets = const {'10': 4, '9': 7},
    }) =>
        SessionSummaryRow.fromMap({
          'athlete_id': 'a1',
          'athlete_name': 'Emir Yılmaz',
          'lane': 3,
          'sets_done': 3,
          'sets_expected': 6,
          'total_score': 146,
          'avg_set': 48.67,
          'best_set': 51,
          'missing_sets': 3,
          'units_recorded': 9,
          'units_expected': 18,
          'progression': progression,
          'score_buckets': buckets,
          'rpe': 7,
          'locked': false,
          'review_flags': flags,
        });

    test('16 alan da okunuyor', () {
      final r = row();
      expect(r.athleteId, 'a1');
      expect(r.athleteName, 'Emir Yılmaz');
      expect(r.lane, 3);
      expect(r.setsDone, 3);
      expect(r.setsExpected, 6);
      expect(r.totalScore, 146);
      expect(r.avgSet, closeTo(48.67, 0.01));
      expect(r.bestSet, 51);
      expect(r.missingSets, 3);
      expect(r.unitsRecorded, 9);
      expect(r.unitsExpected, 18);
      expect(r.progression, [46, 51, 49]);
      expect(r.scoreBuckets, {'10': 4, '9': 7});
      expect(r.rpe, 7);
      expect(r.locked, isFalse);
      expect(r.reviewFlags, isEmpty);
    });

    test('set ilerleyişinde girilmemiş set null kalıyor', () {
      // Grafikte boşluk görünmeli; 0 çizmek düşüş gibi okunurdu.
      expect(
          row(progression: const [46, null, 49]).progression, [46, null, 49]);
    });

    test('inceleme uyarıları etikete çevriliyor', () {
      final r = row(flags: const ['skor_yok', 'son_sette_dusus']);
      expect(r.needsReview, isTrue);
      expect(r.flagLabel('skor_yok'), 'Skor girmemiş');
      expect(r.flagLabel('son_sette_dusus'), 'Son sette belirgin düşüş');
      expect(r.flagLabel('bilinmeyen'), 'bilinmeyen');
    });

    test('uyarı yoksa inceleme gerekmiyor', () {
      expect(row().needsReview, isFalse);
    });

    test('basit girişte puan dağılımı boş', () {
      expect(row(buckets: const {}).scoreBuckets, isEmpty);
    });
  });

  group('Geçmiş', () {
    TrainingHistoryEntry entry({String kind = 'club', int done = 6}) =>
        TrainingHistoryEntry.fromMap({
          'session_id': 'h1',
          'kind': kind,
          'protocol_name': 'Teknik çalışma',
          'sport_code': 'okculuk',
          'started_at': '2026-09-01T17:00:00Z',
          'status': 'completed',
          'sets_done': done,
          'set_count': 6,
          'total_score': 280,
        });

    test('bireysel antrenman ayırt ediliyor', () {
      expect(entry(kind: 'personal').isPersonal, isTrue);
      expect(entry(kind: 'personal').kindLabel, 'Bireysel');
      expect(entry().kindLabel, 'Kulüp');
    });

    test('tamamlanma hesabı', () {
      expect(entry(done: 6).isComplete, isTrue);
      expect(entry(done: 4).isComplete, isFalse);
    });
  });

  group('Şablon', () {
    TrainingProtocol proto({String? clubId, int version = 1}) =>
        TrainingProtocol.fromMap({
          'id': 'p1',
          'club_id': clubId,
          'sport_code': 'okculuk',
          'name': 'Puanlı set',
          'version': version,
          'config': const {
            'set_count': 10,
            'units_per_set': 3,
            'max_unit_score': 10,
            'entry_mode': 'detailed',
            'mode': 'scored',
          },
        });

    test('platform şablonu işaretleniyor', () {
      expect(proto().isPlatformTemplate, isTrue);
      expect(proto(clubId: 'c1').isPlatformTemplate, isFalse);
    });

    test('sürüm etiketi ilk sürümde çizilmiyor', () {
      // "v1" yazmak her satıra gürültü ekler.
      expect(proto().versionLabel, isNull);
      expect(proto(version: 3).versionLabel, 'v3');
    });

    test('yapılandırma çözülüyor', () {
      expect(proto().config.setCount, 10);
      expect(proto().config.plannedUnits, 30);
      expect(proto().config.entryMode, ScoreEntryMode.detailed);
    });

    test('branş kelimeleri bağlanıyor', () {
      expect(proto().branch?.displayName, 'Okçuluk');
    });
  });

  group('Genel özet', () {
    test('alanlar okunuyor', () {
      final o = SessionOverview.fromMap({
        'joined_count': 8,
        'completed_count': 5,
        'no_score_count': 1,
        'awaiting_lock': 3,
        'team_total': 1240,
        'session_avg': 47.2,
        'units_recorded': 120,
        'units_expected': 144,
        'protocol_name': 'Müsabaka simülasyonu',
        'protocol_version': 2,
        'set_count': 12,
        'status': 'review',
      });
      expect(o.joinedCount, 8);
      expect(o.completedCount, 5);
      expect(o.noScoreCount, 1);
      expect(o.awaitingLock, 3);
      expect(o.teamTotal, 1240);
      expect(o.sessionAvg, closeTo(47.2, 0.01));
      expect(o.unitsRecorded, 120);
      expect(o.unitsExpected, 144);
      expect(o.protocolVersion, 2);
      expect(o.setCount, 12);
      expect(o.status, 'review');
    });
  });
}
