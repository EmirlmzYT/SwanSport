import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_app/app/navigation/app_router.dart';

void main() {
  late GoRouter router;

  tearDown(() => router.dispose());

  testWidgets('four branches keep independent widget state', (tester) async {
    router = buildSwanRouter(
      feedBuilder: (_, __) => const _Branch(label: 'feed'),
      exploreBuilder: (_, __) => const _Branch(label: 'explore'),
      messagesBuilder: (_, state) =>
          _Branch(label: 'messages-${state.uri.queryParameters['tab']}'),
      profileBuilder: (_, __) => const _Branch(label: 'profile'),
      shellBuilder: (_, __, shell) => Scaffold(
        body: shell,
        bottomNavigationBar: Row(
          children: List<Widget>.generate(
            4,
            (index) => TextButton(
              key: Key('branch-$index'),
              onPressed: () => shell.goBranch(index),
              child: Text('$index'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.enterText(find.byKey(const Key('field-feed')), 'korunur');

    await tester.tap(find.byKey(const Key('branch-1')));
    await tester.pumpAndSettle();
    expect(find.text('explore'), findsOneWidget);

    await tester.tap(find.byKey(const Key('branch-0')));
    await tester.pumpAndSettle();
    expect(find.text('korunur'), findsOneWidget);
  });

  testWidgets('legacy communities path opens messages community tab',
      (tester) async {
    router = buildSwanRouter(
      initialLocation: '/topluluklar',
      feedBuilder: (_, __) => const _Branch(label: 'feed'),
      exploreBuilder: (_, __) => const _Branch(label: 'explore'),
      messagesBuilder: (_, state) =>
          _Branch(label: 'messages-${state.uri.queryParameters['tab']}'),
      profileBuilder: (_, __) => const _Branch(label: 'profile'),
      shellBuilder: (_, __, shell) => Scaffold(body: shell),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('messages-communities'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/mesajlar');
  });

  testWidgets('unknown path has a dedicated not-found screen', (tester) async {
    router = buildSwanRouter(
      initialLocation: '/olmayan-sayfa',
      feedBuilder: (_, __) => const _Branch(label: 'feed'),
      exploreBuilder: (_, __) => const _Branch(label: 'explore'),
      messagesBuilder: (_, __) => const _Branch(label: 'messages'),
      profileBuilder: (_, __) => const _Branch(label: 'profile'),
      shellBuilder: (_, __, shell) => Scaffold(body: shell),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Sayfa bulunamadı'), findsOneWidget);
    expect(find.text('/olmayan-sayfa'), findsOneWidget);
  });

  testWidgets('legacy fallback receives direct old locations', (tester) async {
    router = buildSwanRouter(
      initialLocation: '/calendar',
      feedBuilder: (_, __) => const _Branch(label: 'feed'),
      exploreBuilder: (_, __) => const _Branch(label: 'explore'),
      messagesBuilder: (_, __) => const _Branch(label: 'messages'),
      profileBuilder: (_, __) => const _Branch(label: 'profile'),
      shellBuilder: (_, __, shell) => Scaffold(body: shell),
      legacyFallbackBuilder: (_, state) => Text('legacy:${state.uri.path}'),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('legacy:/calendar'), findsOneWidget);
  });
}

class _Branch extends StatelessWidget {
  const _Branch({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label),
            TextField(key: Key('field-$label')),
          ],
        ),
      );
}
