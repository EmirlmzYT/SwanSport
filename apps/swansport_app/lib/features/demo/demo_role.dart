import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/config/app_environment.dart';

/// ---------------------------------------------------------------------------
/// DEMO Rol Katmanı — sunum/deneme için geçici rol değiştirici.
///
/// Tasarım ilkesi: opt-in. `demoRoleProvider` null iken hiçbir şey değişmez
/// (launcher tüm modülleri gösterir, alt bar tam açık, isPlatformAdmin gerçek
/// değerden okunur). Yalnızca bir demo rolü seçilince kısıtlama devreye girer.
/// ---------------------------------------------------------------------------

enum DemoRole {
  platformAdmin,
  clubAdmin,
  coach5,
  coach4,
  coach3,
  coach2,
  coach1,
  athleteLicensed,
  athleteIndividual,
  guardian,
  member,
}

/// Rol grupları (demo ekranında başlıklandırma için).
enum DemoRoleGroup { platform, club, coach, athlete, family, member }

extension DemoRoleX on DemoRole {
  String get label => switch (this) {
        DemoRole.platformAdmin => 'Platform Yöneticisi',
        DemoRole.clubAdmin => 'Kulüp Yöneticisi',
        DemoRole.coach5 => '5. Kademe — Teknik Direktör',
        DemoRole.coach4 => '4. Kademe — Baş Antrenör',
        DemoRole.coach3 => '3. Kademe — Kıdemli Antrenör',
        DemoRole.coach2 => '2. Kademe — Antrenör',
        DemoRole.coach1 => '1. Kademe — Yardımcı Antrenör',
        DemoRole.athleteLicensed => 'Lisanslı Sporcu',
        DemoRole.athleteIndividual => 'Ferdi Sporcu',
        DemoRole.guardian => 'Veli',
        DemoRole.member => 'Üye',
      };

  /// Kısa etiket (başlık/rozet için).
  String get shortLabel => switch (this) {
        DemoRole.platformAdmin => 'Platform Yöneticisi',
        DemoRole.clubAdmin => 'Kulüp Yöneticisi',
        DemoRole.coach5 => 'Teknik Direktör',
        DemoRole.coach4 => 'Baş Antrenör',
        DemoRole.coach3 => 'Kıdemli Antrenör',
        DemoRole.coach2 => 'Antrenör',
        DemoRole.coach1 => 'Yardımcı Antrenör',
        DemoRole.athleteLicensed => 'Lisanslı Sporcu',
        DemoRole.athleteIndividual => 'Ferdi Sporcu',
        DemoRole.guardian => 'Veli',
        DemoRole.member => 'Üye',
      };

  DemoRoleGroup get group => switch (this) {
        DemoRole.platformAdmin => DemoRoleGroup.platform,
        DemoRole.clubAdmin => DemoRoleGroup.club,
        DemoRole.coach5 ||
        DemoRole.coach4 ||
        DemoRole.coach3 ||
        DemoRole.coach2 ||
        DemoRole.coach1 =>
          DemoRoleGroup.coach,
        DemoRole.athleteLicensed ||
        DemoRole.athleteIndividual =>
          DemoRoleGroup.athlete,
        DemoRole.guardian => DemoRoleGroup.family,
        DemoRole.member => DemoRoleGroup.member,
      };

  /// Antrenör kademesi (1..5), antrenör değilse null.
  int? get kademe => switch (this) {
        DemoRole.coach5 => 5,
        DemoRole.coach4 => 4,
        DemoRole.coach3 => 3,
        DemoRole.coach2 => 2,
        DemoRole.coach1 => 1,
        _ => null,
      };

  bool get isPlatformAdmin => this == DemoRole.platformAdmin;

  /// Kulüp adına paylaşım yapabilir mi? (yalnızca kulüp yetkilileri)
  bool get canPostAsClub => switch (this) {
        DemoRole.clubAdmin ||
        DemoRole.coach5 ||
        DemoRole.coach4 ||
        DemoRole.coach3 ||
        DemoRole.coach2 ||
        DemoRole.coach1 =>
          true,
        _ => false,
      };

  /// Kendi adına paylaşım yapabilir mi? (doğrulanmış kişiler)
  bool get canPostPersonally => switch (this) {
        DemoRole.guardian || DemoRole.member => false,
        _ => true,
      };

  /// Rol seçilince gidilecek ana ekran.
  ///
  /// Herkesin ana sayfası akış; yalnızca platform yöneticisi doğrudan
  /// paneline düşer çünkü onun işi orada başlıyor.
  String get homeRoute =>
      this == DemoRole.platformAdmin ? '/onay-paneli' : '/akis';

  /// Bu rolün erişebildiği rotalar (modül başlatıcı + alt bar bu setle filtrelenir).
  Set<String> get allowedRoutes => switch (this) {
        DemoRole.platformAdmin => const {
            '/home-command',
            '/onay-paneli',
            '/federasyon-yetkili',
            '/haber-kaynaklari',
            '/dogrulama',
            '/gizlilik',
            '/settings',
          },
        DemoRole.clubAdmin => const {
            ..._clubStaff,
            '/home-command',
            '/finans',
            '/reports',
            '/facilities',
            '/configuration',
            '/teams',
            '/documents',
            '/medical-center',
            '/performance-analytics',
          },
        // Antrenör kademeleri — süperset: coachN = coach(N-1) ∪ ekstra.
        DemoRole.coach1 => _coach1,
        DemoRole.coach2 => _coach2,
        DemoRole.coach3 => _coach3,
        DemoRole.coach4 => _coach4,
        DemoRole.coach5 => _coach5,
        DemoRole.athleteLicensed => const {
            '/dashboard',
            '/calendar',
            '/announcements',
            '/performance-analytics',
            '/sporcu-performans',
            '/documents',
            '/takim-kadro',
            '/basvurular',
            '/dogrulama',
            '/settings',
          },
        DemoRole.athleteIndividual => const {
            '/dashboard',
            '/calendar',
            '/performance-analytics',
            '/sporcu-performans',
            '/documents',
            // Ferdi sporcu kulübe başvurabilir — kadro/duyuru yok.
            '/basvurular',
            '/dogrulama',
            '/settings',
          },
        DemoRole.guardian => const {
            '/dashboard',
            '/calendar',
            '/announcements',
            '/veli-bagla',
            '/medical-center',
            '/documents',
            '/sporcu-performans',
            '/settings',
          },
        DemoRole.member => const {
            '/dashboard',
            '/announcements',
            '/dogrulama',
            '/settings',
          },
      };

  /// Kulüpte görev alan herkesin ortak tabanı.
  static const Set<String> _clubStaff = {
    '/dashboard',
    '/calendar',
    '/attendance',
    '/devam-durumu',
    '/athletes',
    '/announcements',
    '/takim-kadro',
    '/sporcu-performans',
    // Topluluk ve federasyon kanalları doğrulanmış antrenörlere açıktır.
    '/topluluklar',
    '/topluluk',
    '/federasyon',
    '/basvurular',
    '/dogrulama',
    '/settings',
  };

  static const Set<String> _coach1 = {..._clubStaff};
  static const Set<String> _coach2 = {
    ..._coach1,
    '/performance-analytics',
    '/teams',
    '/documents',
    '/medical-center',
  };
  static const Set<String> _coach3 = {..._coach2, '/reports'};
  static const Set<String> _coach4 = {..._coach3, '/facilities'};
  static const Set<String> _coach5 = {..._coach4, '/configuration'};
}

/// Kademe numarasını (1..5) karşılık gelen antrenör rolüne çevirir.
///
/// Onaylanmış bir antrenörlük belgesinde kademe sayı olarak tutuluyor; menü
/// kümeleri ise rol enum'una bağlı. Aradaki çeviri tek yerde dursun.
DemoRole coachRoleForLevel(int level) => switch (level) {
      >= 5 => DemoRole.coach5,
      4 => DemoRole.coach4,
      3 => DemoRole.coach3,
      2 => DemoRole.coach2,
      _ => DemoRole.coach1,
    };

/// Tüm demo rolleri, ekranda gösterim sırasıyla.
const List<DemoRole> kDemoRolesOrdered = [
  DemoRole.platformAdmin,
  DemoRole.clubAdmin,
  DemoRole.coach5,
  DemoRole.coach4,
  DemoRole.coach3,
  DemoRole.coach2,
  DemoRole.coach1,
  DemoRole.athleteLicensed,
  DemoRole.athleteIndividual,
  DemoRole.guardian,
  DemoRole.member,
];

// =============================== Provider'lar ==============================

/// Demo araçları gösterilsin mi?
///
/// Demo rol değiştirici bir geliştirme aracıdır: menüyü ve ekran erişimini
/// taklit eder ama veriyi değiştirmez. Üretimde kullanıcıya gösterilirse
/// uygulamanın bir parçası sanılır ve boş listeler hata gibi görünür.
/// Bu yüzden ortamın `enableDebugTools` bayrağının arkasında durur.
final debugToolsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(appEnvironmentProvider).enableDebugTools;
});

/// Aktif demo rolü. null = demo kapalı (gerçek rol/akış geçerli).
///
/// Üretimde demo araçları kapalı olduğu için bu değer daima null kalır.
final demoRoleProvider = StateProvider<DemoRole?>((ref) => null);


/// Gerçek (demo olmayan) rolün görebileceği rotalar.
///
/// Demo rolleri için hazırlanan kümeler burada yeniden kullanılıyor: aynı
/// hiyerarşiyi ikinci kez tanımlamak, iki listenin zamanla birbirinden
/// ayrılması demekti. Demo katmanı yalnızca hangi kümenin seçildiğini taklit
/// eder; kümelerin kendisi tek yerde durur.
///
/// Kaynak `swanAccessProvider` — **kim olduğun** hesabı paylaşılan pakette
/// (`swansport_data`), **ne göreceğin** hesabı burada.
///
/// Bu ayrım bilinçli: "2. kademe onaylı antrenör" olmak iki uygulamada da
/// aynı şey, ama bunun karşılığı mobilde bir rota kümesi, konsolda bir modül
/// listesi. Ortak olan kısım pakette durur; eskiden iki uygulama aynı hesabı
/// ayrı ayrı yapıyordu ve biri değişince diğeri sessizce geride kalıyordu.
///
/// Sonuç bir **birleşim**, çünkü bir kişi aynı anda birden fazla şey olabilir:
/// ferdi sporcuyken 2. kademe antrenörlüğü onaylanan biri hem sporcu hem
/// antrenör ekranlarını görmeli.
///
/// Bu yalnızca **görünürlük**. Gerçek yetkiyi veritabanı belirliyor: örneğin
/// `create_club` kendi içinde onaylı ≥2. kademe belgesi arıyor.
///
/// null dönerse kısıtlama yok (rol henüz yüklenmemiş olabilir — menüyü boş
/// göstermektense tamamını göstermek daha az yanıltıcı).
final realRoleRoutesProvider = Provider<Set<String>?>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null) return null;

  final access = ref.watch(swanAccessProvider);

  final routes = <String>{
    ...switch (access.clubRole) {
      'club_admin' => DemoRole.clubAdmin.allowedRoutes,
      // Kademe bilgisi üyelikte tutulmuyor; belgeden gelmezse orta kademe
      // varsayılır — yalnızca menü görünürlüğünü etkiler.
      'coach' || 'official' => DemoRole.coach3.allowedRoutes,
      'athlete' => DemoRole.athleteLicensed.allowedRoutes,
      'parent' => DemoRole.guardian.allowedRoutes,
      _ => DemoRole.member.allowedRoutes,
    },
  };

  // Onaylanmış antrenörlük belgesi kendi kademesinin ekranlarını açar.
  if (access.coachLevel > 0) {
    routes.addAll(coachRoleForLevel(access.coachLevel).allowedRoutes);
  }
  if (access.isVerifiedAthlete) {
    routes.addAll(access.isLicensedAthlete
        ? DemoRole.athleteLicensed.allowedRoutes
        : DemoRole.athleteIndividual.allowedRoutes);
  }

  // Platform yöneticisi kendi rolüne ek olarak yönetim ekranlarını da görür.
  if (access.isPlatformAdmin) {
    routes.addAll(DemoRole.platformAdmin.allowedRoutes);
  }
  return routes;
});

/// İzinli rota seti. null = kısıtlama yok.
///
/// Öncelik: geliştirmede seçili bir demo rolü varsa o, yoksa kullanıcının
/// gerçek rolü. Üretimde demo katmanı hiç devreye girmez.
final effectiveAllowedRoutesProvider = Provider<Set<String>?>((ref) {
  if (ref.watch(debugToolsEnabledProvider)) {
    final demo = ref.watch(demoRoleProvider);
    if (demo != null) return demo.allowedRoutes;
  }
  return ref.watch(realRoleRoutesProvider);
});

/// Demo-duyarlı platform admin bayrağı.
final effectiveIsPlatformAdminProvider = Provider<bool>((ref) {
  final demo = ref.watch(debugToolsEnabledProvider)
      ? ref.watch(demoRoleProvider)
      : null;
  if (demo != null) return demo.isPlatformAdmin;
  return ref.watch(isPlatformAdminProvider).valueOrNull ?? false;
});

/// Demo aktifse rol etiketi, değilse null (başlıkta göstermek için).
final effectiveRoleLabelProvider = Provider<String?>((ref) {
  if (!ref.watch(debugToolsEnabledProvider)) return null;
  return ref.watch(demoRoleProvider)?.shortLabel;
});

/// Rol kısıtlamasından muaf rotalar.
///
/// Burası bilerek dar tutuldu: liste şiştikçe rol değiştirmek anlamsızlaşıyor,
/// çünkü her rol aynı şeyleri görmeye başlıyor. Yalnızca kimliğe değil kişiye
/// bağlı olanlar burada: kendi profilin, kendi mesajın, kendi borcun.
const Set<String> kAlwaysAllowedRoutes = {
  '/akis',
  '/profil',
  '/kulup-profil',
  '/ara',
  '/bildirimler',
  '/mesajlar',
  '/sohbet',
  '/baglantilar',
  // Aidat herkesi ilgilendirir: sporcunun da velinin de borcu olabilir.
  '/aidatlarim',
  '/bagis',
  '/kesfet',
  '/ilanlar',
  '/organizasyonlar',
  '/gizlilik',
};

/// Bir rotanın izinli olup olmadığı (null set = her şey izinli).
bool demoAllows(Set<String>? allowed, String route) =>
    allowed == null ||
    kAlwaysAllowedRoutes.contains(route) ||
    allowed.contains(route);
