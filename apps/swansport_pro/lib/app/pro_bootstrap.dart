import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';

import '../features/auth/pro_startup_failure_screen.dart';
import 'pro_app.dart';
import 'pro_environment.dart';

typedef SupabaseInitializer = Future<void> Function(SupabaseConfig config);
typedef WidgetRunner = void Function(Widget app);

/// SwanSport Pro uygulamasını başlatır.
///
/// Üretim ortamında Supabase yapılandırması eksikse veya başlatma başarısız olursa
/// uygulama kesin olarak kapalı konuma geçer (fail-closed) ve sahte/fixture veriye
/// asla düşmez; hata ekranı gösterir.
Future<void> bootstrapPro(
  ProEnvironment environment, {
  SupabaseConfig config = SupabaseConfig.empty,
  SupabaseInitializer? initializeSupabase,
  WidgetRunner? runWidgetApp,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final runner = runWidgetApp ?? runApp;

  if (config.isConfigured) {
    try {
      if (initializeSupabase != null) {
        await initializeSupabase(config);
      } else {
        final key = config.anonKey;
        if (key.startsWith('sb_publishable_')) {
          await Supabase.initialize(
            url: config.url,
            publishableKey: key,
          ).timeout(const Duration(seconds: 10));
        } else {
          await Supabase.initialize(
            url: config.url,
            // ignore: deprecated_member_use
            anonKey: key,
          ).timeout(const Duration(seconds: 10));
        }
      }
    } catch (error) {
      runner(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ProStartupFailureScreen(
            environment: environment,
            error: error,
            onRetry: () => bootstrapPro(
              environment,
              config: config,
              initializeSupabase: initializeSupabase,
              runWidgetApp: runWidgetApp,
            ),
          ),
        ),
      );
      return;
    }
  } else if (environment.isProduction) {
    runner(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ProStartupFailureScreen(
          environment: environment,
          error: const ProEnvironmentException(
            'Supabase yapılandırması bulunamadı (URL veya API anahtarı eksik).',
          ),
        ),
      ),
    );
    return;
  }

  runner(
    ProviderScope(
      overrides: [
        proEnvironmentProvider.overrideWithValue(environment),
        supabaseConfigProvider.overrideWithValue(config),
        pushAppTargetProvider.overrideWithValue(PushAppTarget.pro),
      ],
      child: const ProApp(),
    ),
  );
}
