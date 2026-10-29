/// Canonical application paths.
///
/// Keep externally shared paths stable. Legacy aliases are normalized by
/// [RouteLinkAdapter] before the navigation layer sees them.
abstract final class AppRoutes {
  static const root = '/';
  static const feed = '/akis';
  static const explore = '/kesfet';
  static const messages = '/mesajlar';
  static const communities = '/topluluklar';
  static const community = '/topluluk';
  static const directMessage = '/sohbet';
  static const profile = '/profil';
  static const clubProfile = '/kulup-profil';
  static const clubDetail = '/kulup-detay';
  static const notifications = '/bildirimler';
  static const announcements = '/announcements';
  static const account = '/hesap';
  static const clubSettings = '/settings';
  static const venues = '/kortlar';
  static const turfVenues = '/halisahalar';
  static const partnerSearch = '/partner-ara';
  static const playerWanted = '/oyuncu-aranan';
  static const swanId = '/swan-id';
  static const search = '/ara';

  // Finans ve Muhasebe
  static const finance = '/finans';
  static const quickExpense = '/gider-ekle';
  static const financeTasks = '/mali-isler';
  static const accountantLedger = '/muhasebeci-defter';
  static const periodReversal = '/ters-islem';

  // Kulüp Operasyonları ve Yönetim
  static const clubCockpit = '/kulup-yonetim';
  static const athletes = '/athletes';
  static const teams = '/teams';
  static const calendar = '/calendar';
  static const attendance = '/attendance';
  static const attendanceHistory = '/devam-durumu';
  static const seasonSetup = '/sezon-acilisi';
  static const facilities = '/facilities';
  static const facilityReservation = '/rezervasyon';
  static const medicalCenter = '/medical-center';
  static const clubInventory = '/kulup/malzeme-zimmet';
  static const clubHealth = '/kulup/saglik-takibi';
  static const clubSquadPlanning = '/kulup/kadro-planlama';
  static const homeCommand = '/home-command';
  static const performanceAnalytics = '/performance-analytics';

  // Antrenman
  static const myTraining = '/antrenmanlarim';
  static const trainingSession = '/antrenman-oturumu';
  static const trainingProtocols = '/antrenman-sablonlari';
  static const createWorkout = '/antrenman-olustur';
  static const trainingResult = '/antrenman-sonuc';

  // Kişisel, Veli ve Hakem
  static const myFees = '/aidatlarim';
  static const documents = '/documents';
  static const credentials = '/dogrulama';
  static const refereeDuties = '/hakem/gorevler';
  static const parentConsent = '/veli-izinleri';
  static const guardianLink = '/veli-bagla';
  static const developmentReport = '/gelisim-raporu';
  static const courtOperations = '/saha-islemlerim';

  // Keşif, Federasyon ve Pazaryeri
  static const liveScore = '/canli-skor';
  static const federation = '/federasyon';
  static const federationCenter = '/federasyon-merkezi';
  static const federationCalendar = '/federasyon-takvimi';
  static const organizations = '/organizasyonlar';
  static const marketplace = '/pazaryeri';
  static const clubs = '/kulupler';
  static const listings = '/ilanlar';
  static const createListing = '/ilan-ver';
  static const storeApplication = '/magaza-basvuru';
  static const coachDiscovery = '/antrenor-bul';

  // Platform ve Yardım
  static const adminReview = '/onay-paneli';
  static const rssAdmin = '/haber-kaynaklari';
  static const federationAdmin = '/federasyon-yetkili';
  static const help = '/yardim';
  static const support = '/destek';
  static const savedPosts = '/kaydedilenler';
  static const campaigns = '/bagis';
  static const applications = '/basvurular';
  static const guide = '/rehber';
  static const assistant = '/swan-asistan';
  static const aiAssistant = assistant;
  static const auth = '/auth';
  static const demoRole = '/demo-rol';

  static const shellRoots = <String>[
    feed,
    explore,
    messages,
    profile,
  ];

  // Dinamik rota üreticileri
  static String swanIdVerification(String token) => '$swanId/dogrula/$token';
  static String athleteMatchCard(String matchId) => '/mac-kartim/$matchId';
  static String liveMatch(String matchId) => '/canli-mac/$matchId';
  static String refereeLineup(String matchId) => '/hakem/esame/$matchId';
  static String refereeLive(String matchId) => '/hakem/canli/$matchId';
  static String refereeReport(String matchId) => '/hakem/rapor/$matchId';
  static String officialResult({
    required String notificationId,
    String? matchId,
    String? childId,
  }) {
    final params = <String, String>{
      'notification': notificationId,
      if (matchId != null && matchId.isNotEmpty) 'match': matchId,
      if (childId != null && childId.isNotEmpty) 'child': childId,
    };
    return Uri(path: '/resmi-sonuc', queryParameters: params).toString();
  }
}
