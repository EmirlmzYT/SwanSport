import 'dart:io';

import 'package:apk_sideload/install_apk.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// APK'yı uygulama içinde indirir ve Android kurulum ekranını açar.
///
/// İndirmeyi kendimiz yazıyoruz (`http` zaten bağımlılık) — hazır "güncelleyici"
/// paketleri bu işi de yapıyor ama hepsi çok az kullanılan küçük paketler;
/// güncelleme yolu gibi kritik bir yere bakımsız kod koymak istemedik.
/// Üçüncü parti yalnızca son adımda: `apk_sideload` Android'in FileProvider +
/// kurulum niyeti (intent) kısmını hallediyor, o kadar.
///
/// **Sınır — dürüst olalım:** Android yine "bilinmeyen kaynaklardan kuruluma
/// izin ver" iznini ve kendi kurulum onay ekranını gösterecek. Bu işletim
/// sistemi seviyesinde ve atlatılamaz (atlatılmamalı da). Kaldırdığımız şey
/// tarayıcıya atlayıp indirilenler klasöründe dosya arama adımı.

/// İndirme ilerlemesi: 0.0 – 1.0. Boyut bilinmiyorsa null gelir.
typedef ProgressCallback = void Function(double? progress);

class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// APK'yı indirip kurulum ekranını açar.
///
/// Hata durumunda [UpdateDownloadException] fırlatır — çağıran taraf
/// kullanıcıya anlaşılır bir cümle gösterip tarayıcıya düşebilsin diye.
Future<void> downloadAndInstall(
  String url, {
  ProgressCallback? onProgress,
}) async {
  final File file;
  try {
    // Uygulamanın kendi geçici klasörü: harici depolama izni gerektirmiyor
    // ve sistem gerektiğinde kendisi temizliyor.
    final dir = await getTemporaryDirectory();
    file = File('${dir.path}/swansport-update.apk');

    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw UpdateDownloadException(
          'Dosya indirilemedi (${response.statusCode}).');
    }

    final total = response.contentLength;
    var received = 0;
    final sink = file.openWrite();

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(total == null ? null : received / total);
      }
    } finally {
      await sink.close();
    }

    // Yarım inen dosyayı kurmaya çalışmak "bozuk paket" hatası verir;
    // burada yakalamak daha anlaşılır.
    if (total != null && received < total) {
      throw const UpdateDownloadException(
          'İndirme yarıda kesildi. Bağlantını kontrol edip tekrar dene.');
    }
  } on UpdateDownloadException {
    rethrow;
  } catch (e) {
    throw UpdateDownloadException('İndirme başarısız: $e');
  }

  try {
    await InstallApk().installApk(file.path);
  } catch (e) {
    throw UpdateDownloadException(
        'Kurulum başlatılamadı. Ayarlar\'dan "bilinmeyen kaynaklardan '
        'kuruluma izin ver" seçeneğini açman gerekebilir.');
  }
}
