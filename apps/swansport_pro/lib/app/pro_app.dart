import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/pro_auth_gate.dart';
import 'pro_router.dart';
import 'pro_theme.dart';

class ProApp extends ConsumerWidget {
  const ProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(proRouterProvider);

    return MaterialApp.router(
      title: 'SwanSport Pro',
      debugShowCheckedModeBanner: false,
      theme: ProTheme.dark(),
      routerConfig: router,
      builder: (context, child) {
        return ProAuthGate(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
