import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';

import '../config/app_environment.dart';
import '../diagnostics/diagnostic_runtime.dart';
import '../push/push_service.dart';
import '../swansport_app.dart';
import 'startup_failure_app.dart';

/// Uygulamayı başlatır.
///
/// [supabaseConfig] tanımlıysa istemci uygulamadan önce hazırlanır ve özellik
/// sağlayıcıları canlı veri kaynaklarına geçer.
///
/// Backend'e ulaşılamazsa davranış ortama göre değişir:
///
/// * **Development** — sabit örnek veriye (fixture) düşer; backend olmadan da
///   ekranlar geliştirilebilsin diye.
/// * **Production** — fixture'a DÜŞMEZ. Sahte veriyi gerçek sanmak, boş ekran
///   görmekten daha kötüdür: kullanıcı kulübünün kayıtlarına baktığını sanır.
///   Bunun yerine ne olduğunu söyleyen ve tekrar denemeye izin veren bir
///   bağlantı hatası ekranı gösterilir.
Future<void> bootstrap(
  AppEnvironment environment, {
  SupabaseConfig supabaseConfig = SupabaseConfig.empty,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(initializeAppDiagnostics());

  var effectiveConfig = supabaseConfig;
  Object? startupError;

  if (supabaseConfig.isConfigured) {
    final key = supabaseConfig.anonKey;
    // Supabase eski JWT anon anahtarından (eyJ...) yeni yayımlanabilir anahtar
    // biçimine (sb_publishable_...) geçiyor; değer hangi biçimdeyse ona uygun
    // parametreye yönlendirilir.
    try {
      if (key.startsWith('sb_publishable_')) {
        await Supabase.initialize(
          url: supabaseConfig.url,
          httpClient: DiagnosticHttpClient(
              http.Client(), DiagnosticsRecorder.instance,
              backendHost: Uri.parse(supabaseConfig.url).host),
          publishableKey: key,
        ).timeout(const Duration(seconds: 10));
      } else {
        await Supabase.initialize(
          url: supabaseConfig.url,
          httpClient: DiagnosticHttpClient(
              http.Client(), DiagnosticsRecorder.instance,
              backendHost: Uri.parse(supabaseConfig.url).host),
          // ignore: deprecated_member_use
          anonKey: key,
        ).timeout(const Duration(seconds: 10));
      }
      await bindAppDiagnostics(Supabase.instance.client);
      debugPrint('SwanSport: Supabase initialized (${supabaseConfig.url}).');
    } catch (error, stackTrace) {
      DiagnosticsRecorder.instance
          .capture(error, stackTrace, operation: 'auth');
      startupError = error;
      debugPrint('SwanSport: Supabase.initialize FAILED: $error');
      debugPrint('$stackTrace');

      if (environment.isProduction) {
        // Üretimde sahte veri gösterme — hatayı açıkça bildir.
        runApp(StartupFailureApp(
          environment: environment,
          error: error,
          onRetry: () => bootstrap(environment, supabaseConfig: supabaseConfig),
        ));
        return;
      }

      // Geliştirmede fixture'a düş.
      effectiveConfig = SupabaseConfig.empty;
    }
  } else if (environment.isProduction) {
    // Üretim derlemesinde yapılandırma hiç verilmemişse bu bir dağıtım
    // hatasıdır; sessizce fixture moda geçmek onu gizler.
    runApp(StartupFailureApp(
      environment: environment,
      error: const AppEnvironmentException(
          'Supabase yapılandırması bulunamadı (URL/anahtar eksik).'),
      onRetry: null,
    ));
    return;
  }

  if (startupError != null) {
    debugPrint('SwanSport: fixture moduna geçildi (geliştirme ortamı).');
  }

  runApp(
    ProviderScope(
      observers: [DiagnosticProviderObserver()],
      overrides: <Override>[
        appEnvironmentProvider.overrideWithValue(environment),
        supabaseConfigProvider.overrideWithValue(effectiveConfig),
      ],
      child: const PushLifecycleObserver(child: SwanSportApp()),
    ),
  );
}
