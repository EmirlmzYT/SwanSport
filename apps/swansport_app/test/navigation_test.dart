import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Gezinme bütünlüğü.
///
/// **Neden dosya okuyarak test ediyor:** rota tablosu `MaterialApp` içinde
/// gömülü; onu çalıştırmadan okumanın tek yolu kaynağı taramak. Kırılganlığı
/// kabul ediyorum çünkü koruduğu şey daha değerli: 34 girişlik modül menüsü
/// silindi ve **rotaların erişilebilirliği artık Keşfet ile Profil > Yönetim'e
/// bağlı.** Oradan bir satır düşerse rota tanımlı kalır ama hiçbir yerden
/// açılamaz — sessiz kayıp. Bu test onu yakalıyor.
void main() {
  final root = Directory.current.path;
  String read(String rel) => File('$root/$rel').readAsStringSync();

  final routes = read('lib/app/swansport_app.dart');
  final explore = read('lib/features/network/presentation/explore_screen.dart');
  final management =
      read('lib/features/social/presentation/widgets/management_section.dart');
  final nav = read('lib/app/widgets/swan_bottom_nav.dart');
  final createSheet = read('lib/app/widgets/create_sheet.dart');
  // Profil'deki kişisel kısayollar (Aidatlarım / Belgelerim / Doğrulama).
  final profile = read('lib/features/social/presentation/profile_screen.dart');

  /// Bir kullanıcının menüsüz ulaşabilmesi gereken her rota.
  ///
  /// Ekran içinden açılan alt sayfalar (`/sohbet`, `/kort` gibi) burada yok —
  /// onların girişi kendi bağlamında.
  const reachable = [
    // Alt gezinme
    '/akis', '/kesfet', '/mesajlar', '/profil',
    // Keşfet
    '/kortlar', '/partner-ara', '/ilanlar', '/kulupler', '/topluluklar',
    '/organizasyonlar',
    // Profil > Yönetim
    '/athletes', '/teams', '/calendar', '/attendance', '/devam-durumu',
    '/announcements', '/performance-analytics', '/home-command',
    '/finans', '/gider-ekle', '/reports', '/medical-center', '/facilities',
    '/onay-paneli', '/haber-kaynaklari', '/federasyon-yetkili',
    '/configuration', '/bagis', '/basvurular', '/veli-bagla', '/settings',
    // Profil kısayolları
    '/aidatlarim', '/documents', '/dogrulama',
  ];

  group('rota bütünlüğü', () {
    test('erişilebilir sayılan her rota tanımlı', () {
      final missing =
          reachable.where((r) => !routes.contains("'$r'")).toList();
      expect(missing, isEmpty,
          reason: 'Bu rotalar swansport_app.dart içinde tanımlı değil: '
              '$missing');
    });

    test('her rotanın bir giriş noktası var', () {
      // Menü silindi; giriş noktaları artık bu dört dosya.
      final entryPoints =
          explore + management + nav + createSheet + profile;
      final orphans =
          reachable.where((r) => !entryPoints.contains("'$r'")).toList();

      expect(orphans, isEmpty,
          reason: 'Bu rotalar tanımlı ama hiçbir yerden açılamıyor — '
              'Keşfet ya da Profil > Yönetim listesinden düşmüş olabilir: '
              '$orphans');
    });
  });

  group('alt gezinme sözleşmesi', () {
    test('tam dört sekme, tam bu rotalar', () {
      // Brief §3: "maksimum 5 öğe" (dört sekme + ortadaki oluştur).
      // Beşinci sekmeyi eklemek kolay, sonuç yine katalog olur.
      const expected = ['/akis', '/kesfet', '/mesajlar', '/profil'];
      final navRoutes = RegExp(r"'(/[a-z-]+)'")
          .allMatches(nav)
          .map((m) => m.group(1)!)
          .toSet();

      expect(navRoutes, unorderedEquals(expected),
          reason: 'Alt gezinme tam bu dört rotayı göstermeli');
      expect(nav.contains('_CreateButton'), isTrue,
          reason: 'Ortadaki oluştur düğmesi kaybolmuş');
    });

    test('rol-uyarlamalı yuvalar geri gelmemiş', () {
      // Eskiden ikinci ve dördüncü sekme role göre değişiyordu; aynı konum
      // kişiden kişiye farklı şey açıyordu.
      expect(nav.contains('_slot1'), isFalse);
      expect(nav.contains('_slot3'), isFalse);
    });
  });

  group('modül menüsü geri gelmemiş', () {
    test('kAllModules ve showModuleLauncher yok', () {
      final premium = read('lib/app/widgets/premium.dart');
      expect(premium.contains('showModuleLauncher'), isFalse);
      expect(File('$root/lib/app/widgets/module_launcher.dart').existsSync(),
          isFalse);
    });
  });
}
