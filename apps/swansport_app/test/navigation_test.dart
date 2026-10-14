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
  final guest = read('lib/features/network/presentation/guest_explore_screen.dart');
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
    '/akis', '/kesfet', '/mesajlar', '/profil', '/federasyon-takvimi',
    // Keşfet
    '/kortlar', '/partner-ara', '/ilanlar', '/kulupler', '/topluluklar',
    '/organizasyonlar',
    '/canli-skor',
    // Profil > Yönetim
    '/athletes', '/teams', '/calendar', '/attendance', '/devam-durumu',
    '/announcements', '/performance-analytics', '/home-command',
    '/sezon-acilisi', '/veli-izinleri', '/gelisim-raporu', '/saha-islemlerim',
    '/finans', '/gider-ekle', '/medical-center', '/facilities',
    '/onay-paneli', '/haber-kaynaklari', '/federasyon-yetkili',
    '/bagis', '/basvurular', '/veli-bagla', '/rehber', '/settings',
    // Profil kısayolları
    '/aidatlarim', '/documents', '/dogrulama', '/antrenmanlarim',
    '/hakem/gorevler',
    '/kulup/malzeme-zimmet', '/kulup/saglik-takibi', '/kulup/kadro-planlama',
    // Antrenman oturumu (0071-0073). '/antrenman-sonuc' burada YOK:
    // oturum ekranindan acilan bir alt sayfa, girisi kendi baglaminda.
    '/antrenman-oturumu', '/antrenman-sablonlari',
  ];

  group('rota bütünlüğü', () {
    test('public live match UUID route has hub/strip entrances and guest-safe parsing', () {
      final router=read('lib/app/router.dart');
      expect(router.contains("'canli-mac'"),isTrue);
      expect(router.contains('isPublicMatchId(target.pathSegments.last)'),isTrue);
      expect(routes.contains('liveMatchRoute(settings)'),isTrue);
      expect(read('lib/features/live_match/presentation/live_match_widgets.dart').contains('/canli-mac/'),isTrue);
      expect(read('lib/features/social/presentation/feed_screen.dart').contains('LiveMatchStrip()'),isTrue);
    });
    test('referee deep routes retain validated match IDs and account guard', () {
      final router = read('lib/app/router.dart');
      for (final route in ['/hakem/esame', '/hakem/canli', '/hakem/rapor']) {
        expect(router.contains("'$route'"), isTrue);
      }
      expect(routes.contains('refereeRoute(settings)'), isTrue);
      expect(routes.contains('guardAccountRoutes'), isTrue);
      expect(router.contains('hasMatch(matchId)'), isTrue);
    });
    test('private official result has notification and child calendar entry points', () {
      expect(routes.contains("'/resmi-sonuc'"), isTrue);
      expect(read('lib/features/social/presentation/notifications_screen.dart').contains('n.resultRoute'), isTrue);
      expect(read('lib/features/calendar/presentation/screens/guardian_official_result_screen.dart').contains('/resmi-sonuc?notification='), isTrue);
    });
    test('kaldırılan prototip menülerinin eski bağlantıları korunur', () {
      for (final route in ['/reports', '/configuration']) {
        expect(routes.contains("'$route'"), isTrue);
        expect(management.contains("'$route'"), isFalse);
      }
    });
    test('erişilebilir sayılan her rota tanımlı', () {
      final missing = reachable.where((r) => !routes.contains("'$r'")).toList();
      expect(
        missing,
        isEmpty,
        reason: 'Bu rotalar swansport_app.dart içinde tanımlı değil: '
            '$missing',
      );
    });

    test('her rotanın bir giriş noktası var', () {
      // Menü silindi; giriş noktaları artık bu dört dosya.
      final entryPoints = explore + management + nav + createSheet + profile + guest;
      final orphans =
          reachable.where((r) => !entryPoints.contains("'$r'")).toList();

      expect(
        orphans,
        isEmpty,
        reason: 'Bu rotalar tanımlı ama hiçbir yerden açılamıyor — '
            'Keşfet ya da Profil > Yönetim listesinden düşmüş olabilir: '
            '$orphans',
      );
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

      expect(
        navRoutes,
        unorderedEquals(expected),
        reason: 'Alt gezinme tam bu dört rotayı göstermeli',
      );
      expect(
        nav.contains('_CreateButton'),
        isTrue,
        reason: 'Ortadaki oluştur düğmesi kaybolmuş',
      );
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
      expect(
        File('$root/lib/app/widgets/module_launcher.dart').existsSync(),
        isFalse,
      );
    });
  });
}
