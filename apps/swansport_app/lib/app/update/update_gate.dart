import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_navigator.dart';
import 'update_checker.dart';

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

    // Bu sürümü zaten kapatmışsa bir daha aynı açılışta göstermeyelim de,
    // sonraki açılışlarda tekrar hatırlatalım — dismissed bilgisi kalıcı
    // değil, bilerek: güncellemeyi unutmak kolay olmasın.
    final prefs = await SharedPreferences.getInstance();
    final dismissedThisSession = prefs.getString('update_dismissed_run') ==
        '${DateTime.now().year}${DateTime.now().month}${DateTime.now().day}${update.version}';
    if (dismissedThisSession) return;

    final messenger = swanMessengerKey.currentState;
    if (messenger == null) return;

    messenger.showMaterialBanner(MaterialBanner(
      content: Text('Yeni sürüm var: ${update.version}'),
      leading: const Icon(Icons.system_update_rounded),
      actions: [
        TextButton(
          onPressed: () async {
            messenger.hideCurrentMaterialBanner();
            final today = DateTime.now();
            final prefs2 = await SharedPreferences.getInstance();
            await prefs2.setString('update_dismissed_run',
                '${today.year}${today.month}${today.day}${update.version}');
          },
          child: const Text('Sonra'),
        ),
        FilledButton(
          onPressed: () async {
            messenger.hideCurrentMaterialBanner();
            await launchUrl(Uri.parse(update.downloadUrl),
                mode: LaunchMode.externalApplication);
          },
          child: const Text('İndir'),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
