import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';

import '../config/app_environment.dart';
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
          publishableKey: key,
        ).timeout(const Duration(seconds: 10));
      } else {
        await Supabase.initialize(
          url: supabaseConfig.url,
          // ignore: deprecated_member_use
          anonKey: key,
        ).timeout(const Duration(seconds: 10));
      }
      debugPrint('SwanSport: Supabase initialized (${supabaseConfig.url}).');
    } catch (error, stackTrace) {
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
      overrides: <Override>[
        appEnvironmentProvider.overrideWithValue(environment),
        supabaseConfigProvider.overrideWithValue(effectiveConfig),
      ],
      child: const SwanSportApp(),
    ),
  );
}
