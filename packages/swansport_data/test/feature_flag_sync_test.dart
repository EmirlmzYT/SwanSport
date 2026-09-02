import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Bayrak anahtarları SQL ile Dart arasında birebir olmalı.
///
/// **Neden dosya okuyarak:** anahtarlar iki ayrı yerde tanımlı — migration'da
/// `insert into public.feature_flags` ve Dart'ta `FeatureFlags` sabitleri.
/// Ayrıştıklarında hiçbir hata çıkmıyor: sunucu `partner_search` derken
/// istemci `partnerSearch` arıyor, `has()` sessizce false dönüyor ve bayrak
/// **hiç açılmıyor.** Belirtisi yok; özellik yayınlandı sanılıyor.
///
/// Kırılganlığı kabul ediliyor: SQL biçimi değişirse bu test de güncellenir.
/// Koruduğu şey daha değerli.
void main() {
  // Paket kökünden depo köküne çık.
  final repo = Directory.current.path.replaceAll('\\', '/');
  final root = repo.endsWith('/packages/swansport_data')
      ? repo.substring(0, repo.length - '/packages/swansport_data'.length)
      : repo;

  Set<String> sqlKeys() {
    final dir = Directory('$root/supabase/migrations');
    final keys = <String>{};
    // `('anahtar', 'kademe', ...` biçimindeki satırlar. Yalnızca
    // feature_flags insert'lerinin içindekiler sayılıyor.
    final insert = RegExp(
        r'insert\s+into\s+public\.feature_flags[^;]*;',
        caseSensitive: false, dotAll: true);
    final row = RegExp(r"\(\s*'([a-z0-9_]+)'\s*,\s*'(off|admins|testers|everyone)'");

    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.sql')) continue;
      for (final m in insert.allMatches(f.readAsStringSync())) {
        for (final r in row.allMatches(m.group(0)!)) {
          keys.add(r.group(1)!);
        }
      }
    }
    return keys;
  }

  Set<String> dartKeys() {
    final src = File('$root/packages/swansport_data/lib/src/feature_flags.dart')
        .readAsStringSync();
    return RegExp(r"static const \w+ = '([a-z0-9_]+)';")
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toSet();
  }

  test('SQL bayraklarının hepsinin Dart sabiti var', () {
    final missing = sqlKeys().difference(dartKeys());
    expect(missing, isEmpty,
        reason: 'Bu anahtarlar SQL\'de tanımlı ama Dart sabiti yok. '
            'Sabitsiz kullanım yazım hatasını derlemede yakalamıyor: '
            '$missing');
  });

  test('Dart sabitlerinin hepsi SQL\'de tanımlı', () {
    final missing = dartKeys().difference(sqlKeys());
    expect(missing, isEmpty,
        reason: 'Bu sabitler Dart\'ta var ama hiçbir migration onları '
            'feature_flags tablosuna yazmıyor. Bayrak sunucuda yoksa '
            'my_feature_flags onu hiç döndürmez ve özellik hiç açılmaz: '
            '$missing');
  });

  test('en az yirmi bayrak tanımlı — regex boşa çalışmıyor', () {
    // Desen tutmazsa iki test de boş kümeyi boş kümeyle karşılaştırıp
    // geçerdi. Bu depoda tam olarak bu tuzağa düşüldü: `grep 'error •'`
    // hiçbir şey saymıyordu ve bir tur boyunca "0 hata" diye raporlandı.
    expect(sqlKeys().length, greaterThanOrEqualTo(20));
    expect(dartKeys().length, greaterThanOrEqualTo(20));
  });

  test('bilinen birkaç anahtar gerçekten okunuyor', () {
    expect(sqlKeys(), contains(FeatureFlags.marketplace));
    expect(sqlKeys(), contains(FeatureFlags.eligibilityGate));
    expect(sqlKeys(), contains(FeatureFlags.offlineAttendance));
  });
}
