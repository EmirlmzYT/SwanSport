import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_app/app/navigation/app_router.dart';
import 'package:swansport_app/app/navigation/app_routes.dart';
import 'package:swansport_app/app/navigation/swan_navigation.dart';
import 'package:swansport_app/app/widgets/app_shell.dart';

void main() {
  late GoRouter router;

  tearDown(() => router.dispose());

  testWidgets(
      'Android back button on non-feed branch returns to feed root branch',
      (tester) async {
    router = buildSwanRouter(
      feedBuilder: (_, __) => const Scaffold(body: Text('FeedScreenContent')),
      exploreBuilder: (_, __) =>
          const Scaffold(body: Text('ExploreScreenContent')),
      messagesBuilder: (_, __) =>
          const Scaffold(body: Text('MessagesScreenContent')),
      profileBuilder: (_, __) =>
          const Scaffold(body: Text('ProfileScreenContent')),
      shellBuilder: (_, __, shell) => SwanAppShell(navigationShell: shell),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FeedScreenContent'), findsOneWidget);

    // Switch to Explore branch (index 1)
    router.go(AppRoutes.explore);
    await tester.pumpAndSettle();
    expect(find.text('ExploreScreenContent'), findsOneWidget);

    // Simulate system back button via tester.binding.handlePopRoute()
    final handled = await tester.binding.handlePopRoute();
    expect(handled, isTrue,
        reason: 'PopScope should handle back on non-feed branch');
    await tester.pumpAndSettle();

    // Now it should have switched back to Feed branch (index 0)
    expect(find.text('FeedScreenContent'), findsOneWidget);
  });

  testWidgets(
      'SwanNavigation helper switches branch for shell roots and pushes within branch',
      (tester) async {
    router = buildSwanRouter(
      feedBuilder: (context, _) => Scaffold(
        body: TextButton(
          onPressed: () => context.swanGo(AppRoutes.explore),
          child: const Text('GoExplore'),
        ),
      ),
      exploreBuilder: (context, _) => Scaffold(
        body: TextButton(
          onPressed: () => context.swanGo(AppRoutes.messages),
          child: const Text('GoMessages'),
        ),
      ),
      messagesBuilder: (_, __) => const Scaffold(body: Text('MessagesContent')),
      profileBuilder: (_, __) => const Scaffold(body: Text('ProfileContent')),
      shellBuilder: (_, __, shell) => SwanAppShell(navigationShell: shell),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GoExplore'), findsOneWidget);

    // Tap to go to explore
    await tester.tap(find.text('GoExplore'));
    await tester.pumpAndSettle();

    expect(find.text('GoMessages'), findsOneWidget);

    // Tap to go to messages
    await tester.tap(find.text('GoMessages'));
    await tester.pumpAndSettle();

    expect(find.text('MessagesContent'), findsOneWidget);
  });
}
