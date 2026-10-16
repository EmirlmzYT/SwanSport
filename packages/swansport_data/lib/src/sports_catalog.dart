/// Türkiye Spor Federasyonları ve Branş Kataloğu.
///
/// Veritabanındaki `public.sports` ve `public.federations` kayıtlarıyla
/// tam uyumludur. Mobil ve konsol arayüzlerinde çevrimdışı, tip güvenli
/// branş ve federasyon seçimini sağlar.
class SportItem {
  const SportItem({
    required this.code,
    required this.name,
    required this.federationName,
    required this.acronym,
    required this.category,
  });

  /// Veritabanı anahtarı (örn: `basketbol`, `aticilik-avcilik`).
  final String code;

  /// Yaygın spor branş adı (örn: `Basketbol`).
  final String name;

  /// Resmi federasyon tüzel kişilik adı.
  final String federationName;

  /// Federasyon kısa kodu / akronimi (örn: `TBF`, `TVF`).
  final String acronym;

  /// Branş kategorisi (örn: `Takım Sporları`, `Dövüş Sporları`).
  final String category;
}

abstract final class SportsCatalog {
  /// Desteklenen tüm resmi branş ve federasyonlar (60 branş).
  static const List<SportItem> all = [
    SportItem(
      code: 'aticilik-avcilik',
      name: 'Atıcılık ve Avcılık',
      federationName: 'Türkiye Atıcılık ve Avcılık Federasyonu',
      acronym: 'TAAF',
      category: 'Hedef & Açık Hava',
    ),
    SportItem(
      code: 'atletizm',
      name: 'Atletizm',
      federationName: 'Türkiye Atletizm Federasyonu',
      acronym: 'TAF',
      category: 'Pist & Saha',
    ),
    SportItem(
      code: 'badminton',
      name: 'Badminton',
      federationName: 'Türkiye Badminton Federasyonu',
      acronym: 'TBF',
      category: 'Raket Sporları',
    ),
    SportItem(
      code: 'basketbol',
      name: 'Basketbol',
      federationName: 'Türkiye Basketbol Federasyonu',
      acronym: 'TBF',
      category: 'Takım Sporları',
    ),
    SportItem(
      code: 'bedensel-engelliler',
      name: 'Bedensel Engelliler Spor',
      federationName: 'Türkiye Bedensel Engelliler Spor Federasyonu',
      acronym: 'TBESF',
      category: 'Paralimpik & Engelli',
    ),
    SportItem(
      code: 'bilardo',
      name: 'Bilardo',
      federationName: 'Türkiye Bilardo Federasyonu',
      acronym: 'TBF',
      category: 'Salon & Hassas',
    ),
    SportItem(
      code: 'binicilik',
      name: 'Binicilik',
      federationName: 'Türkiye Binicilik Federasyonu',
      acronym: 'TBF',
      category: 'Bireysel & Hayvanlı',
    ),
    SportItem(
      code: 'bisiklet',
      name: 'Bisiklet',
      federationName: 'Türkiye Bisiklet Federasyonu',
      acronym: 'TBF',
      category: 'Açık Hava & Dayanıklılık',
    ),
    SportItem(
      code: 'bocce-bowling-dart',
      name: 'Bocce, Bowling ve Dart',
      federationName: 'Türkiye Bocce Bowling ve Dart Federasyonu',
      acronym: 'TBBDF',
      category: 'Hedef Sporları',
    ),
    SportItem(
      code: 'boks',
      name: 'Boks',
      federationName: 'Türkiye Boks Federasyonu',
      acronym: 'TBF',
      category: 'Dövüş Sporları',
    ),
    SportItem(
      code: 'bric',
      name: 'Briç',
      federationName: 'Türkiye Briç Federasyonu',
      acronym: 'TBF',
      category: 'Zihin Sporları',
    ),
    SportItem(
      code: 'buz-hokeyi',
      name: 'Buz Hokeyi',
      federationName: 'Türkiye Buz Hokeyi Federasyonu',
      acronym: 'TBHF',
      category: 'Kış & Buz Sporları',
    ),
    SportItem(
      code: 'buz-pateni',
      name: 'Buz Pateni',
      federationName: 'Türkiye Buz Pateni Federasyonu',
      acronym: 'TBPF',
      category: 'Kış & Buz Sporları',
    ),
    SportItem(
      code: 'cimnastik',
      name: 'Cimnastik',
      federationName: 'Türkiye Cimnastik Federasyonu',
      acronym: 'TCF',
      category: 'Estetik & Bireysel',
    ),
    SportItem(
      code: 'curling',
      name: 'Curling',
      federationName: 'Türkiye Curling Federasyonu',
      acronym: 'TCF',
      category: 'Kış & Buz Sporları',
    ),
    SportItem(
      code: 'dagcilik',
      name: 'Dağcılık',
      federationName: 'Türkiye Dağcılık Federasyonu',
      acronym: 'TDF',
      category: 'Doğa & Tırmanış',
    ),
    SportItem(
      code: 'dans-sporlari',
      name: 'Dans Sporları',
      federationName: 'Türkiye Dans Sporları Federasyonu',
      acronym: 'TDSF',
      category: 'Estetik & Performans',
    ),
    SportItem(
      code: 'e-spor',
      name: 'E-Spor',
      federationName: 'Türkiye E-Spor Federasyonu',
      acronym: 'TESFED',
      category: 'Dijital & Zihin',
    ),
    SportItem(
      code: 'eskrim',
      name: 'Eskrim',
      federationName: 'Türkiye Eskrim Federasyonu',
      acronym: 'TEF',
      category: 'Dövüş & Bireysel',
    ),
    SportItem(
      code: 'futbol',
      name: 'Futbol',
      federationName: 'Türkiye Futbol Federasyonu',
      acronym: 'TFF',
      category: 'Takım Sporları',
    ),
    SportItem(
      code: 'geleneksel-okculuk',
      name: 'Geleneksel Türk Okçuluğu',
      federationName: 'Türkiye Geleneksel Türk Okçuluğu Federasyonu',
      acronym: 'TGTOF',
      category: 'Hedef & Geleneksel',
    ),
    SportItem(
      code: 'golf',
      name: 'Golf',
      federationName: 'Türkiye Golf Federasyonu',
      acronym: 'TGF',
      category: 'Bireysel & Çim',
    ),
    SportItem(
      code: 'gorme-engelliler',
      name: 'Görme Engelliler Spor',
      federationName: 'Türkiye Görme Engelliler Spor Federasyonu',
      acronym: 'TGESF',
      category: 'Paralimpik & Engelli',
    ),
    SportItem(
      code: 'gures',
      name: 'Güreş',
      federationName: 'Türkiye Güreş Federasyonu',
      acronym: 'TGF',
      category: 'Dövüş & Ata Sporu',
    ),
    SportItem(
      code: 'halk-oyunlari',
      name: 'Halk Oyunları',
      federationName: 'Türkiye Halk Oyunları Federasyonu',
      acronym: 'THOF',
      category: 'Kültür & Performans',
    ),
    SportItem(
      code: 'halter',
      name: 'Halter',
      federationName: 'Türkiye Halter Federasyonu',
      acronym: 'THF',
      category: 'Güç & Ağırlık',
    ),
    SportItem(
      code: 'hava-sporlari',
      name: 'Hava Sporları',
      federationName: 'Türkiye Hava Sporları Federasyonu',
      acronym: 'THSF',
      category: 'Havacılık & Ekstrem',
    ),
    SportItem(
      code: 'hentbol',
      name: 'Hentbol',
      federationName: 'Türkiye Hentbol Federasyonu',
      acronym: 'THF',
      category: 'Takım Sporları',
    ),
    SportItem(
      code: 'hokey',
      name: 'Hokey',
      federationName: 'Türkiye Hokey Federasyonu',
      acronym: 'THF',
      category: 'Takım Sporları',
    ),
    SportItem(
      code: 'isitme-engelliler',
      name: 'İşitme Engelliler Spor',
      federationName: 'Türkiye İşitme Engelliler Spor Federasyonu',
      acronym: 'TİESF',
      category: 'Paralimpik & Engelli',
    ),
    SportItem(
      code: 'izcilik',
      name: 'İzcilik',
      federationName: 'Türkiye İzcilik Federasyonu',
      acronym: 'TİF',
      category: 'Doğa & Gençlik',
    ),
    SportItem(
      code: 'judo',
      name: 'Judo',
      federationName: 'Türkiye Judo Federasyonu',
      acronym: 'TJF',
      category: 'Dövüş Sporları',
    ),
    SportItem(
      code: 'kano',
      name: 'Kano',
      federationName: 'Türkiye Kano Federasyonu',
      acronym: 'TKF',
      category: 'Su Sporları',
    ),
    SportItem(
      code: 'karate',
      name: 'Karate',
      federationName: 'Türkiye Karate Federasyonu',
      acronym: 'TKF',
      category: 'Dövüş Sporları',
    ),
    SportItem(
      code: 'kayak',
      name: 'Kayak',
      federationName: 'Türkiye Kayak Federasyonu',
      acronym: 'TKF',
      category: 'Kış Sporları',
    ),
    SportItem(
      code: 'kaykay',
      name: 'Kaykay',
      federationName: 'Türkiye Kaykay Federasyonu',
      acronym: 'TKF',
      category: 'Ekstrem Sporlar',
    ),
    SportItem(
      code: 'kick-boks',
      name: 'Kick Boks',
      federationName: 'Türkiye Kick Boks Federasyonu',
      acronym: 'TKBF',
      category: 'Dövüş Sporları',
    ),
    SportItem(
      code: 'kizak',
      name: 'Kızak',
      federationName: 'Türkiye Kızak Federasyonu',
      acronym: 'TKF',
      category: 'Kış Sporları',
    ),
    SportItem(
      code: 'kurek',
      name: 'Kürek',
      federationName: 'Türkiye Kürek Federasyonu',
      acronym: 'TKF',
      category: 'Su Sporları',
    ),
    SportItem(
      code: 'masa-tenisi',
      name: 'Masa Tenisi',
      federationName: 'Türkiye Masa Tenisi Federasyonu',
      acronym: 'TMTF',
      category: 'Raket Sporları',
    ),
    SportItem(
      code: 'modern-pentatlon',
      name: 'Modern Pentatlon',
      federationName: 'Türkiye Modern Pentatlon Federasyonu',
      acronym: 'TMPF',
      category: 'Çoklu & Kombine',
    ),
    SportItem(
      code: 'motosiklet',
      name: 'Motosiklet',
      federationName: 'Türkiye Motosiklet Federasyonu',
      acronym: 'TMF',
      category: 'Motor Sporları',
    ),
    SportItem(
      code: 'muaythai',
      name: 'Muaythai',
      federationName: 'Türkiye Muaythai Federasyonu',
      acronym: 'TMTF',
      category: 'Dövüş Sporları',
    ),
    SportItem(
      code: 'okculuk',
      name: 'Okçuluk',
      federationName: 'Türkiye Okçuluk Federasyonu',
      acronym: 'TOF',
      category: 'Hedef Sporları',
    ),
    SportItem(
      code: 'oryantiring',
      name: 'Oryantiring',
      federationName: 'Türkiye Oryantiring Federasyonu',
      acronym: 'TOF',
      category: 'Doğa & Zihin',
    ),
    SportItem(
      code: 'otomobil-sporlari',
      name: 'Otomobil Sporları',
      federationName: 'Türkiye Otomobil Sporları Federasyonu',
      acronym: 'TOSFED',
      category: 'Motor Sporları',
    ),
    SportItem(
      code: 'ozel-sporcular',
      name: 'Özel Sporcular',
      federationName: 'Türkiye Özel Sporcular Spor Federasyonu',
      acronym: 'TÖSSFED',
      category: 'Paralimpik & Engelli',
    ),
    SportItem(
      code: 'rafting',
      name: 'Rafting',
      federationName: 'Türkiye Rafting Federasyonu',
      acronym: 'TRF',
      category: 'Su & Doğa',
    ),
    SportItem(
      code: 'ragbi',
      name: 'Ragbi',
      federationName: 'Türkiye Ragbi Federasyonu',
      acronym: 'TRF',
      category: 'Takım Sporları',
    ),
    SportItem(
      code: 'satranc',
      name: 'Satranç',
      federationName: 'Türkiye Satranç Federasyonu',
      acronym: 'TSF',
      category: 'Zihin Sporları',
    ),
    SportItem(
      code: 'su-topu',
      name: 'Sutopu',
      federationName: 'Türkiye Sutopu Federasyonu',
      acronym: 'TSTF',
      category: 'Su & Takım',
    ),
    SportItem(
      code: 'sualti-sporlari',
      name: 'Sualtı Sporları',
      federationName: 'Türkiye Sualtı Sporları Federasyonu',
      acronym: 'TSSF',
      category: 'Su Sporları',
    ),
    SportItem(
      code: 'taekwondo',
      name: 'Taekwondo',
      federationName: 'Türkiye Taekwondo Federasyonu',
      acronym: 'TTF',
      category: 'Dövüş Sporları',
    ),
    SportItem(
      code: 'tenis',
      name: 'Tenis',
      federationName: 'Türkiye Tenis Federasyonu',
      acronym: 'TTF',
      category: 'Raket Sporları',
    ),
    SportItem(
      code: 'triatlon',
      name: 'Triatlon',
      federationName: 'Türkiye Triatlon Federasyonu',
      acronym: 'TTF',
      category: 'Dayanıklılık & Çoklu',
    ),
    SportItem(
      code: 'voleybol',
      name: 'Voleybol',
      federationName: 'Türkiye Voleybol Federasyonu',
      acronym: 'TVF',
      category: 'Takım Sporları',
    ),
    SportItem(
      code: 'vucut-gelistirme-fitness',
      name: 'Vücut Geliştirme ve Fitness',
      federationName:
          'Türkiye Vücut Geliştirme, Fitness ve Bilek Güreşi Federasyonu',
      acronym: 'TVGFBF',
      category: 'Güç & Fitness',
    ),
    SportItem(
      code: 'wushu-kung-fu',
      name: 'Wushu Kung-Fu',
      federationName: 'Türkiye Wushu Kung Fu Federasyonu',
      acronym: 'TWKF',
      category: 'Dövüş Sporları',
    ),
    SportItem(
      code: 'yelken',
      name: 'Yelken',
      federationName: 'Türkiye Yelken Federasyonu',
      acronym: 'TYF',
      category: 'Su & Rüzgar',
    ),
    SportItem(
      code: 'yuzme',
      name: 'Yüzme',
      federationName: 'Türkiye Yüzme Federasyonu',
      acronym: 'TYF',
      category: 'Su Sporları',
    ),
  ];

  static SportItem? findByCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final item in all) {
      if (item.code == code) return item;
    }
    return null;
  }

  static List<SportItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((item) {
      return item.name.toLowerCase().contains(q) ||
          item.federationName.toLowerCase().contains(q) ||
          item.acronym.toLowerCase().contains(q) ||
          item.code.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q);
    }).toList();
  }

  static List<String> get categories {
    final set = <String>{};
    for (final item in all) {
      set.add(item.category);
    }
    return set.toList()..sort();
  }

  static List<SportItem> byCategory(String category) {
    return all.where((item) => item.category == category).toList();
  }
}
