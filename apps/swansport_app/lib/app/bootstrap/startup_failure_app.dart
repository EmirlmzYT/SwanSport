import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../config/app_environment.dart';

/// Backend'e ulaşılamadığında üretimde gösterilen ekran.
///
/// Fixture moduna düşmek yerine bunu göstermenin sebebi: sahte veriyi gerçek
/// sanmak, hiç veri görmemekten daha kötüdür. Kullanıcı kulübünün kayıtlarına
/// baktığını sanıp yanlış karar verebilir.
///
/// Tasarım dili uygulamanın geri kalanıyla aynı; ancak burada tema sağlayıcı
/// henüz kurulmadığı için renkler doğrudan verilir.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    super.key,
    required this.environment,
    required this.error,
    this.onRetry,
  });

  final AppEnvironment environment;
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    const ground = Color(0xFF0A111E);
    const surface = Color(0xFF131D2E);
    const line = Color(0xFF233149);
    const teal = Color(0xFF14B8B1);
    const muted = Color(0xFF8FA0B8);

    return MaterialApp(
      title: environment.appName,
      debugShowCheckedModeBanner: false,
      theme: SwanTheme.dark(),
      home: Scaffold(
        backgroundColor: ground,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: line),
                    ),
                    child: const Icon(Icons.cloud_off_rounded,
                        size: 30, color: teal),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Sunucuya ulaşılamadı',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'İnternet bağlantını kontrol edip tekrar dene. '
                    'Bağlantın varsa sunucu geçici olarak yanıt vermiyor '
                    'olabilir.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: muted, fontSize: 14, height: 1.5),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: teal,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text(
                          'Tekrar dene',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                  // Hata ayrıntısı yalnızca geliştirmede; kullanıcıya teknik
                  // mesaj göstermek bilgi vermiyor, yalnızca kaygı veriyor.
                  if (environment.isDevelopment) ...[
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: line),
                      ),
                      child: Text(
                        '$error',
                        style: const TextStyle(
                            color: muted, fontSize: 11.5, height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
