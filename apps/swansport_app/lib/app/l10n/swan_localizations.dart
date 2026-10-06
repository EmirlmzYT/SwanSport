import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// SwanSport çoklu dil (i18n / l10n) yerelleştirme sözlüğü.
class SwanLocalizations {
  const SwanLocalizations(this.locale);

  final Locale locale;

  static SwanLocalizations of(BuildContext context) {
    return Localizations.of<SwanLocalizations>(context, SwanLocalizations) ??
        const SwanLocalizations(Locale('tr', 'TR'));
  }

  static const LocalizationsDelegate<SwanLocalizations> delegate =
      _SwanLocalizationsDelegate();

  bool get isTurkish => locale.languageCode == 'tr';

  // --- Genel (Common) ---
  String get appName => 'SwanSport';
  String get save => isTurkish ? 'Kaydet' : 'Save';
  String get cancel => isTurkish ? 'Vazgeç' : 'Cancel';
  String get delete => isTurkish ? 'Sil' : 'Delete';
  String get edit => isTurkish ? 'Düzenle' : 'Edit';
  String get search => isTurkish ? 'Ara' : 'Search';
  String get filter => isTurkish ? 'Filtrele' : 'Filter';
  String get all => isTurkish ? 'Tümü' : 'All';
  String get share => isTurkish ? 'Paylaş' : 'Share';
  String get report => isTurkish ? 'Şikayet Et' : 'Report';
  String get send => isTurkish ? 'Gönder' : 'Send';
  String get close => isTurkish ? 'Kapat' : 'Close';
  String get retry => isTurkish ? 'Yeniden Dene' : 'Retry';
  String get loading => isTurkish ? 'Yükleniyor...' : 'Loading...';
  String get error => isTurkish ? 'Bir hata oluştu' : 'An error occurred';
  String get success => isTurkish ? 'Başarılı' : 'Success';
  String get seeAll => isTurkish ? 'Tümünü Gör' : 'See All';
  String get back => isTurkish ? 'Geri' : 'Back';
  String get emptyState => isTurkish ? 'Henüz bir içerik yok' : 'No content yet';

  // --- Alt Gezinme (Bottom Navigation) ---
  String get navFeed => isTurkish ? 'Akış' : 'Feed';
  String get navExplore => isTurkish ? 'Keşfet' : 'Explore';
  String get navCreate => isTurkish ? 'Oluştur' : 'Create';
  String get navMessages => isTurkish ? 'Mesajlar' : 'Messages';
  String get navProfile => isTurkish ? 'Profil' : 'Profile';

  // --- Keşfet & Arama (Explore & Discovery) ---
  String get exploreTitle => isTurkish ? 'Keşfet' : 'Explore';
  String get exploreSubtitle => isTurkish ? 'Kulüpler, sahalar ve topluluk' : 'Clubs, venues and community';
  String get searchHint => isTurkish ? 'Sporcu, kulüp, etkinlik veya branş ara...' : 'Search athlete, club, event or branch...';
  String get quickModuleHub => isTurkish ? 'Hızlı Modül Hub\'ı' : 'Quick Module Hub';
  String get allServices => isTurkish ? 'Tüm Servisler →' : 'All Services →';
  String get sportSection => isTurkish ? 'Spor yap' : 'Play Sports';
  String get communitySection => isTurkish ? 'Topluluğa katıl' : 'Join Community';
  String get needsSection => isTurkish ? 'İhtiyacını bul' : 'Find Your Needs';
  String get featuredAnnouncements => isTurkish ? 'Öne Çıkan Duyurular' : 'Featured Announcements';
  String get popularAthletes => isTurkish ? 'Popüler Sporcular & Antrenörler' : 'Popular Athletes & Coaches';
  String get performanceBento => isTurkish ? 'Performans & Keşif Kinetiği' : 'Performance & Discovery Kinetics';
  String get bentoBadge => isTurkish ? 'KEŞİF IZGARASI' : 'BENTO GRID';
  String get movementOfTheDay => isTurkish ? 'GÜNÜN HAREKETİ' : 'MOVEMENT OF THE DAY';
  String get clubPostsTrends => isTurkish ? 'Kulüp Gönderileri & Trendler' : 'Club Posts & Trends';
  String get latestPosts => isTurkish ? 'En yeniler' : 'Latest';

  // --- Spor & Tesisler ---
  String get courtsAndVenues => isTurkish ? 'Kortlar & Sahalar' : 'Courts & Pitches';
  String get findPartner => isTurkish ? 'Partner bul' : 'Find Partner';
  String get organizations => isTurkish ? 'Organizasyonlar' : 'Organizations';
  String get leaderboard => isTurkish ? 'Liderlik & Ligler' : 'Leaderboard & Leagues';
  String get nutrition => isTurkish ? 'Beslenme & Makrolar' : 'Nutrition & Macros';
  String get clubs => isTurkish ? 'Kulüpler' : 'Clubs';
  String get communities => isTurkish ? 'Topluluklar' : 'Communities';
  String get teams => isTurkish ? 'Takımlar' : 'Teams';
  String get marketplace => isTurkish ? 'Pazaryeri' : 'Marketplace';
  String get coachDiscovery => isTurkish ? 'Antrenör bul' : 'Find a Coach';
  String get listings => isTurkish ? 'İlanlar' : 'Listings';

  // --- Atletik Araçlar & Antrenman ---
  String get stopwatch => isTurkish ? 'Kronometre' : 'Stopwatch';
  String get whistle => isTurkish ? 'Düdük & Sinyal' : 'Whistle & Signal';
  String get tacticalNote => isTurkish ? 'Taktik Notu' : 'Tactical Note';
  String get tacticalBoard => isTurkish ? 'Taktik Tahtası' : 'Tactical Board';
  String get start => isTurkish ? 'Başlat' : 'Start';
  String get stop => isTurkish ? 'Durdur' : 'Stop';
  String get reset => isTurkish ? 'Sıfırla' : 'Reset';
  String get lap => isTurkish ? 'Tur' : 'Lap';
  String get recordingVoice => isTurkish ? 'Ses kaydediliyor...' : 'Recording voice...';
  String get voiceMessage => isTurkish ? 'Sesli Mesaj' : 'Voice Message';
  String get workoutBuilder => isTurkish ? 'Antrenman Planlayıcı' : 'Workout Builder';
  String get exercises => isTurkish ? 'Egzersizler' : 'Exercises';
  String get sets => isTurkish ? 'Setler' : 'Sets';
  String get reps => isTurkish ? 'Tekrar' : 'Reps';
  String get restTime => isTurkish ? 'Dinlenme' : 'Rest';

  // --- Ayarlar & Hesap ---
  String get settings => isTurkish ? 'Ayarlar' : 'Settings';
  String get languagePreference => isTurkish ? 'Uygulama Dili' : 'App Language';
  String get themePreference => isTurkish ? 'Tema Tercihi' : 'Theme Preference';
  String get notifications => isTurkish ? 'Bildirimler' : 'Notifications';
  String get privacy => isTurkish ? 'Gizlilik ve Güvenlik' : 'Privacy & Security';
  String get support => isTurkish ? 'Yardım & Destek' : 'Help & Support';
  String get logout => isTurkish ? 'Çıkış Yap' : 'Log Out';
}

class _SwanLocalizationsDelegate
    extends LocalizationsDelegate<SwanLocalizations> {
  const _SwanLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['tr', 'en'].contains(locale.languageCode);
  }

  @override
  Future<SwanLocalizations> load(Locale locale) {
    return SynchronousFuture<SwanLocalizations>(SwanLocalizations(locale));
  }

  @override
  bool shouldReload(_SwanLocalizationsDelegate old) => false;
}

/// Kolay erişim için BuildContext extension'ı.
extension SwanLocalizationsX on BuildContext {
  SwanLocalizations get l10n => SwanLocalizations.of(this);
}
