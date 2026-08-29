import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Halı saha doluluk panosu — veri katmanı.
///
/// Bu ekranın tek işi doğru bilgi göstermek: yanlış "boş" yazan bir hücre
/// birini boşuna telefon ettirir, yanlış "dolu" yazan bir hücre gerçek bir
/// müşteriyi kaçırır. Testler bu iki yönü de kapsıyor.
void main() {
  group('TurfField', () {
    TurfField field({double? distance, double? lat, double? lng}) => TurfField(
          id: 'f1',
          name: 'Saha 1',
          venueName: 'Yıldız Halı Saha',
          opensAt: '08:00',
          closesAt: '24:00',
          district: 'Selçuklu',
          cityName: 'Konya',
          lat: lat,
          lng: lng,
          distanceMeters: distance,
        );

    test('konum yoksa mesafe etiketi boş', () {
      expect(field().distanceLabel, isEmpty);
    });

    test('bir kilometrenin altı metre olarak yazılır', () {
      expect(field(distance: 420).distanceLabel, '420 m');
    });

    test('bir kilometrenin üstü virgüllü kilometre', () {
      expect(field(distance: 2350).distanceLabel, '2,4 km');
    });

    test('yer etiketi ilçe ve şehri birleştirir', () {
      expect(field().where, 'Selçuklu, Konya');
    });

    test('withDistance orijinal alanı değiştirmez', () {
      final f = field(lat: 37.87, lng: 32.49);
      final withD = f.withDistance(500);
      expect(f.distanceMeters, isNull);
      expect(withD.distanceMeters, 500);
      expect(withD.name, f.name);
    });

    test('koordinat yoksa null kalır — konsolda boş bırakılabilir alan', () {
      final f = field();
      expect(f.lat, isNull);
      expect(f.lng, isNull);
    });
  });

  group('TurfField.fromMap', () {
    test('lat/lng eksikse hata vermeden null döner', () {
      final f = TurfField.fromMap({
        'id': 'f1',
        'name': 'Saha 1',
        'venue_name': 'Yıldız Halı Saha',
        'opens_at': '08:00:00',
        'closes_at': '24:00:00',
      });
      expect(f.lat, isNull);
      expect(f.lng, isNull);
    });

    test('saat alanı saniyesiz kısaltılır', () {
      final f = TurfField.fromMap({
        'id': 'f1',
        'name': 'Saha 1',
        'venue_name': 'Yıldız Halı Saha',
        'opens_at': '08:00:00',
        'closes_at': '24:00:00',
      });
      expect(f.opensAt, '08:00');
      expect(f.closesAt, '24:00');
    });
  });

  group('TurfSlot', () {
    test('fromMap occupied bayrağını doğru okur', () {
      final busy = TurfSlot.fromMap({
        'starts_at': '2026-08-30T18:00:00Z',
        'occupied': true,
        'note': 'Ahmet - haftalık',
      });
      final free = TurfSlot.fromMap({
        'starts_at': '2026-08-30T19:00:00Z',
        'occupied': false,
        'note': null,
      });
      expect(busy.occupied, isTrue);
      expect(busy.note, 'Ahmet - haftalık');
      expect(free.occupied, isFalse);
      expect(free.note, isNull);
    });

    test('occupied alanı eksikse boş sayılır — yanlışlıkla dolu gösterip '
        'gerçek müşteriyi kaçırmamalı', () {
      final s = TurfSlot.fromMap({'starts_at': '2026-08-30T18:00:00Z'});
      expect(s.occupied, isFalse);
    });

    test('saat etiketi iki haneli', () {
      final s = TurfSlot(
          startsAt: DateTime(2026, 8, 30, 9), occupied: false);
      expect(s.hourLabel, '09:00');
    });
  });

  group('SwanAccess.isTurfManagerOf', () {
    SwanAccess withManaged(Set<String> ids) => SwanAccess(
          isPlatformAdmin: false,
          clubRole: null,
          coachLevel: 0,
          athleteKind: null,
          managedTurfFieldIds: ids,
        );

    test('yönetilen sahada true döner', () {
      expect(withManaged({'f1', 'f2'}).isTurfManagerOf('f1'), isTrue);
    });

    test('yönetilmeyen sahada false döner', () {
      expect(withManaged({'f1'}).isTurfManagerOf('f9'), isFalse);
    });

    test('varsayılan hesap hiçbir sahayı yönetmez', () {
      expect(SwanAccess.none.isTurfManagerOf('f1'), isFalse);
    });
  });
}
