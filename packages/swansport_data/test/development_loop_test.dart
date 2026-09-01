import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Gelişim döngüsü (0044).
///
/// Buradaki iki mantık da sessizce yanlış olabilir: ön-doldurma yanlış tahmin
/// ederse katılım verisi bozulur, hedef ölçüme bağlanmazsa ilerleme donar.
/// İkisi de ekrana bakınca "çalışıyor" görünür.
void main() {
  group('RosterEntry.suggested — yoklama ön-doldurma', () {
    RosterEntry e({String? rsvp, String? attendance}) => RosterEntry(
          athleteId: 'a1',
          fullName: 'Emir Ölmez',
          rsvp: rsvp,
          attendance: attendance,
        );

    test('"katılıyorum" → Var', () {
      expect(e(rsvp: 'attending').suggested, 'present');
    });

    test('"gelemem" → Yok', () {
      expect(e(rsvp: 'unavailable').suggested, 'absent');
    });

    test('"belirsiz" boş bırakılır', () {
      // Belirsiz gerçekten belirsiz: antrenör karar versin.
      expect(e(rsvp: 'uncertain').suggested, isNull);
    });

    test('YANIT VERMEYEN boş bırakılır, "Var" sayılmaz', () {
      // Eski ekran herkesi varsayılan `present` işaretliyordu. Antrenör
      // gelmeyenleri kaldırmayı unuttuğunda katılım olduğundan yüksek
      // görünüyordu — bu, üstüne kurulacak her performans ölçümünü bozar.
      expect(e().suggested, isNull);
    });

    test('kaydedilmiş yoklama RSVP tahminini EZER', () {
      // Antrenör "geldi demişti ama gelmedi" diye düzelttiyse, o karar
      // tahmine yenilmemeli.
      expect(e(rsvp: 'attending', attendance: 'absent').suggested, 'absent');
    });

    test('kaydedilmiş yoklama tek başına da geçerli', () {
      expect(e(attendance: 'late').suggested, 'late');
    });
  });

  group('DevelopmentGoal.isMeasured — ölçülebilir hedef', () {
    DevelopmentGoal g({String? test, double? base, double? target}) =>
        DevelopmentGoal(
          id: 'g1',
          athleteId: 'a1',
          title: 'Sprint hızını geliştir',
          category: 'surat',
          progress: 0,
          status: 'active',
          testName: test,
          baselineValue: base,
          targetValue: target,
        );

    test('üçü de doluysa ölçülebilir', () {
      expect(g(test: '30 m sprint', base: 4.8, target: 4.4).isMeasured, isTrue);
    });

    test('yarısı dolu hedef ölçülebilir SAYILMAZ', () {
      // Yarısı dolu bir hedef ilerleme hesaplayamaz ama arayüzde
      // hesaplanıyormuş gibi görünürdü. Şema da bunu kısıtlıyor.
      expect(g(test: '30 m sprint').isMeasured, isFalse);
      expect(g(test: '30 m sprint', base: 4.8).isMeasured, isFalse);
      expect(g(base: 4.8, target: 4.4).isMeasured, isFalse);
    });

    test('ölçüme bağlı olmayan hedef eskisi gibi çalışır', () {
      // Mevcut hedefler bozulmamalı: ikisi bir arada yaşıyor.
      expect(g().isMeasured, isFalse);
    });
  });

  group('ilerleme yönü', () {
    // SQL tarafındaki `goal_progress` ile aynı formül. Burada tutulmasının
    // sebebi yönün kolayca ters çevrilebilmesi: sprintte küçük değer iyidir,
    // sıçramada büyük. Ters çevrilirse ekranda "%0 ilerleme" diye görünür ve
    // sporcu gelişmediğini sanır.
    int progress(double base, double target, double current, bool lowerBetter) {
      final r = lowerBetter
          ? (base - current) / (base - target)
          : (current - base) / (target - base);
      return (r * 100).round().clamp(0, 100);
    }

    test('küçük iyidir (sprint): süre düşünce ilerleme artar', () {
      expect(progress(4.8, 4.4, 4.8, true), 0);
      expect(progress(4.8, 4.4, 4.6, true), 50);
      expect(progress(4.8, 4.4, 4.4, true), 100);
    });

    test('büyük iyidir (sıçrama): mesafe artınca ilerleme artar', () {
      expect(progress(2.00, 2.40, 2.00, false), 0);
      expect(progress(2.00, 2.40, 2.20, false), 50);
      expect(progress(2.00, 2.40, 2.40, false), 100);
    });

    test('hedefi aşmak %100 üstüne çıkmaz', () {
      expect(progress(4.8, 4.4, 4.0, true), 100);
    });

    test('geriye gitmek eksiye düşmez', () {
      expect(progress(4.8, 4.4, 5.2, true), 0);
    });
  });
}
