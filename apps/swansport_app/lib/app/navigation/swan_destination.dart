import 'app_routes.dart';

/// The four core branches hosted inside [SwanAppShell].
enum SwanShellBranch {
  feed(AppRoutes.feed, 'Ana Sayfa'),
  explore(AppRoutes.explore, 'Keşfet'),
  messages(AppRoutes.messages, 'Mesajlar'),
  profile(AppRoutes.profile, 'Profil');

  const SwanShellBranch(this.rootRoute, this.label);

  final String rootRoute;
  final String label;

  static SwanShellBranch? fromIndex(int index) {
    if (index < 0 || index >= values.length) return null;
    return values[index];
  }

  static SwanShellBranch? fromRoute(String? route) {
    if (route == null) return null;
    for (final branch in values) {
      if (branch.rootRoute == route) return branch;
    }
    return null;
  }
}

/// Metadata model defining navigation chrome behavior and branch association.
///
/// Note: Access control and permissions must NEVER be decided here.
/// All authorization logic resides strictly in [SwanAccess].
class SwanDestination {
  const SwanDestination({
    required this.route,
    required this.title,
    this.branch,
    this.hideBottomNav = false,
    this.featureFlag,
  });

  final String route;
  final String title;
  final SwanShellBranch? branch;
  final bool hideBottomNav;
  final String? featureFlag;

  static final Map<String, SwanDestination> _registry = {
    // 4 Kök Branch
    AppRoutes.feed: const SwanDestination(
      route: AppRoutes.feed,
      title: 'Ana Sayfa',
      branch: SwanShellBranch.feed,
    ),
    AppRoutes.explore: const SwanDestination(
      route: AppRoutes.explore,
      title: 'Keşfet',
      branch: SwanShellBranch.explore,
    ),
    AppRoutes.messages: const SwanDestination(
      route: AppRoutes.messages,
      title: 'Mesajlar',
      branch: SwanShellBranch.messages,
    ),
    AppRoutes.profile: const SwanDestination(
      route: AppRoutes.profile,
      title: 'Profil',
      branch: SwanShellBranch.profile,
    ),

    // Tam Ekran & Shell Alt Barı Gizlenen Ekranlar
    AppRoutes.auth: const SwanDestination(
      route: AppRoutes.auth,
      title: 'Giriş Yap',
      hideBottomNav: true,
    ),
    AppRoutes.demoRole: const SwanDestination(
      route: AppRoutes.demoRole,
      title: 'Demo Rolü',
      hideBottomNav: true,
    ),
    AppRoutes.credentials: const SwanDestination(
      route: AppRoutes.credentials,
      title: 'Doğrulama',
      hideBottomNav: true,
    ),
    AppRoutes.trainingSession: const SwanDestination(
      route: AppRoutes.trainingSession,
      title: 'Antrenman Oturumu',
      hideBottomNav: true,
    ),
    AppRoutes.createWorkout: const SwanDestination(
      route: AppRoutes.createWorkout,
      title: 'Antrenman Oluştur',
      hideBottomNav: true,
    ),
    AppRoutes.trainingResult: const SwanDestination(
      route: AppRoutes.trainingResult,
      title: 'Oturum Özeti',
      hideBottomNav: true,
    ),
    '/sepet': const SwanDestination(
      route: '/sepet',
      title: 'Sepet & Ödeme',
      hideBottomNav: true,
    ),

    // Profil & Yönetim Alt Rotaları
    AppRoutes.account: const SwanDestination(
      route: AppRoutes.account,
      title: 'Hesap & Ayarlar',
      branch: SwanShellBranch.profile,
    ),
    AppRoutes.clubSettings: const SwanDestination(
      route: AppRoutes.clubSettings,
      title: 'Kulüp Ayarları',
      branch: SwanShellBranch.profile,
    ),
    AppRoutes.clubCockpit: const SwanDestination(
      route: AppRoutes.clubCockpit,
      title: 'Kulüp Kokpiti',
      branch: SwanShellBranch.profile,
    ),
    AppRoutes.finance: const SwanDestination(
      route: AppRoutes.finance,
      title: 'Finans',
      branch: SwanShellBranch.profile,
    ),
    AppRoutes.accountantLedger: const SwanDestination(
      route: AppRoutes.accountantLedger,
      title: 'Muhasebeci Defteri',
      branch: SwanShellBranch.profile,
    ),
    AppRoutes.refereeDuties: const SwanDestination(
      route: AppRoutes.refereeDuties,
      title: 'Hakem Görevleri',
      branch: SwanShellBranch.profile,
    ),
    AppRoutes.myFees: const SwanDestination(
      route: AppRoutes.myFees,
      title: 'Aidatlarım',
      branch: SwanShellBranch.profile,
    ),
    AppRoutes.documents: const SwanDestination(
      route: AppRoutes.documents,
      title: 'Belgelerim',
      branch: SwanShellBranch.profile,
    ),
    AppRoutes.myTraining: const SwanDestination(
      route: AppRoutes.myTraining,
      title: 'Antrenmanlarım',
      branch: SwanShellBranch.profile,
    ),
    AppRoutes.parentConsent: const SwanDestination(
      route: AppRoutes.parentConsent,
      title: 'Veli İzinleri',
      branch: SwanShellBranch.profile,
    ),
    AppRoutes.guardianLink: const SwanDestination(
      route: AppRoutes.guardianLink,
      title: 'Veli Bağla',
      branch: SwanShellBranch.profile,
    ),

    // Keşfet Alt Rotaları
    AppRoutes.venues: const SwanDestination(
      route: AppRoutes.venues,
      title: 'Kortlar ve Tesisler',
      branch: SwanShellBranch.explore,
    ),
    AppRoutes.turfVenues: const SwanDestination(
      route: AppRoutes.turfVenues,
      title: 'Halı Sahalar',
      branch: SwanShellBranch.explore,
    ),
    AppRoutes.partnerSearch: const SwanDestination(
      route: AppRoutes.partnerSearch,
      title: 'Partner Ara',
      branch: SwanShellBranch.explore,
    ),
    AppRoutes.playerWanted: const SwanDestination(
      route: AppRoutes.playerWanted,
      title: 'Oyuncu Aranan',
      branch: SwanShellBranch.explore,
    ),
    AppRoutes.clubs: const SwanDestination(
      route: AppRoutes.clubs,
      title: 'Kulüpler',
      branch: SwanShellBranch.explore,
    ),
    AppRoutes.marketplace: const SwanDestination(
      route: AppRoutes.marketplace,
      title: 'Pazaryeri',
      branch: SwanShellBranch.explore,
    ),
    AppRoutes.liveScore: const SwanDestination(
      route: AppRoutes.liveScore,
      title: 'Canlı Skor',
      branch: SwanShellBranch.explore,
    ),
    AppRoutes.federationCenter: const SwanDestination(
      route: AppRoutes.federationCenter,
      title: 'Federasyon Merkezi',
      branch: SwanShellBranch.explore,
    ),
  };

  /// Looks up destination metadata by route path.
  static SwanDestination? findByRoute(String? route) {
    if (route == null) return null;
    final exact = _registry[route];
    if (exact != null) return exact;

    // Dinamik veya önek eşleşmeleri
    if (route.startsWith('/hakem/canli') ||
        route.startsWith('/hakem/rapor') ||
        route.startsWith('/hakem/esame') ||
        route.startsWith('/swan-id/dogrula') ||
        route.startsWith('/canli-mac')) {
      return SwanDestination(
        route: route,
        title: 'Operasyon',
        hideBottomNav: true,
      );
    }

    return null;
  }

  /// Whether the persistent bottom bar should be suppressed for [route].
  static bool shouldHideBottomNav(String? route) {
    final dest = findByRoute(route);
    return dest?.hideBottomNav ?? false;
  }
}
