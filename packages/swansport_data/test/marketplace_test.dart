import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Pazaryeri modelleri.
///
/// Yetki ve RLS kuralları SQL tarafında ve buradan test edilemiyor (oturum
/// gerekiyor). Burada test edilen şey **istemcinin sunucuya ne gönderdiği**
/// ve **ne okuduğu**: kod eşlemeleri sessizce kayarsa ürün durumu yanlış
/// görünür, filtre yanlış süzer ve hiçbiri hata vermez.
void main() {
  group('kod eşlemeleri — şemayla birebir olmalı', () {
    test('ürün durumu kodları', () {
      // Bu değerler `listings_condition_valid` kısıtıyla aynı olmak zorunda;
      // ayrışırsa insert kısıt hatasıyla düşer.
      expect(ItemCondition.isNew.code, 'new');
      expect(ItemCondition.likeNew.code, 'like_new');
      expect(ItemCondition.veryGood.code, 'very_good');
      expect(ItemCondition.good.code, 'good');
      expect(ItemCondition.used.code, 'used');
    });

    test('teslim kodları', () {
      expect(DeliveryKind.hand.code, 'hand_delivery');
      expect(DeliveryKind.shipping.code, 'shipping');
      expect(DeliveryKind.both.code, 'both');
    });

    test('yaşam döngüsü kodları', () {
      expect(MarketStatus.draft.code, 'draft');
      expect(MarketStatus.active.code, 'active');
      expect(MarketStatus.reserved.code, 'reserved');
      expect(MarketStatus.sold.code, 'sold');
      expect(MarketStatus.removedByOwner.code, 'removed_by_owner');
      expect(MarketStatus.underReview.code, 'under_review');
      expect(MarketStatus.hiddenByModeration.code, 'hidden_by_moderation');
    });

    test('rapor sebebi kodları', () {
      expect(ReportReason.counterfeit.code, 'counterfeit');
      expect(ReportReason.wrongDescription.code, 'wrong_description');
      expect(ReportReason.prohibited.code, 'prohibited');
      expect(ReportReason.inappropriate.code, 'inappropriate');
    });

    test('bilinmeyen kod çökertmez', () {
      // Sunucuya yeni bir durum eklenirse eski uygulama çökmemeli.
      expect(ItemConditionX.fromCode('gelecekteki_durum'), isNull);
      expect(MarketStatusX.fromCode('gelecekteki_durum'), MarketStatus.draft);
      expect(DeliveryKindX.fromCode(null), DeliveryKind.hand);
    });
  });

  group('MarketStatus.isBuyable', () {
    test('yalnızca yayındaki ilan alınabilir', () {
      expect(MarketStatus.active.isBuyable, isTrue);
    });

    test('rezerve ve satıldı alınamaz', () {
      // İkisi de aramada görünüyor ama "satıcıya yaz" düğmesi kapalı:
      // görünmesi bilgi, tıklanabilir olması yanıltma olurdu.
      expect(MarketStatus.reserved.isBuyable, isFalse);
      expect(MarketStatus.sold.isBuyable, isFalse);
    });

    test('taslak ve moderasyon durumları alınamaz', () {
      expect(MarketStatus.draft.isBuyable, isFalse);
      expect(MarketStatus.underReview.isBuyable, isFalse);
      expect(MarketStatus.hiddenByModeration.isBuyable, isFalse);
    });
  });

  group('MarketItem', () {
    test('arama satırını okur', () {
      final it = MarketItem.fromMap({
        'id': 'l1',
        'title': 'Nike krampon',
        'price': 1500,
        'item_condition': 'like_new',
        'seller_type': 'verified_store',
        'store_id': 's1',
        'store_name': 'Konya Spor',
        'city_code': '42',
        'district': 'Selçuklu',
        'delivery': 'both',
        'market_status': 'active',
        'created_at': '2026-09-01T10:00:00Z',
      });

      expect(it.price, 1500);
      expect(it.condition, ItemCondition.likeNew);
      expect(it.isStore, isTrue);
      expect(it.placeLabel, 'Selçuklu, 42');
      expect(it.status.isBuyable, isTrue);
    });

    test('bireysel satıcı mağaza sayılmaz', () {
      final it = MarketItem.fromMap({
        'id': 'l2',
        'title': 'Raket',
        'seller_type': 'individual',
        'market_status': 'active',
        'created_at': '2026-09-01T10:00:00Z',
      });
      expect(it.isStore, isFalse);
      expect(it.price, isNull);
    });

    test('eksik alan çökertmez', () {
      final it = MarketItem.fromMap({
        'id': 'l3',
        'created_at': '2026-09-01T10:00:00Z',
      });
      expect(it.title, '');
      expect(it.placeLabel, '');
      expect(it.status, MarketStatus.draft);
    });
  });

  group('MarketFilter', () {
    test('boş filtre boş sayılır', () {
      expect(const MarketFilter().isEmpty, isTrue);
    });

    test('tek bir alan doluysa boş değil', () {
      expect(const MarketFilter(query: 'krampon').isEmpty, isFalse);
      expect(const MarketFilter(condition: ItemCondition.isNew).isEmpty, isFalse);
    });

    test('sıralama tek başına filtre sayılmaz', () {
      // Sıralama değiştirmek "filtre uygulandı" demek değil; ekrandaki
      // temizle düğmesi bu ayrıma bakıyor.
      expect(const MarketFilter(sort: 'price_asc').isEmpty, isTrue);
    });

    test('copyWith bir alanı null yapabilir', () {
      // Nöbetçi değer olmasa bir filtreyi temizlemek mümkün olmazdı:
      // `copyWith(condition: null)` "değiştirme" ile aynı görünürdü.
      const f = MarketFilter(condition: ItemCondition.isNew, query: 'a');
      final cleared = f.copyWith(condition: null);
      expect(cleared.condition, isNull);
      expect(cleared.query, 'a', reason: 'diğer alanlar korunmalı');
    });

    test('copyWith dokunulmayan alanı korur', () {
      const f = MarketFilter(query: 'krampon', city: '42');
      expect(f.copyWith(sort: 'price_asc').query, 'krampon');
      expect(f.copyWith(sort: 'price_asc').city, '42');
    });
  });

  group('StoreRow', () {
    test('yalnızca onaylı mağaza satabilir', () {
      expect(
        StoreRow.fromMap(const {'id': 's', 'name': 'X', 'status': 'approved'})
            .isApproved,
        isTrue,
      );
      for (final s in ['pending', 'rejected', 'suspended']) {
        expect(
          StoreRow.fromMap({'id': 's', 'name': 'X', 'status': s}).isApproved,
          isFalse,
          reason: '$s durumundaki mağaza satamaz',
        );
      }
    });

    test('ret notu taşınıyor', () {
      // Sebebini bilmeyen başvuran aynı başvuruyu tekrar gönderiyor.
      final s = StoreRow.fromMap(const {
        'id': 's',
        'name': 'X',
        'status': 'rejected',
        'review_note': 'Mağaza adı gerçek bir işletmeye ait değil',
      });
      expect(s.reviewNote, isNotEmpty);
      expect(s.statusLabel, 'Reddedildi');
    });
  });
}
