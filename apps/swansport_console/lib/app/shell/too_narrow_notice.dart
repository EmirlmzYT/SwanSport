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
    final isDark = t.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ConsoleTheme.commandBackground,
                    ConsoleTheme.commandSurface,
                  ],
                )
              : null,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(ConsoleDensity.xl),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(ConsoleDensity.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: t.colorScheme.primary.withValues(alpha: .14),
                          borderRadius:
                              BorderRadius.circular(ConsoleDensity.radius),
                          border: Border.all(
                            color: t.colorScheme.primary.withValues(alpha: .32),
                          ),
                        ),
                        child: Icon(
                          Icons.desktop_windows_rounded,
                          size: 24,
                          color: t.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: ConsoleDensity.lg),
                      Text(
                        'Konsol masaüstü içindir',
                        style: t.textTheme.titleLarge,
                      ),
                      const SizedBox(height: ConsoleDensity.sm),
                      Text(
                        'Yönetim ekranları geniş tablolar ve yan yana paneller '
                        'kullanıyor; ${ConsoleDensity.minSupportedWidth.toInt()} '
                        'pikselden dar ekranda okunmuyor.\n\n'
                        'Bilgisayardan aç ya da telefonda SwanSport uygulamasını '
                        'kullan.',
                        style: t.textTheme.bodySmall?.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
