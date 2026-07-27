import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/swansport_app.dart';
import 'package:swansport_app/features/athlete_workspace/presentation/screens/athlete_workspace_screen.dart';
import 'package:swansport_app/features/home/application/home_controller.dart';
import 'package:swansport_app/features/home/domain/home_command_center.dart';
import 'package:swansport_app/features/home/presentation/screens/home_command_center_screen.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

void main() {
  testWidgets(
      'home command center renders header, kpi strip, agenda, tasks, and alerts',
      (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          darkTheme: SwanTheme.dark(),
          home: const HomeCommandCenterScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.byKey(const Key('home-command-header')), findsOneWidget);
    expect(find.byKey(const Key('home-agenda-card')), findsOneWidget);
    expect(find.byKey(const Key('home-tasks-card')), findsOneWidget);
    expect(find.byKey(const Key('home-alerts-card')), findsOneWidget);
    expect(find.byKey(const Key('home-fav-modules-grid')), findsOneWidget);
  });

  testWidgets('role switcher dropdown changes current role in state',
      (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const HomeCommandCenterScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.byKey(const Key('home-role-switcher')), findsOneWidget);
    await t.tap(find.byKey(const Key('home-role-switcher')));
    await t.pumpAndSettle();

    final itemFinder =
        find.widgetWithText(DropdownMenuItem<HomeRole>, 'Finans Yöneticisi');
    await t.tap(itemFinder);
    await t.pumpAndSettle();

    expect(find.textContaining('Finans Yöneticisi'), findsAtLeastNWidgets(1));
  });

  testWidgets('global search filters tasks and alerts in real-time', (t) async {
    t.view.physicalSize = const Size(1200, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const HomeCommandCenterScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(find.byKey(const Key('home-global-search')), findsOneWidget);
    await t.enterText(
      find.byKey(const Key('home-global-search')),
      'Ece Sönmez',
    );
    await t.pumpAndSettle();

    expect(find.textContaining('Ece Sönmez'), findsAtLeastNWidgets(1));
  });

  testWidgets(
      'home command center renders responsively across device sizes and light/dark themes',
      (t) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final w in mode == ThemeMode.light
          ? [375.0, 600.0, 768.0, 1024.0, 1440.0]
          : [375.0, 1024.0]) {
        t.view.physicalSize = Size(w, 1000);
        t.view.devicePixelRatio = 1;

        await t.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: SwanTheme.light(),
              darkTheme: SwanTheme.dark(),
              themeMode: mode,
              home: const HomeCommandCenterScreen(),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);

        await t.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('1-click module navigation from favorite launcher works',
      (t) async {
    t.view.physicalSize = const Size(1024, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    await t.pumpWidget(const ProviderScope(child: SwanSportApp()));
    await t.pumpAndSettle();

    final nav = t.state<NavigatorState>(find.byType(Navigator));
    unawaited(nav.pushNamed('/home-command'));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('home-fav-modules-grid')), findsOneWidget);

    final sportsTile = find.widgetWithText(InkWell, 'Sporcu Yönetimi').first;
    await t.tap(sportsTile);
    await t.pumpAndSettle();

    expect(find.byType(AthleteWorkspaceScreen), findsOneWidget);
  });

  test('notifications, personalization and RBAC mutate deterministically', () {
    final controller = HomeController(FixtureHomeRepository());
    expect(controller.state.unreadNotificationCount, 2);
    controller.markNotificationRead(controller.state.notifications.first.id);
    expect(controller.state.unreadNotificationCount, 1);
    controller.toggleNotificationPinned(controller.state.notifications.last.id);
    expect(controller.state.notifications.last.isPinned, isTrue);

    controller.toggleWidgetCollapsed('agenda');
    controller.toggleWidgetPinned('tasks');
    controller.moveWidget('activity', -2);
    expect(
      controller.state.widgetPreferences
          .firstWhere((item) => item.id == 'agenda')
          .collapsed,
      isTrue,
    );
    expect(controller.state.visibleWidgets.first.pinned, isTrue);
    controller.hideWidget('alerts');
    expect(
      controller.state.visibleWidgets.any((item) => item.id == 'alerts'),
      isFalse,
    );
    controller.restoreWidgets();
    expect(
      controller.state.visibleWidgets.any((item) => item.id == 'alerts'),
      isTrue,
    );

    controller.changeRole(HomeRole.athlete);
    final task = controller.state.tasks.first;
    controller.completeTask(task.id);
    expect(controller.state.tasks.first.isCompleted, isFalse);
    controller.search('ödeme');
    expect(controller.state.globalResults, isEmpty);
  });

  testWidgets('notifications, branch selection and widget manager interact',
      (t) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          home: const HomeCommandCenterScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('home-branch-selector')), findsOneWidget);
    expect(find.byKey(const Key('home-operational-status')), findsOneWidget);
    expect(find.byKey(const Key('home-widget-manager')), findsOneWidget);

    await t.tap(find.byKey(const Key('home-notifications')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('home-notification-center')), findsOneWidget);
    expect(find.text('Bildirim Merkezi'), findsOneWidget);
  });

  testWidgets('home command center remains safe at 2x text scale', (t) async {
    t.view.physicalSize = const Size(375, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: SwanTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: const HomeCommandCenterScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
