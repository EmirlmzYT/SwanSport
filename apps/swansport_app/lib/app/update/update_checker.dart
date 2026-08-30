import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// APK güncelleme kontrolü — Play Store'suz dağıtımın orta yolu.
///
/// Gerçek otomatik güncelleme değil: kullanıcı yine "bilinmeyen kaynak"
/// iznini onaylayıp APK'yı kendisi kuracak. Bunun kaldırdığı tek şey bizim
/// tarafı — yeni sürümü elden göndermek yerine GitHub Release'e yüklemek
/// yeterli, uygulama kendi kendine haber veriyor.
///
/// GitHub deposu **public** olduğu için Releases API kimlik doğrulaması
/// istemiyor ve CORS'a açık — hem native hem web derlemede çalışıyor.
const kReleasesUrl =
    'https://api.github.com/repos/EmirlmzYT/SwanSport/releases/latest';

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.notes,
  });

  final String version;
  final String downloadUrl;
  final String? notes;
}

/// Yeni sürüm varsa döner; yoksa (ya da kontrol başarısızsa) null.
///
/// Ağ hatası, henüz hiç release yokluğu (404) gibi durumlar sessizce null
/// döner — bu bir kritik akış değil, başarısız olursa uygulama olduğu gibi
/// çalışmaya devam etmeli.
Future<UpdateInfo?> checkForUpdate() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final localVersion = '${info.version}+${info.buildNumber}';

    final res = await http
        .get(Uri.parse(kReleasesUrl),
            headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (body['tag_name'] as String?) ?? '';
    final remoteVersion = tag.startsWith('v') ? tag.substring(1) : tag;

    if (!isVersionNewer(remoteVersion, localVersion)) return null;

    final assets = (body['assets'] as List?) ?? const [];
    final apk = assets.cast<Map<String, dynamic>>().firstWhere(
          (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
          orElse: () => const {},
        );
    final url = apk['browser_download_url'] as String?;
    if (url == null) return null;

    return UpdateInfo(
      version: remoteVersion,
      downloadUrl: url,
      notes: body['body'] as String?,
    );
  } catch (_) {
    return null;
  }
}

/// `remote`, `local`'dan yeni mi? İkisi de `major.minor.patch(+build)`.
///
/// Yalnızca sürüm adını değil build numarasını da kıyaslar: aynı sürüm
/// adıyla hızlı bir düzeltme (`0.1.0+2`) yayınlarsak da kullanıcıya haber
/// gitsin diye. Ayrıştırılamayan bir sürüm "daha yeni değil" sayılır —
/// belirsizlikte kullanıcıyı gereksiz yere APK indirmeye yönlendirmemek
/// yanlış negatiften iyidir.
bool isVersionNewer(String remote, String local) {
  final r = _Version.parse(remote);
  final l = _Version.parse(local);
  if (r == null || l == null) return false;
  return r.isNewerThan(l);
}

class _Version {
  const _Version(this.major, this.minor, this.patch, this.build);

  final int major;
  final int minor;
  final int patch;
  final int build;

  static _Version? parse(String raw) {
    final parts = raw.split('+');
    final semver = parts[0].split('.');
    if (semver.length < 3) return null;
    final major = int.tryParse(semver[0]);
    final minor = int.tryParse(semver[1]);
    final patch = int.tryParse(semver[2]);
    if (major == null || minor == null || patch == null) return null;
    final build = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return _Version(major, minor, patch, build);
  }

  bool isNewerThan(_Version other) {
    if (major != other.major) return major > other.major;
    if (minor != other.minor) return minor > other.minor;
    if (patch != other.patch) return patch > other.patch;
    return build > other.build;
  }
}
