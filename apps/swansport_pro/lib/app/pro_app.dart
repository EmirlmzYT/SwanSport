import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/pro_auth_gate.dart';
import '../features/operations/pro_feature_host.dart';
import 'pro_router.dart';
import 'pro_theme.dart';
import 'push/pro_push_coordinator.dart';

class ProApp extends ConsumerWidget {
  const ProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(proRouterProvider);

    return MaterialApp.router(
      title: 'SwanSport Pro',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ProTheme.dark(),
      routerConfig: router,
      builder: (context, child) {
        return ProPushCoordinator(
          router: router,
          child: ProAuthGate(
            child: ProOperationsFeatureHost(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
