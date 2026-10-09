import 'dart:async';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';

import 'console_app.dart';
import 'theme/console_theme.dart';

bool _diagnosticHandlersInstalled = false;

class _ConsoleDiagnosticObserver extends ProviderObserver {
  @override
  void providerDidFail(ProviderBase<Object?> provider, Object error,
      StackTrace stackTrace, ProviderContainer container) {
    container
        .read(diagnosticsProvider)
        .capture(error, stackTrace, code: 'provider', operation: 'provider');
  }
}

/// Konsolu başlatır.
///
/// **Fixture modu yoktur.** Mobil uygulama backend'e ulaşamadığında
/// geliştirme ortamında örnek veriye düşebiliyor; konsol düşmez. Sebep:
/// burada yapılan iş okumak değil yönetmek. Sahte bir kadroda toplu düzenleme
/// yapmak, sahte bir faturayı "ödendi" işaretlemek boş ekrandan çok daha
/// kötüdür. Bağlantı yoksa her ortamda hata gösterilir.
Future<void> bootstrapConsole({
  SupabaseConfig supabaseConfig = const SupabaseConfig(url: '', anonKey: ''),
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final recorder = DiagnosticsRecorder.instance;
  recorder.application = 'console';
  recorder.platform = 'web';
  recorder.release =
      const String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');
  unawaited(DiagnosticPreferencesController.initialize(recorder));
  if (!_diagnosticHandlersInstalled) {
    _diagnosticHandlersInstalled = true;
    final previousError = FlutterError.onError;
    FlutterError.onError = (details) {
      recorder.capture(details.exception, details.stack ?? StackTrace.current,
          code: 'framework', operation: 'framework');
      if (previousError != null) {
        previousError(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    final previousAsync = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      recorder.capture(error, stack, operation: 'async');
      return previousAsync?.call(error, stack) ?? false;
    };
  }

  // Adres çubuğunda `/#/sporcular` değil `/sporcular` görünsün — konsol
  // kullanıcısı yer imi koyar ve linki paylaşır.
  usePathUrlStrategy();

  if (!supabaseConfig.isConfigured) {
    runApp(const _StartupFailure(
      message: 'Supabase yapılandırması bulunamadı (URL/anahtar eksik).',
      detail: 'Derleme --dart-define-from-file=env/prod.json ile yapılmalı.',
    ));
    return;
  }

  try {
    final key = supabaseConfig.anonKey;
    if (key.startsWith('sb_publishable_')) {
      await Supabase.initialize(
        url: supabaseConfig.url,
        httpClient: DiagnosticHttpClient(http.Client(), recorder,
            backendHost: Uri.parse(supabaseConfig.url).host),
        publishableKey: key,
      ).timeout(const Duration(seconds: 10));
    } else {
      await Supabase.initialize(
        url: supabaseConfig.url,
        httpClient: DiagnosticHttpClient(http.Client(), recorder,
            backendHost: Uri.parse(supabaseConfig.url).host),
        // ignore: deprecated_member_use
        anonKey: key,
      ).timeout(const Duration(seconds: 10));
    }
  } catch (error) {
    runApp(_StartupFailure(
      message: 'Sunucuya bağlanılamadı.',
      detail: '$error',
      onRetry: () => bootstrapConsole(supabaseConfig: supabaseConfig),
    ));
    return;
  }

  await recorder.bind(Supabase.instance.client);
  runApp(
    ProviderScope(
      observers: [_ConsoleDiagnosticObserver()],
      overrides: [
        supabaseConfigProvider.overrideWithValue(supabaseConfig),
      ],
      child: const ConsoleApp(),
    ),
  );
}

class _StartupFailure extends StatelessWidget {
  const _StartupFailure({
    required this.message,
    required this.detail,
    this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ConsoleTheme.light(),
      darkTheme: ConsoleTheme.dark(),
      home: Builder(
        builder: (context) {
          final t = Theme.of(context);
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cloud_off_rounded,
                        size: 30, color: t.colorScheme.error),
                    const SizedBox(height: ConsoleDensity.lg),
                    Text(message, style: t.textTheme.titleLarge),
                    const SizedBox(height: ConsoleDensity.sm),
                    Text(detail, style: t.textTheme.bodySmall),
                    if (onRetry != null) ...[
                      const SizedBox(height: ConsoleDensity.xl),
                      FilledButton(
                        onPressed: onRetry,
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
