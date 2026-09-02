import 'package:swansport_branch_engine/swansport_branch_engine.dart';
import 'package:test/test.dart';

/// Aşama makinesi ve sayaç.
///
/// Buradaki örnekler `training_next_phase` (0072) ile **aynı** olmalı.
/// İki tarafta iki ayrı otorite yok: sunucu karar veriyor, bu tablo yalnızca
/// önizleme çiziyor. Yine de kaymasınlar diye aynı örneklerle sınanıyorlar.
void main() {
  // Ok toplama ve dinlenme dolu — bütün aşamalar var.
  final full = const TrainingProtocolConfig(
    setCount: 3,
    unitsPerSet: 6,
    prepSeconds: 20,
    shootSeconds: 120,
    collectSeconds: 40,
    restSeconds: 60,
    maxUnitScore: 10,
    entryMode: ScoreEntryMode.detailed,
    mode: TrainingMode.scored,
  ).toMap();

  // Ok toplama ve dinlenme sıfır — ikisi de atlanmalı.
  final lean = const TrainingProtocolConfig(
    setCount: 2,
    unitsPerSet: 3,
    prepSeconds: 10,
    shootSeconds: 60,
    collectSeconds: 0,
    restSeconds: 0,
    maxUnitScore: 10,
    entryMode: ScoreEntryMode.simple,
    mode: TrainingMode.technique,
  ).toMap();

  group('aşama sırası', () {
    test('tam protokolde sıra eksiksiz ilerliyor', () {
      expect(nextPhase(SessionPhase.prep, 1, full),
          const PhaseStep(SessionPhase.shoot, 1));
      expect(nextPhase(SessionPhase.shoot, 1, full),
          const PhaseStep(SessionPhase.collect, 1));
      expect(nextPhase(SessionPhase.collect, 1, full),
          const PhaseStep(SessionPhase.score, 1));
      expect(nextPhase(SessionPhase.score, 1, full),
          const PhaseStep(SessionPhase.rest, 1));
      expect(nextPhase(SessionPhase.rest, 1, full),
          const PhaseStep(SessionPhase.prep, 2));
    });

    test('ok toplama süresi 0 ise atlanıyor', () {
      // Sıfır saniyelik aşama ekranda bir kare titreyip geçen adım olurdu.
      expect(nextPhase(SessionPhase.shoot, 1, lean),
          const PhaseStep(SessionPhase.score, 1));
    });

    test('dinlenme 0 ise doğrudan sonraki setin hazırlığına', () {
      expect(nextPhase(SessionPhase.score, 1, lean),
          const PhaseStep(SessionPhase.prep, 2));
    });

    test('son sette skordan sonra oturum bitiyor', () {
      expect(nextPhase(SessionPhase.score, 3, full),
          const PhaseStep(SessionPhase.done, 3));
      expect(nextPhase(SessionPhase.score, 2, lean),
          const PhaseStep(SessionPhase.done, 2));
    });

    test('bitmiş oturum bitmiş kalıyor', () {
      expect(nextPhase(SessionPhase.done, 3, full),
          const PhaseStep(SessionPhase.done, 3));
    });
  });

  group('aşama süreleri', () {
    test('yapılandırmadan okunuyor', () {
      expect(phaseSeconds(SessionPhase.prep, full), 20);
      expect(phaseSeconds(SessionPhase.shoot, full), 120);
      expect(phaseSeconds(SessionPhase.collect, full), 40);
      expect(phaseSeconds(SessionPhase.rest, full), 60);
    });

    test('skor girişi süresiz', () {
      // Sayaçla sınırlansaydı yarım kalan giriş kaydedilemezdi.
      expect(phaseSeconds(SessionPhase.score, full), isNull);
      expect(phaseSeconds(SessionPhase.done, full), isNull);
    });
  });

  group('sayaç', () {
    final ends = DateTime.utc(2026, 9, 2, 10, 5, 0);

    test('kalan süre iki zaman damgasının farkı', () {
      final now = DateTime.utc(2026, 9, 2, 10, 0, 30);
      expect(remaining(endsAt: ends, now: now),
          const Duration(minutes: 4, seconds: 30));
    });

    test('arka plandan uzun süre sonra dönmek sayacı ileri taşımıyor', () {
      // Geri sayan bir sayıcı tutsaydık burada 4 dakika kalmış gibi
      // görünürdü. Zaman damgası yalan söylemiyor.
      final now = DateTime.utc(2026, 9, 2, 10, 4, 0);
      expect(remaining(endsAt: ends, now: now), const Duration(minutes: 1));
    });

    test('süre geçmişse negatif değil sıfır', () {
      final now = DateTime.utc(2026, 9, 2, 10, 9, 0);
      expect(remaining(endsAt: ends, now: now), Duration.zero);
    });

    test('duraklatılmışken kalan süre donuyor', () {
      final paused = DateTime.utc(2026, 9, 2, 10, 2, 0);
      final now = DateTime.utc(2026, 9, 2, 10, 4, 30);
      expect(remaining(endsAt: ends, now: now, pausedAt: paused),
          const Duration(minutes: 3));
    });

    test('süresiz aşamada sayaç yok', () {
      expect(remaining(endsAt: null, now: DateTime.utc(2026)), isNull);
    });

    test('süre dolduğunda işaretleniyor ama ilerletme kararı verilmiyor', () {
      // Fonksiyon yalnızca "doldu" diyor; ne yapılacağına insan karar
      // veriyor. Sahte durum üretmek en tehlikeli seçenekti.
      expect(phaseExpired(endsAt: ends, now: DateTime.utc(2026, 9, 2, 10, 6)),
          isTrue);
      expect(phaseExpired(endsAt: ends, now: DateTime.utc(2026, 9, 2, 10, 4)),
          isFalse);
      expect(phaseExpired(endsAt: null, now: DateTime.utc(2026)), isFalse);
    });

    test('duraklatılmış oturumda süre dolmuş sayılmıyor', () {
      final paused = DateTime.utc(2026, 9, 2, 10, 1, 0);
      final now = DateTime.utc(2026, 9, 2, 11, 0, 0);
      expect(phaseExpired(endsAt: ends, now: now, pausedAt: paused), isFalse);
    });

    test('biçimlendirme', () {
      expect(formatRemaining(const Duration(minutes: 4, seconds: 5)), '04:05');
      expect(formatRemaining(Duration.zero), '00:00');
      expect(formatRemaining(const Duration(seconds: 605)), '10:05');
    });
  });

  group('aşama okuma', () {
    test('sunucudaki metinden', () {
      expect(SessionPhase.parse('collect'), SessionPhase.collect);
      expect(SessionPhase.parse('done'), SessionPhase.done);
    });

    test('tanınmayan değer hazırlığa düşüyor, bitmişe değil', () {
      // Bilinmeyen aşamada oturumu "bitti" saymak sporcunun ekranını
      // sessizce kapatırdı.
      expect(SessionPhase.parse('bilinmeyen'), SessionPhase.prep);
      expect(SessionPhase.parse(null), SessionPhase.prep);
    });

    test('skor yalnızca uygun aşamalarda giriliyor', () {
      expect(SessionPhase.score.acceptsScore, isTrue);
      expect(SessionPhase.rest.acceptsScore, isTrue);
      expect(SessionPhase.shoot.acceptsScore, isFalse);
    });
  });
}
