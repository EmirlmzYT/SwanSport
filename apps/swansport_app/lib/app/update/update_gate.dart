import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_navigator.dart';
import 'update_checker.dart';
import 'update_downloader.dart';

/// Uygulama açılışında bir kez güncelleme kontrolü yapar, varsa kalıcı bir
/// banner gösterir.
///
/// `MaterialApp(builder: ...)` içine sarılır — hangi ekranda olursa olsun
/// tek yerden çalışır, her ekrana ayrı ayrı eklenmesi gerekmez.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({required this.child, super.key});
  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    // Yalnızca Android APK kurulumu için anlamlı — web zaten her deploy'da
    // otomatik güncelleniyor, indirme linki APK olduğu için web/masaüstüde
    // göstermek kafa karıştırırdı.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final update = await checkForUpdate();
    if (update == null) return;

    // Bu sürümü bugün kapatmışsa tekrar göstermeyelim; yarın yine
    // hatırlatalım — güncellemeyi unutmak kolay olmasın diye kalıcı olarak
    // susturmuyoruz.
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('update_dismissed_run') == _dismissKey(update.version)) {
      return;
    }

    final messenger = swanMessengerKey.currentState;
    if (messenger == null) return;

    messenger.showMaterialBanner(MaterialBanner(
      content: Text('Yeni sürüm var: ${update.version}'),
      leading: const Icon(Icons.system_update_rounded),
      actions: [
        TextButton(
          onPressed: () async {
            messenger.hideCurrentMaterialBanner();
            final prefs2 = await SharedPreferences.getInstance();
            await prefs2.setString(
                'update_dismissed_run', _dismissKey(update.version));
          },
          child: const Text('Sonra'),
        ),
        FilledButton(
          onPressed: () {
            messenger.hideCurrentMaterialBanner();
            _startDownload(update);
          },
          child: const Text('Güncelle'),
        ),
      ],
    ));
  }

  String _dismissKey(String version) {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}-$version';
  }

  void _startDownload(UpdateInfo update) {
    final context = swanNavigatorKey.currentContext;
    if (context == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadDialog(update: update),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// İndirme ilerlemesini gösterir, bitince Android kurulum ekranını açar.
///
/// Başarısız olursa tarayıcıya düşme seçeneği sunuyor — uygulama içi kurulum
/// cihaz ayarlarına bağlı olduğu için her telefonda çalışacağının garantisi
/// yok, kullanıcıyı çıkmaz sokakta bırakmamalı.
class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.update});
  final UpdateInfo update;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double? _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      await downloadAndInstall(
        widget.update.downloadUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      // Kurulum ekranı açıldı; bu diyaloğun işi bitti.
      if (mounted) Navigator.of(context).pop();
    } on UpdateDownloadException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Beklenmeyen bir hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AlertDialog(
        title: const Text('Güncelleme yapılamadı'),
        content: Text(_error!),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await launchUrl(Uri.parse(widget.update.downloadUrl),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text('Tarayıcıda aç'),
          ),
        ],
      );
    }

    final percent = _progress == null ? null : (_progress! * 100).round();

    return AlertDialog(
      title: Text('${widget.update.version} indiriliyor'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 12),
        Text(percent == null ? 'İndiriliyor…' : '%$percent'),
        const SizedBox(height: 8),
        const Text(
            'İndirme bitince Android kurulum ekranı açılacak. İlk seferde '
            '"bilinmeyen kaynaklara izin ver" sorabilir.',
            style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}
