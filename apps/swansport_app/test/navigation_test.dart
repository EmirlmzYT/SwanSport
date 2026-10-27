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
const _routeToAppRoutesConstant = <String, String>{
  '/akis': 'AppRoutes.feed',
  '/kesfet': 'AppRoutes.explore',
  '/mesajlar': 'AppRoutes.messages',
  '/profil': 'AppRoutes.profile',
  '/kortlar': 'AppRoutes.venues',
  '/halisahalar': 'AppRoutes.turfVenues',
  '/partner-ara': 'AppRoutes.partnerSearch',
  '/oyuncu-aranan': 'AppRoutes.playerWanted',
  '/kulupler': 'AppRoutes.clubs',
  '/ilanlar': 'AppRoutes.listings',
  '/pazaryeri': 'AppRoutes.marketplace',
  '/canli-skor': 'AppRoutes.liveScore',
  '/federasyon-merkezi': 'AppRoutes.federationCenter',
  '/federasyon-takvimi': 'AppRoutes.federationCalendar',
  '/antrenor-bul': 'AppRoutes.coachDiscovery',
  '/ara': 'AppRoutes.search',
  '/announcements': 'AppRoutes.announcements',
  '/organizasyonlar': 'AppRoutes.organizations',
  '/topluluklar': 'AppRoutes.communities',
  '/settings': 'AppRoutes.clubSettings',
  '/hesap': 'AppRoutes.account',
  '/finans': 'AppRoutes.finance',
  '/gider-ekle': 'AppRoutes.quickExpense',
  '/kulup-yonetim': 'AppRoutes.clubCockpit',
  '/athletes': 'AppRoutes.athletes',
  '/teams': 'AppRoutes.teams',
  '/calendar': 'AppRoutes.calendar',
  '/attendance': 'AppRoutes.attendance',
  '/devam-durumu': 'AppRoutes.attendanceHistory',
  '/sezon-acilisi': 'AppRoutes.seasonSetup',
  '/facilities': 'AppRoutes.facilities',
  '/rezervasyon': 'AppRoutes.facilityReservation',
  '/medical-center': 'AppRoutes.medicalCenter',
  '/muhasebeci-defter': 'AppRoutes.accountantLedger',
  '/antrenmanlarim': 'AppRoutes.myTraining',
  '/antrenman-oturumu': 'AppRoutes.trainingSession',
  '/antrenman-sablonlari': 'AppRoutes.trainingProtocols',
  '/aidatlarim': 'AppRoutes.myFees',
  '/documents': 'AppRoutes.documents',
  '/dogrulama': 'AppRoutes.credentials',
  '/hakem/gorevler': 'AppRoutes.refereeDuties',
  '/veli-izinleri': 'AppRoutes.parentConsent',
  '/veli-bagla': 'AppRoutes.guardianLink',
  '/gelisim-raporu': 'AppRoutes.developmentReport',
  '/saha-islemlerim': 'AppRoutes.courtOperations',
  '/onay-paneli': 'AppRoutes.adminReview',
  '/haber-kaynaklari': 'AppRoutes.rssAdmin',
  '/federasyon-yetkili': 'AppRoutes.federationAdmin',
  '/bagis': 'AppRoutes.campaigns',
  '/basvurular': 'AppRoutes.applications',
  '/rehber': 'AppRoutes.guide',
  '/kulup/malzeme-zimmet': 'AppRoutes.clubInventory',
  '/kulup/saglik-takibi': 'AppRoutes.clubHealth',
  '/kulup/kadro-planlama': 'AppRoutes.clubSquadPlanning',
  '/performance-analytics': 'AppRoutes.performanceAnalytics',
  '/home-command': 'AppRoutes.homeCommand',
};

void main() {
  final root = Directory.current.path;
  String read(String rel) => File('$root/$rel').readAsStringSync();

  final routes = read('lib/app/swansport_app.dart');
  final legacyRegistry = read('lib/app/navigation/legacy_route_registry.dart');
  final explore = read('lib/features/network/presentation/explore_screen.dart');
  final guest =
      read('lib/features/network/presentation/guest_explore_screen.dart');
  final management =
      read('lib/features/social/presentation/widgets/management_section.dart');
  final cockpit =
      read('lib/features/clubs/presentation/club_cockpit_screen.dart');
  final proFeatureHost =
      read('lib/features/pro_operations/swan_pro_feature_host.dart');
  final nav = read('lib/app/widgets/swan_bottom_nav.dart');
  final createSheet = read('lib/app/widgets/create_sheet.dart');
  final messages =
      read('lib/features/social/presentation/messages_screen.dart');
  // Profil'deki kişisel kısayollar (Aidatlarım / Belgelerim / Doğrulama).
  final profile = read('lib/features/social/presentation/profile_screen.dart');
  final profileMenu = read(
      'lib/features/social/presentation/widgets/swan_profile_menu_sheet.dart');

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
    '/federasyon-merkezi',
    // Profil > Yönetim
    '/kulup-yonetim',
    '/athletes', '/teams', '/calendar', '/attendance', '/devam-durumu',
    '/announcements', '/performance-analytics', '/home-command',
    '/sezon-acilisi', '/veli-izinleri', '/gelisim-raporu', '/saha-islemlerim',
    '/finans', '/gider-ekle', '/medical-center', '/facilities',
    '/muhasebeci-defter',
    '/onay-paneli', '/haber-kaynaklari', '/federasyon-yetkili',
    '/bagis', '/basvurular', '/veli-bagla', '/rehber', '/hesap', '/settings',
    // Profil kısayolları
    '/aidatlarim', '/documents', '/dogrulama', '/antrenmanlarim',
    '/hakem/gorevler',
    '/kulup/malzeme-zimmet', '/kulup/saglik-takibi', '/kulup/kadro-planlama',
    // Antrenman oturumu (0071-0073). '/antrenman-sonuc' burada YOK:
    // oturum ekranindan acilan bir alt sayfa, girisi kendi baglaminda.
    '/antrenman-oturumu', '/antrenman-sablonlari',
  ];

  group('rota bütünlüğü', () {
    test('profil menüsü rol ve özellik kapılarını birlikte uygular', () {
      expect(profileMenu.contains('access.isParent &&'), isTrue);
      expect(
        profileMenu.contains(
          'featureEnabledProvider(FeatureFlags.parentHub)',
        ),
        isTrue,
      );
      expect(profileMenu.contains('access.isReferee &&'), isTrue);
      expect(
        profileMenu.contains(
          'featureEnabledProvider(FeatureFlags.refereeCockpit)',
        ),
        isTrue,
      );
      expect(profileMenu.contains('if (isStaff)'), isTrue);
      expect(profileMenu.contains("open('/kulup-yonetim')"), isTrue);
    });

    test('kulüp operasyonları tek kokpit girişinin arkasında kalır', () {
      for (final route in [
        '/antrenman-oturumu',
        '/medical-center',
        '/performance-analytics',
        '/home-command',
      ]) {
        final constName = _routeToAppRoutesConstant[route];
        expect(
          cockpit.contains("'$route'") ||
              (constName != null && cockpit.contains(constName)),
          isTrue,
        );
        expect(profileMenu.contains("'$route'"), isFalse);
      }
      expect(
        cockpit.contains(
          'featureEnabledProvider(FeatureFlags.sportTrainingSessions)',
        ),
        isTrue,
      );
    });

    test('kulüp davet bağlantısı profil başvuru rotasına açılır', () {
      expect(
          cockpit.contains('swansport.pages.dev/#/kulup-profil?id='), isTrue);
      expect(routes.contains("target?.path == '/kulup-profil'"), isTrue);
      expect(routes.contains("target?.queryParameters['id']"), isTrue);
    });
    test(
        'public live match UUID route has hub/strip entrances and guest-safe parsing',
        () {
      final router = read('lib/app/router.dart');
      expect(router.contains("'canli-mac'"), isTrue);
      expect(
          router.contains('isPublicMatchId(target.pathSegments.last)'), isTrue);
      expect(routes.contains('liveMatchRoute(settings)'), isTrue);
      expect(
          read('lib/features/live_match/presentation/live_match_widgets.dart')
              .contains('/canli-mac/'),
          isTrue);
      expect(
          read('lib/features/social/presentation/feed_screen.dart')
              .contains('LiveMatchStrip()'),
          isTrue);
    });
    test('referee deep routes retain validated match IDs and account guard',
        () {
      final router = read('lib/app/router.dart');
      for (final route in ['/hakem/esame', '/hakem/canli', '/hakem/rapor']) {
        expect(router.contains("'$route'"), isTrue);
      }
      expect(routes.contains('refereeRoute(settings)'), isTrue);
      expect(
        routes.contains('LegacyRouteRegistry.protectDynamicRoutes'),
        isTrue,
      );
      expect(legacyRegistry.contains('guardAccountRoutes'), isTrue);
      expect(router.contains('hasMatch(matchId)'), isTrue);
    });
    test(
        'private official result has notification and child calendar entry points',
        () {
      expect(routes.contains("'/resmi-sonuc'"), isTrue);
      expect(
          read('lib/features/social/presentation/notifications_screen.dart')
              .contains('n.resultRoute'),
          isTrue);
      expect(
          read('lib/features/calendar/presentation/screens/guardian_official_result_screen.dart')
              .contains('/resmi-sonuc?notification='),
          isTrue);
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

    test('hesap ve kulüp ayarları ayrı giriş ve kapsam kullanır', () {
      final settings = read(
        'lib/features/settings/presentation/screens/club_settings_screen.dart',
      );
      expect(management.contains("'Hesap ve Uygulama', '/hesap'"), isTrue);
      expect(management.contains("'Kulüp Ayarları', '/settings'"), isTrue);
      expect(settings.contains('class ClubSettingsRouteGate'), isTrue);
      expect(settings.contains('hasActiveClubStaffMembership'), isTrue);
      expect(routes.contains("'/hesap'"), isTrue);
    });

    test('rol merkezleri gerçek kapsam olmadan görünmez', () {
      expect(management.contains('hasActiveClubStaffMembership'), isTrue);
      expect(management.contains('access.canOpenTurfCenter'), isTrue);
      expect(management.contains('access.canOpenFederationOperations'), isTrue);
      expect(profileMenu.contains('access.canOpenTurfCenter'), isTrue);
      expect(
        profileMenu.contains('access.canOpenFederationOperations'),
        isTrue,
      );
    });

    test('veli bağlantısı tek durum uyarlamalı girişten açılır', () {
      expect(management.contains("access.isParent ? '/veli-izinleri'"), isTrue);
      expect(profileMenu.contains("isParent ? '/veli-izinleri'"), isTrue);
      expect(
        profileMenu.contains("'Davet Kodu Ekle', '/veli-bagla'"),
        isFalse,
      );
      expect(management.contains("'Davet Kodu', '/veli-bagla'"), isFalse);
    });

    test('dış muhasebeci yalnız gizlilik korumalı merkezden girer', () {
      final ledger = read(
        'lib/features/financial_management/presentation/accountant_privacy_ledger_screen.dart',
      );
      expect(management.contains("'Muhasebe Merkezi'"), isTrue);
      expect(management.contains("'/muhasebeci-defter'"), isTrue);
      expect(profileMenu.contains("'Muhasebe Merkezi'"), isTrue);
      expect(ledger.contains("route: '/ters-islem'"), isTrue);
      expect(routes.contains('.isAccountant'), isTrue);
    });

    test('Keşfet kişisel ve kulüp yönetim modüllerini taşımaz', () {
      expect(explore.contains("'/antrenmanlarim'"), isFalse);
      expect(explore.contains("'/teams'"), isFalse);
      expect(explore.contains("'/athletes'"), isFalse);
      expect(explore.contains("'/kulup-yonetim'"), isFalse);
    });

    test('oluştur menüsü yalnız gerçek ve yetkili yazma akışlarını gösterir',
        () {
      expect(createSheet.contains("route: '/antrenman'"), isFalse);
      expect(createSheet.contains("route: '/duyurular'"), isFalse);
      expect(createSheet.contains("route: '/announcements'"), isTrue);
      expect(createSheet.contains('access.canPublishClubPosts'), isTrue);
      expect(createSheet.contains('Kayıtlı Taslaklar (2)'), isFalse);
    });

    test('Swan Asistan Mesajlar içinde bayraklı sabit giriş taşır', () {
      expect(
        messages.contains('FeatureFlags.swanAssistant'),
        isTrue,
      );
      expect(messages.contains("id: 'swan-assistant'"), isTrue);
      expect(
        messages.contains("'/swan-asistan'") ||
            messages.contains('AppRoutes.aiAssistant'),
        isTrue,
      );
    });

    test('her rotanın bir giriş noktası var', () {
      // Menü silindi; giriş noktaları artık bu dosyalar.
      final entryPoints = explore +
          management +
          cockpit +
          proFeatureHost +
          nav +
          createSheet +
          profile +
          profileMenu +
          guest;

      // Hem string literal ('/kortlar') hem AppRoutes (AppRoutes.venues) sözleşmesini destekle
      final orphans = reachable.where((r) {
        if (entryPoints.contains("'$r'")) return false;
        final constName = _routeToAppRoutesConstant[r];
        if (constName != null && entryPoints.contains(constName)) return false;
        return true;
      }).toList();

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

  group('GoRouter ve rota matrisi bütünlüğü', () {
    test('shellRoots tam dört sabit branch içerir', () {
      final appRoutesFile = read('lib/app/navigation/app_routes.dart');
      expect(appRoutesFile.contains("feed = '/akis'"), isTrue);
      expect(appRoutesFile.contains("explore = '/kesfet'"), isTrue);
      expect(appRoutesFile.contains("messages = '/mesajlar'"), isTrue);
      expect(appRoutesFile.contains("profile = '/profil'"), isTrue);
    });

    test('SwanDestination metadata modeli tanımlı ve tutarlıdır', () {
      final destinationFile = read('lib/app/navigation/swan_destination.dart');
      expect(destinationFile.contains('enum SwanShellBranch'), isTrue);
      expect(destinationFile.contains('class SwanDestination'), isTrue);
      expect(destinationFile.contains('shouldHideBottomNav'), isTrue);
    });

    test('SwanNavigation ortak gezinme yardımcısı tanımlıdır', () {
      final navigationHelper = read('lib/app/navigation/swan_navigation.dart');
      expect(navigationHelper.contains('abstract final class SwanNavigation'), isTrue);
      expect(navigationHelper.contains('extension SwanNavigationExtension on BuildContext'), isTrue);
    });
  });
}
