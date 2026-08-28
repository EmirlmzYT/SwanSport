import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'console_router.dart';
import 'theme/console_theme.dart';

class ConsoleApp extends ConsumerWidget {
  const ConsoleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SwanSport Konsol',
      debugShowCheckedModeBanner: false,
      theme: ConsoleTheme.light(),
      darkTheme: ConsoleTheme.dark(),
      routerConfig: ref.watch(consoleRouterProvider),
    );
  }
}
