import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

/// Konsolu kullanan kitleler.
///
/// Beşi de bugünden tanımlı, üçü henüz kullanılmıyor. Sebep: yeni bir kitle
/// eklemek — muhasebeci, pazar yeri satıcısı, federasyon — kenar çubuğunu,
/// yönlendiriciyi ve yetki katmanını ayrı ayrı değiştirmek olmasın. Yuva
/// açık; içi geldiğinde `kConsoleModules` listesine satır eklenir.
///
/// Yeni **tablo** açılmaz: bu enum yalnızca arayüz gruplandırmasıdır, veri
/// modeli değildir.
enum ConsoleAudience {
  clubStaff,
  platformAdmin,
  federation,
  accountant,
  marketplace,
}

extension ConsoleAudienceX on ConsoleAudience {
  String get label => switch (this) {
        ConsoleAudience.clubStaff => 'Kulüp',
        ConsoleAudience.platformAdmin => 'Platform',
        ConsoleAudience.federation => 'Federasyon',
        ConsoleAudience.accountant => 'Muhasebe',
        ConsoleAudience.marketplace => 'Pazar Yeri',
      };
}

/// Bir kitlenin konsolda açık olup olmadığı.
///
/// Kim olduğun hesabı paylaşılan pakette (`SwanAccess`); burada yalnızca o
/// hesabın konsol kitlelerine çevrilmesi var. Eskiden bu dosya erişimi
/// sıfırdan hesaplıyordu ve mobil uygulamanın hesabıyla ayrışma riski
/// taşıyordu — kademe eşiği gibi bir kural değişince biri güncellenip diğeri
/// unutulabilirdi.
extension ConsoleAudienceAccess on SwanAccess {
  bool allows(ConsoleAudience a) => switch (a) {
        ConsoleAudience.clubStaff => isClubStaff,
        ConsoleAudience.platformAdmin => isPlatformAdmin,
        // Henüz kimseye açılmadı — modül yazıldığında burası dolacak.
        ConsoleAudience.federation ||
        ConsoleAudience.accountant ||
        ConsoleAudience.marketplace =>
          false,
      };
}

/// Konsolun erişim profili — paylaşılan hesabın aynısı.
///
/// Ayrı bir isimle duruyor ki konsol kodu `swanAccessProvider`'ı doğrudan
/// bilmek zorunda kalmasın; ileride konsola özel bir kural eklenirse (ör.
/// "yalnızca masaüstünden erişilebilen bir kitle") burası genişler.
final consoleAccessProvider = Provider<SwanAccess>((ref) {
  return ref.watch(swanAccessProvider);
});

/// Kenar çubuğundaki ve yönlendiricideki tek modül listesi.
class ConsoleModule {
  const ConsoleModule({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    required this.audience,
    required this.builder,
    this.minCoachLevel = 0,
  });

  final String id;
  final String label;
  final IconData icon;

  /// Gerçek URL yolu — konsol kullanıcısı sekme açar, yer imi koyar.
  final String route;

  final ConsoleAudience audience;

  /// Kulüp modülleri için asgari kademe (0 = kademe şartı yok).
  final int minCoachLevel;

  final WidgetBuilder builder;

  bool visibleTo(SwanAccess a) {
    if (!a.allows(audience)) return false;
    // Kademe eşiği kontrolü paylaşılan hesapta: kulüp yöneticisi kademesiz de
    // olsa geçer, kuralın kendisi tek yerde durur.
    return a.hasCoachLevel(minCoachLevel);
  }
}
