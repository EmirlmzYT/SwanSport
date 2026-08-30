import 'package:shared_preferences/shared_preferences.dart';

/// Son kullanılan modüller — menünün en üstündeki kısayol satırı.
///
/// 39 modülün çoğu kişi 3–5 tanesini kullanıyor. Bu satır onlar için menüyü
/// tek bakışta çözüyor; gruplama ve arama geri kalan seyrek kullanım için.
///
/// Cihazda saklanıyor (`shared_preferences`), sunucuya gitmiyor: hangi
/// ekranları açtığın kişisel bir alışkanlık bilgisi, hesabın parçası değil.

const _kKey = 'recent_module_routes';

/// Satırda gösterilecek azami modül sayısı.
///
/// 6: iki satırlık ızgarada tam oturuyor ve "son kullanılan" olmaktan çıkıp
/// ikinci bir tam listeye dönüşmüyor.
const kRecentModuleLimit = 6;

Future<List<String>> recentRoutes() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_kKey) ?? const [];
}

/// Rotayı listenin başına taşır ve [kRecentModuleLimit] ile kırpar.
///
/// Zaten listedeyse kopyalanmaz, öne alınır — yoksa aynı modül satırı
/// doldururdu.
Future<void> pushRecent(String route) async {
  final prefs = await SharedPreferences.getInstance();
  final current = prefs.getStringList(_kKey) ?? const <String>[];
  final next = <String>[route, ...current.where((r) => r != route)];
  await prefs.setStringList(
      _kKey, next.take(kRecentModuleLimit).toList(growable: false));
}

/// Saf sıralama mantığı — test edilebilir olsun diye ayrı.
///
/// [pushRecent] bunun `shared_preferences` sarmalayıcısı; kural burada.
List<String> nextRecents(List<String> current, String route) =>
    <String>[route, ...current.where((r) => r != route)]
        .take(kRecentModuleLimit)
        .toList(growable: false);
