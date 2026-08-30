import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/widgets/module_launcher.dart';
import 'package:swansport_app/app/widgets/recent_modules.dart';

/// Modül menüsünün bütünlüğü.
///
/// Buradaki asıl test **"her modül bir gruba ait mi"**. Menüye modül ekleyip
/// `kModuleGroup`'a satır eklemeyi unutmak sessiz bir hata: modül "Diğer"
/// öbeğine düşüyor, kimse fark etmiyor. Bu oturumda dört modül tam olarak
/// böyle yanlış yere düştü — test bunu bir daha bırakmasın diye var.
void main() {
  group('modül-grup bütünlüğü', () {
    test('her modül bir gruba ait — hiçbiri "Diğer"e düşmüyor', () {
      final ungrouped = kAllModules
          .where((m) => !kModuleGroup.containsKey(m.$3))
          .map((m) => '${m.$2} (${m.$3})')
          .toList();

      expect(ungrouped, isEmpty,
          reason: 'Bu modüller kModuleGroup içinde yok, menüde "Diğer" '
              'öbeğine düşecek: $ungrouped');
    });

    test('grup haritasında olup menüde olmayan rota yok', () {
      final routes = kAllModules.map((m) => m.$3).toSet();
      final orphans =
          kModuleGroup.keys.where((r) => !routes.contains(r)).toList();

      expect(orphans, isEmpty,
          reason: 'Bu rotalar kModuleGroup içinde ama kAllModules içinde '
              'yok — silinmiş modülden kalmış olabilir: $orphans');
    });

    test('kullanılan her grup adı kModuleGroupOrder içinde', () {
      final unknown = kModuleGroup.values
          .toSet()
          .where((g) => !kModuleGroupOrder.contains(g))
          .toList();

      expect(unknown, isEmpty,
          reason: 'Bu gruplar sıralamada yok, menüde hiç görünmezler: '
              '$unknown');
    });

    test('aynı rota iki kez listelenmemiş', () {
      final routes = kAllModules.map((m) => m.$3).toList();
      expect(routes.length, routes.toSet().length,
          reason: 'kAllModules içinde yinelenen rota var');
    });
  });

  group('foldTr — Türkçe arama tuzağı', () {
    test('büyük İ düz i ile eşleşir', () {
      // 'İlanlar'.toLowerCase() birleşik noktalı i üretir ve kullanıcının
      // yazdığı 'ilan' ile eşleşmez. Asıl yakalanan hata bu.
      expect(foldTr('İlanlar'), 'ilanlar');
      expect(foldTr('İlanlar').contains(foldTr('ilan')), isTrue);
    });

    test('noktasız ı ile noktalı i aynı sayılır', () {
      expect(foldTr('Aranıyor'), foldTr('Araniyor'));
    });

    test('diğer Türkçe harfler katlanır', () {
      expect(foldTr('ÇĞÖŞÜ'), 'cgosu');
      expect(foldTr('çğöşü'), 'cgosu');
    });

    test('Türkçe olmayan metin bozulmaz', () {
      expect(foldTr('Panel'), 'panel');
    });
  });

  group('filterModules', () {
    test('boş sorgu hepsini döndürür', () {
      expect(filterModules(kAllModules, '').length, kAllModules.length);
      expect(filterModules(kAllModules, '   ').length, kAllModules.length);
    });

    test('"partner" yalnızca Partner Ara\'yı bulur', () {
      final r = filterModules(kAllModules, 'partner');
      expect(r.map((m) => m.$3), contains('/partner-ara'));
      expect(r.length, 1);
    });

    test('"ilan" büyük İ\'li İlanlar\'ı bulur', () {
      final r = filterModules(kAllModules, 'ilan');
      expect(r.map((m) => m.$3), contains('/ilanlar'));
    });

    test('"aidatlarim" noktasız ı\'lı Aidatlarım\'ı bulur', () {
      // Kullanıcı düz klavyeyle 'aidatlarim' yazıyor, etiket 'Aidatlarım'.
      final r = filterModules(kAllModules, 'aidatlarim');
      expect(r.map((m) => m.$3), contains('/aidatlarim'));
    });

    test('eşleşme yoksa boş liste', () {
      expect(filterModules(kAllModules, 'zzzzyok'), isEmpty);
    });
  });

  group('nextRecents', () {
    test('yeni rota başa gelir', () {
      expect(nextRecents(const ['/a', '/b'], '/c'), ['/c', '/a', '/b']);
    });

    test('zaten listedeyse kopyalanmaz, öne alınır', () {
      expect(nextRecents(const ['/a', '/b', '/c'], '/c'), ['/c', '/a', '/b']);
    });

    test('sınırda kırpılır', () {
      final full = List.generate(kRecentModuleLimit, (i) => '/m$i');
      final next = nextRecents(full, '/yeni');
      expect(next.length, kRecentModuleLimit);
      expect(next.first, '/yeni');
      // En eski düşmüş olmalı.
      expect(next, isNot(contains('/m${kRecentModuleLimit - 1}')));
    });

    test('boş listeden başlayabilir', () {
      expect(nextRecents(const [], '/a'), ['/a']);
    });
  });
}
