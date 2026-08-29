import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Malzeme ilanlarının veri katmanı davranışı.
///
/// Buradaki testlerin çoğu "kod ↔ enum" eşlemesini koruyor: bir tür kodu
/// yanlış çevrilirse ilan sessizce başka bir türe düşer ve kimse fark etmez.
void main() {
  Listing listing({
    ListingKind kind = ListingKind.equipmentSale,
    num? price,
    ListingCondition? condition,
    String? sportName,
    int? ageMin,
    String? position,
  }) =>
      Listing(
        id: 'l1',
        kind: kind,
        title: 'Başlık',
        ownerId: 'u1',
        ownerName: 'Sahip',
        applicationCount: 0,
        applied: false,
        canManage: false,
        createdAt: DateTime(2026, 8, 29),
        price: price,
        condition: condition,
        sportName: sportName,
        ageMin: ageMin,
        position: position,
      );

  group('ListingKind', () {
    test('her türün kodu kendine geri çözülüyor', () {
      for (final k in ListingKind.values) {
        expect(ListingKindX.fromCode(k.code), k, reason: k.name);
      }
    });

    test('bilinmeyen kod sporcu ilanına düşer, hata vermez', () {
      expect(ListingKindX.fromCode('bilinmeyen'), ListingKind.athleteWanted);
    });

    test('yalnızca malzeme türleri isEquipment', () {
      expect(ListingKind.equipmentSale.isEquipment, isTrue);
      expect(ListingKind.equipmentWanted.isEquipment, isTrue);
      expect(ListingKind.tryout.isEquipment, isFalse);
      expect(ListingKind.athleteWanted.isEquipment, isFalse);
    });

    test('her türün görünen adı dolu ve benzersiz', () {
      final labels = ListingKind.values.map((k) => k.label).toSet();
      expect(labels.length, ListingKind.values.length);
      expect(labels.any((l) => l.trim().isEmpty), isFalse);
    });
  });

  group('ListingCondition', () {
    test('kod çözümü çift yönlü', () {
      for (final c in ListingCondition.values) {
        expect(ListingConditionX.fromCode(c.code), c);
      }
    });

    test('boş ya da bilinmeyen kod null döner', () {
      expect(ListingConditionX.fromCode(null), isNull);
      expect(ListingConditionX.fromCode('kirik'), isNull);
    });
  });

  group('Listing.criteria', () {
    test('malzemede durum gösterilir, yaş ve mevki gösterilmez', () {
      final l = listing(
        condition: ListingCondition.used,
        ageMin: 12,
        position: 'Libero',
      );
      expect(l.criteria, contains('İkinci el'));
      expect(l.criteria, isNot(contains('yaş')));
      expect(l.criteria, isNot(contains('Libero')));
    });

    test('sporcu ilanında yaş ve mevki gösterilir', () {
      final l = listing(
        kind: ListingKind.athleteWanted,
        ageMin: 12,
        position: 'Libero',
      );
      expect(l.criteria, contains('yaş'));
      expect(l.criteria, contains('Libero'));
    });

    test('branş her iki tarafta da korunur', () {
      expect(listing(sportName: 'Yüzme').criteria, contains('Yüzme'));
    });

    test('hiçbir alan yoksa boş döner — ayırıcı sızmaz', () {
      expect(listing().criteria, isEmpty);
    });
  });

  group('DiscoverFilter', () {
    // Provider anahtarı olarak kullanılıyor: yeni bir alan == ve hashCode'a
    // eklenmezse filtre değişse bile Riverpod eski sonucu döndürür ve hata
    // hiçbir yerde görünmez.
    test('tür değişince eşitlik bozulur', () {
      const a = DiscoverFilter();
      final b = a.copyWith(kind: 'equipment_sale');
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('fiyat tavanı değişince eşitlik bozulur', () {
      const a = DiscoverFilter();
      final b = a.copyWith(priceMax: 5000);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('aynı değerlerle kurulan iki filtre eşit', () {
      const a = DiscoverFilter(kind: 'equipment_sale', priceMax: 5000);
      const b = DiscoverFilter(kind: 'equipment_sale', priceMax: 5000);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('clearPriceMax tavanı gerçekten siler', () {
      const a = DiscoverFilter(priceMax: 5000);
      expect(a.copyWith(clearPriceMax: true).priceMax, isNull);
    });

    test('tür ve fiyat boşken filtre boş sayılır', () {
      expect(const DiscoverFilter().isEmpty, isTrue);
      expect(const DiscoverFilter(kind: 'equipment_sale').isEmpty, isFalse);
      expect(const DiscoverFilter(priceMax: 1).isEmpty, isFalse);
    });
  });
}
