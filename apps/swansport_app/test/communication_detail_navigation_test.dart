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
}
