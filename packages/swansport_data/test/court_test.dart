import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Kort sırasının veri katmanı.
///
/// Buradaki testlerin işi sayı doğrulamak değil, **sessiz bozulmayı**
/// yakalamak: mesafe hesabı yanlışsa kimse kortta olduğunu doğrulayamaz ve
/// hata hiçbir yerde görünmez, sadece kimse sistemi kullanamaz.
void main() {
  group('metersBetween', () {
    test('aynı nokta sıfır metre', () {
      expect(metersBetween(37.874641, 32.492500, 37.874641, 32.492500),
          closeTo(0, 0.001));
    });

    test('Konya Millet Bahçesi ile Şefikcan Parkı arası makul', () {
      // İki gerçek nokta; kilometrelerce uzaklar, aynı kort sayılmamalılar.
      final d = metersBetween(37.874641, 32.492500, 37.866000, 32.470000);
      expect(d, greaterThan(1500));
      expect(d, lessThan(3500));
    });

    test('yaklaşık 111 metre kuzeye 0.001 derece', () {
      // Enlemde 0.001 derece ≈ 111 m. Yarıçapımız 150 m olduğu için bu
      // aralığın doğru olması doğrudan "kortta sayılır mıyım"ı belirliyor.
      final d = metersBetween(37.870000, 32.490000, 37.871000, 32.490000);
      expect(d, closeTo(111, 3));
    });

    test('simetrik — yön değişince mesafe değişmez', () {
      final a = metersBetween(37.87, 32.49, 37.88, 32.50);
      final b = metersBetween(37.88, 32.50, 37.87, 32.49);
      expect(a, closeTo(b, 0.0001));
    });

    test('150 metrelik yarıçap ayrımı doğru tarafta', () {
      // ~55 m: kortta sayılmalı. ~333 m: sayılmamalı.
      expect(metersBetween(37.870000, 32.490000, 37.870500, 32.490000),
          lessThan(150));
      expect(metersBetween(37.870000, 32.490000, 37.873000, 32.490000),
          greaterThan(150));
    });
  });

  group('SwanAccess.verificationTier', () {
    test('kademeler doğru sırada', () {
      expect(SwanAccess.rankOf('none'), 0);
      expect(SwanAccess.rankOf('location'), 1);
      expect(SwanAccess.rankOf('phone'), 2);
      expect(SwanAccess.rankOf('id'), 3);
    });

    test('bilinmeyen kademe en alta düşer — kapı açık kalmaz', () {
      expect(SwanAccess.rankOf('uydurma'), 0);
      expect(SwanAccess.rankOf(''), 0);
    });

    SwanAccess withTier(String tier) => SwanAccess(
          isPlatformAdmin: false,
          clubRole: null,
          coachLevel: 0,
          athleteKind: null,
          verificationTier: tier,
        );

    test('doğrulanmamış hesap sıra alamaz', () {
      expect(withTier('none').hasVerificationTier('location'), isFalse);
    });

    test('konumla doğrulanmış hesap sıra alabilir', () {
      expect(withTier('location').hasVerificationTier('location'), isTrue);
    });

    test('üst kademe alt kademenin yerine geçer', () {
      // Belgeyle 'id' olmuş biri korta gitmeden de sıra alabilmeli.
      expect(withTier('id').hasVerificationTier('location'), isTrue);
      expect(withTier('phone').hasVerificationTier('location'), isTrue);
    });

    test('varsayılan hesap doğrulanmamış sayılır', () {
      expect(SwanAccess.none.verificationTier, 'none');
      expect(SwanAccess.none.hasVerificationTier('location'), isFalse);
    });
  });

  group('Court', () {
    Court court({double? distance}) => Court(
          id: 'c1',
          name: 'Millet Bahçesi Kort 1',
          lat: 37.874641,
          lng: 32.492500,
          opensAt: '08:00',
          closesAt: '23:00',
          capacity: 4,
          venue: 'Millet Bahçesi',
          cityName: 'Konya',
          district: 'Selçuklu',
          distanceMeters: distance,
        );

    test('mesafe bilinmiyorsa etiket boş — "0 m" yazmaz', () {
      expect(court().distanceLabel, isEmpty);
    });

    test('bir kilometrenin altı metre olarak yazılır', () {
      expect(court(distance: 340).distanceLabel, '340 m');
    });

    test('bir kilometrenin üstü virgüllü kilometre', () {
      expect(court(distance: 1240).distanceLabel, '1,2 km');
    });

    test('konum listesi sıralarken kortun kendisi değişmez', () {
      final c = court();
      expect(c.withDistance(500).distanceMeters, 500);
      expect(c.distanceMeters, isNull);
      expect(c.withDistance(500).name, c.name);
    });

    test('yer etiketi ilçe ve şehri birleştirir', () {
      expect(court().where, 'Selçuklu, Konya');
    });
  });

  group('TimelineSlot', () {
    TimelineSlot slot({String? slotId, String status = 'free', int needed = 0}) =>
        TimelineSlot(
          startsAt: DateTime(2026, 8, 29, 15),
          status: status,
          needed: needed,
          players: 0,
          mine: false,
          slotId: slotId,
        );

    test('kutu kimliği yoksa boş sayılır', () {
      expect(slot().isFree, isTrue);
      expect(slot(slotId: 's1', status: 'claimed').isFree, isFalse);
    });

    test('yalnızca active durumu oynanıyor demek', () {
      expect(slot(slotId: 's1', status: 'active').isPlaying, isTrue);
      expect(slot(slotId: 's1', status: 'claimed').isPlaying, isFalse);
    });

    test('oyuncu aranıyor bayrağı sayıya bağlı', () {
      expect(slot(slotId: 's1', needed: 1).lookingForPlayers, isTrue);
      expect(slot(slotId: 's1').lookingForPlayers, isFalse);
    });

    test('saat etiketi iki haneli', () {
      expect(slot().hourLabel, '15:00');
      expect(
          TimelineSlot(
            startsAt: DateTime(2026, 8, 29, 9),
            status: 'free',
            needed: 0,
            players: 0,
            mine: false,
          ).hourLabel,
          '09:00');
    });
  });

  group('OpenSlot', () {
    test('kalan oyuncu sayısı negatife düşmez', () {
      final s = OpenSlot(
        slotId: 's1',
        courtId: 'c1',
        courtName: 'Kort 1',
        startsAt: DateTime(2026, 8, 29, 15),
        ownerId: 'u1',
        ownerName: 'Emir',
        needed: 2,
        accepted: 3, // sunucu tarafı buna izin vermez ama arayüz çökmemeli
        requested: false,
      );
      expect(s.remaining, 0);
    });

    test('kalan oyuncu doğru hesaplanıyor', () {
      final s = OpenSlot(
        slotId: 's1',
        courtId: 'c1',
        courtName: 'Kort 1',
        startsAt: DateTime(2026, 8, 29, 15),
        ownerId: 'u1',
        ownerName: 'Emir',
        needed: 3,
        accepted: 1,
        requested: false,
      );
      expect(s.remaining, 2);
    });
  });
}
