import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/announcements/domain/models/communication_center.dart';
import 'package:swansport_app/features/announcements/presentation/routing/communication_detail_route_args.dart';
import 'package:swansport_models/swansport_models.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await tester.pumpAndSettle();
  }

  NavigatorState navigator(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator));

  void push(
    WidgetTester tester,
    String route, {
    Object? arguments,
  }) =>
      unawaited(
        navigator(tester).pushNamed(route, arguments: arguments),
      );

  testWidgets('registered typed route opens correct communication',
      (tester) async {
    await pumpApp(tester);
    push(
      tester,
      '/communication-detail',
      arguments: const CommunicationDetailRouteArgs(
        communicationId: SwanId('communication_facility'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tesis Bakım Çalışması Hakkında'), findsOneWidget);
  });

  testWidgets('missing and wrong arguments fail safely', (tester) async {
    await pumpApp(tester);
    for (final arguments in [null, 'wrong']) {
      push(
        tester,
        '/communication-detail',
        arguments: arguments,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('communication-detail-invalid-route')),
        findsOneWidget,
      );
      navigator(tester).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('unknown and unauthorized detail requests fail safely',
      (tester) async {
    await pumpApp(tester);
    push(
      tester,
      '/communication-detail',
      arguments: const CommunicationDetailRouteArgs(
        communicationId: SwanId('missing'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('communication-detail-not-found')),
      findsOneWidget,
    );
    navigator(tester).pop();
    await tester.pumpAndSettle();

    push(
      tester,
      '/communication-detail',
      arguments: const CommunicationDetailRouteArgs(
        communicationId: SwanId('communication_facility'),
        role: CommunicationRole.guardian,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('communication-detail-permission-denied')),
      findsOneWidget,
    );
  });

  testWidgets('feed card opens detail and back preserves search and filter',
      (tester) async {
    await pumpApp(tester);
    push(tester, '/announcements');
    await tester.pumpAndSettle();
    expect(find.text('Duyurular & Bültenler'), findsOneWidget);

    final search = find.byKey(const Key('communication-search-field'));
    await tester.enterText(search, 'tesis');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Duyuru'));
    await tester.pumpAndSettle();

    final title = find.text('Tesis Bakım Çalışması Hakkında');
    await tester.tap(
      find.ancestor(of: title, matching: find.byType(InkWell)).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communication-detail-title')), findsOneWidget);

    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(search).controller!.text,
      'tesis',
    );
    expect(
      tester
          .widget<FilterChip>(
            find.widgetWithText(FilterChip, 'Duyuru'),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('detail opens linked athlete and back preserves detail state',
      (tester) async {
    await pumpApp(tester);
    push(
      tester,
      '/communication-detail',
      arguments: const CommunicationDetailRouteArgs(
        communicationId: SwanId('communication_facility'),
      ),
    );
    await tester.pumpAndSettle();

    final link = find.byKey(
      const Key('communication-operational-link-athlete_can_yilmaz'),
    );
    expect(link, findsOneWidget);
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Can Yılmaz'), findsWidgets);

    navigator(tester).pop();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('communication-detail-title')),
      findsOneWidget,
    );
    expect(link, findsOneWidget);
  });

  testWidgets('/announcements remains registered', (tester) async {
    await pumpApp(tester);
    push(tester, '/announcements');
    await tester.pumpAndSettle();
    expect(find.text('Duyurular & Bültenler'), findsOneWidget);
  });
}
