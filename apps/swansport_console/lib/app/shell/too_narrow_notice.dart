import 'package:flutter/material.dart';

import '../theme/console_theme.dart';

/// Ekran konsol için çok darsa gösterilir.
///
/// Konsolu telefona sığdırmaya çalışmak iki arayüzü birden bozardı: yoğun
/// tablolar dar ekranda okunmaz, mobil için sadeleştirilmiş konsol da masa
/// başındaki işi görmez. Mobil kitlenin zaten uygulaması var — doğru cevap
/// onu göstermek.
class TooNarrowNotice extends StatelessWidget {
  const TooNarrowNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(ConsoleDensity.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.desktop_windows_rounded,
                    size: 32, color: t.colorScheme.primary),
                const SizedBox(height: ConsoleDensity.lg),
                Text('Konsol masaüstü içindir',
                    style: t.textTheme.titleLarge),
                const SizedBox(height: ConsoleDensity.sm),
                Text(
                  'Yönetim ekranları geniş tablolar ve yan yana paneller '
                  'kullanıyor; ${ConsoleDensity.minSupportedWidth.toInt()} '
                  'pikselden dar ekranda okunmuyor.\n\n'
                  'Bilgisayardan aç ya da telefonda SwanSport uygulamasını '
                  'kullan.',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
