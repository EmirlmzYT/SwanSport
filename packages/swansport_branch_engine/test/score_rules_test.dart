import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:test/test.dart';

/// Skor kuralları.
///
/// En önemli iddia: **eksik ≠ sıfır**. Girilmeyen değer `null` kalıyor.
/// Sıfır yazmak sporcuyu hiç atmamış gibi değil kötü atmış gibi gösterirdi.
void main() {
  group('tek atış', () {
    test('aralık içi kabul', () {
      expect(checkUnitScore(10, maxUnitScore: 10).isValid, isTrue);
      expect(checkUnitScore(0, maxUnitScore: 10).isValid, isTrue);
    });

    test('aralık dışı reddediliyor', () {
      expect(checkUnitScore(11, maxUnitScore: 10).isValid, isFalse);
      expect(checkUnitScore(-1, maxUnitScore: 10).isValid, isFalse);
    });

    test('atılmamış ok geçerli', () {
      // null = ok atılmadı. Bu bir hata değil, bir gerçek.
      expect(checkUnitScore(null, maxUnitScore: 10).isValid, isTrue);
    });

    test('hata metni azami puanı söylüyor', () {
      expect(checkUnitScore(11, maxUnitScore: 10).error, contains('10'));
    });
  });

  group('set toplamı', () {
    test('protokolün üst sınırını aşamıyor', () {
      // 6 ok x 10 puan = 60
      expect(
          checkSetTotal(60, unitsPerSet: 6, maxUnitScore: 10).isValid, isTrue);
      expect(
          checkSetTotal(61, unitsPerSet: 6, maxUnitScore: 10).isValid, isFalse);
    });

    test('girilmemiş toplam geçerli', () {
      expect(checkSetTotal(null, unitsPerSet: 6, maxUnitScore: 10).isValid,
          isTrue);
    });
  });

  group('atış listesi', () {
    test('protokoldeki ok sayısını aşamıyor', () {
      expect(
          checkEntries([10, 9, 8, 7], unitsPerSet: 3, maxUnitScore: 10).isValid,
          isFalse);
      expect(checkEntries([10, 9, 8], unitsPerSet: 3, maxUnitScore: 10).isValid,
          isTrue);
    });

    test('eksik ok içeren liste geçerli', () {
      expect(
          checkEntries([10, null, 8], unitsPerSet: 3, maxUnitScore: 10).isValid,
          isTrue);
    });

    test('listedeki aralık dışı puan yakalanıyor', () {
      expect(checkEntries([10, 12], unitsPerSet: 3, maxUnitScore: 10).isValid,
          isFalse);
    });
  });

  group('toplama — eksik sıfır değil', () {
    test('dolu atışlar toplanıyor', () {
      expect(sumEntries([10, 9, 8]), 27);
    });

    test('eksik ok toplamı düşürmüyor', () {
      // 10 + 8 = 18. Ortadaki null'ı 0 saysaydık yine 18 çıkardı ama
      // `unit_count` yalan söylerdi: 3 ok atılmış görünürdü.
      expect(sumEntries([10, null, 8]), 18);
      expect(countEntries([10, null, 8]), 2);
    });

    test('hiç atış yoksa toplam null — sıfır DEĞİL', () {
      // Bu testin tek işi o farkı korumak. `0` dönseydi sporcu "0 puan
      // aldı" gibi görünürdü.
      expect(sumEntries([null, null]), isNull);
      expect(sumEntries([]), isNull);
      expect(countEntries([null, null]), 0);
    });

    test('eksik set işaretleniyor', () {
      expect(isSetMissing(null), isTrue);
      expect(isSetMissing(0), isFalse);
    });
  });

  group('giriş biçimi', () {
    test('okuma', () {
      expect(ScoreEntryMode.parse('detailed'), ScoreEntryMode.detailed);
      expect(ScoreEntryMode.parse('flexible'), ScoreEntryMode.flexible);
      expect(ScoreEntryMode.parse(null), ScoreEntryMode.simple);
    });

    test('hangi biçim neye izin veriyor', () {
      expect(ScoreEntryMode.simple.allowsDetailed, isFalse);
      expect(ScoreEntryMode.simple.allowsTotalOnly, isTrue);
      expect(ScoreEntryMode.detailed.allowsDetailed, isTrue);
      expect(ScoreEntryMode.detailed.allowsTotalOnly, isFalse);
      expect(ScoreEntryMode.flexible.allowsDetailed, isTrue);
      expect(ScoreEntryMode.flexible.allowsTotalOnly, isTrue);
    });
  });

  group('protokol yapılandırması', () {
    test('sunucudan gelen jsonb okunuyor', () {
      final c = TrainingProtocolConfig.fromMap(const {
        'set_count': 10,
        'units_per_set': 3,
        'prep_seconds': 10,
        'shoot_seconds': 120,
        'collect_seconds': 45,
        'rest_seconds': 30,
        'max_unit_score': 10,
        'entry_mode': 'detailed',
        'mode': 'scored',
      });
      expect(c.setCount, 10);
      expect(c.plannedUnits, 30);
      expect(c.maxSetScore, 30);
      expect(c.entryMode, ScoreEntryMode.detailed);
      expect(c.mode, TrainingMode.scored);
      expect(c.hasRest, isTrue);
      expect(c.hasCollect, isTrue);
    });

    test('eksik alan çökertmiyor', () {
      final c = TrainingProtocolConfig.fromMap(const {'set_count': 4});
      expect(c.setCount, 4);
      expect(c.maxUnitScore, 10);
      expect(c.entryMode, ScoreEntryMode.simple);
    });

    test('sıfır süreli aşamalar işaretleniyor', () {
      final c = TrainingProtocolConfig.fromMap(
          const {'collect_seconds': 0, 'rest_seconds': 0});
      expect(c.hasCollect, isFalse);
      expect(c.hasRest, isFalse);
    });

    test('teknik çalışmada puan ikincil', () {
      expect(TrainingMode.technique.scoreMatters, isFalse);
      expect(TrainingMode.scored.scoreMatters, isTrue);
    });
  });

  group('ritim', () {
    test('yalnızca kişisel ritimde sporcu aşamayı ilerletiyor', () {
      expect(SessionRhythm.individual.athleteControlsPhase, isTrue);
      expect(SessionRhythm.shared.athleteControlsPhase, isFalse);
      expect(SessionRhythm.mixed.athleteControlsPhase, isFalse);
    });
  });

  group('branş tanımı', () {
    test('okçuluk motorun kelimelerini branşa çeviriyor', () {
      const a = ArcheryDefinition();
      expect(a.code, 'okculuk');
      expect(a.unitLabel, 'ok');
      expect(branchByCode('okculuk'), isA<ArcheryDefinition>());
    });

    test('tanınmayan branş null — çağıran genel kelime kullanıyor', () {
      expect(branchByCode('kriket'), isNull);
      expect(branchByCode(null), isNull);
    });
  });
}
